import pathlib, sys, unittest

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from p2p_support import support_report, support_report_text


class SupportReportTest(unittest.TestCase):
  def test_report_keeps_aggregates_and_drops_sensitive_runtime_fields(self):
    report = support_report(
      {"id": "plugin", "version": "1.2.3", "schemaVersion": 1},
      {"privacyFilter": False, "consoleHost": "private.home", "serviceLabels": {"x": "Alice"}, "serviceLayout": "grid"},
      {"durationMs": 12, "diagnostics": [{"code": "timeout", "detail": "/home/alice/secret"}], "services": [
        {"id": "custom-alice", "name": "Alice node", "active": True, "backend": "docker", "category": "Sync", "pids": [123], "endpoints": ["10.0.0.1"]},
        {"id": "i2pd", "active": False, "hasError": True, "backend": "systemd", "category": "Privacy"},
      ]}, {"watcherHealth":"polling","watcherCode":"polling-only","privatePath":"/home/alice"})
    text = support_report_text(report)
    self.assertTrue(report["privacyFiltered"])
    self.assertEqual(report["settings"], {"privacyFilter": True, "serviceLayout": "grid"})
    self.assertEqual(report["services"]["states"], {"running": 1, "unhealthy": 1})
    self.assertEqual(report["monitoring"]["watcherCode"], "polling-only")
    for secret in ("Alice", "custom-alice", "10.0.0.1", "/home/alice", "private.home", "123"):
      self.assertNotIn(secret, text)


if __name__ == "__main__": unittest.main()
