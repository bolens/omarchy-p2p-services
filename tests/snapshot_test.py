import unittest

from p2p_snapshot import SnapshotContext


class SnapshotContextTests(unittest.TestCase):
  def test_reset_clears_probe_caches_but_preserves_diagnostics(self):
    context=SnapshotContext()
    context.packages={"syncthing"}; context.warning("partial_probe",detail="timeout")
    context.reset(all_containers=False)
    self.assertIsNone(context.packages)
    self.assertFalse(context.all_containers)
    self.assertEqual(context.process_matches, {})
    self.assertEqual(context.diagnostics[0]["code"],"partial_probe")


if __name__ == "__main__": unittest.main()
