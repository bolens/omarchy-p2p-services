import pathlib
import tempfile
from unittest import mock

from control_test_support import CONTROL, ROOT, ControlTestCase


class DiscoveryIntegrationTests(ControlTestCase):
  def test_package_detection_uses_one_snapshot_and_short_circuits_other_probes(self):
    calls = []

    def package_query(args, timeout=2):
      calls.append((args, timeout))
      return type("Result", (), {"returncode": 0, "stdout": "i2pd\n", "stderr": ""})()

    with mock.patch.object(CONTROL, "run", side_effect=package_query), \
         mock.patch.object(CONTROL.PROBE, "docker_matches") as containers, \
         mock.patch.object(CONTROL.PROBE, "pids_for") as processes, \
         mock.patch.object(CONTROL.PROBE, "unit_state") as units:
      self.assertTrue(CONTROL.detected(self.service("i2pd")))
      self.assertTrue(CONTROL.detected(self.service("i2pd")))
    self.assertEqual(calls, [(["/usr/bin/pacman", "-Qq"], 5)])
    containers.assert_not_called()
    processes.assert_not_called()
    units.assert_not_called()

  def test_detection_falls_through_to_declared_system_unit(self):
    CONTROL.SNAPSHOT.packages = set()
    service = self.service("yggdrasil")
    with mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[]), \
         mock.patch.object(CONTROL, "command_path", return_value=""), \
         mock.patch.object(CONTROL.PROBE, "pids_for", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", side_effect=[("", False), ("yggdrasil.service", False)]) as units:
      self.assertTrue(CONTROL.detected(service))
    self.assertEqual(units.call_args_list, [mock.call(service["units"], True), mock.call(service["units"], False)])

  def test_container_matching_is_exact(self):
    service = self.service("i2p")
    self.assertFalse(CONTROL.PROBE.container_matches_service(service, self.item("unrelated-i2p-archive")))
    self.assertTrue(CONTROL.PROBE.container_matches_service(service, self.item("i2p-router")))
    self.assertTrue(CONTROL.PROBE.container_matches_service(service, self.item("router", service="i2p")))

  def test_mesh_service_container_aliases_match_exactly_without_prefix_collisions(self):
    aliases = {
      "tailscale": "tailscaled", "zerotier": "zerotier-one", "nebula": "nebula",
      "headscale": "headscale", "netbird": "netbird-client",
      "netbird-server": "netbird-management", "netmaker": "netmaker-server",
      "netclient": "netclient",
    }
    for service_id, alias in aliases.items():
      service = self.service(service_id)
      with self.subTest(service=service_id):
        self.assertTrue(CONTROL.PROBE.container_matches_service(service, self.item(alias)))
        self.assertFalse(CONTROL.PROBE.container_matches_service(service, self.item(alias + "-backup")))

  def test_freenet_and_hyphanet_are_distinct(self):
    freenet = self.service("freenet")
    hyphanet = self.service("hyphanet")
    self.assertEqual(freenet["web"], "http://127.0.0.1:7509/")
    self.assertEqual(freenet["units"], ["freenet.service"])
    self.assertEqual(hyphanet["web"], "http://127.0.0.1:8888/")
    self.assertEqual(hyphanet["units"], ["hyphanet.service"])
    self.assertEqual(CONTROL.PACKAGE_HINTS["freenet"], [])
    self.assertEqual(CONTROL.PACKAGE_HINTS["hyphanet"], [])

  def test_all_services_merges_valid_durable_custom_rows_without_mutating_catalog(self):
    before = list(CONTROL.SERVICES)
    durable = {"customServices": [
      {"id": "custom-node", "name": "Node", "commands": ["node"], "processes": [], "units": []},
      {"id": "i2pd", "name": "Reserved", "commands": ["other"], "processes": [], "units": []},
    ]}
    with mock.patch.object(CONTROL.SETTINGS, "load", return_value=durable):
      combined = CONTROL.all_services()
    self.assertEqual([service["id"] for service in combined[-1:]], ["custom-node"])
    self.assertEqual(len(combined), len(before) + 1)
    self.assertEqual(CONTROL.SERVICES, before)

  def test_custom_services_are_constrained_and_shell_free(self):
    rows = CONTROL.normalized_custom_services([
      {"id":"custom-demo","name":"Demo","icon":"D","commands":["demo"],"processes":["demo"],"units":["demo.service"],"config":"~/.config/demo","web":"http://127.0.0.1:9000/"},
      {"id":"bad","name":"Bad","commands":["sh -c evil"],"processes":[],"units":[]},
      {"id":"custom-shell","name":"Bad command","commands":["sh -c evil"],"processes":[],"units":[]},
      {"id":"custom-url","name":"Bad URL","commands":["demo"],"web":"javascript:alert(1)"},
    ])
    self.assertEqual([row["id"] for row in rows], ["custom-demo", "custom-url"])
    self.assertEqual(rows[0]["commands"], ["demo"])
    self.assertEqual(rows[1]["web"], "")

  def test_published_url_uses_safe_host_override_and_port_mapping(self):
    service = dict(self.service("syncthing"), web="http://127.0.0.1:8384/")
    item = {"NetworkSettings": {"Ports": {"8384/tcp": [{"HostIp": "0.0.0.0", "HostPort": "18384"}]}}}
    self.assertEqual(CONTROL.PROBE.published_url(service, [item], "node.home.arpa"), "http://node.home.arpa:18384/")
    self.assertEqual(CONTROL.PROBE.published_url(service, [item], "bad/host"), "http://127.0.0.1:18384/")

  def test_proxy_discovery_reads_only_compose_trusted_project_files(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory); compose = root/"compose.yml"; compose.write_text("services: {}\n")
      (root/"caddy_snippet.conf").write_text("sync.home.arpa {\n reverse_proxy app:8384\n}\n")
      item = self.item("syncthing", workdir=str(root), config_files=str(compose))
      self.assertIn((1, "https://sync.home.arpa/", "caddy"), CONTROL.PROBE.proxy_candidates([item]))
      outside = root.parent/"outside-compose.yml"; outside.write_text("services: {}\n")
      untrusted = self.item("syncthing", workdir=str(root), config_files=str(outside))
      self.assertEqual(CONTROL.PROBE.proxy_candidates([untrusted]), [])

  def test_fuse_btfs_is_not_detected_as_btfs_node(self):
    service = self.service("btfs")
    original_which, original_run = CONTROL.shutil.which, CONTROL.run
    try:
      CONTROL.shutil.which = lambda command: "/usr/bin/btfs" if command == "btfs" else None
      CONTROL.run = lambda args, timeout=2: type("Result", (), {"returncode": 255, "stdout": "", "stderr": "Find metadata failed"})()
      self.assertEqual(CONTROL.command_path(service), "")
      CONTROL.run = lambda args, timeout=2: type("Result", (), {"returncode": 0, "stdout": "btfs version 2.3.1", "stderr": ""})()
      self.assertEqual(CONTROL.command_path(service), "/usr/bin/btfs")
    finally:
      CONTROL.shutil.which, CONTROL.run = original_which, original_run
    self.assertEqual(CONTROL.PACKAGE_HINTS["btfs"], [])

  def test_monerod_rpc_is_not_exposed_as_browser_console(self):
    monerod = self.service("monerod")
    self.assertEqual(monerod["web"], "")

  def test_lokinet_marks_root_managed_config(self):
    lokinet = self.service("lokinet")
    self.assertEqual(lokinet["config"], "/etc/loki/lokinet.ini")
    self.assertTrue(lokinet["protectedConfig"])

  def test_inspect_privacy_redacts_identifiers_but_preserves_aggregates(self):
    service = self.service("syncthing")
    item = self.item("syncthing")
    item.update({"_runtime":"docker", "State":{"Running":True,"Pid":42,"StartedAt":"2020-01-01T00:00:00Z"}})
    CONTROL.SNAPSHOT.container_stats = {("docker", "syncthing"): (1024, 2048)}
    with mock.patch.object(CONTROL.PROBE, "pids_for", return_value=[]), \
         mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[item]), \
         mock.patch.object(CONTROL.PROBE, "unit_state", return_value=("", False)), \
         mock.patch.object(CONTROL.PROBE, "unit_has_error", return_value=False), \
         mock.patch.object(CONTROL.PROBE, "service_diagnostics", return_value=(0, "", "")), \
         mock.patch.object(CONTROL, "sockets", side_effect=lambda pids, private: (2, 1, [] if private else ["secret endpoint"])), \
         mock.patch.object(CONTROL.PROBE, "unit_uptime", return_value=0), \
         mock.patch.object(CONTROL.PROBE, "pid_uptime", return_value=60), \
         mock.patch.object(CONTROL, "config_targets", return_value=["/secret/config"]), \
         mock.patch.object(CONTROL.PROBE, "proxy_candidates", return_value=[(0, "https://sync.example.test/", "caddy")]):
      private = CONTROL.INSPECTOR.inspect(service, True)
      public = CONTROL.INSPECTOR.inspect(service, False)
    self.assertEqual(private["pids"], [])
    self.assertEqual(private["endpoints"], [])
    self.assertEqual(private["containers"], [])
    self.assertEqual(private["config"], "Hidden")
    self.assertEqual(private["web"], "Available")
    self.assertEqual(private["category"], "File sync")
    self.assertEqual((private["processCount"], private["connections"], private["rxBytes"], private["txBytes"]), (1, 2, 1024, 2048))
    self.assertEqual(public["pids"], [42])
    self.assertEqual(public["web"], "https://sync.example.test/")

  def test_private_diagnostics_omit_paths_urls_pids_and_endpoints(self):
    service = self.service("syncthing")
    entry = {"name":"Syncthing","id":"syncthing","health":"healthy","backend":"docker","restartCount":1,
      "unit":"syncthing.service","lastTransition":"today","failureReason":"","config":"Hidden","pids":[],"endpoints":[],"web":"Available"}
    with mock.patch.object(CONTROL.INSPECTOR, "inspect", return_value=entry):
      text = CONTROL.INSPECTOR.diagnostics_text(service, True)
    self.assertIn("Privacy filtered: yes", text)
    for secret in ("/home/", "http://", "https://", "PID:", "endpoint"):
      self.assertNotIn(secret, text)

  def test_process_snapshot_is_shared_by_pid_and_uptime_queries(self):
    original_run = CONTROL.run
    calls = []
    try:
      def fake_run(args, timeout=2):
        calls.append(args)
        return type("Result", (), {"returncode": 0, "stdout": "1000 42 123 daemon /usr/bin/daemon --flag\n", "stderr": ""})()
      CONTROL.run = fake_run
      self.assertEqual(CONTROL.PROBE.pids_for(["daemon"]), [42])
      self.assertEqual(CONTROL.PROBE.pids_for(["daemon"]), [42])
      self.assertEqual(CONTROL.PROBE.pid_uptime(42), 123)
      self.assertEqual(len(calls), 1)
    finally:
      CONTROL.run = original_run

  def test_status_snapshot_inspects_only_detected_services_with_requested_privacy(self):
    original_detected, original_inspect = CONTROL.detected, CONTROL.INSPECTOR.inspect
    try:
      inspected = []
      CONTROL.detected = lambda service: service["id"] == "aria2"
      CONTROL.INSPECTOR.inspect = lambda service, private, console_host="": inspected.append((service["id"], private, console_host)) or {"id": service["id"]}
      result = CONTROL.status_snapshot(True, "", False, False)
      self.assertEqual(result, [{"id": "aria2"}])
      self.assertEqual(inspected, [("aria2", True, "")])
      self.assertFalse(CONTROL.SNAPSHOT.all_containers)
    finally:
      CONTROL.detected, CONTROL.INSPECTOR.inspect = original_detected, original_inspect

  def test_status_snapshot_collects_running_container_stats_once_per_runtime_name(self):
    services = [self.service("syncthing"), self.service("resilio")]
    shared = self.item("shared-sync")
    shared.update({"_runtime": "docker", "_runtime_cmd": "/usr/bin/docker"})
    stopped = self.item("stopped-sync")
    stopped.update({"_runtime": "docker", "State": {"Running": False}})
    with mock.patch.object(CONTROL, "all_services", return_value=services), \
         mock.patch.object(CONTROL, "detected", return_value=True), \
         mock.patch.object(CONTROL.PROBE, "docker_matches", return_value=[shared, stopped]), \
         mock.patch.object(CONTROL.PROBE, "container_stats") as stats, \
         mock.patch.object(CONTROL.INSPECTOR, "inspect", side_effect=lambda service, private, host: {"id": service["id"]}):
      result = CONTROL.status_snapshot(False, "node.home", True, False)
    self.assertEqual(result, [{"id": "syncthing"}, {"id": "resilio"}])
    stats.assert_called_once_with([shared])
    self.assertFalse(CONTROL.SNAPSHOT.all_containers)

  def test_watch_messages_are_versioned_bounded_and_non_sensitive(self):
    payload = CONTROL.watch_event_payload("changed", False, "backend_unavailable" * 10)
    self.assertEqual(payload["type"], "watch-event")
    self.assertEqual(payload["version"], 1)
    self.assertEqual(payload["kind"], "changed")
    self.assertFalse(payload["healthy"])
    self.assertEqual(len(payload["code"]), 64)
    self.assertNotIn("path", payload)
    self.assertNotIn("command", payload)

  def test_socket_snapshot_is_shared_between_services(self):
    original_run = CONTROL.run
    calls = []
    try:
      def fake_run(args, timeout=2):
        calls.append(args)
        return type("Result", (), {"returncode": 0, "stdout": 'tcp ESTAB 0 0 127.0.0.1:1 127.0.0.1:2 users:(("daemon",pid=42,fd=3))\n', "stderr": ""})()
      CONTROL.run = fake_run
      self.assertEqual(CONTROL.sockets([42], True)[:2], (1, 0))
      self.assertEqual(CONTROL.sockets([42], False)[:2], (1, 0))
      self.assertEqual(len(calls), 1)
    finally:
      CONTROL.run = original_run

  def test_systemd_snapshot_batches_declared_units(self):
    original_run = CONTROL.run
    calls = []
    try:
      output = "Id=monerod.service\nLoadState=loaded\nActiveState=active\nSubState=running\nActiveEnterTimestampMonotonic=1\nMainPID=77\nResult=success\nExecMainStatus=0\n"
      def fake_run(args, timeout=2):
        calls.append(args)
        return type("Result", (), {"returncode": 0, "stdout": output, "stderr": ""})()
      CONTROL.run = fake_run
      self.assertEqual(CONTROL.PROBE.unit_state(["monerod.service"], False), ("monerod.service", True))
      self.assertEqual(CONTROL.PROBE.unit_main_pid("monerod.service", False), 77)
      self.assertFalse(CONTROL.PROBE.unit_has_error("monerod.service", False))
      self.assertGreater(CONTROL.PROBE.unit_uptime("monerod.service", False), 0)
      self.assertEqual(len(calls), 1)
      self.assertIn("yggdrasil.service", calls[0])
      self.assertIn("monerod.service", calls[0])
    finally:
      CONTROL.run = original_run

  def test_fast_container_snapshot_lists_only_running_containers(self):
    original_run = CONTROL.run
    original_which = CONTROL.shutil.which
    calls = []
    try:
      CONTROL.SNAPSHOT.all_containers = False
      CONTROL.shutil.which = lambda runtime: "/usr/bin/docker" if runtime == "docker" else None
      def fake_run(args, timeout=2):
        calls.append(args)
        return type("Result", (), {"returncode": 0, "stdout": "", "stderr": ""})()
      CONTROL.run = fake_run
      self.assertEqual(CONTROL.PROBE.containers(), [])
      self.assertEqual(calls[0][1:], ["ps", "-q"])
    finally:
      CONTROL.run = original_run
      CONTROL.shutil.which = original_which

  def test_container_stats_only_queries_requested_items(self):
    original_run = CONTROL.run
    calls = []
    try:
      item = self.item("syncthing")
      item["_runtime"] = "docker"
      item["_runtime_cmd"] = "/usr/bin/docker"
      def fake_run(args, timeout=2):
        calls.append(args)
        return type("Result", (), {"returncode": 0, "stdout": '{"Name":"syncthing","NetIO":"1KiB / 2KiB"}\n', "stderr": ""})()
      CONTROL.run = fake_run
      stats = CONTROL.PROBE.container_stats([item])
      self.assertEqual(stats[("docker", "syncthing")], (1024, 2048))
      self.assertEqual(len(calls), 1)
      self.assertIn("syncthing", calls[0])
      self.assertNotIn("unrelated", calls[0])
    finally:
      CONTROL.run = original_run
