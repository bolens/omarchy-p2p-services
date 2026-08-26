import unittest

from p2p_inspection import ServiceInspector, public_web_fields
from p2p_snapshot import SnapshotContext


class FakeProbe:
  def pids_for(self, _names): return [42]
  def docker_matches(self, _service):
    return [{"Name": "/daemon", "_runtime": "docker", "State": {"Running": True, "Pid": 99}}]
  def unit_state(self, _units, user): return ("daemon.service", True) if user else ("", False)
  def unit_main_pid(self, unit, _user): return 77 if unit else 0
  def unit_has_error(self, _unit, _user): return False
  def service_diagnostics(self, *_args): return (2, "recently", "")
  def unit_uptime(self, unit, _user): return 100 if unit else 0
  def container_uptime(self, _item): return 80
  def pid_uptime(self, pid): return {42: 60, 77: 50, 99: 40}.get(pid, 0)
  def proxy_candidates(self, _items): return [(0, "https://daemon.example.test/", "traefik")]
  def published_url(self, *_args): return ""


class ServiceInspectorTests(unittest.TestCase):
  def setUp(self):
    snapshot = SnapshotContext()
    snapshot.container_stats = {("docker", "daemon"): (1024, 2048)}
    self.socket_calls = []

    def sockets(pids, private):
      self.socket_calls.append((pids, private))
      return 3, 1, [] if private else ["127.0.0.1:9000"]

    self.inspector = ServiceInspector(FakeProbe(), snapshot, sockets, lambda _service, _items: ["/secret/daemon.conf"])
    self.service = {"id": "daemon", "name": "Daemon", "icon": "D", "category": "Test", "processes": ["daemon"], "units": ["daemon.service"], "config": "~/.config/daemon", "web": "http://127.0.0.1:9000/"}

  def test_private_projection_redacts_identifiers_but_preserves_aggregates(self):
    entry = self.inspector.inspect(self.service, True)
    self.assertEqual(entry["pids"], [])
    self.assertEqual(entry["endpoints"], [])
    self.assertEqual(entry["containers"], [])
    self.assertEqual(entry["config"], "Hidden")
    self.assertEqual(entry["web"], "Available")
    self.assertEqual(entry["defaultWeb"], "")
    self.assertEqual((entry["processCount"], entry["containerCount"]), (3, 1))
    self.assertEqual((entry["connections"], entry["listeners"]), (3, 1))
    self.assertEqual((entry["rxBytes"], entry["txBytes"]), (1024, 2048))
    self.assertEqual(entry["uptime"], 100)
    self.assertEqual(entry["backend"], "docker")
    self.assertTrue(entry["privacyFiltered"])

  def test_public_projection_exposes_operational_details(self):
    entry = self.inspector.inspect(self.service, False)
    self.assertEqual(entry["pids"], [42, 77, 99])
    self.assertEqual(entry["endpoints"], ["127.0.0.1:9000"])
    self.assertEqual(entry["containers"], ["daemon"])
    self.assertEqual(entry["config"], "/secret/daemon.conf")
    self.assertEqual(entry["web"], "https://daemon.example.test/")
    self.assertEqual(entry["proxy"], "traefik")
    self.assertEqual(entry["unitScope"], "user")
    self.assertEqual(entry["restartCount"], 2)

  def test_diagnostics_is_derived_from_privacy_projection(self):
    text = self.inspector.diagnostics_text(self.service, True)
    self.assertIn("Daemon (daemon)", text)
    self.assertIn("Privacy filtered: yes", text)
    self.assertNotIn("/secret/", text)
    self.assertNotIn("https://", text)

  def test_private_projection_redacts_untrusted_failure_detail(self):
    self.inspector.probe.service_diagnostics = lambda *_args: (1, "recently", "failed at /home/alice/secret.conf on 10.0.0.8")
    private = self.inspector.inspect(self.service, True)
    public = self.inspector.inspect(self.service, False)
    self.assertEqual(private["failureReason"], "Service reported an error")
    self.assertEqual(public["failureReason"], "failed at /home/alice/secret.conf on 10.0.0.8")
    self.assertNotIn("/home/alice", self.inspector.diagnostics_text(self.service, True))

  def test_web_projection_never_reports_invalid_urls_as_available(self):
    self.assertEqual(public_web_fields("javascript:alert(1)", False), ("", "", False))
    self.assertEqual(public_web_fields("javascript:alert(1)", True), ("", "", False))
    self.assertEqual(public_web_fields(" https://node.example.test/ui ", False),
                     ("https://node.example.test/ui", "https://node.example.test/ui", True))
    self.assertEqual(public_web_fields("https://node.example.test/ui", True), ("Available", "", True))


if __name__ == "__main__":
  unittest.main()
