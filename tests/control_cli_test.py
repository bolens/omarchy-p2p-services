import io
import json
import os
import pathlib
import subprocess
import tempfile
import types
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

from control_test_support import CONTROL, ControlTestCase
from p2p_backup_store import ConfigBackupStore
from p2p_settings import sanitize_settings
from p2p_settings_store import SettingsStore


class ControlCliTests(ControlTestCase):
  def invoke(self, *args):
    output, errors = io.StringIO(), io.StringIO()
    with mock.patch.object(CONTROL.sys, "argv", ["p2p-control", *args]), \
         redirect_stdout(output), redirect_stderr(errors):
      CONTROL.main()
    return output.getvalue(), errors.getvalue()

  def test_list_arguments_drive_status_snapshot_and_return_only_services(self):
    observed = []

    def cache(key, producer, root, bypass=False):
      observed.append((json.loads(key)[:4], root, bypass))
      return producer()

    with mock.patch.object(CONTROL.SETTINGS, "load", return_value={"customServices": []}), \
         mock.patch.object(CONTROL, "status_snapshot", side_effect=lambda *args: observed.append(args) or [{"id": "daemon"}]), \
         mock.patch.object(CONTROL, "cached_status", side_effect=cache):
      output, errors = self.invoke("list", "unsafe", "node.home", "no-stats", "running-containers", "bypass-cache")

    self.assertEqual(json.loads(output), [{"id": "daemon"}])
    self.assertEqual(errors, "")
    self.assertEqual(observed[0][0], [False, "node.home", False, False])
    self.assertTrue(observed[0][2])
    self.assertEqual(observed[1], (False, "node.home", False, False))

  def test_status_wraps_services_with_diagnostics_and_duration(self):
    CONTROL.SNAPSHOT.warning("probe_failed", command="docker")
    with mock.patch.object(CONTROL.SETTINGS, "load", return_value={}), \
         mock.patch.object(CONTROL, "status_snapshot", return_value=[{"id": "daemon"}]), \
         mock.patch.object(CONTROL, "cached_status", side_effect=lambda _key, producer, _root, bypass=False: producer()):
      output, _errors = self.invoke("status")
    payload = json.loads(output)
    self.assertEqual(payload["services"], [{"id": "daemon"}])
    self.assertEqual(payload["diagnostics"], [{"code": "probe_failed", "command": "docker"}])
    self.assertIsInstance(payload["durationMs"], int)

  def test_catalog_cli_exposes_install_and_backup_metadata_consumed_by_qml(self):
    service = self.service("aria2")
    backups = [{"name": "snapshot", "timestamp": "2026-01-01T00:00:00"}]
    with mock.patch.object(CONTROL, "all_services", return_value=[service]), \
         mock.patch.object(CONTROL, "detected", return_value=True), \
         mock.patch.object(CONTROL, "installed_packages", return_value=["aria2"]), \
         mock.patch.object(CONTROL.BACKUPS, "records", return_value=backups):
      output, errors = self.invoke("catalog")
    self.assertEqual(json.loads(output), [{
      "id": "aria2", "name": "aria2", "icon": service["icon"], "category": "Download client", "detected": True,
      "packages": ["aria2"], "installedPackages": ["aria2"], "backups": backups,
    }])
    self.assertEqual(errors, "")

  def test_open_url_launches_only_valid_http_destination(self):
    with mock.patch.object(CONTROL.subprocess, "Popen") as launch:
      self.invoke("open-url", "https://node.example.test/ui")
      launch.assert_called_once_with(["/usr/bin/xdg-open", "https://node.example.test/ui"], start_new_session=True)
      with self.assertRaisesRegex(SystemExit, "invalid console URL"):
        self.invoke("open-url", "file:///etc/passwd")
    self.assertEqual(launch.call_count, 1)

  def test_settings_cli_round_trip_uses_private_durable_store_and_export(self):
    with tempfile.TemporaryDirectory() as directory:
      home = pathlib.Path(directory)
      state = home/"state"
      store = SettingsStore(state, state/"settings.json", sanitize_settings)
      with mock.patch.object(CONTROL, "SETTINGS", store), mock.patch.object(CONTROL, "HOME", home), \
           mock.patch.dict(CONTROL.os.environ, {"XDG_DATA_HOME": str(home/".local/share")}):
        self.invoke("settings-save", '{"showCount":false}')
        loaded, _ = self.invoke("settings-load")
        self.assertFalse(json.loads(loaded)["showCount"])

        patched, _ = self.invoke("settings-patch", '{"showCount":true}')
        self.assertTrue(json.loads(patched)["showCount"])
        undone, _ = self.invoke("settings-undo")
        self.assertFalse(json.loads(undone)["showCount"])

        reconciled, _ = self.invoke("settings-reconcile", '{"showCount":true,"_p2pRevision":20}')
        self.assertTrue(json.loads(reconciled)["showCount"])
        exported, _ = self.invoke("settings-export")
        export_path = pathlib.Path(exported.strip())
        self.assertEqual(export_path, home/".local/share/omarchy/p2p-services/settings-export.json")
        self.assertEqual(export_path.stat().st_mode & 0o777, 0o600)

        export_path.write_text('{"showCount":false}')
        imported, _ = self.invoke("settings-import")
        self.assertFalse(json.loads(imported)["showCount"])
        self.assertEqual(store.state_root.stat().st_mode & 0o777, 0o700)

  def test_settings_export_honors_xdg_data_home(self):
    with tempfile.TemporaryDirectory() as directory:
      data_home = pathlib.Path(directory)/"portable-data"
      with mock.patch.dict(CONTROL.os.environ, {"XDG_DATA_HOME": str(data_home)}), \
           mock.patch.object(CONTROL.SETTINGS, "load", return_value={"showCount": True}):
        exported, _ = self.invoke("settings-export")
      target = data_home/"omarchy/p2p-services/settings-export.json"
      self.assertEqual(pathlib.Path(exported.strip()), target)
      self.assertEqual(json.loads(target.read_text()), {"showCount": True})

  def test_relative_xdg_directories_fall_back_to_absolute_user_locations(self):
    with tempfile.TemporaryDirectory() as directory, \
         mock.patch.object(CONTROL, "HOME", pathlib.Path(directory)), \
         mock.patch.dict(CONTROL.os.environ, {
           "XDG_DATA_HOME": "relative-data",
           "XDG_STATE_HOME": "relative-state",
           "XDG_RUNTIME_DIR": "relative-runtime",
         }):
      self.assertEqual(CONTROL.data_home(), pathlib.Path(directory)/".local/share")
      self.assertEqual(
        CONTROL.xdg_directory("XDG_STATE_HOME", CONTROL.HOME/".local/state"),
        pathlib.Path(directory)/".local/state",
      )
      self.assertEqual(
        CONTROL.xdg_directory("XDG_RUNTIME_DIR", "/run/user/"+str(CONTROL.os.getuid())),
        pathlib.Path("/run/user")/str(CONTROL.os.getuid()),
      )

  def test_fresh_process_honors_xdg_state_home(self):
    with tempfile.TemporaryDirectory() as directory:
      state_home = pathlib.Path(directory)/"portable-state"
      environment = dict(os.environ, XDG_STATE_HOME=str(state_home))
      result = subprocess.run(
        [str(pathlib.Path(__file__).parents[1]/"p2p-control"), "settings-save", '{"showCount":false}'],
        text=True, capture_output=True, env=environment, check=False,
      )
      self.assertEqual(result.returncode, 0, result.stderr)
      settings = state_home/"omarchy/p2p-services/settings.json"
      self.assertFalse(json.loads(settings.read_text())["showCount"])
      self.assertEqual(settings.parent.stat().st_mode & 0o777, 0o700)

  def test_invalid_settings_payload_becomes_clean_cli_failure_without_file(self):
    with tempfile.TemporaryDirectory() as directory:
      state = pathlib.Path(directory)/"state"
      store = SettingsStore(state, state/"settings.json", sanitize_settings)
      with mock.patch.object(CONTROL, "SETTINGS", store):
        with self.assertRaises(SystemExit) as raised:
          self.invoke("settings-save", "[]")
      self.assertEqual(raised.exception.code, 1)
      self.assertFalse(store.settings_file.exists())

  def test_custom_service_package_and_restore_routes_fail_before_mutation(self):
    custom = dict(self.service("syncthing"), id="custom-node", custom=True, controllable=False)
    for arguments, collaborator in [
      (("install", "custom-node"), "install_service"),
      (("uninstall", "custom-node"), "uninstall_service"),
      (("restore-backup", "custom-node", "snapshot"), None),
    ]:
      with mock.patch.object(CONTROL, "service_by_id", return_value=custom), \
           mock.patch.object(CONTROL, collaborator, create=True) if collaborator else mock.patch.object(CONTROL.BACKUPS, "restore") as mutation:
        with self.assertRaisesRegex(SystemExit, "observation-only"):
          self.invoke(*arguments)
      mutation.assert_not_called()

  def test_restore_backup_cli_round_trip_uses_real_backup_store(self):
    with tempfile.TemporaryDirectory() as directory:
      home = pathlib.Path(directory)
      config = home/"aria2.conf"
      config.write_text("original=true\n")
      service = dict(self.service("aria2"), config=str(config))
      store = ConfigBackupStore(home, lambda *_args: [])
      selected = pathlib.Path(store.backup(service)).name
      config.write_text("changed=true\n")

      with mock.patch.object(CONTROL, "BACKUPS", store), \
           mock.patch.object(CONTROL, "service_by_id", return_value=service):
        output, errors = self.invoke("restore-backup", "aria2", selected)

      self.assertEqual(output.strip(), str(config))
      self.assertEqual(errors, "")
      self.assertEqual(config.read_text(), "original=true\n")
      self.assertGreaterEqual(len(store.records("aria2")), 2)

  def test_action_failure_preserves_child_exit_code(self):
    service = self.service("aria2")
    with mock.patch.object(CONTROL, "service_by_id", return_value=service), \
         mock.patch.object(CONTROL, "detected", return_value=True), \
         mock.patch.object(CONTROL, "control", side_effect=subprocess.CalledProcessError(17, ["control"])):
      with self.assertRaises(SystemExit) as raised:
        self.invoke("action", "aria2", "start")
    self.assertEqual(raised.exception.code, 17)

  def test_watch_without_available_backends_reports_polling_only_and_stops_retrying(self):
    previous_handler = object()
    signal_calls = []

    def set_signal(kind, handler):
      signal_calls.append((kind, handler))
      return previous_handler

    with mock.patch.object(CONTROL.shutil, "which", return_value=None), \
         mock.patch.object(CONTROL.signal, "signal", side_effect=set_signal), \
         redirect_stdout(output := io.StringIO()), redirect_stderr(errors := io.StringIO()):
      self.assertFalse(CONTROL.watch_events())
    messages = [json.loads(line) for line in output.getvalue().splitlines()]
    self.assertEqual(len(messages), 2)
    self.assertEqual({key: messages[0][key] for key in ("type", "version", "kind", "healthy", "code")}, {
      "type": "watch-event", "version": 1, "kind": "heartbeat", "healthy": True, "code": "ok",
    })
    self.assertEqual(messages[1]["code"], "polling-only")
    self.assertEqual(errors.getvalue(), "")
    self.assertEqual(signal_calls[-1], (CONTROL.signal.SIGTERM, previous_handler))

  def test_watch_survives_backend_process_start_failure(self):
    previous_handler = object()
    with mock.patch.object(CONTROL.shutil, "which", side_effect=lambda name: "/usr/bin/docker" if name == "docker" else None), \
         mock.patch.object(CONTROL.os.path, "realpath", side_effect=lambda path: path), \
         mock.patch.object(CONTROL.subprocess, "Popen", side_effect=PermissionError("denied")) as launch, \
         mock.patch.object(CONTROL.signal, "signal", return_value=previous_handler), \
         redirect_stdout(output := io.StringIO()), redirect_stderr(errors := io.StringIO()):
      self.assertFalse(CONTROL.watch_events())
    self.assertEqual([json.loads(line)["kind"] for line in output.getvalue().splitlines()], ["heartbeat", "heartbeat"])
    self.assertEqual(errors.getvalue(), "")
    self.assertEqual(launch.call_count, 1)

  def test_watch_debounces_backends_emits_idle_heartbeat_and_cleans_up(self):
    class EventStream:
      def readline(self): return "container changed\n"

    class Process:
      def __init__(self): self.stdout, self.terminated = EventStream(), False
      def poll(self): return None
      def terminate(self): self.terminated = True

    processes = [Process(), Process()]

    class Selector:
      def __init__(self): self.streams = []; self.calls = 0
      def register(self, stream, _events): self.streams.append(stream)
      def select(self, timeout):
        self.calls += 1
        if self.calls == 1: return [(types.SimpleNamespace(fileobj=stream), None) for stream in self.streams]
        if self.calls == 2: return []
        raise KeyboardInterrupt()

    previous_handler = object()
    signal_calls = []
    with mock.patch.object(CONTROL.shutil, "which", side_effect=lambda name: "/usr/bin/" + name if name in ("docker", "podman") else None), \
         mock.patch.object(CONTROL.os.path, "realpath", side_effect=lambda path: path), \
         mock.patch.object(CONTROL.subprocess, "Popen", side_effect=processes) as launch, \
         mock.patch.object(CONTROL.selectors, "DefaultSelector", side_effect=Selector), \
         mock.patch.object(CONTROL.time, "monotonic", side_effect=[10.0, 10.2, 10.2, 30.0]), \
         mock.patch.object(CONTROL.signal, "signal", side_effect=lambda kind, handler: signal_calls.append((kind, handler)) or previous_handler):
      output, errors = self.invoke("watch")

    messages = [json.loads(line) for line in output.splitlines()]
    self.assertEqual([message["kind"] for message in messages], ["heartbeat", "changed", "heartbeat"])
    self.assertEqual(errors, "")
    self.assertEqual([call.args[0] for call in launch.call_args_list], [
      ["/usr/bin/docker", "events", "--filter", "type=container"],
      ["/usr/bin/podman", "events", "--filter", "type=container"],
    ])
    self.assertTrue(all(process.terminated for process in processes))
    self.assertEqual(signal_calls[-1], (CONTROL.signal.SIGTERM, previous_handler))

  def test_copy_diagnostics_defaults_private_and_requires_explicit_unsafe(self):
    service = self.service("aria2")
    privacy = []

    def diagnostics(_service, private):
      privacy.append(private)
      return "filtered\n" if private else "unsafe\n"

    with mock.patch.object(CONTROL, "service_by_id", return_value=service), \
         mock.patch.object(CONTROL, "detected", return_value=True), \
         mock.patch.object(CONTROL.shutil, "which", return_value="/usr/bin/wl-copy"), \
         mock.patch.object(CONTROL.os.path, "realpath", side_effect=lambda path: path), \
         mock.patch.object(CONTROL.INSPECTOR, "diagnostics_text", side_effect=diagnostics), \
         mock.patch.object(CONTROL.subprocess, "run") as copy:
      self.invoke("copy-diagnostics", "aria2")
      self.invoke("copy-diagnostics", "aria2", "unsafe")

    self.assertEqual(privacy, [True, False])
    self.assertEqual([call.kwargs["input"] for call in copy.call_args_list], ["filtered\n", "unsafe\n"])
    for call in copy.call_args_list:
      self.assertEqual(call.args[0], ["/usr/bin/wl-copy"])
      self.assertTrue(call.kwargs["check"])

  def test_unknown_service_commands_fail_before_any_external_side_effect(self):
    commands = [
      ("install", "missing"),
      ("uninstall", "missing"),
      ("restore-backup", "missing", "snapshot"),
      ("action", "missing", "start"),
      ("logs", "missing"),
      ("copy-diagnostics", "missing"),
    ]
    with mock.patch.object(CONTROL, "install_service") as install, \
         mock.patch.object(CONTROL, "uninstall_service") as uninstall, \
         mock.patch.object(CONTROL.BACKUPS, "restore") as restore, \
         mock.patch.object(CONTROL, "control") as control, \
         mock.patch.object(CONTROL, "show_logs") as logs, \
         mock.patch.object(CONTROL, "detected") as detected, \
         mock.patch.object(CONTROL.subprocess, "run") as external:
      for command in commands:
        with self.subTest(command=command), self.assertRaises(SystemExit):
          self.invoke(*command)
    for operation in (install, uninstall, restore, control, logs, detected, external):
      operation.assert_not_called()


if __name__ == "__main__":
  unittest.main()
