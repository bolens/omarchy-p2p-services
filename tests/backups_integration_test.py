import pathlib
import tempfile
import os
import multiprocessing
from unittest import mock

from control_test_support import CONTROL, ControlTestCase
from backend.p2p_backup_store import ConfigBackupStore


def backup_worker(home, config, ready, start, results):
  store = ConfigBackupStore(pathlib.Path(home), lambda *_args: [])
  ready.put(1)
  start.wait()
  fixed = __import__("datetime").datetime(2026, 1, 1, 0, 0, 0)
  with mock.patch("backend.p2p_backup_store.datetime.datetime") as clock:
    clock.now.return_value = fixed
    results.put(store.backup({"id":"aria2", "config":config}, retention=20))


class BackupsIntegrationTests(ControlTestCase):
  def test_concurrent_backups_with_the_same_timestamp_are_serialized(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      config = root/"service.conf"
      config.write_text("stable")
      context = multiprocessing.get_context("fork")
      ready,start,results = context.Queue(),context.Event(),context.Queue()
      workers = [context.Process(target=backup_worker,args=(directory,str(config),ready,start,results)) for _ in range(12)]
      for worker in workers: worker.start()
      for _worker in workers: ready.get(timeout=5)
      start.set()
      for worker in workers: worker.join(timeout=5)
      paths = [pathlib.Path(results.get(timeout=5)) for _worker in workers]
      self.assertEqual([worker.exitcode for worker in workers],[0]*12)
      self.assertEqual(len(set(paths)),12)
      self.assertTrue(all(path.read_text() == "stable" for path in paths))

  def test_backups_with_the_same_timestamp_remain_distinct(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      store = ConfigBackupStore(root, CONTROL.restore_plan)
      config = root/"service.conf"
      service = dict(self.service("aria2"), config=str(config))
      fixed = __import__("datetime").datetime(2026, 1, 1, 0, 0, 0)
      with mock.patch("backend.p2p_backup_store.datetime.datetime") as clock:
        clock.now.return_value = fixed
        config.write_text("first")
        first = pathlib.Path(store.backup(service))
        config.write_text("second")
        second = pathlib.Path(store.backup(service))
      self.assertNotEqual(first, second)
      self.assertEqual(first.read_text(), "first")
      self.assertEqual(second.read_text(), "second")
      os.utime(first, (100,100)); os.utime(second, (100,100))
      self.assertEqual(store.records("aria2")[0]["name"], second.name)

  def test_backup_records_break_mtime_ties_by_name(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      store = ConfigBackupStore(root, CONTROL.restore_plan)
      backup_root = store.service_root("aria2")
      backup_root.mkdir(parents=True)
      older_name = backup_root/"20260101-000000-000000-service.conf"
      newer_name = backup_root/"20260101-000000-000001-service.conf"
      older_name.write_text("older")
      newer_name.write_text("newer")
      os.utime(older_name, (100,100)); os.utime(newer_name, (100,100))
      with mock.patch.object(pathlib.Path,"iterdir",return_value=iter([older_name,newer_name])):
        self.assertEqual([record["name"] for record in store.records("aria2")], [newer_name.name,older_name.name])

  def test_backup_store_accepts_xdg_data_root(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      data_home = root/"xdg-data"
      store = ConfigBackupStore(root, CONTROL.restore_plan, data_home)
      config = root/"service.conf"
      config.write_text("portable=true\n")
      backup = pathlib.Path(store.backup({"id": "aria2", "config": str(config)}))
      self.assertTrue(backup.is_relative_to(data_home/"omarchy/p2p-services/config-backups/aria2"))

  def test_protected_restore_plan_is_narrow_and_file_only(self):
    service = dict(self.service("monerod"), protectedConfig=True)
    plan = CONTROL.restore_plan(service, pathlib.Path("/tmp/backup.conf"), pathlib.Path("/etc/monerod.conf"), destination_mode=0o640)
    self.assertEqual(plan, [CONTROL.PKEXEC, "/usr/bin/install", "--mode", "0640", "/tmp/backup.conf", "/etc/monerod.conf"])
    safe_plan = CONTROL.restore_plan(service, pathlib.Path("/tmp/backup.conf"), pathlib.Path("/etc/monerod.conf"), destination_mode=0o4755)
    self.assertEqual(safe_plan[2:4], ["--mode", "0755"])
    with self.assertRaisesRegex(RuntimeError, "directory"):
      CONTROL.restore_plan(service, pathlib.Path("/tmp/backup-dir"), pathlib.Path("/etc/monerod"), source_is_dir=True)

  def test_backup_retention_and_restore_latest(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      store = ConfigBackupStore(root, CONTROL.restore_plan)
      config = root/"service.conf"
      service = dict(self.service("aria2"), config=str(config))
      for value in ("one", "two", "three"):
        config.write_text(value)
        store.backup(service, 2)
      self.assertEqual(len(store.records("aria2")), 2)
      config.write_text("current")
      store.restore(service)
      self.assertEqual(config.read_text(), "three")
      with self.assertRaisesRegex(RuntimeError, "invalid backup"):
        store.restore(service, "../escape")

  def test_restore_rejects_backup_symlink_escaping_service_root(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      store = ConfigBackupStore(root, CONTROL.restore_plan)
      backup_root = root/".local/share/omarchy/p2p-services/config-backups/aria2"
      backup_root.mkdir(parents=True)
      outside = root/"outside.conf"; outside.write_text("secret")
      (backup_root/"escape.conf").symlink_to(outside)
      service = dict(self.service("aria2"), config=str(root/"target.conf"))
      with self.assertRaisesRegex(RuntimeError, "invalid backup path"):
        store.restore(service, "escape.conf")

  def test_backup_rejects_symlinked_service_storage_root(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      data_home = root/"data"
      backup_parent = data_home/"omarchy/p2p-services/config-backups"
      backup_parent.mkdir(parents=True)
      outside = root/"outside"; outside.mkdir()
      (backup_parent/"aria2").symlink_to(outside, target_is_directory=True)
      config = root/"aria2.conf"; config.write_text("safe=true\n")
      store = ConfigBackupStore(root, CONTROL.restore_plan, data_home)
      with self.assertRaisesRegex(RuntimeError, "unsafe backup storage"):
        store.backup({"id":"aria2", "config":str(config)})

  def test_config_backup_preserves_source(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      source = root/"service.conf"
      source.write_text("keep=true\n")
      store = ConfigBackupStore(root, CONTROL.restore_plan)
      service = dict(self.service("aria2"), config=str(source))
      backup = pathlib.Path(store.backup(service))
      self.assertEqual(source.read_text(), "keep=true\n")
      self.assertEqual(backup.read_text(), "keep=true\n")
      self.assertTrue(str(backup).startswith(str(root/".local/share/omarchy/p2p-services/config-backups/aria2")))

  def test_directory_backup_restore_replaces_current_tree(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      config = root/"daemon-config"
      config.mkdir()
      (config/"settings.ini").write_text("version=original\n")
      store = ConfigBackupStore(root, lambda *_args: [])
      service = {"id": "daemon", "config": str(config)}
      selected = pathlib.Path(store.backup(service)).name

      (config/"settings.ini").write_text("version=changed\n")
      (config/"temporary").write_text("remove me\n")
      store.restore(service, selected)

      self.assertEqual((config/"settings.ini").read_text(), "version=original\n")
      self.assertFalse((config/"temporary").exists())
      self.assertGreaterEqual(len(store.records("daemon")), 2)

  def test_failed_restore_staging_preserves_current_configuration(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      config = root/"daemon-config"
      config.mkdir()
      (config/"settings.ini").write_text("original\n")
      store = ConfigBackupStore(root, lambda *_args: [])
      service = {"id": "daemon", "config": str(config)}
      selected = pathlib.Path(store.backup(service)).name
      (config/"settings.ini").write_text("current\n")
      with mock.patch("backend.p2p_backup_store.shutil.copytree", side_effect=OSError("disk full")):
        with self.assertRaisesRegex(OSError, "disk full"):
          store.restore(service, selected)
      self.assertEqual((config/"settings.ini").read_text(), "current\n")
      self.assertEqual(list(root.glob("daemon-config.restore-*")), [])

  def test_failed_restore_commit_rolls_back_displaced_configuration(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      config = root/"service.conf"
      config.write_text("backup-version\n")
      store = ConfigBackupStore(root, lambda *_args: [])
      service = {"id": "daemon", "config": str(config)}
      selected = pathlib.Path(store.backup(service)).name
      config.write_text("current-version\n")
      real_replace = __import__("os").replace
      calls = 0

      def fail_commit(source, destination):
        nonlocal calls
        calls += 1
        if calls == 2: raise OSError("commit failed")
        return real_replace(source, destination)

      with mock.patch("backend.p2p_backup_store.os.replace", side_effect=fail_commit):
        with self.assertRaisesRegex(OSError, "commit failed"):
          store.restore(service, selected)
      self.assertEqual(config.read_text(), "current-version\n")
      self.assertEqual(list(root.glob("service.conf.previous-*")), [])

  def test_privileged_restore_executes_only_planned_command(self):
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      config = root/"protected.conf"
      config.write_text("original\n")
      planned = ["/usr/bin/pkexec", "/usr/bin/install", "--mode", "0600", "source", "destination"]
      planner_calls = []
      store = ConfigBackupStore(root, lambda *args: planner_calls.append(args) or planned)
      service = {"id": "protected", "config": str(config)}
      selected = pathlib.Path(store.backup(service)).name
      config.write_text("changed\n")

      with mock.patch("backend.p2p_backup_store.subprocess.check_call") as execute:
        restored = store.restore(service, selected)

      execute.assert_called_once_with(planned)
      self.assertEqual(restored, str(config))
      self.assertEqual(len(planner_calls), 1)
      self.assertEqual(planner_calls[0][2], config)
      self.assertFalse(planner_calls[0][4])
