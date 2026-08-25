import json
import multiprocessing
import pathlib
import tempfile
import unittest

from p2p_cache import cached_status
from p2p_settings import sanitize_settings
from p2p_settings_store import SettingsStore


def patch_settings_worker(state_root, ready, start, index):
  root = pathlib.Path(state_root)
  store = SettingsStore(root, root/"settings.json", sanitize_settings)
  ready.put(index)
  start.wait()
  store.patch(json.dumps({"widgetIcon": str(index)}))


def cache_worker(cache_root, ready, start, produced, results):
  ready.put(1)
  start.wait()

  def produce():
    with produced.get_lock(): produced.value += 1
    return {"services": [{"id": "shared"}]}

  results.put(cached_status("shared-key", produce, pathlib.Path(cache_root), ttl=30))


class ConcurrencyTests(unittest.TestCase):
  def test_concurrent_settings_patches_are_serialized_and_leave_valid_state(self):
    with tempfile.TemporaryDirectory() as directory:
      context = multiprocessing.get_context("fork")
      ready, start = context.Queue(), context.Event()
      workers = [context.Process(target=patch_settings_worker, args=(directory, ready, start, index)) for index in range(4)]
      for worker in workers: worker.start()
      for _worker in workers: ready.get(timeout=5)
      start.set()
      for worker in workers: worker.join(timeout=5)

      self.assertEqual([worker.exitcode for worker in workers], [0, 0, 0, 0])
      store = SettingsStore(pathlib.Path(directory), pathlib.Path(directory)/"settings.json", sanitize_settings)
      loaded = store.load()
      self.assertEqual(loaded["_p2pRevision"], 4)
      self.assertIn(loaded["widgetIcon"], {"0", "1", "2", "3"})
      self.assertEqual(list(pathlib.Path(directory).glob("*.tmp")), [])

  def test_concurrent_cache_misses_share_one_producer_result(self):
    with tempfile.TemporaryDirectory() as directory:
      context = multiprocessing.get_context("fork")
      ready, start, results = context.Queue(), context.Event(), context.Queue()
      produced = context.Value("i", 0)
      workers = [context.Process(target=cache_worker, args=(directory, ready, start, produced, results)) for _ in range(4)]
      for worker in workers: worker.start()
      for _worker in workers: ready.get(timeout=5)
      start.set()
      payloads = [results.get(timeout=5) for _worker in workers]
      for worker in workers: worker.join(timeout=5)

      self.assertEqual([worker.exitcode for worker in workers], [0, 0, 0, 0])
      self.assertEqual(produced.value, 1)
      self.assertEqual(payloads, [{"services": [{"id": "shared"}]}] * 4)


if __name__ == "__main__":
  unittest.main()
