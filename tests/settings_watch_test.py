import json
import pathlib
import tempfile
import unittest

from p2p_settings_watch import SettingsChangeTracker
from p2p_settings import sanitize_settings
from p2p_settings_store import SettingsStore


class SettingsChangeTrackerTests(unittest.TestCase):
  def test_reports_only_new_valid_revisions(self):
    with tempfile.TemporaryDirectory() as directory:
      settings = pathlib.Path(directory) / "settings.json"
      tracker = SettingsChangeTracker(settings)
      self.assertIsNone(tracker.poll())
      settings.write_text('{"_p2pRevision":2}')
      self.assertEqual(tracker.poll(), 2)
      self.assertIsNone(tracker.poll())
      settings.write_text("not json")
      self.assertIsNone(tracker.poll())
      settings.write_text('{"_p2pRevision":3}')
      self.assertEqual(tracker.poll(), 3)

  def test_atomic_replacement_with_same_revision_is_not_reemitted(self):
    with tempfile.TemporaryDirectory() as directory:
      settings = pathlib.Path(directory) / "settings.json"
      settings.write_text(json.dumps({"_p2pRevision":4}))
      tracker = SettingsChangeTracker(settings)
      self.assertEqual(tracker.poll(), 4)
      replacement = settings.with_suffix(".tmp")
      replacement.write_text(json.dumps({"_p2pRevision":4, "showCount":False}))
      replacement.replace(settings)
      self.assertIsNone(tracker.poll())

  def test_save_and_undo_are_visible_to_revision_tracker(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      settings = root / "settings.json"
      store = SettingsStore(root, settings, sanitize_settings)
      tracker = SettingsChangeTracker(settings)
      first = store.save('{"showCount":true,"_p2pRevision":8}')
      self.assertEqual(tracker.poll(), first["_p2pRevision"])
      second = store.save('{"showCount":false,"_p2pRevision":1}')
      self.assertEqual(tracker.poll(), second["_p2pRevision"])
      restored = store.undo()
      self.assertTrue(restored["showCount"])
      self.assertEqual(tracker.poll(), restored["_p2pRevision"])


if __name__ == "__main__": unittest.main()
