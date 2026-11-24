import copy
import io
import json
import os
import pathlib
import signal
import subprocess
import types
import unittest
import xml.etree.ElementTree as ET
from contextlib import redirect_stdout, redirect_stderr
from unittest import mock

from backend import p2p_docker_control_helper as helper
from backend import p2p_restricted_discovery as client
from backend.p2p_catalog import DOCKER_ALIASES
from backend.p2p_inspection import ServiceInspector
from control_test_support import CONTROL, ControlTestCase, ROOT
from restricted_discovery_test import fixture, IDENTITY

OTHER = "b"*64


class ControlHelperTests(unittest.TestCase):
  def setUp(self):
    self.items = {IDENTITY:fixture(),OTHER:fixture()}
    self.items[OTHER]["Id"] = OTHER
    for item in self.items.values(): item["State"]["Error"] = ""
    self.calls = []
  def api(self,method,path):
    self.calls.append((method,path))
    identity = path.split("/")[2]
    item = self.items[identity]
    if method == "GET": return copy.deepcopy(item)
    action = path.split("/")[3].split("?")[0]
    item["State"]["Running"] = action != "stop"
  def test_canonical_per_service_aliases(self): self.assertEqual(helper.SERVICE_ALIASES,DOCKER_ALIASES)
  def test_three_operations_use_only_immutable_ids_and_fixed_endpoints(self):
    for action in ("start","stop","restart"):
      self.calls = []
      self.items[IDENTITY]["State"]["Running"] = action != "start"
      result = helper.control([action,"syncthing",IDENTITY],api=self.api)
      self.assertEqual(result,{"checked":1,"completed":1,"mutated":True})
      posts = [path for method,path in self.calls if method=="POST"]
      self.assertEqual(posts,["/containers/"+IDENTITY+"/"+action+("?t=5" if action!="start" else "")])
      self.assertEqual(self.items[IDENTITY]["State"]["Running"],action!="stop")
  def test_check_mode_validates_without_mutating(self):
    result = helper.control(["--check","restart","syncthing",IDENTITY],api=self.api)
    self.assertFalse(result["mutated"])
    self.assertEqual(result["completed"],0)
    self.assertTrue(all(method=="GET" for method,_ in self.calls))
  def test_noop_start_and_stop_do_not_post(self):
    self.assertEqual(helper.control(["start","syncthing",IDENTITY],api=self.api)["completed"],0)
    self.items[IDENTITY]["State"]["Running"] = False
    self.assertEqual(helper.control(["stop","syncthing",IDENTITY],api=self.api)["completed"],0)
    self.assertTrue(all(method=="GET" for method,_ in self.calls))
  def test_invalid_input_is_rejected_before_any_request(self):
    for arguments in [[],["exec","syncthing",IDENTITY],["stop","custom",IDENTITY],["stop","syncthing","/etc/passwd"],
                      ["stop","syncthing","-a"],["stop","syncthing",IDENTITY,IDENTITY],
                      ["stop","syncthing"]+[format(n,"064x") for n in range(17)]]:
      with self.assertRaises(helper.ControlError): helper.control(arguments,api=self.api)
    self.assertEqual(self.calls,[])
  def test_all_targets_are_preflighted_before_any_mutation(self):
    self.items[OTHER]["Config"]["Image"] = "postgres"
    self.items[OTHER]["Config"]["Labels"] = {}
    self.items[OTHER]["Name"] = "/database"
    with self.assertRaisesRegex(helper.ControlError,"service_mismatch"):
      helper.control(["stop","syncthing",IDENTITY,OTHER],api=self.api)
    self.assertTrue(all(method=="GET" for method,_ in self.calls))
  def test_replaced_identity_or_changed_service_is_rejected_on_reinspection(self):
    calls = 0
    def changed(method,path):
      nonlocal calls
      calls += 1
      result = self.api(method,path)
      if calls == 2: result["Id"] = OTHER
      return result
    with self.assertRaisesRegex(helper.ControlError,"identity_changed"):
      helper.control(["stop","syncthing",IDENTITY],api=changed)
    self.assertTrue(all(method=="GET" for method,_ in self.calls))
  def test_init_sidecars_and_wrong_services_cannot_be_controlled(self):
    self.items[IDENTITY]["Name"] = "/syncthing-init"
    with self.assertRaisesRegex(helper.ControlError,"service_mismatch"):
      helper.control(["restart","syncthing",IDENTITY],api=self.api)
    self.items[IDENTITY]["Name"] = "/peer"
    with self.assertRaisesRegex(helper.ControlError,"service_mismatch"):
      helper.control(["restart","ipfs",IDENTITY],api=self.api)
    self.assertTrue(all(method=="GET" for method,_ in self.calls))
  def test_partial_failure_reports_accepted_operations_without_second_post(self):
    def fail(method,path):
      if OTHER in path and len(self.calls)>3: raise helper.ControlError("target_unavailable")
      return self.api(method,path)
    with self.assertRaises(helper.ControlError) as error:
      helper.control(["stop","syncthing",IDENTITY,OTHER],api=fail)
    self.assertEqual(error.exception.completed,1)
    self.assertEqual(len([1 for method,_ in self.calls if method=="POST"]),1)
  def test_unconfirmed_state_is_a_failure(self):
    def never_changes(method,path):
      self.calls.append((method,path))
      return copy.deepcopy(self.items[IDENTITY]) if method=="GET" else None
    ticks = iter([0,6])
    with self.assertRaisesRegex(helper.ControlError,"state_not_confirmed"):
      helper.control(["stop","syncthing",IDENTITY],api=never_changes,clock=lambda:next(ticks))
  def test_caller_guard_checks_uid_and_stops_requests_when_parent_exits(self):
    with mock.patch.dict(helper.os.environ,{"PKEXEC_UID":"1000"}), mock.patch.object(helper.os,"getppid",return_value=42), \
         mock.patch.object(helper.os,"stat",return_value=types.SimpleNamespace(st_uid=1000)), \
         mock.patch.object(helper.os,"pidfd_open",return_value=77), \
         mock.patch.object(helper.select,"select",return_value=([77],[],[])), mock.patch.object(helper,"request") as request:
      descriptor,api = helper.caller_guard()
      self.assertEqual(descriptor,77)
      with self.assertRaisesRegex(helper.ControlError,"caller_cancelled"): api("POST","/containers/"+IDENTITY+"/stop")
      request.assert_not_called()
    with mock.patch.dict(helper.os.environ,{"PKEXEC_UID":"bad"}), self.assertRaisesRegex(helper.ControlError,"invalid_caller"):
      helper.caller_guard()
  def test_lock_refuses_concurrent_requests_or_untrusted_files(self):
    info = types.SimpleNamespace(st_uid=0,st_mode=0o100600,st_nlink=1)
    with mock.patch.object(helper.os,"open",return_value=77), mock.patch.object(helper.os,"fstat",return_value=info), \
         mock.patch.object(helper.os,"close") as close, mock.patch.object(helper.fcntl,"flock",side_effect=BlockingIOError):
      with self.assertRaisesRegex(helper.ControlError,"control_busy"): helper.acquire_lock()
      close.assert_called_once_with(77)
    info.st_uid = 1000
    with mock.patch.object(helper.os,"open",return_value=77), mock.patch.object(helper.os,"fstat",return_value=info), mock.patch.object(helper.os,"close"):
      with self.assertRaisesRegex(helper.ControlError,"unsafe_lock"): helper.acquire_lock()
  def test_http_boundary_has_no_command_output_and_accepts_only_expected_statuses(self):
    connection = mock.Mock(); response = connection.getresponse.return_value
    response.status = 204; response.read.return_value = b""
    with mock.patch.object(helper,"DockerConnection",return_value=connection): helper.request("POST","/containers/"+IDENTITY+"/stop?t=5")
    self.assertEqual(connection.request.call_args.args,("POST","/containers/"+IDENTITY+"/stop?t=5"))
    self.assertEqual(connection.request.call_args.kwargs["body"],b"")
    response.status = 500; response.read.return_value = b"private-token"
    with mock.patch.object(helper,"DockerConnection",return_value=connection), self.assertRaisesRegex(helper.ControlError,"operation_failed"):
      helper.request("POST","/containers/"+IDENTITY+"/stop?t=5")
  def test_main_cannot_run_as_unprivileged_user(self):
    with mock.patch.object(helper.os,"geteuid",return_value=1000), mock.patch.object(helper,"request") as request:
      self.assertEqual(helper.main(),2)
      request.assert_not_called()


class PolicyTests(unittest.TestCase):
  def test_policy_is_bound_to_only_controller_with_no_retained_authorization(self):
    policy = ET.parse(ROOT/"scripts"/client.CONTROL_POLICY.name)
    action = policy.getroot().find("action")
    self.assertEqual(action.get("id"),client.CONTROL_ACTION_ID)
    self.assertEqual([action.findtext("defaults/"+scope) for scope in ("allow_any","allow_inactive","allow_active")],["no","no","auth_admin"])
    self.assertEqual({n.get("key"):n.text for n in action.findall("annotate")},{"org.freedesktop.policykit.exec.path":str(client.CONTROL_HELPER)})
  def test_missing_or_untrusted_policy_disables_control_capability(self):
    with mock.patch.object(client,"trusted_helper",return_value=False): self.assertFalse(client.controls_available())
    content = (ROOT/"scripts"/client.CONTROL_POLICY.name).read_bytes()
    for allowed in (True,False):
      data = content if allowed else content.replace(b"auth_admin",b"auth_admin_keep")
      with mock.patch.object(client,"trusted_helper",return_value=True), mock.patch.object(pathlib.Path,"open",return_value=io.BytesIO(data)):
        self.assertEqual(client.controls_available(),allowed)


class AuthorizedClientTests(unittest.TestCase):
  def setUp(self):
    self.service = {"id":"syncthing"}
    self.item = fixture(); self.item["_discovery_only"] = True
  def test_selection_is_explicit_and_never_uses_passwordless_sudo(self):
    with mock.patch.object(client,"controls_available",return_value=True):
      command = client.control_command(self.service,"restart",[self.item])
    self.assertEqual(command,["/usr/bin/pkexec","--disable-internal-agent",str(client.CONTROL_HELPER),"restart","syncthing",IDENTITY])
  def test_no_capability_custom_or_mixed_targets_fail_closed(self):
    with mock.patch.object(client,"controls_available",return_value=False), self.assertRaises(RuntimeError):
      client.control_command(self.service,"stop",[self.item])
    with mock.patch.object(client,"controls_available",return_value=True):
      for service,action,items in [(dict(self.service,custom=True),"stop",[self.item]),(self.service,"config",[self.item]),
                                  (self.service,"stop",[dict(self.item,_discovery_only=False)])]:
        with self.assertRaises((RuntimeError,ValueError)): client.control_command(service,action,items)
  def test_cancelled_authorization_preserves_exit_126_and_does_not_retry(self):
    process = mock.Mock(pid=77,returncode=126); process.communicate.return_value = (None,"")
    with mock.patch.object(client,"controls_available",return_value=True), mock.patch.object(client.subprocess,"Popen",return_value=process) as launch, \
         mock.patch.object(client.signal,"signal"), redirect_stdout(output:=io.StringIO()):
      with self.assertRaises(subprocess.CalledProcessError) as error: client.authorized_control(self.service,"stop",[self.item])
    self.assertEqual(error.exception.returncode,126)
    launch.assert_called_once()
    self.assertTrue(launch.call_args.kwargs["start_new_session"])
    self.assertEqual(json.loads(output.getvalue())["phase"],"authorization")
  def test_timeout_terminates_only_owned_group_and_never_falls_back_to_sudo(self):
    process = mock.Mock(pid=77); process.communicate.side_effect = subprocess.TimeoutExpired("pkexec",225)
    with mock.patch.object(client,"controls_available",return_value=True), mock.patch.object(client.subprocess,"Popen",return_value=process), \
         mock.patch.object(client.signal,"signal"), mock.patch.object(client.os,"killpg") as kill, redirect_stdout(io.StringIO()):
      with self.assertRaisesRegex(RuntimeError,"timed out"): client.authorized_control(self.service,"stop",[self.item])
    kill.assert_called_once_with(77,signal.SIGTERM)
  def test_signal_cancellation_restores_handlers_and_exits_without_retry(self):
    process = mock.Mock(pid=77)
    handlers = {}
    def install(kind,handler):
      handlers[kind]=handler
      return "old"
    def communicate(**_kwargs): handlers[signal.SIGTERM](signal.SIGTERM,None)
    process.communicate.side_effect = communicate
    with mock.patch.object(client,"controls_available",return_value=True), mock.patch.object(client.subprocess,"Popen",return_value=process), \
         mock.patch.object(client.signal,"signal",side_effect=install), mock.patch.object(client.os,"killpg",side_effect=PermissionError), redirect_stdout(io.StringIO()):
      with self.assertRaises(SystemExit) as error: client.authorized_control(self.service,"stop",[self.item])
    self.assertEqual(error.exception.code,143)
    self.assertEqual(handlers[signal.SIGTERM],"old")
  def test_untrusted_error_text_is_not_exposed(self):
    process = mock.Mock(pid=77,returncode=1); process.communicate.return_value = (None,"private-token")
    with mock.patch.object(client,"controls_available",return_value=True), mock.patch.object(client.subprocess,"Popen",return_value=process), \
         mock.patch.object(client.signal,"signal"), redirect_stdout(io.StringIO()):
      with self.assertRaises(RuntimeError) as error: client.authorized_control(self.service,"stop",[self.item])
    self.assertNotIn("private-token",str(error.exception))


class AuthorizedIntegrationTests(ControlTestCase):
  def test_restricted_actions_use_authorization_path_and_never_direct_docker(self):
    item = fixture(); item["_discovery_only"] = True
    with mock.patch.object(CONTROL.PROBE,"docker_matches",return_value=[item]), mock.patch.object(CONTROL.PROBE,"unit_state",return_value=("",False)), \
         mock.patch.object(CONTROL,"authorized_control") as authorize, mock.patch.object(CONTROL.subprocess,"check_call") as direct, redirect_stdout(io.StringIO()):
      CONTROL.control(self.service("syncthing"),"restart")
    authorize.assert_called_once_with(self.service("syncthing"),"restart",[item])
    direct.assert_not_called()
  def test_active_systemd_ambiguity_denies_before_authorization(self):
    item = fixture(); item["_discovery_only"] = True
    with mock.patch.object(CONTROL.PROBE,"docker_matches",return_value=[item]), mock.patch.object(CONTROL.PROBE,"unit_state",return_value=("syncthing.service",True)), \
         mock.patch.object(CONTROL,"authorized_control") as authorize:
      with self.assertRaisesRegex(RuntimeError,"multiple control backends"): CONTROL.control(self.service("syncthing"),"restart")
    authorize.assert_not_called()
