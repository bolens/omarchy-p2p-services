"""Configuration backup inventory, retention, and restoration."""

import datetime
import os
import pathlib
import shutil
import subprocess
import uuid

from backend.p2p_secure_files import ensure_private_directory


class ConfigBackupStore:
  def __init__(self, home, restore_planner, data_home=None):
    self.home = pathlib.Path(home)
    self.restore_planner = restore_planner
    self.data_home = pathlib.Path(data_home) if data_home else self.home / ".local/share"

  def service_root(self, service_id):
    base = self.data_home / "omarchy/p2p-services/config-backups"
    root = base / service_id
    if root.is_symlink(): raise RuntimeError("unsafe backup storage symlink")
    if root.exists() and not root.resolve(strict=True).is_relative_to(base.resolve(strict=True)):
      raise RuntimeError("unsafe backup storage path")
    return root

  def records(self, service_id):
    root = self.service_root(service_id)
    if not root.is_dir(): return []
    records = []
    try: paths = list(root.iterdir())
    except OSError: return []
    for path in paths:
      try:
        modified = path.stat().st_mtime
        records.append({"name": path.name, "timestamp": datetime.datetime.fromtimestamp(modified).isoformat(timespec="seconds"), "_mtime": modified})
      except OSError: pass
    records.sort(key=lambda record: (record["_mtime"],record["name"]), reverse=True)
    for record in records: record.pop("_mtime", None)
    return records

  def backup(self, service, retention=10, preserve=()):
    source = pathlib.Path(os.path.expanduser(service["config"]))
    if not source.exists() and not source.is_symlink(): return ""
    root = self.service_root(service["id"])
    ensure_private_directory(root, self.data_home)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    destination = root / (stamp + "-" + source.name)
    if source.is_dir() and not source.is_symlink(): shutil.copytree(source, destination, symlinks=True)
    else: shutil.copy2(source, destination, follow_symlinks=False)
    for record in self.records(service["id"])[max(1, min(50, int(retention or 10))):]:
      if record["name"] in preserve: continue
      stale = root / record["name"]
      if stale.is_dir() and not stale.is_symlink(): shutil.rmtree(stale)
      else: stale.unlink(missing_ok=True)
    return str(destination)

  def restore(self, service, backup_name=""):
    records = self.records(service["id"])
    if not records: raise RuntimeError("no configuration backup is available")
    selected = backup_name or records[0]["name"]
    if selected not in [record["name"] for record in records]: raise RuntimeError("invalid backup selection")
    root = self.service_root(service["id"]).resolve(strict=True)
    source = (root / selected).resolve(strict=True)
    if not source.is_relative_to(root): raise RuntimeError("invalid backup path")
    destination = pathlib.Path(os.path.expanduser(service["config"]))
    source_is_dir = source.is_dir() and not source.is_symlink()
    mode = (destination.stat().st_mode & 0o7777) if destination.exists() else 0o600
    if destination.exists() or destination.is_symlink(): self.backup(service, preserve=(selected,))
    privileged = self.restore_planner(service, source, destination, mode, source_is_dir)
    if privileged:
      subprocess.check_call(privileged)
      return str(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    token = uuid.uuid4().hex
    staged = destination.with_name(destination.name + ".restore-" + token)
    displaced = destination.with_name(destination.name + ".previous-" + token)
    try:
      if source_is_dir: shutil.copytree(source, staged, symlinks=True)
      else: shutil.copy2(source, staged, follow_symlinks=False)
      had_destination = destination.exists() or destination.is_symlink()
      if had_destination: os.replace(destination, displaced)
      try: os.replace(staged, destination)
      except Exception:
        if had_destination and displaced.exists(): os.replace(displaced, destination)
        raise
      if displaced.is_dir() and not displaced.is_symlink(): shutil.rmtree(displaced)
      else: displaced.unlink(missing_ok=True)
    finally:
      if staged.is_dir() and not staged.is_symlink(): shutil.rmtree(staged, ignore_errors=True)
      else: staged.unlink(missing_ok=True)
    return str(destination)
