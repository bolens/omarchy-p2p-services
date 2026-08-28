import io
import pathlib
import subprocess
import tempfile
import types
from contextlib import redirect_stdout
from unittest import mock

from control_test_support import CONTROL, ControlTestCase


class ControlIntegrationTests(ControlTestCase):
  def test_managed_install_sources_are_explicit(self):
    expected_aur = {
      "airdcpp": "airdcpp-webclient", "eiskaltdcpp": "eiskaltdcpp-qt",
      "zeronet": "zeronet", "gnunet": "gnunet", "retroshare": "retroshare-git", "lokinet": "lokinet",
      "veilid": "veilid", "slskd": "slskd-bin", "soulseekqt": "soulseekqt",
      "tribler": "tribler-bin", "webtorrent": "webtorrent-cli",
      "opentracker": "opentracker", "lnd": "lnd",
      "netbird": "netbird",
    }
    self.assertEqual(CONTROL.AUR_INSTALL_IDS, frozenset(expected_aur))
    for service_id, package in expected_aur.items():
      self.assertEqual(CONTROL.PACKAGE_HINTS[service_id][0], package)
    for service_id in ("freenet", "hyphanet", "linuxdcpp", "tahoe", "btfs", "nym", "resilio", "netbird-server", "netmaker", "netclient"):
      self.assertEqual(CONTROL.PACKAGE_HINTS[service_id], [])

  def test_monerod_uses_packaged_configuration_path(self):
    monerod = self.service("monerod")
    self.assertEqual(monerod["config"], "/etc/monerod.conf")
    self.assertTrue(monerod["protectedConfig"])

  def test_i2pd_uses_packaged_configuration_path(self):
    self.assertEqual(self.service("i2pd")["config"], "/etc/i2pd/i2pd.conf")

  def test_mesh_overlay_services_use_arch_packages_and_system_units(self):
    expected = {
      "tailscale": ("tailscale", ["tailscaled.service"], "/etc/default/tailscaled"),
      "zerotier": ("zerotier-one", ["zerotier-one.service"], "/var/lib/zerotier-one/local.conf"),
      "nebula": ("nebula", ["nebula.service"], "/etc/nebula/config.yml"),
    }
    for service_id, (package, units, config) in expected.items():
      with self.subTest(service=service_id):
        service = self.service(service_id)
        self.assertEqual(CONTROL.PACKAGE_HINTS[service_id], [package])
        self.assertEqual(service["units"], units)
        self.assertEqual(service["config"], config)
        self.assertTrue(service["protectedConfig"])
        self.assertIn(service_id, CONTROL.DOCKER_ALIASES)

  def test_mesh_control_planes_and_agents_have_safe_management_routes(self):
    expected = {
      "headscale": (["headscale"], ["headscale.service"], "/etc/headscale/config.yaml"),
      "netbird": (["netbird"], ["netbird.service", "netbird@main.service"], "/etc/sysconfig/netbird"),
      "netbird-server": ([], ["netbird-server.service"], "~/netbird/config.yaml"),
      "netmaker": ([], ["netmaker.service"], "~/netmaker/config.yaml"),
      "netclient": ([], ["netclient.service"], "/etc/netclient/config/netconfig"),
    }
    for service_id, (packages, units, config) in expected.items():
      with self.subTest(service=service_id):
        service = self.service(service_id)
        self.assertEqual(CONTROL.PACKAGE_HINTS[service_id], packages)
        self.assertEqual(service["units"], units)
        self.assertEqual(service["config"], config)
        self.assertIn(service_id, CONTROL.DOCKER_ALIASES)

  def test_aria2_launch_enables_local_rpc_foreground(self):
    original_which = CONTROL.shutil.which
    try:
      CONTROL.shutil.which = lambda command: "/usr/bin/aria2c" if command == "aria2c" else None
      command = CONTROL.launch_command(self.service("aria2"))
      self.assertEqual(command[0], "/usr/bin/aria2c")
      self.assertIn("--enable-rpc=true", command)
      self.assertIn("--daemon=false", command)
      self.assertIn("--rpc-listen-all=false", command)
      self.assertTrue(any(value.startswith("--conf-path=") for value in command))
    finally:
      CONTROL.shutil.which = original_which

  def test_verify_action_rejects_false_success(self):
    original_sleep, original_reset, original_inspect = CONTROL.time.sleep, CONTROL.reset_discovery, CONTROL.INSPECTOR.inspect
    try:
      CONTROL.time.sleep = lambda _seconds: None
      CONTROL.reset_discovery = lambda: None
      CONTROL.INSPECTOR.inspect = lambda _service, _private: {"active": False, "hasError": False}
      with self.assertRaisesRegex(RuntimeError, "start timeout"):
        CONTROL.verify_action(self.service("freenet"), "start", timeout=0)
      CONTROL.INSPECTOR.inspect = lambda _service, _private: {"active": True, "hasError": False}
      with self.assertRaisesRegex(RuntimeError, "still running"):
        CONTROL.verify_action(self.service("freenet"), "stop", timeout=0)
    finally:
      CONTROL.time.sleep, CONTROL.reset_discovery, CONTROL.INSPECTOR.inspect = original_sleep, original_reset, original_inspect

  def test_command_failures_are_reported_without_raising_or_leaking_arguments(self):
    with mock.patch.object(CONTROL.subprocess, "run", side_effect=subprocess.TimeoutExpired(["/secret/tool", "token"], 3)):
      self.assertIsNone(CONTROL.run(["/secret/tool", "token"], 3))
    self.assertEqual(CONTROL.SNAPSHOT.diagnostics[-1], {"code": "command_timeout", "command": "tool", "timeoutSeconds": 3})

    with mock.patch.object(CONTROL.subprocess, "run", side_effect=PermissionError("denied")):
      self.assertIsNone(CONTROL.run(["/private/daemon", "credential"], 2))
    self.assertEqual(CONTROL.SNAPSHOT.diagnostics[-1], {"code": "command_failed", "command": "daemon", "detail": "PermissionError"})
    self.assertNotIn("credential", repr(CONTROL.SNAPSHOT.diagnostics))

  def test_package_snapshot_reuses_inventory_across_helper_scans(self):
    with tempfile.TemporaryDirectory() as directory, \
         mock.patch.object(CONTROL, "STATUS_CACHE_ROOT", pathlib.Path(directory)), \
         mock.patch.object(CONTROL, "run", return_value=types.SimpleNamespace(returncode=0, stdout="aria2\nsyncthing\n")) as query:
      self.assertEqual(CONTROL.package_snapshot(), {"aria2", "syncthing"})
      self.assertEqual(CONTROL.package_snapshot(), {"aria2", "syncthing"})
    query.assert_called_once_with([CONTROL.PACMAN, "-Qq"], 5)

  def test_package_database_change_invalidates_inventory_cache(self):
    with tempfile.TemporaryDirectory() as directory, \
         mock.patch.object(CONTROL, "STATUS_CACHE_ROOT", pathlib.Path(directory)), \
         mock.patch.object(CONTROL, "package_database_generation", side_effect=[1, 2]), \
         mock.patch.object(CONTROL, "run", side_effect=[
           types.SimpleNamespace(returncode=0, stdout="aria2\n"),
           types.SimpleNamespace(returncode=0, stdout="syncthing\n"),
         ]) as query:
      self.assertEqual(CONTROL.package_snapshot(), {"aria2"})
      self.assertEqual(CONTROL.package_snapshot(), {"syncthing"})
    self.assertEqual(query.call_count, 2)

  def test_required_package_inventory_rejects_query_failure_and_bypasses_cache(self):
    with tempfile.TemporaryDirectory() as directory, \
         mock.patch.object(CONTROL, "STATUS_CACHE_ROOT", pathlib.Path(directory)), \
         mock.patch.object(CONTROL, "run", return_value=None) as query:
      self.assertEqual(CONTROL.package_snapshot(), set())
      with self.assertRaisesRegex(RuntimeError, "package inventory is unavailable"):
        CONTROL.package_snapshot(required=True, bypass=True)
    self.assertEqual(query.call_count, 2)

  def test_terminal_editor_accepts_only_allowlisted_single_executable(self):
    with mock.patch.dict(CONTROL.os.environ, {"EDITOR": "sh -c injected"}), \
         mock.patch.object(CONTROL.shutil, "which", return_value=None):
      with self.assertRaisesRegex(RuntimeError, "no supported terminal editor"):
        CONTROL.terminal_editor()
    with mock.patch.dict(CONTROL.os.environ, {"EDITOR": "/custom/nvim"}), \
         mock.patch.object(CONTROL.shutil, "which", side_effect=lambda value: value if value == "/custom/nvim" else None), \
         mock.patch.object(CONTROL.os.path, "realpath", side_effect=lambda path: path):
      self.assertEqual(CONTROL.terminal_editor(), "/custom/nvim")

  def test_logs_follow_exact_container_or_systemd_source(self):
    service = self.service("syncthing")
    container = self.item("syncthing")
    container.update({"_runtime_cmd": "/usr/bin/docker", "_runtime": "docker"})
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[container]), \
         mock.patch.object(CONTROL.subprocess, "call", return_value=5) as follow:
      self.assertEqual(CONTROL.show_logs(service), 5)
    follow.assert_called_once_with(["/usr/bin/docker", "logs", "--tail", "200", "-f", "syncthing"])

    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("", False), ("syncthing.service", False)]), \
         mock.patch.object(CONTROL.subprocess, "call", return_value=0) as follow:
      self.assertEqual(CONTROL.show_logs(service), 0)
    follow.assert_called_once_with(["/usr/bin/journalctl", "-u", "syncthing.service", "-n", "200", "-f"])

    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.subprocess, "call") as follow:
      with self.assertRaisesRegex(RuntimeError, "no systemd or container log source"):
        CONTROL.show_logs(service)
    follow.assert_not_called()

  def test_logs_choose_container_independently_of_runtime_order(self):
    service = self.service("syncthing")
    alpha = self.item("alpha"); alpha.update({"_runtime_cmd":"/usr/bin/docker","_runtime":"docker"})
    zeta = self.item("zeta"); zeta.update({"_runtime_cmd":"/usr/bin/docker","_runtime":"docker"})
    with mock.patch.object(CONTROL.PROBE,"docker_matches",return_value=[zeta,alpha]), \
         mock.patch.object(CONTROL.subprocess,"call",return_value=0) as follow:
      CONTROL.show_logs(service)
    follow.assert_called_once_with(["/usr/bin/docker","logs","--tail","200","-f","alpha"])

  def test_container_control_targets_exact_owned_non_init_containers(self):
    service = self.service("syncthing")
    running = self.item("syncthing"); running.update({"_runtime":"docker","_runtime_cmd":"/usr/bin/docker"})
    init = self.item("syncthing-init"); init.update({"_runtime":"docker","_runtime_cmd":"/usr/bin/docker"})
    stopped = self.item("syncthing-old"); stopped.update({"_runtime":"docker","_runtime_cmd":"/usr/bin/docker","State":{"Running":False}})
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[running, init, stopped]), \
         mock.patch.object(CONTROL.subprocess, "check_call") as call:
      CONTROL.control(service, "stop")
      call.assert_called_once_with(["/usr/bin/docker", "stop", "syncthing"])

  def test_multi_runtime_control_order_and_failure_code_are_deterministic(self):
    service = self.service("syncthing")
    docker = self.item("docker-sync"); docker.update({"_runtime":"docker", "_runtime_cmd":"/usr/bin/docker"})
    podman = self.item("podman-sync"); podman.update({"_runtime":"podman", "_runtime_cmd":"/usr/bin/podman"})
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[podman, docker]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.subprocess, "check_call", side_effect=[None, subprocess.CalledProcessError(23, ["podman"])]) as execute:
      with self.assertRaises(subprocess.CalledProcessError) as raised:
        CONTROL.control(service, "restart")
    self.assertEqual(raised.exception.returncode, 23)
    self.assertEqual(raised.exception.completed_commands, [["/usr/bin/docker", "restart", "docker-sync"]])
    self.assertEqual(execute.call_args_list, [
      mock.call(["/usr/bin/docker", "restart", "docker-sync"]),
      mock.call(["/usr/bin/podman", "restart", "podman-sync"]),
    ])

  def test_control_rejects_unknown_action_without_mutating(self):
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.subprocess, "check_call") as call, \
         mock.patch.object(CONTROL.subprocess, "Popen") as popen:
      with self.assertRaisesRegex(RuntimeError, "unsupported action"):
        CONTROL.control(self.service("syncthing"), "delete")
    call.assert_not_called(); popen.assert_not_called()

  def test_custom_services_are_observation_only_at_cli_mutation_boundary(self):
    service = dict(self.service("syncthing"), id="custom-network", custom=True, controllable=False)
    with mock.patch.object(CONTROL.PROBE, "docker_matches") as containers, \
         mock.patch.object(CONTROL.subprocess, "check_call") as execute, \
         mock.patch.object(CONTROL.os, "kill") as kill:
      with self.assertRaisesRegex(RuntimeError, "observation-only"):
        CONTROL.control(service, "stop")
    containers.assert_not_called(); execute.assert_not_called(); kill.assert_not_called()

  def test_process_stop_targets_only_current_user_matches(self):
    service = self.service("nicotine")
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.PROBE, "pids_for", return_value=[42]) as pids, \
         mock.patch.object(CONTROL, "terminate_matching_process", return_value=True) as terminate:
      CONTROL.control(service, "stop")
    self.assertEqual(pids.call_args_list, [mock.call(service["processes"]), mock.call(service["processes"], current_user_only=True)])
    terminate.assert_called_once_with(42, service["processes"])

  def test_external_process_control_never_duplicates_or_signals_unowned_processes(self):
    service = self.service("nicotine")
    for action in ("stop", "restart"):
      with self.subTest(action=action), \
           mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
           mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
           mock.patch.object(CONTROL.PROBE, "pids_for", side_effect=lambda _names, current_user_only=False: [] if current_user_only else [42]), \
           mock.patch.object(CONTROL, "terminate_matching_process") as terminate, \
           mock.patch.object(CONTROL.subprocess, "Popen") as launch:
        with self.assertRaisesRegex(RuntimeError, "not owned by the current user"):
          CONTROL.control(service, action)
      terminate.assert_not_called()
      launch.assert_not_called()

    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.PROBE, "pids_for", return_value=[42]), \
         mock.patch.object(CONTROL.subprocess, "Popen") as launch:
      CONTROL.control(service, "start")
    launch.assert_not_called()

  def test_process_termination_revalidates_identity_and_uses_pidfd(self):
    with tempfile.TemporaryDirectory() as directory:
      proc = pathlib.Path(directory); process = proc/"42"; process.mkdir()
      (process/"comm").write_text("syncthing\n")
      (process/"cmdline").write_bytes(b"/usr/bin/syncthing\0serve\0")
      with mock.patch.object(CONTROL.os, "pidfd_open", return_value=9), \
           mock.patch.object(CONTROL.signal, "pidfd_send_signal") as send, \
           mock.patch.object(CONTROL.os, "close"):
        self.assertTrue(CONTROL.terminate_matching_process(42,["syncthing"],proc))
      send.assert_called_once_with(9,CONTROL.signal.SIGTERM)
      (process/"comm").write_text("unrelated\n"); (process/"cmdline").write_bytes(b"unrelated\0")
      with mock.patch.object(CONTROL.os, "pidfd_open", return_value=10), \
           mock.patch.object(CONTROL.signal, "pidfd_send_signal") as send, \
           mock.patch.object(CONTROL.os, "close"):
        self.assertFalse(CONTROL.terminate_matching_process(42,["syncthing"],proc))
      send.assert_not_called()

  def test_process_exit_wait_observes_identity_instead_of_elapsed_delay(self):
    with tempfile.TemporaryDirectory() as directory:
      proc = pathlib.Path(directory); process = proc/"42"; process.mkdir()
      (process/"comm").write_text("syncthing\n")
      (process/"cmdline").write_bytes(b"/usr/bin/syncthing\0serve\0")
      identity_check = CONTROL.matching_process_alive
      def process_exits(_seconds):
        (process/"comm").unlink(); (process/"cmdline").unlink(); process.rmdir()
      with mock.patch.object(CONTROL, "matching_process_alive", side_effect=lambda pid, names: identity_check(pid,names,proc)), \
           mock.patch.object(CONTROL.time, "sleep", side_effect=process_exits) as sleep:
        CONTROL.wait_for_process_exit([42],["syncthing"],timeout=1,interval=0.05)
      sleep.assert_called_once_with(0.05)

  def test_process_exit_wait_has_a_bounded_timeout(self):
    with mock.patch.object(CONTROL, "matching_process_alive", return_value=True), \
         mock.patch.object(CONTROL.time, "monotonic", side_effect=[10.0,10.6]), \
         mock.patch.object(CONTROL.time, "sleep") as sleep:
      with self.assertRaisesRegex(RuntimeError, "still stopping"):
        CONTROL.wait_for_process_exit([42],["syncthing"],timeout=0.5)
    sleep.assert_not_called()

  def test_process_restart_terminates_current_instance_before_launching_replacement(self):
    service = self.service("nicotine")
    events = []
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.PROBE, "pids_for", return_value=[42]), \
         mock.patch.object(CONTROL, "terminate_matching_process", side_effect=lambda pid, names: events.append(("kill", pid, CONTROL.signal.SIGTERM)) or True), \
         mock.patch.object(CONTROL, "wait_for_process_exit", side_effect=lambda pids, names: events.append(("wait-exit", pids, names))), \
         mock.patch.object(CONTROL, "launch_command", return_value=["/usr/bin/nicotine"]), \
         mock.patch.object(CONTROL.subprocess, "Popen", side_effect=lambda command, **kwargs: events.append(("launch", command, kwargs))):
      CONTROL.control(service, "restart")
    self.assertEqual(events[0], ("kill", 42, CONTROL.signal.SIGTERM))
    self.assertEqual(events[1], ("wait-exit", [42], service["processes"]))
    self.assertEqual(events[2][0:2], ("launch", ["/usr/bin/nicotine"]))
    self.assertTrue(events[2][2]["start_new_session"])

  def test_process_restart_does_not_launch_while_original_instance_survives(self):
    service = self.service("nicotine")
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.PROBE, "pids_for", return_value=[42]), \
         mock.patch.object(CONTROL, "terminate_matching_process", return_value=True), \
         mock.patch.object(CONTROL, "wait_for_process_exit", side_effect=RuntimeError("still stopping")), \
         mock.patch.object(CONTROL.subprocess, "Popen") as launch:
      with self.assertRaisesRegex(RuntimeError, "still stopping"):
        CONTROL.control(service, "restart")
    launch.assert_not_called()

  def test_control_routes_user_and_system_units_through_correct_authority(self):
    service = self.service("syncthing")
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("syncthing.service", True), ("", False)]), \
         mock.patch.object(CONTROL.subprocess, "check_call") as execute:
      CONTROL.control(service, "restart")
    execute.assert_called_once_with(["/usr/bin/systemctl", "--user", "restart", "syncthing.service"])

  def test_control_selects_the_active_systemd_scope_and_rejects_two_active_scopes(self):
    service = self.service("syncthing")
    for action in ("stop", "restart"):
      with self.subTest(active_scope="system", action=action), \
           mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
           mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("syncthing.service", False), ("syncthing.service", True)]), \
           mock.patch.object(CONTROL, "privileged_call") as execute:
        CONTROL.control(service, action, terminal_auth=True)
      execute.assert_called_once_with(["/usr/bin/systemctl", action, "syncthing.service"], True)

    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("syncthing.service", False), ("syncthing.service", True)]), \
         mock.patch.object(CONTROL.subprocess, "check_call") as user_execute, \
         mock.patch.object(CONTROL, "privileged_call") as system_execute:
      CONTROL.control(service, "start", terminal_auth=True)
    user_execute.assert_not_called(); system_execute.assert_not_called()

    for action in ("stop", "restart"):
      with self.subTest(active_scope="both", action=action), \
           mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
           mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("syncthing.service", True), ("syncthing.service", True)]), \
           mock.patch.object(CONTROL.subprocess, "check_call") as user_execute, \
           mock.patch.object(CONTROL, "privileged_call") as system_execute:
        with self.assertRaisesRegex(RuntimeError, "multiple systemd scopes"):
          CONTROL.control(service, action, terminal_auth=True)
      user_execute.assert_not_called(); system_execute.assert_not_called()

    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("syncthing.service", True), ("syncthing.service", True)]):
      with self.assertRaisesRegex(RuntimeError, "multiple systemd scopes"):
        CONTROL.control(service, "start", terminal_auth=True)

  def test_control_rejects_mixed_container_and_active_systemd_ownership(self):
    service = self.service("syncthing")
    container = self.item("syncthing"); container.update({"_runtime":"docker", "_runtime_cmd":"/usr/bin/docker"})
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[container]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("syncthing.service", True), ("", False)]), \
         mock.patch.object(CONTROL.subprocess, "check_call") as execute:
      with self.assertRaisesRegex(RuntimeError, "multiple control backends"):
        CONTROL.control(service, "restart")
    execute.assert_not_called()

  def test_repeated_start_and_stop_are_noops_at_desired_systemd_state(self):
    service = self.service("syncthing")
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("syncthing.service", True), ("", False)]), \
         mock.patch.object(CONTROL.subprocess, "check_call") as execute:
      CONTROL.control(service, "start")
    execute.assert_not_called()

    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("syncthing.service", False), ("", False)]), \
         mock.patch.object(CONTROL.subprocess, "check_call") as execute:
      CONTROL.control(service, "stop")
    execute.assert_not_called()

    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("", False), ("syncthing.service", False)]), \
         mock.patch.object(CONTROL, "prepare_service_start") as prepare, \
         mock.patch.object(CONTROL, "privileged_call") as execute:
      CONTROL.control(service, "start", terminal_auth=True)
    prepare.assert_called_once_with(service, "syncthing.service", True)
    execute.assert_called_once_with(["/usr/bin/systemctl", "start", "syncthing.service"], True)

  def test_amule_restart_stops_prepares_then_starts_system_unit(self):
    service = self.service("amule")
    events = []
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("", False), ("amuled.service", True)]), \
         mock.patch.object(CONTROL, "privileged_call", side_effect=lambda command, auth=False: events.append(("control", command, auth))), \
         mock.patch.object(CONTROL, "prepare_service_start", side_effect=lambda item, unit, auth=False: events.append(("prepare", item["id"], unit, auth))):
      CONTROL.control(service, "restart", terminal_auth=True)
    self.assertEqual(events, [
      ("control", ["/usr/bin/systemctl", "stop", "amuled.service"], True),
      ("prepare", "amule", "amuled.service", True),
      ("control", ["/usr/bin/systemctl", "start", "amuled.service"], True),
    ])

  def test_open_action_prefers_valid_discovered_proxy_and_rejects_unsafe_fallback(self):
    service = self.service("syncthing")
    item = self.item("syncthing")
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[item]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.PROBE, "proxy_candidates", return_value=[(0, "https://sync.example.test/", "traefik")]), \
         mock.patch.object(CONTROL.subprocess, "Popen") as launch:
      CONTROL.control(service, "open")
    launch.assert_called_once_with(["/usr/bin/xdg-open", "https://sync.example.test/"], start_new_session=True)

    unsafe = dict(service, web="file:///etc/passwd")
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.PROBE, "proxy_candidates", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "published_url", return_value=""), \
         mock.patch.object(CONTROL.subprocess, "Popen") as launch:
      with self.assertRaisesRegex(RuntimeError, "no valid console URL"):
        CONTROL.control(unsafe, "open")
    launch.assert_not_called()

  def test_installed_packages_is_exact_and_allowlisted(self):
    original_run = CONTROL.run
    calls = []
    try:
      def fake_run(args, timeout=2):
        calls.append(args)
        return type("Result", (), {"returncode": 0, "stdout": "i2pd unrelated\ni2pd-git-tools\n", "stderr": ""})()
      CONTROL.run = fake_run
      self.assertEqual(CONTROL.installed_packages(self.service("i2pd")), ["i2pd"])
      self.assertEqual(CONTROL.installed_packages(self.service("i2pd")), ["i2pd"])
      self.assertEqual(len(calls), 1)
      self.assertEqual(calls[0], ["/usr/bin/pacman", "-Qq"])
    finally:
      CONTROL.run = original_run

  def test_compose_config_action_uses_resolved_host_file(self):
    original_docker = CONTROL.PROBE.docker_matches
    original_unit = CONTROL.PROBE.unit_state
    original_popen = CONTROL.subprocess.Popen
    original_which = CONTROL.shutil.which
    try:
      with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        compose = root/"docker-compose.yml"
        compose.write_text("services: {}\n")
        item = self.item("syncthing", service="syncthing", workdir=str(root), config_files=str(compose))
        item["_runtime"] = "docker"
        item["_runtime_cmd"] = "/usr/bin/docker"
        CONTROL.PROBE.docker_matches = lambda _service: [item]
        CONTROL.PROBE.unit_state = lambda _units, _user: ("", False)
        CONTROL.shutil.which = lambda command: "/usr/bin/omarchy-launch-config-editor" if command == "omarchy-launch-config-editor" else original_which(command)
        launched = []
        CONTROL.subprocess.Popen = lambda args, **kwargs: launched.append(args)
        self.assertEqual(CONTROL.config_targets(self.service("syncthing"), [item]), [str(compose)])
        CONTROL.control(self.service("syncthing"), "config")
        self.assertEqual(launched[0][-1], str(compose))
        self.assertEqual(pathlib.Path(launched[0][0]).name, "omarchy-launch-config-editor")
    finally:
      CONTROL.PROBE.docker_matches = original_docker
      CONTROL.PROBE.unit_state = original_unit
      CONTROL.subprocess.Popen = original_popen
      CONTROL.shutil.which = original_which

  def test_config_targets_ignore_missing_and_outside_compose_paths(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)/"project"
      root.mkdir()
      compose = root/"compose.yml"
      compose.write_text("services: {}\n")
      outside = pathlib.Path(directory)/"outside.yml"
      outside.write_text("services: {}\n")
      service = dict(self.service("syncthing"), config=str(root/"missing.conf"))
      outside_item = self.item("syncthing", workdir=str(root), config_files=str(outside))
      missing_item = self.item("syncthing", workdir=str(root), config_files=str(root/"missing.yml"))
      missing_root = self.item("syncthing", workdir=str(root/"absent"), config_files=str(compose))
      self.assertEqual(CONTROL.config_targets(service, [outside_item, missing_item, missing_root]), [])

  def test_config_targets_do_not_depend_on_container_order(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      alpha = root/"alpha.yml"; alpha.write_text("services: {}\n")
      zeta = root/"zeta.yml"; zeta.write_text("services: {}\n")
      alpha_item = self.item("alpha",workdir=str(root),config_files=str(alpha))
      zeta_item = self.item("zeta",workdir=str(root),config_files=str(zeta))
      expected = [str(alpha),str(zeta)]
      service = dict(self.service("syncthing"),config=str(root/"missing"))
      self.assertEqual(CONTROL.config_targets(service,[zeta_item,alpha_item]),expected)
      self.assertEqual(CONTROL.config_targets(service,[alpha_item,zeta_item]),expected)

  def test_protected_config_action_forces_validated_terminal_editor(self):
    original_docker = CONTROL.PROBE.docker_matches
    original_unit = CONTROL.PROBE.unit_state
    original_access = CONTROL.os.access
    original_popen = CONTROL.subprocess.Popen
    original_terminal_editor = CONTROL.terminal_editor
    try:
      with tempfile.TemporaryDirectory() as directory:
        config = pathlib.Path(directory)/"service.conf"
        config.write_text("enabled=true\n")
        service = dict(self.service("aria2"), config=str(config))
        CONTROL.PROBE.docker_matches = lambda _service: []
        CONTROL.PROBE.unit_state = lambda _units, _user: ("", False)
        CONTROL.os.access = lambda path, mode: False if str(path) == str(config) else original_access(path, mode)
        CONTROL.terminal_editor = lambda: "/usr/bin/vim"
        launched = []
        CONTROL.subprocess.Popen = lambda args, **kwargs: launched.append((args, kwargs))
        CONTROL.control(service, "config")
        args, kwargs = launched[0]
        self.assertEqual(args, ["omarchy-launch-terminal", "/usr/bin/sudoedit", str(config)])
        editor = kwargs["env"]["SUDO_EDITOR"]
        self.assertIn(pathlib.Path(editor).name, CONTROL.TERMINAL_EDITORS)
        self.assertEqual(kwargs["env"]["VISUAL"], editor)
        self.assertEqual(kwargs["env"]["EDITOR"], editor)
    finally:
      CONTROL.PROBE.docker_matches = original_docker
      CONTROL.PROBE.unit_state = original_unit
      CONTROL.os.access = original_access
      CONTROL.subprocess.Popen = original_popen
      CONTROL.terminal_editor = original_terminal_editor

  def test_amule_managed_start_enables_external_connections(self):
    amule = self.service("amule")
    self.assertEqual(amule["config"], "/var/lib/amule/.aMule/amule.conf")
    original_exists = CONTROL.os.path.exists
    original_privileged = CONTROL.privileged_call
    original_home = CONTROL.HOME
    temporary_home = tempfile.TemporaryDirectory()
    try:
      CONTROL.HOME = pathlib.Path(temporary_home.name)
      CONTROL.os.path.exists = lambda path: (
          str(path) == "/var/lib/amule/.aMule/amule.conf"
          or original_exists(path)
      )
      calls = []
      CONTROL.privileged_call = lambda args, terminal_auth=False: calls.append((args, terminal_auth))
      with mock.patch.dict(CONTROL.os.environ, {"XDG_DATA_HOME": str(CONTROL.HOME/".local/share")}):
        CONTROL.prepare_service_start(amule, "amuled.service", True)
      self.assertEqual(len(calls), 1)
      self.assertEqual(calls[0][0][0:4], ["/usr/bin/sed", "-i", "-e", "s/^AcceptExternalConnections=.*/AcceptExternalConnections=1/"])
      password_edit = calls[0][0][5]
      self.assertTrue(password_edit.startswith("s/^ECPassword="))
      self.assertIn("/ECPassword=", password_edit)
      self.assertTrue(password_edit.endswith("/"))
      digest = password_edit.split("/ECPassword=", 1)[1][:-1]
      self.assertEqual(len(digest), 32)
      self.assertTrue(all(character in "0123456789abcdef" for character in digest))
      self.assertIn(chr(36), password_edit.split("/ECPassword=", 1)[0])
      web_edit = calls[0][0][7]
      self.assertIn(r"\[WebServer\]", web_edit)
      self.assertIn(r"\[GUI\]", web_edit)
      self.assertIn("Enabled=1", web_edit)
      self.assertIn("Password=" + digest, web_edit)
      self.assertIn("Template=default", web_edit)
      self.assertEqual(calls[0][0][8], "/var/lib/amule/.aMule/amule.conf")
      credential = CONTROL.HOME/".local/share/omarchy/p2p-services/credentials/amule-ec-password"
      self.assertTrue(credential.is_file())
      self.assertEqual(credential.stat().st_mode & 0o777, 0o600)
    finally:
      CONTROL.os.path.exists = original_exists
      CONTROL.privileged_call = original_privileged
      CONTROL.HOME = original_home
      temporary_home.cleanup()

  def test_amule_first_start_waits_for_generated_configuration(self):
    amule = self.service("amule")
    with tempfile.TemporaryDirectory() as directory, \
         mock.patch.object(CONTROL, "data_home", return_value=pathlib.Path(directory)), \
         mock.patch.object(CONTROL.os.path, "exists", return_value=False), \
         mock.patch.object(CONTROL, "read_or_create_secret", return_value="secret"), \
         mock.patch.object(CONTROL, "privileged_call") as execute, \
         mock.patch.object(CONTROL, "wait_for_path") as wait:
      CONTROL.prepare_service_start(amule,"amuled.service",True)
    self.assertEqual(execute.call_args_list[0], mock.call([CONTROL.SYSTEMCTL,"start","amuled.service"],True))
    wait.assert_called_once_with("/var/lib/amule/.aMule/amule.conf")

  def test_amule_first_start_does_not_edit_before_configuration_exists(self):
    amule = self.service("amule")
    with tempfile.TemporaryDirectory() as directory, \
         mock.patch.object(CONTROL, "data_home", return_value=pathlib.Path(directory)), \
         mock.patch.object(CONTROL.os.path, "exists", return_value=False), \
         mock.patch.object(CONTROL, "privileged_call") as execute, \
         mock.patch.object(CONTROL, "wait_for_path", side_effect=RuntimeError("not created")):
      with self.assertRaisesRegex(RuntimeError,"not created"):
        CONTROL.prepare_service_start(amule,"amuled.service",True)
    self.assertEqual(execute.call_count,1)

  def test_path_wait_observes_file_creation(self):
    with tempfile.TemporaryDirectory() as directory:
      target=pathlib.Path(directory)/"generated.conf"
      with mock.patch.object(CONTROL.time,"sleep",side_effect=lambda _seconds: target.touch()) as sleep:
        CONTROL.wait_for_path(target,timeout=1,interval=0.05)
      sleep.assert_called_once_with(0.05)

  def test_path_wait_has_a_bounded_timeout(self):
    with tempfile.TemporaryDirectory() as directory, \
         mock.patch.object(CONTROL.time,"monotonic",side_effect=[10.0,10.6]), \
         mock.patch.object(CONTROL.time,"sleep") as sleep:
      with self.assertRaisesRegex(RuntimeError,"was not created"):
        CONTROL.wait_for_path(pathlib.Path(directory)/"missing.conf",timeout=0.5)
    sleep.assert_not_called()

  def test_install_autostart_uses_verified_control_path(self):
    original_which = CONTROL.shutil.which
    original_check = CONTROL.subprocess.check_call
    original_reset = CONTROL.reset_discovery
    original_control = CONTROL.control
    original_verify = CONTROL.verify_action
    original_aur_environment = CONTROL.aur_environment
    original_installed_packages = CONTROL.installed_packages
    try:
      calls = []
      CONTROL.shutil.which = lambda command: "/usr/bin/omarchy" if command == "omarchy" else original_which(command)
      CONTROL.subprocess.check_call = lambda args, **kwargs: calls.append(("install", args))
      CONTROL.reset_discovery = lambda: calls.append(("reset",))
      CONTROL.control = lambda service, action, terminal_auth=False: calls.append(("control", service["id"], action, terminal_auth))
      CONTROL.verify_action = lambda service, action: calls.append(("verify", service["id"], action))
      CONTROL.aur_environment = lambda service: {"GNUPGHOME": "/tmp/test-aur-gnupg"}
      CONTROL.installed_packages = lambda service, **_options: CONTROL.PACKAGE_HINTS[service["id"]][:1]
      CONTROL.install_service(self.service("aria2"), True)
      self.assertEqual(calls[1:], [("reset",), ("reset",), ("control", "aria2", "start", True), ("verify", "aria2", "start")])
      self.assertIn("aria2", calls[0][1])
      calls.clear()
      CONTROL.install_service(self.service("gnunet"), False)
      self.assertEqual(calls, [("install", ["/usr/bin/omarchy", "pkg", "aur", "add", "gnunet"]), ("reset",)])
    finally:
      CONTROL.shutil.which = original_which
      CONTROL.subprocess.check_call = original_check
      CONTROL.reset_discovery = original_reset
      CONTROL.control = original_control
      CONTROL.verify_action = original_verify
      CONTROL.aur_environment = original_aur_environment
      CONTROL.installed_packages = original_installed_packages

  def test_install_and_uninstall_verify_package_postconditions(self):
    service = self.service("i2pd")
    with mock.patch.object(CONTROL.shutil, "which", return_value="/usr/bin/omarchy"), \
         mock.patch.object(CONTROL.os.path, "realpath", side_effect=lambda path: path), \
         mock.patch.object(CONTROL.subprocess, "check_call"), \
         mock.patch.object(CONTROL, "installed_packages", return_value=[]):
      with self.assertRaisesRegex(RuntimeError, "package was not detected after installation"):
        CONTROL.install_service(service)

    with mock.patch.object(CONTROL, "installed_packages", side_effect=[["i2pd"], ["i2pd"]]), \
         mock.patch.object(CONTROL.INSPECTOR, "inspect", return_value={"active": False}), \
         mock.patch.object(CONTROL.BACKUPS, "backup", return_value=""), \
         mock.patch.object(CONTROL.shutil, "which", return_value="/usr/bin/omarchy"), \
         mock.patch.object(CONTROL.os.path, "realpath", side_effect=lambda path: path), \
         mock.patch.object(CONTROL.subprocess, "check_call"):
      with self.assertRaisesRegex(RuntimeError, "package is still installed after removal"):
        CONTROL.uninstall_service(service)

  def test_aur_signing_key_download_failure_stops_before_import(self):
    with tempfile.TemporaryDirectory() as directory, \
         mock.patch.object(CONTROL, "HOME", pathlib.Path(directory)), \
         mock.patch.dict(CONTROL.os.environ, {"XDG_DATA_HOME": str(pathlib.Path(directory)/".local/share")}), \
         mock.patch.object(CONTROL.subprocess, "run") as run:
      run.side_effect = [
        mock.Mock(returncode=1),
        mock.Mock(returncode=22, stdout=b""),
      ]
      with self.assertRaisesRegex(RuntimeError, "could not be downloaded"):
        CONTROL.aur_environment(self.service("gnunet"))
    self.assertEqual(run.call_count, 2)
    self.assertIn("--list-keys", run.call_args_list[0].args[0])
    self.assertIn("keys.openpgp.org", run.call_args_list[1].args[0][-1])

  def test_aur_signing_key_is_imported_reverified_and_uses_private_keyring(self):
    with tempfile.TemporaryDirectory() as directory, \
         mock.patch.object(CONTROL, "HOME", pathlib.Path(directory)), \
         mock.patch.dict(CONTROL.os.environ, {"XDG_DATA_HOME": str(pathlib.Path(directory)/".local/share")}), \
         mock.patch.object(CONTROL.subprocess, "run") as run:
      run.side_effect = [
        mock.Mock(returncode=1),
        mock.Mock(returncode=0, stdout=b"public key"),
        mock.Mock(returncode=0),
        mock.Mock(returncode=0),
      ]
      environment = CONTROL.aur_environment(self.service("gnunet"))
      keyring = pathlib.Path(environment["GNUPGHOME"])
      self.assertEqual(keyring.stat().st_mode & 0o777, 0o700)
    self.assertEqual(run.call_count, 4)
    self.assertEqual(run.call_args_list[2].kwargs["input"], b"public key")
    self.assertIn("--import", run.call_args_list[2].args[0])
    self.assertIn("--list-keys", run.call_args_list[3].args[0])

  def test_uninstall_refuses_active_service_before_backup_or_package_removal(self):
    service = self.service("i2pd")
    with mock.patch.object(CONTROL, "installed_packages", return_value=["i2pd"]), \
         mock.patch.object(CONTROL.INSPECTOR, "inspect", return_value={"active": True}), \
         mock.patch.object(CONTROL.BACKUPS, "backup") as backup, \
         mock.patch.object(CONTROL.subprocess, "check_call") as remove:
      with self.assertRaisesRegex(RuntimeError, "stop the service"):
        CONTROL.uninstall_service(service)
    backup.assert_not_called()
    remove.assert_not_called()

  def test_uninstall_backs_up_before_exact_package_removal(self):
    service = self.service("i2pd")
    events = []
    with mock.patch.object(CONTROL, "installed_packages", side_effect=[["i2pd"], []]), \
         mock.patch.object(CONTROL.INSPECTOR, "inspect", return_value={"active": False}), \
         mock.patch.object(CONTROL.BACKUPS, "backup", side_effect=lambda item, retention: events.append(("backup", item["id"], retention)) or "/backup/i2pd"), \
         mock.patch.object(CONTROL.shutil, "which", return_value="/usr/bin/omarchy"), \
         mock.patch.object(CONTROL.os.path, "realpath", side_effect=lambda path: path), \
         mock.patch.object(CONTROL.subprocess, "check_call", side_effect=lambda command: events.append(("remove", command))):
      output = io.StringIO()
      with redirect_stdout(output):
        CONTROL.uninstall_service(service, retention=7)
    self.assertEqual(events, [
      ("backup", "i2pd", 7),
      ("remove", ["/usr/bin/omarchy", "pkg", "drop", "i2pd"]),
    ])
    self.assertEqual(output.getvalue(), "Configuration backup: /backup/i2pd\nCompleted stage: package removed\n")

  def test_uninstall_requires_allowlisted_package_without_side_effects(self):
    with mock.patch.object(CONTROL, "installed_packages", return_value=[]), \
         mock.patch.object(CONTROL.INSPECTOR, "inspect") as inspect, \
         mock.patch.object(CONTROL.BACKUPS, "backup") as backup:
      with self.assertRaisesRegex(RuntimeError, "no removable"):
        CONTROL.uninstall_service(self.service("i2pd"))
    inspect.assert_not_called()
    backup.assert_not_called()

  def test_uninstall_checks_remover_before_creating_backup(self):
    with mock.patch.object(CONTROL, "installed_packages", return_value=["i2pd"]), \
         mock.patch.object(CONTROL.INSPECTOR, "inspect", return_value={"active": False}), \
         mock.patch.object(CONTROL.shutil, "which", return_value=None), \
         mock.patch.object(CONTROL.BACKUPS, "backup") as backup:
      with self.assertRaisesRegex(RuntimeError, "package remover is unavailable"):
        CONTROL.uninstall_service(self.service("i2pd"))
    backup.assert_not_called()

  def test_uninstall_rechecks_service_after_backup_before_removal(self):
    with mock.patch.object(CONTROL, "installed_packages", return_value=["i2pd"]), \
         mock.patch.object(CONTROL.INSPECTOR, "inspect", side_effect=[{"active": False}, {"active": True}]) as inspect, \
         mock.patch.object(CONTROL.shutil, "which", return_value="/usr/bin/omarchy"), \
         mock.patch.object(CONTROL.BACKUPS, "backup", return_value="/backup/i2pd"), \
         mock.patch.object(CONTROL.subprocess, "check_call") as remove:
      with self.assertRaisesRegex(RuntimeError, "started while its configuration was being backed up"):
        CONTROL.uninstall_service(self.service("i2pd"))
    self.assertEqual(inspect.call_count, 2)
    remove.assert_not_called()
