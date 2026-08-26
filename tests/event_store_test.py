import pathlib, sys, tempfile, unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
from p2p_event_store import EventStore


class EventStoreTest(unittest.TestCase):
  def test_append_bounds_validates_and_clears_private_journal(self):
    with tempfile.TemporaryDirectory() as directory:
      store = EventStore(pathlib.Path(directory) / "state")
      store.MAX_EVENTS = 2
      with mock.patch("p2p_event_store.time.time", side_effect=[1, 2, 3]):
        store.append("unhealthy", 2); store.append("recovered"); events = store.append("action-success")
      self.assertEqual(events, [{"kind":"recovered","count":1,"at":2},{"kind":"action-success","count":1,"at":3}])
      self.assertEqual(store.path.stat().st_mode & 0o777, 0o600)
      with self.assertRaises(ValueError): store.append("arbitrary-sensitive-text")
      store.clear(); self.assertEqual(store.load(), [])


if __name__ == "__main__": unittest.main()
