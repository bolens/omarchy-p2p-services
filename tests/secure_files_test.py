import pathlib
import tempfile
import unittest
from unittest import mock

from p2p_secure_files import atomic_private_write, ensure_private_directory, read_or_create_secret, read_private_text


class SecureFilesTests(unittest.TestCase):
  def test_atomic_private_write_replaces_symlink_without_following_it(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      outside = root/"outside"; outside.write_text("preserve\n")
      target = root/"export.json"; target.symlink_to(outside)
      atomic_private_write(target, '{"safe":true}\n')
      self.assertFalse(target.is_symlink())
      self.assertEqual(target.read_text(), '{"safe":true}\n')
      self.assertEqual(outside.read_text(), "preserve\n")
      self.assertEqual(target.stat().st_mode & 0o777, 0o600)

  def test_atomic_private_write_failure_preserves_target_and_removes_temporary(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      target = root/"export.json"; target.write_text("previous\n")
      with mock.patch("p2p_secure_files.os.replace", side_effect=OSError("disk full")):
        with self.assertRaisesRegex(OSError, "disk full"):
          atomic_private_write(target, "replacement\n")
      self.assertEqual(target.read_text(), "previous\n")
      self.assertEqual(list(root.glob("export.json.tmp-*")), [])

  def test_secret_storage_rejects_symlink(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      outside = root/"outside"; outside.write_text("do-not-read\n")
      secret = root/"secret"; secret.symlink_to(outside)
      with self.assertRaises(OSError):
        read_or_create_secret(secret, lambda: "generated")
      self.assertEqual(outside.read_text(), "do-not-read\n")

  def test_private_directory_rejects_intermediate_symlink_below_data_root(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory); data = root/"data"; data.mkdir()
      outside = root/"outside"; outside.mkdir()
      (data/"omarchy").symlink_to(outside, target_is_directory=True)
      with self.assertRaisesRegex(RuntimeError, "symlinked storage"):
        ensure_private_directory(data/"omarchy/p2p-services/credentials", data)

  def test_private_text_reader_rejects_symlink(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      outside = root/"outside"; outside.write_text('{"customServices":[]}')
      imported = root/"settings-export.json"; imported.symlink_to(outside)
      with self.assertRaises(OSError): read_private_text(imported)

  def test_secret_and_private_text_limits_are_measured_in_bytes(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      secret = root/"secret"; secret.write_text("ééé")
      with self.assertRaisesRegex(RuntimeError, "invalid secret"):
        read_or_create_secret(secret, lambda: "unused", max_bytes=5)
      document = root/"document"; document.write_text("ééé")
      with self.assertRaisesRegex(RuntimeError, "too large"):
        read_private_text(document, max_bytes=5)


if __name__ == "__main__": unittest.main()
