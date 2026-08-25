import pathlib
import tempfile
import unittest
from unittest import mock

from p2p_cache import cached_status


class StatusCacheTests(unittest.TestCase):
  def test_partitions_keys_and_reuses_fresh_payload(self):
    with tempfile.TemporaryDirectory() as directory:
      calls = []
      root = pathlib.Path(directory)
      first = cached_status("private:no-stats", lambda: calls.append(1) or {"services": [1]}, root, ttl=10)
      second = cached_status("private:no-stats", lambda: calls.append(2) or {"services": [2]}, root, ttl=10)
      other = cached_status("unsafe:no-stats", lambda: calls.append(3) or {"services": [3]}, root, ttl=10)
      self.assertEqual(first, second)
      self.assertEqual(other["services"], [3])
      self.assertEqual(calls, [1, 3])

  def test_bypass_invalidates_every_partition_before_refresh(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      cached_status("first", lambda: {"generation": 1}, root, ttl=10)
      cached_status("second", lambda: {"generation": 1}, root, ttl=10)
      refreshed = cached_status("first", lambda: {"generation": 2}, root, ttl=10, bypass=True)
      self.assertEqual(refreshed["generation"], 2)
      self.assertEqual(len(list(root.glob("*.json"))), 1)
      self.assertEqual(cached_status("second", lambda: {"generation": 2}, root, ttl=10)["generation"], 2)

  def test_bounds_payloads_and_recovers_from_corruption(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      for generation in range(8):
        cached_status("key-%d" % generation, lambda generation=generation: {"generation": generation}, root, ttl=10, max_entries=3)
      self.assertLessEqual(len(list(root.glob("*.json"))), 3)
      cached_status("corrupt", lambda: {"generation": 1}, root, ttl=10, max_entries=4)
      target = max(root.glob("*.json"), key=lambda path: path.stat().st_mtime_ns)
      target.write_text("not json")
      self.assertEqual(cached_status("corrupt", lambda: {"recovered": True}, root, ttl=10)["recovered"], True)

  def test_cache_files_are_private_and_failed_producer_leaves_no_partial_payload(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory) / "cache"
      cached_status("safe", lambda: {"services": []}, root)
      self.assertEqual(root.stat().st_mode & 0o777, 0o700)
      self.assertTrue(all(path.stat().st_mode & 0o777 == 0o600 for path in root.iterdir()))
      with self.assertRaisesRegex(RuntimeError, "probe failed"):
        cached_status("failure", lambda: (_ for _ in ()).throw(RuntimeError("probe failed")), root)
      self.assertEqual(list(root.glob("*.tmp-*")), [])

  def test_unavailable_cache_storage_falls_back_to_uncached_producer(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)/"cache"
      with mock.patch("p2p_cache.pathlib.Path.mkdir", side_effect=OSError("read only")):
        self.assertEqual(cached_status("key", lambda: {"fresh": True}, root), {"fresh": True})

  def test_symlinked_cache_root_is_never_traversed_or_pruned(self):
    with tempfile.TemporaryDirectory() as directory:
      base = pathlib.Path(directory); outside = base/"outside"; outside.mkdir()
      marker = outside/"keep.json"; marker.write_text("preserve")
      root = base/"cache"; root.symlink_to(outside, target_is_directory=True)
      self.assertEqual(cached_status("key", lambda: {"fresh": True}, root, bypass=True), {"fresh": True})
      self.assertEqual(marker.read_text(), "preserve")


if __name__ == "__main__":
  unittest.main()
