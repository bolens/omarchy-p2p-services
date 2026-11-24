import ast
import copy
import importlib.machinery
import importlib.util
import io
import json
import pathlib
import stat
import types
import unittest
from contextlib import redirect_stdout
from unittest import mock

from backend import p2p_docker_helper as helper
from backend import p2p_restricted_discovery as client
from backend.p2p_actions import container_action_commands
from backend.p2p_catalog import DOCKER_ALIASES
from backend.p2p_inspection import ServiceInspector
from backend.p2p_runtime import RuntimeProbe
from backend.p2p_snapshot import SnapshotContext
from control_test_support import CONTROL, ControlTestCase, ROOT

IDENTITY = "a" * 64


def fixture():
  return {"Id":IDENTITY,"Name":"/peer","Config":{"Image":"example/syncthing:latest","Env":["TOKEN=private-token"],
    "Labels":{"com.docker.compose.service":"syncthing","unrelated.secret":"private-token",
      "com.docker.compose.project.working_dir":"/srv/sync", "com.docker.compose.project.config_files":"/srv/sync/compose.yaml",
      "traefik.http.routers.sync.rule":"Host(`sync.example.test`)","traefik.http.middlewares.auth.basicauth.users":"private-token"}},
    "Mounts":[{"Source":"/private-token"}],"State":{"Running":True,"Pid":123,"Status":"running","ExitCode":0,
      "StartedAt":"2026-11-23T10:00:00Z","Error":"private-token","Health":{"Status":"healthy","Log":["private-token"]}},
    "RestartCount":2,"NetworkSettings":{"Ports":{"8384/tcp":[{"HostIp":"127.0.0.1","HostPort":"8385"}]}}}


class HelperTests(unittest.TestCase):
  def test_aliases_match_canonical_registry_and_reject_prefix_collisions(self):
    self.assertEqual(helper.ALIASES, {alias for values in DOCKER_ALIASES.values() for alias in values})
    self.assertFalse(helper.matches("syncthing-backup","unrelated",{}))
    self.assertTrue(helper.matches("peer","example/syncthing:latest",{}))
    self.assertTrue(helper.matches("peer","unrelated",{"com.docker.compose.service":"syncthing"}))

  def test_projection_omits_secrets_and_preserves_discovery_fields(self):
    result = helper.project(fixture())
    self.assertNotIn("private-token",json.dumps(result))
    self.assertEqual(result["State"]["Error"],"Container reported an error")
    self.assertEqual(result["State"]["Health"],{"Status":"healthy"})
    self.assertEqual(result["NetworkSettings"]["Ports"]["8384/tcp"][0]["HostPort"],"8385")
    self.assertEqual(result["Config"]["Labels"]["traefik.http.routers.sync.rule"],"Host(`sync.example.test`)")
    self.assertNotIn("Env", result["Config"])
    item = fixture(); item["Config"]["Image"] = "unrelated"; item["Config"]["Labels"] = {}
    self.assertIsNone(helper.project(item))

  def test_invalid_id_cannot_become_an_api_path(self):
    item = fixture(); item["Id"] = "../../exec"
    with self.assertRaises(ValueError): helper.project(item)
    get = mock.Mock(return_value=[{"Id":"../exec","Names":["/syncthing"]}])
    with self.assertRaises(ValueError): helper.collect(get,lambda:0)
    self.assertEqual(get.call_count,1)

  def test_collector_only_inspects_matches_and_projects_stats_and_events(self):
    calls = []
    def get(path):
      calls.append(path)
      if path == "/containers/json?all=1": return [
        {"Id":"b"*64,"Names":["/database"],"Image":"postgres"},
        {"Id":IDENTITY,"Names":["/peer"],"Image":"example/syncthing:latest"}]
      if path.endswith("/json"): return fixture()
      if "/stats?" in path: return {"networks":{"eth0":{"rx_bytes":42,"tx_bytes":84}},"secret":"private-token"}
      if path.startswith("/events?"): return [
        {"Action":"die","Actor":{"ID":IDENTITY,"Attributes":{"exitCode":"9","secret":"private-token"}}},
        {"Action":"start","Actor":{"ID":IDENTITY}}, {"Action":"exec_start","Actor":{"ID":IDENTITY}}]
      raise AssertionError(path)
    result = helper.collect(get,lambda:0)
    self.assertEqual(len(result["containers"]),1)
    self.assertEqual(result["containers"][0]["traffic"],[42,84])
    self.assertEqual(result["containers"][0]["events"],[{"Action":"die","ExitCode":9},{"Action":"start","ExitCode":0}])
    self.assertNotIn("private-token",json.dumps(result))
    self.assertEqual(len(calls),4)
    self.assertFalse(any("b"*64 in path for path in calls))

  def test_deadlines_and_optional_probe_failures_are_explicit(self):
    with self.assertRaises(ValueError): helper.collect(lambda _: {},lambda:0)
    get = mock.Mock(return_value=[{"Id":IDENTITY,"Names":["/syncthing"]}])
    result = helper.collect(get,iter([0,11]).__next__)
    self.assertEqual(result["containers"],[])
    self.assertIn("restricted_docker_partial",result["diagnostics"])
    def failed(path):
      if path == "/containers/json?all=1": return [{"Id":IDENTITY,"Names":["/syncthing"]}]
      if path.endswith("/json"): return fixture()
      raise PermissionError("private-token")
    result = helper.collect(failed,lambda:0)
    self.assertEqual(len(result["containers"]),1)
    self.assertEqual(result["diagnostics"],["restricted_docker_events_unavailable","restricted_docker_stats_unavailable"])
    self.assertNotIn("private-token",json.dumps(result))

  def test_http_boundary_only_uses_get_and_bounded_reads(self):
    connection = mock.Mock()
    response = connection.getresponse.return_value
    response.status = 200; response.read.return_value = b'[]'
    with mock.patch.object(helper,"DockerConnection",return_value=connection):
      self.assertEqual(helper.request("/containers/json?all=1"),[])
    self.assertEqual(connection.request.call_args.args,("GET","/containers/json?all=1"))
    response.read.assert_called_once_with(helper.MAX_BODY+1)
    connection.close.assert_called_once()
    response.read.return_value = b'x'*(helper.MAX_BODY+1)
    with mock.patch.object(helper,"DockerConnection",return_value=connection), self.assertRaises(ValueError):
      helper.request("/containers/json?all=1")

  def test_main_rejects_arguments_and_nonroot_without_reading_docker(self):
    for args,uid in [(["helper","--help"],0),(["helper"],1000)]:
      with mock.patch.object(helper.sys,"argv",args), mock.patch.object(helper.os,"geteuid",return_value=uid), mock.patch.object(helper,"collect") as collect:
        self.assertEqual(helper.main(),2)
        collect.assert_not_called()

  def test_standalone_has_no_plugin_imports_or_process_execution(self):
    source = (ROOT/"backend/p2p_docker_helper.py").read_text()
    self.assertTrue(source.startswith("#!/usr/bin/python3 -I\n"))
    imports = [node.module for node in ast.walk(ast.parse(source)) if isinstance(node,ast.ImportFrom)]
    self.assertEqual(imports,[])
    self.assertNotIn("subprocess",source)


class RestrictedClientTests(unittest.TestCase):
  def setUp(self): self.snapshot = SnapshotContext()
  def test_missing_or_untrusted_helper_never_invokes_sudo(self):
    run = mock.Mock()
    with mock.patch.object(client,"trusted_helper",return_value=False): self.assertIsNone(client.discover(run,self.snapshot))
    run.assert_not_called()

  def test_parent_ownership_permissions_and_symlinks_are_checked(self):
    path = pathlib.Path("/root/helper")
    good = types.SimpleNamespace(st_uid=0,st_mode=stat.S_IFREG|0o755)
    directory = types.SimpleNamespace(st_uid=0,st_mode=stat.S_IFDIR|0o755)
    with mock.patch.object(pathlib.Path,"lstat",side_effect=[good,directory,directory]): self.assertTrue(client.trusted_helper(path))
    for bad in [types.SimpleNamespace(st_uid=1000,st_mode=stat.S_IFREG|0o755),
                types.SimpleNamespace(st_uid=0,st_mode=stat.S_IFREG|0o777),
                types.SimpleNamespace(st_uid=0,st_mode=stat.S_IFLNK|0o777)]:
      with mock.patch.object(pathlib.Path,"lstat",return_value=bad): self.assertFalse(client.trusted_helper(path))
    with mock.patch.object(pathlib.Path,"lstat",side_effect=[good,types.SimpleNamespace(st_uid=0,st_mode=stat.S_IFDIR|0o777)]):
      self.assertFalse(client.trusted_helper(path))

  def test_no_argument_sudo_call_and_unprivileged_reprojection(self):
    row = fixture(); row["traffic"] = [42,84]; row["events"] = [{"Action":"die","ExitCode":9}]
    run = mock.Mock(return_value=types.SimpleNamespace(returncode=0,stdout=json.dumps({"version":1,"containers":[row]})))
    with mock.patch.object(client,"trusted_helper",return_value=True): rows = client.discover(run,self.snapshot)
    self.assertEqual(run.call_args.args,(["/usr/bin/sudo","-n","--",str(client.HELPER)],15))
    self.assertTrue(rows[0]["_discovery_only"])
    self.assertEqual(rows[0]["_runtime_cmd"],"")
    self.assertEqual(rows[0]["_discovery_stats"],(42,84))
    self.assertNotIn("private-token",json.dumps(rows))

  def test_malformed_payloads_fail_closed_without_printing_output(self):
    for payload in [{"version":2,"containers":[]},{"version":1,"containers":{}},[],
                    {"version":1,"containers":[{}]}, {"version":1,"containers":[],"diagnostics":["private-token"]}]:
      snapshot = SnapshotContext()
      run = mock.Mock(return_value=types.SimpleNamespace(returncode=0,stdout=json.dumps(payload)))
      with mock.patch.object(client,"trusted_helper",return_value=True), redirect_stdout(output := io.StringIO()):
        self.assertIsNone(client.discover(run,snapshot))
      self.assertEqual(output.getvalue(),"")
      self.assertEqual(snapshot.diagnostics,[{"code":"restricted_docker_invalid","runtime":"docker"}])

  def test_sudo_denial_is_a_safe_unavailable_diagnostic(self):
    with mock.patch.object(client,"trusted_helper",return_value=True):
      self.assertIsNone(client.discover(lambda *_:types.SimpleNamespace(returncode=1,stdout="private-token"),self.snapshot))
    self.assertNotIn("private-token",repr(self.snapshot.diagnostics))


class RestrictedIntegrationTests(ControlTestCase):
  def restricted_item(self):
    item = helper.project(fixture())
    item.update(_runtime="docker",_runtime_cmd="",_discovery_only=True,_discovery_stats=(42,84),_discovery_events=[{"Action":"die","ExitCode":9},{"Action":"start","ExitCode":0}])
    return item

  def test_fallback_preserves_stats_and_filters_stopped_containers_on_fast_scan(self):
    item = self.restricted_item(); stopped = copy.deepcopy(item); stopped["State"]["Running"] = False
    fallback = mock.Mock(return_value=[item,stopped]); run = mock.Mock(return_value=types.SimpleNamespace(returncode=1,stdout=""))
    snapshot = SnapshotContext(); snapshot.reset(all_containers=False)
    probe = RuntimeProbe(snapshot,run,lambda:[],"ps","systemctl",{},fallback)
    with mock.patch("backend.p2p_runtime.shutil.which",side_effect=lambda name:"/usr/bin/docker" if name=="docker" else None):
      self.assertEqual(probe.containers(),[item])
      self.assertEqual(probe.containers(),[item])
    fallback.assert_called_once()
    self.assertEqual(probe.container_stats([item]),{("docker","peer"):(42,84)})
    self.assertEqual(snapshot.diagnostics,[])

  def test_restricted_lifecycle_uses_safe_events_without_a_docker_command(self):
    item = self.restricted_item()
    item["State"]["Error"] = ""
    item["State"]["StartedAt"] = __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat()
    with mock.patch.object(CONTROL.PROBE,"unit_snapshot",return_value={}), mock.patch.object(CONTROL.PROBE,"run") as run:
      self.assertEqual(CONTROL.PROBE.service_restart_kind("",False,[item],2),"crash")
      run.assert_not_called()

  def test_direct_docker_success_does_not_use_privileged_fallback(self):
    fallback = mock.Mock()
    probe = RuntimeProbe(SnapshotContext(),lambda *_:types.SimpleNamespace(returncode=0,stdout=""),lambda:[],"ps","systemctl",{},fallback)
    with mock.patch("backend.p2p_runtime.shutil.which",side_effect=lambda name:"/usr/bin/docker" if name=="docker" else None):
      self.assertEqual(probe.containers(),[])
    fallback.assert_not_called()

  def test_cli_and_planner_cannot_control_discovery_only_containers(self):
    item = self.restricted_item()
    for action in ("start","stop","restart","config"):
      with mock.patch.object(CONTROL.PROBE,"docker_matches",return_value=[item]), mock.patch.object(CONTROL.PROBE,"unit_state",return_value=("",False)), mock.patch.object(CONTROL.subprocess,"check_call") as launch:
        with self.assertRaises(RuntimeError): CONTROL.control(self.service("syncthing"),action)
        launch.assert_not_called()
    with self.assertRaises(ValueError): container_action_commands([item],"stop")
    with mock.patch.object(CONTROL.PROBE,"docker_matches",return_value=[item]), self.assertRaisesRegex(RuntimeError,"log access"):
      CONTROL.show_logs(self.service("syncthing"))

  def test_status_projects_observation_only_and_privacy_with_container_counters(self):
    item = self.restricted_item()
    snapshot = CONTROL.SNAPSHOT
    snapshot.container_stats = {("docker","peer"):(42,84)}
    with mock.patch.object(CONTROL.PROBE,"docker_matches",return_value=[item]), \
         mock.patch.object(CONTROL.PROBE,"pids_for",return_value=[]), \
         mock.patch.object(CONTROL.PROBE,"unit_state",return_value=("",False)), \
         mock.patch.object(CONTROL.PROBE,"unit_main_pid",return_value=0), \
         mock.patch.object(CONTROL.PROBE,"unit_snapshot",return_value={}), \
         mock.patch.object(CONTROL.PROBE,"unit_uptime",return_value=0), \
         mock.patch.object(CONTROL.PROBE,"pid_uptime",return_value=0), \
         mock.patch.object(CONTROL.PROBE,"service_restart_kind",return_value="crash"), \
         mock.patch.object(CONTROL.PROBE,"service_stop_kind",return_value=("","")), \
         mock.patch.object(CONTROL.PROBE,"proxy_candidates",return_value=[]):
      inspector = ServiceInspector(CONTROL.PROBE,snapshot,lambda *_:(0,0,[]),lambda *_:[])
      status = inspector.inspect(self.service("syncthing"),True)
      item["_authorization_control"] = True
      authorized = inspector.inspect(self.service("syncthing"),True)
      with mock.patch.object(CONTROL.PROBE,"unit_state",return_value=("syncthing.service",True)):
        ambiguous = inspector.inspect(self.service("syncthing"),True)
      direct = dict(item,_runtime="podman",_discovery_only=False)
      with mock.patch.object(CONTROL.PROBE,"docker_matches",return_value=[item,direct]):
        mixed = inspector.inspect(self.service("syncthing"),True)
    self.assertTrue(authorized["controllable"])
    self.assertTrue(authorized["authorizationRequired"])
    self.assertTrue(authorized["discoveryOnly"])
    self.assertFalse(ambiguous["controllable"])
    self.assertFalse(mixed["controllable"])
    self.assertTrue(status["active"])
    self.assertFalse(status["controllable"])
    self.assertTrue(status["discoveryOnly"])
    self.assertEqual(status["backend"],"docker")
    self.assertEqual(status["rxBytes"],42)
    self.assertEqual(status["pids"],[])
    self.assertEqual(status["containers"],[])


class InstallerTests(unittest.TestCase):
  def test_rule_grants_only_fixed_helper_with_no_arguments(self):
    loader = importlib.machinery.SourceFileLoader("restricted_installer",str(ROOT/"scripts/install-restricted-discovery"))
    spec = importlib.util.spec_from_loader(loader.name,loader)
    module = importlib.util.module_from_spec(spec); loader.exec_module(module)
    with mock.patch.object(module.pwd,"getpwnam",return_value=types.SimpleNamespace(pw_uid=1000)):
      self.assertEqual(module.sudo_rule("testuser").decode().splitlines()[-1], 'testuser ALL=(root) NOPASSWD: NOSETENV: /usr/local/libexec/omarchy-p2p-discover ""')
      for invalid in ("root ALL", "user\nALL", "user*", "../user"):
        with self.assertRaises(ValueError): module.sudo_rule(invalid)
