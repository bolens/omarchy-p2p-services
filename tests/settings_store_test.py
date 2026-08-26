import pathlib
import tempfile
import unittest

from p2p_settings import SETTINGS_VERSION, sanitize_settings
from p2p_settings_store import SettingsStore


class SettingsStoreTests(unittest.TestCase):
  def store(self, directory):
    root = pathlib.Path(directory) / "state"
    return SettingsStore(root, root / "settings.json", sanitize_settings)

  def test_save_patch_and_undo_round_trip(self):
    with tempfile.TemporaryDirectory() as directory:
      store = self.store(directory)
      store.save('{"showCount":true,"compactCards":false}')
      self.assertFalse(store.can_undo())
      first_revision = store.load()["_p2pRevision"]
      merged = store.patch('{"compactCards":true}')
      self.assertTrue(store.can_undo())
      self.assertTrue(merged["showCount"])
      self.assertTrue(merged["compactCards"])
      self.assertGreater(merged["_p2pRevision"], 0)
      self.assertGreater(merged["_p2pRevision"], first_revision)
      restored = store.undo()
      self.assertFalse(restored["compactCards"])
      self.assertEqual(restored["_p2pSettingsVersion"], SETTINGS_VERSION)
      self.assertGreater(restored["_p2pRevision"], merged["_p2pRevision"])
      self.assertEqual(store.settings_file.stat().st_mode & 0o777, 0o600)
      self.assertEqual(store.lock_file.stat().st_mode & 0o777, 0o600)

  def test_full_saves_advance_beyond_current_and_incoming_revisions(self):
    with tempfile.TemporaryDirectory() as directory:
      store = self.store(directory)
      first = store.save('{"showCount":true,"_p2pRevision":10}')
      self.assertEqual(first["_p2pRevision"], 11)
      second = store.save('{"showCount":false,"_p2pRevision":2}')
      self.assertEqual(second["_p2pRevision"], 12)
      self.assertGreaterEqual(second["_p2pUpdatedAt"], first["_p2pUpdatedAt"])

  def test_rejects_non_object_and_oversized_payloads(self):
    with tempfile.TemporaryDirectory() as directory:
      store = self.store(directory)
      with self.assertRaisesRegex(ValueError, "object"):
        store.save("[]")
      with self.assertRaisesRegex(ValueError, "too large"):
        store.save('{"value":"' + ("x" * 140000) + '"}')

  def test_missing_or_corrupt_settings_load_as_empty(self):
    with tempfile.TemporaryDirectory() as directory:
      store = self.store(directory)
      self.assertEqual(store.load(), {})
      store.state_root.mkdir(parents=True)
      store.settings_file.write_text("not json")
      self.assertEqual(store.load(), {})
      store.settings_file.write_text("[]")
      self.assertEqual(store.load(), {})

  def test_corrupt_current_settings_recover_previous_and_quarantine_damage(self):
    with tempfile.TemporaryDirectory() as directory:
      store = self.store(directory)
      store.save('{"showCount":true}')
      store.patch('{"showCount":false}')
      store.settings_file.write_text("not json")
      recovered = store.load()
      self.assertTrue(recovered["showCount"])
      self.assertTrue(store.last_recovery)
      self.assertEqual(pathlib.Path(store.last_recovery).read_text(), "not json")
      self.assertTrue(store.load()["showCount"])

  def test_undo_without_snapshot_preserves_current_settings(self):
    with tempfile.TemporaryDirectory() as directory:
      store = self.store(directory)
      store.save('{"showCount":false}')
      before = store.settings_file.read_bytes()
      with self.assertRaisesRegex(RuntimeError, "no previous"):
        store.undo()
      self.assertEqual(store.settings_file.read_bytes(), before)

  def test_state_directory_and_every_durable_file_are_private(self):
    with tempfile.TemporaryDirectory() as directory:
      store = self.store(directory)
      store.save('{"showCount":true}')
      store.patch('{"showCount":false}')
      self.assertEqual(store.state_root.stat().st_mode & 0o777, 0o700)
      for path in (store.settings_file, store.previous_file, store.lock_file):
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

  def test_corrupt_undo_snapshot_is_rejected_without_changing_current_settings(self):
    with tempfile.TemporaryDirectory() as directory:
      store = self.store(directory)
      store.save('{"showCount":false}')
      store.previous_file.write_text("not json")
      before = store.settings_file.read_bytes()
      with self.assertRaisesRegex(RuntimeError, "invalid previous settings snapshot"):
        store.undo()
      self.assertEqual(store.settings_file.read_bytes(), before)


if __name__ == "__main__": unittest.main()
