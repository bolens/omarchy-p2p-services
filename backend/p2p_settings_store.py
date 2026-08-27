"""Private, atomic persistence for validated plugin settings."""

import fcntl
import json
import os
import time
import uuid


class SettingsStore:
  MAX_PAYLOAD_BYTES = 131072

  def __init__(self, state_root, settings_file, sanitizer):
    self.state_root = state_root
    self.settings_file = settings_file
    self.sanitize = sanitizer
    self.last_recovery = ""

  @property
  def previous_file(self):
    return self.settings_file.with_name("settings.previous.json")

  @property
  def lock_file(self):
    return self.settings_file.with_name("settings.lock")

  def load(self):
    if not self.settings_file.exists():
      self.last_recovery = ""
      return {}
    with self._lock(): return self._load_unlocked()

  def _load_unlocked(self):
    self.last_recovery = ""
    try:
      data = json.loads(self.settings_file.read_text())
      return self.sanitize(data) if isinstance(data, dict) else {}
    except OSError:
      return {}
    except (ValueError, TypeError):
      return self._recover_previous()

  def _recover_previous(self):
    try:
      previous = json.loads(self.previous_file.read_text())
      if not isinstance(previous, dict): return {}
      recovered = self.sanitize(previous)
      stamp = str(int(time.time() * 1000)) + "-" + uuid.uuid4().hex
      corrupt = self.settings_file.with_name("settings.corrupt-" + stamp + ".json")
      try:
        os.link(self.settings_file, corrupt, follow_symlinks=False)
        os.chmod(corrupt, 0o600, follow_symlinks=False)
      except OSError: return recovered
      self._atomic_write(self.settings_file, recovered)
      self.last_recovery = str(corrupt)
      return recovered
    except (OSError, ValueError, TypeError):
      return {}

  def save(self, raw):
    data = self._decode_object(raw, "settings payload")
    with self._lock():
      saved = self._stamp(data, self._load_unlocked())
      self._write(saved)
      return saved

  def patch(self, raw):
    patch = self._decode_object(raw, "settings patch")
    with self._lock():
      current = self._load_unlocked()
      current.update(patch)
      saved = self._stamp(current, self._load_unlocked())
      self._write(saved)
      return saved

  def undo(self):
    with self._lock():
      if not self.previous_file.exists():
        raise RuntimeError("no previous settings snapshot is available")
      try:
        previous = json.loads(self.previous_file.read_text())
        if not isinstance(previous, dict): raise ValueError("snapshot must be an object")
        restored = self.sanitize(previous)
      except (OSError, ValueError, TypeError) as error:
        raise RuntimeError("invalid previous settings snapshot") from error
      current = self._load_unlocked()
      restored = self._stamp(restored, current)
      self._atomic_write(self.settings_file, restored)
      self._atomic_write(self.previous_file, current)
      return restored

  def can_undo(self):
    try:
      data=json.loads(self.previous_file.read_text())
      return isinstance(data,dict) and bool(self.sanitize(data))
    except (OSError,ValueError,TypeError): return False

  def _stamp(self, data, current):
    clean = self.sanitize(data)
    previous = self.sanitize(current or {})
    clean["_p2pRevision"] = max(int(clean.get("_p2pRevision", 0)), int(previous.get("_p2pRevision", 0))) + 1
    clean["_p2pUpdatedAt"] = int(time.time() * 1000)
    return clean

  def _decode_object(self, raw, label):
    if len(raw.encode("utf-8")) > self.MAX_PAYLOAD_BYTES:
      raise ValueError(label + " is too large")
    data = json.loads(raw)
    if not isinstance(data, dict):
      raise ValueError(label + " must be an object")
    return data

  def _lock(self):
    self.state_root.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(self.state_root, 0o700)
    lock = self.lock_file.open("a+")
    os.chmod(lock.name, 0o600)
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
    return lock

  def _atomic_write(self, path, data):
    self.state_root.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(self.state_root, 0o700)
    temporary = path.with_suffix(path.suffix + ".tmp")
    try:
      with temporary.open("w") as stream:
        stream.write(json.dumps(data, sort_keys=True, separators=(",", ":")) + "\n")
        stream.flush()
        os.fsync(stream.fileno())
      os.chmod(temporary, 0o600)
      os.replace(temporary, path)
      directory = os.open(self.state_root, os.O_RDONLY)
      try: os.fsync(directory)
      finally: os.close(directory)
    finally:
      temporary.unlink(missing_ok=True)

  def _write(self, data, backup=True):
    if backup and self.settings_file.exists():
      try:
        self._atomic_write(self.previous_file, json.loads(self.settings_file.read_text()))
      except (OSError, ValueError, TypeError):
        pass
    self._atomic_write(self.settings_file, self.sanitize(data))
