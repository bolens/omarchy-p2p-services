import pathlib
import tempfile
import types
import unittest
from unittest import mock

from backend.p2p_runtime import RuntimeProbe
from backend.p2p_snapshot import SnapshotContext


class RuntimeProbeTests(unittest.TestCase):
  def setUp(self):
    self.snapshot = SnapshotContext()
    self.calls = []

    def run(args, timeout):
      self.calls.append((args, timeout))
      if args[0] == "/usr/bin/ps":
        return types.SimpleNamespace(stdout="1000 42 123 daemon /usr/bin/daemon --flag\n1001 43 8 other /opt/daemon\n", returncode=0)
      return types.SimpleNamespace(stdout=(
        "Id=daemon.service\nLoadState=loaded\nActiveState=active\nSubState=running\n"
        "Result=success\nExecMainStatus=0\nMainPID=77\nNRestarts=2\n\n"
      ), returncode=0)

    services = lambda: [
      {"id": "daemon", "units": ["daemon.service"]},
      {"id": "peer", "units": ["peer.service", "daemon.service"]},
    ]
    self.probe = RuntimeProbe(
      self.snapshot, run, services, "/usr/bin/ps", "/usr/bin/systemctl",
      {"daemon": ["daemon", "daemon-node"]},
    )

  def test_process_queries_share_one_snapshot(self):
    with mock.patch("backend.p2p_runtime.os.getuid", return_value=1000):
      self.assertEqual(self.probe.pids_for(["daemon"], current_user_only=True), [42])
    self.assertEqual(self.probe.pids_for(["daemon"]), [42, 43])
    with mock.patch.object(self.probe, "process_rows", wraps=self.probe.process_rows) as rows:
      self.assertEqual(self.probe.pid_uptime(42), 123)
      self.assertEqual(self.probe.pid_uptime(42), 123)
    rows.assert_called_once_with()
    self.assertEqual(sum(args[0] == "/usr/bin/ps" for args, _ in self.calls), 1)

  def test_systemd_queries_batch_unique_declared_units_by_scope(self):
    self.assertEqual(self.probe.unit_state(["daemon.service"], True), ("daemon.service", True))
    self.assertEqual(self.probe.unit_main_pid("daemon.service", True), 77)
    self.assertFalse(self.probe.unit_has_error("daemon.service", True))
    self.assertEqual(len(self.calls), 1)
    args, timeout = self.calls[0]
    self.assertEqual(args[:3], ["/usr/bin/systemctl", "--user", "show"])
    self.assertEqual(args.count("daemon.service"), 1)
    self.assertIn("peer.service", args)
    self.assertEqual(timeout, 8)

    self.probe.unit_state(["daemon.service"], False)
    self.assertEqual(len(self.calls), 2)
    self.assertNotIn("--user", self.calls[1][0])

  def test_container_matching_uses_only_exact_runtime_identifiers(self):
    service = {"id": "daemon"}
    item = lambda name, image="", compose="": {
      "Name": "/" + name,
      "Config": {"Image": image, "Labels": {"com.docker.compose.service": compose}},
    }
    self.assertTrue(self.probe.container_matches_service(service, item("daemon-node")))
    self.assertTrue(self.probe.container_matches_service(service, item("other", compose="daemon")))
    self.assertTrue(self.probe.container_matches_service(service, item("other", image="vendor/daemon:latest")))
    self.assertFalse(self.probe.container_matches_service(service, item("old-daemon-backup")))

  def test_service_container_matches_are_indexed_once_per_snapshot(self):
    service = {"id":"daemon"}
    self.probe.services = lambda: [service]
    items = [{"Name":"/daemon","Config":{"Labels":{},"Image":"daemon"}}]
    with mock.patch.object(self.probe, "containers", return_value=items) as containers, \
         mock.patch.object(self.probe, "container_matches_service", wraps=self.probe.container_matches_service) as match:
      first = self.probe.docker_matches(service)
      second = self.probe.docker_matches(service)
    self.assertIs(first, second)
    containers.assert_called_once_with()
    match.assert_called_once()

  def test_all_service_container_matches_share_one_inverted_index(self):
    daemon = {"id":"daemon", "units":[]}
    peer = {"id":"peer", "units":[]}
    self.probe.services = lambda: [daemon, peer]
    self.probe.aliases["peer"] = ["peer"]
    items = [
      {"Name":"/daemon","Config":{"Labels":{},"Image":"daemon"}},
      {"Name":"/peer","Config":{"Labels":{},"Image":"peer"}},
    ]
    with mock.patch.object(self.probe, "containers", return_value=items) as containers:
      self.assertEqual(self.probe.docker_matches(daemon), [items[0]])
      self.assertEqual(self.probe.docker_matches(peer), [items[1]])
      self.assertEqual(self.probe.docker_matches(daemon), [items[0]])
    containers.assert_called_once_with()

  def test_container_discovery_uses_resolved_runtime_and_caches_inspection(self):
    calls = []

    def run(args, timeout):
      calls.append((args, timeout))
      if args[1:3] == ["ps", "-aq"]:
        return types.SimpleNamespace(returncode=0, stdout="abc123\n")
      return types.SimpleNamespace(returncode=0, stdout='[{"Name":"/daemon","State":{"Running":true}}]')

    probe = RuntimeProbe(self.snapshot, run, lambda: [], "/usr/bin/ps", "/usr/bin/systemctl", {})
    with mock.patch("backend.p2p_runtime.shutil.which", side_effect=lambda name: "/usr/bin/docker" if name == "docker" else None), \
         mock.patch("backend.p2p_runtime.os.path.realpath", side_effect=lambda path: path):
      first = probe.containers()
      second = probe.containers()
    self.assertIs(first, second)
    self.assertEqual(first[0]["_runtime"], "docker")
    self.assertEqual(first[0]["_runtime_cmd"], "/usr/bin/docker")
    self.assertEqual(len(calls), 2)

  def test_container_discovery_order_is_stable(self):
    def run(args, _timeout):
      if args[1] == "ps": return types.SimpleNamespace(returncode=0,stdout="zeta alpha\n")
      return types.SimpleNamespace(returncode=0,stdout='[{"Name":"/zeta"},{"Name":"/alpha"}]')
    probe = RuntimeProbe(self.snapshot,run,lambda: [],"/usr/bin/ps","/usr/bin/systemctl",{})
    with mock.patch("backend.p2p_runtime.shutil.which",side_effect=lambda name:"/usr/bin/docker" if name == "docker" else None), \
         mock.patch("backend.p2p_runtime.os.path.realpath",side_effect=lambda path:path):
      self.assertEqual([item["Name"] for item in probe.containers()],["/alpha","/zeta"])

  def test_container_discovery_treats_malformed_inspection_as_unavailable(self):
    def run(args, _timeout):
      if args[1] == "ps": return types.SimpleNamespace(returncode=0, stdout="abc123\n")
      return types.SimpleNamespace(returncode=0, stdout="not-json")

    probe = RuntimeProbe(self.snapshot, run, lambda: [], "/usr/bin/ps", "/usr/bin/systemctl", {})
    with mock.patch("backend.p2p_runtime.shutil.which", side_effect=lambda name: "/usr/bin/docker" if name == "docker" else None), \
         mock.patch("backend.p2p_runtime.os.path.realpath", side_effect=lambda path: path):
      self.assertEqual(probe.containers(), [])

  def test_diagnostics_combines_systemd_and_container_failure_signals(self):
    self.snapshot.unit_snapshots[True] = {"daemon.service": {
      "NRestarts": "2", "Result": "exit-code", "ExecMainStatus": "7",
      "ActiveStateChangeTimestamp": "today",
    }}
    containers = [{"RestartCount": 3, "State": {"Health": {"Status": "unhealthy"}, "OOMKilled": True, "Error": "runtime failure"}}]
    restarts, transition, reason = self.probe.service_diagnostics("daemon.service", "", containers, containers)
    self.assertEqual(restarts, 5)
    self.assertEqual(transition, "today")
    self.assertEqual(reason, "exit-code; exit 7; container unhealthy; container OOM-killed; runtime failure")

  def test_uptime_sources_return_elapsed_seconds_and_reject_invalid_state(self):
    self.snapshot.unit_snapshots[True] = {"daemon.service": {"ActiveState": "active", "ActiveEnterTimestampMonotonic": "1000000"}}
    with mock.patch("backend.p2p_runtime.pathlib.Path.read_text", return_value="11.0 0.0\n"):
      self.assertEqual(self.probe.unit_uptime("daemon.service", True), 10)
    self.snapshot.unit_snapshots[True]["daemon.service"]["ActiveEnterTimestampMonotonic"] = "invalid"
    self.assertEqual(self.probe.unit_uptime("daemon.service", True), 0)

    running = {"State": {"Running": True, "StartedAt": "2020-01-01T00:00:00Z"}}
    self.assertGreater(self.probe.container_uptime(running), 60)
    self.assertEqual(self.probe.container_uptime({"State": {"Running": True, "StartedAt": "invalid"}}), 0)
    self.assertEqual(self.probe.container_uptime({"State": {"Running": False}}), 0)

  def test_container_stats_ignore_stopped_items_and_malformed_runtime_output(self):
    calls = []

    def run(args, timeout):
      calls.append((args, timeout))
      return types.SimpleNamespace(returncode=0, stdout="not-json")

    probe = RuntimeProbe(self.snapshot, run, lambda: [], "/usr/bin/ps", "/usr/bin/systemctl", {})
    running = {"Name": "/daemon", "_runtime": "docker", "_runtime_cmd": "/usr/bin/docker", "State": {"Running": True}}
    stopped = {"Name": "/old", "_runtime": "docker", "_runtime_cmd": "/usr/bin/docker", "State": {"Running": False}}
    self.assertEqual(probe.container_stats([running, stopped]), {})
    self.assertEqual(len(calls), 1)
    self.assertIn("daemon", calls[0][0])
    self.assertNotIn("old", calls[0][0])

  def test_proxy_discovery_validates_labels_and_parses_trusted_proxy_configs(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      compose = root/"compose.yml"
      compose.write_text("services: {}\n")
      (root/"nginx.conf").write_text("server { server_name sync.home.arpa public.example.test; }\n")
      (root/"haproxy.cfg").write_text("acl local hdr(host) -i peer.local\n")
      labels = {
        "traefik.http.routers.sync.rule": "Host(`router.example.test`)",
        "traefik.http.routers.bad.rule": "Host(`bad/host`)",
        "com.docker.compose.project.working_dir": str(root),
        "com.docker.compose.project.config_files": str(compose),
      }
      item = {"Config": {"Labels": labels}}
      candidates = self.probe.proxy_candidates([item])
    self.assertIn((0, "https://router.example.test/", "traefik"), candidates)
    self.assertIn((1, "https://sync.home.arpa/", "nginx"), candidates)
    self.assertIn((0, "https://public.example.test/", "nginx"), candidates)
    self.assertIn((1, "https://peer.local/", "haproxy"), candidates)
    self.assertFalse(any("bad/host" in candidate[1] for candidate in candidates))


if __name__ == "__main__":
  unittest.main()
