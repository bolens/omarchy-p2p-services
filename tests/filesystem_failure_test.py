import pathlib
import tempfile
import unittest
from unittest import mock

from backend import p2p_settings_store
from backend.p2p_cache import cached_status
from backend.p2p_settings import sanitize_settings
from backend.p2p_settings_store import SettingsStore


class FilesystemFailureTests(unittest.TestCase):
  def test_settings_replace_failure_preserves_current_file_and_removes_temporary(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      store = SettingsStore(root, root/"settings.json", sanitize_settings)
      store.save('{"showCount":true}')
      before = store.settings_file.read_bytes()
      original_replace = p2p_settings_store.os.replace

      def replace(source, destination):
        if pathlib.Path(destination) == store.settings_file: raise OSError("disk unavailable")
        return original_replace(source, destination)

      with mock.patch("backend.p2p_settings_store.os.replace", side_effect=replace):
        with self.assertRaisesRegex(OSError, "disk unavailable"):
          store.patch('{"showCount":false}')
      self.assertEqual(store.settings_file.read_bytes(), before)
      self.assertEqual(list(root.glob("*.tmp")), [])

  def test_cache_replace_failure_returns_fresh_payload_and_removes_temporary(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      with mock.patch("backend.p2p_cache.os.replace", side_effect=OSError("disk unavailable")):
        self.assertEqual(cached_status("key", lambda: {"services": [1]}, root), {"services": [1]})
      self.assertEqual(list(root.glob("*.json")), [])
      self.assertEqual(list(root.glob("*.tmp-*")), [])


if __name__ == "__main__":
  unittest.main()
