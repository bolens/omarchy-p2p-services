import json
import multiprocessing
import pathlib
import tempfile
import unittest

from backend.p2p_cache import cached_status
from backend.p2p_event_store import EventStore
from backend.p2p_settings import sanitize_settings
from backend.p2p_settings_store import SettingsStore


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


def partitioned_cache_worker(cache_root, ready, start, index):
  ready.put(1)
  start.wait()
  cached_status("key-" + str(index), lambda: {"index":index}, pathlib.Path(cache_root), ttl=30, max_entries=3)


def event_worker(state_root, ready, start):
  ready.put(1)
  start.wait()
  EventStore(pathlib.Path(state_root)).append("recovered")


def settings_load_worker(state_root, ready, start, results):
  root=pathlib.Path(state_root)
  store=SettingsStore(root,root/"settings.json",lambda values:values)
  ready.put(1)
  start.wait()
  results.put(store.load())


class ConcurrencyTests(unittest.TestCase):
  def test_concurrent_corruption_recovery_is_consistent(self):
    with tempfile.TemporaryDirectory() as directory:
      root=pathlib.Path(directory)
      (root/"settings.json").write_text("malformed")
      (root/"settings.previous.json").write_text('{"value":7}')
      context=multiprocessing.get_context("fork")
      ready,start,results=context.Queue(),context.Event(),context.Queue()
      workers=[context.Process(target=settings_load_worker,args=(directory,ready,start,results)) for _ in range(24)]
      for worker in workers: worker.start()
      for _worker in workers: ready.get(timeout=5)
      start.set()
      values=[results.get(timeout=5) for _worker in workers]
      for worker in workers: worker.join(timeout=5)
      self.assertEqual([worker.exitcode for worker in workers],[0]*24)
      self.assertEqual(values,[{"value":7}]*24)

  def test_cache_pruning_is_serialized_across_partitions(self):
    context=multiprocessing.get_context("fork")
    for _attempt in range(12):
      with tempfile.TemporaryDirectory() as directory:
        ready,start=context.Queue(),context.Event()
        workers=[context.Process(target=partitioned_cache_worker,args=(directory,ready,start,index)) for index in range(24)]
        for worker in workers: worker.start()
        for _worker in workers: ready.get(timeout=5)
        start.set()
        for worker in workers: worker.join(timeout=5)
        self.assertEqual([worker.exitcode for worker in workers],[0]*24)
        self.assertEqual(len(list(pathlib.Path(directory).glob("*.json"))),3)

  def test_concurrent_event_appends_do_not_lose_entries(self):
    with tempfile.TemporaryDirectory() as directory:
      context=multiprocessing.get_context("fork")
      ready,start=context.Queue(),context.Event()
      workers=[context.Process(target=event_worker,args=(directory,ready,start)) for _ in range(24)]
      for worker in workers: worker.start()
      for _worker in workers: ready.get(timeout=5)
      start.set()
      for worker in workers: worker.join(timeout=5)
      self.assertEqual([worker.exitcode for worker in workers],[0]*24)
      self.assertEqual(len(EventStore(pathlib.Path(directory)).load()),24)

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
