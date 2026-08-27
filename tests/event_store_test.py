import pathlib, sys, tempfile, unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from backend.p2p_event_store import EventStore


class EventStoreTest(unittest.TestCase):
  def test_append_bounds_validates_and_clears_private_journal(self):
    with tempfile.TemporaryDirectory() as directory:
      store = EventStore(pathlib.Path(directory) / "state")
      store.MAX_EVENTS = 2
      with mock.patch("backend.p2p_event_store.time.time", side_effect=[1, 2, 3]):
        store.append("unhealthy", 2); store.append("recovered"); events = store.append("action-success")
      self.assertEqual(events, [{"kind":"recovered","count":1,"at":2},{"kind":"action-success","count":1,"at":3}])
      self.assertEqual(store.path.stat().st_mode & 0o777, 0o600)
      with self.assertRaises(ValueError): store.append("arbitrary-sensitive-text")
      store.clear(); self.assertEqual(store.load(), [])

  def test_load_filters_malformed_and_unknown_events_and_append_clamps_counts(self):
    with tempfile.TemporaryDirectory() as directory:
      store = EventStore(pathlib.Path(directory) / "state")
      store.root.mkdir(parents=True)
      store.path.write_text(__import__("json").dumps([
        {"kind":"unhealthy","count":2,"at":1},
        {"kind":"unknown","count":1,"at":2},
        {"kind":"recovered","count":"1","at":3},
        {"kind":"recovered","count":1,"at":"4"},
        "not-an-event",
      ]))
      self.assertEqual(store.load(), [{"kind":"unhealthy","count":2,"at":1}])
      with mock.patch("backend.p2p_event_store.time.time", return_value=5):
        self.assertEqual(store.append("recovered", -10)[-1]["count"], 1)
        self.assertEqual(store.append("restarts", 5000)[-1]["count"], 999)


if __name__ == "__main__": unittest.main()
