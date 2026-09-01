"""Bounded privacy-safe operational event journal."""

import fcntl
import json
import os
import pathlib
import time

from backend.p2p_secure_files import atomic_private_write, ensure_private_directory, read_private_text

KINDS = {"stopped", "unhealthy", "recovered", "updated", "replaced", "crashed", "restarts", "action-success", "action-failure", "watcher-fallback"}


class EventStore:
  MAX_EVENTS = 100
  MAX_BYTES = 65536

  def __init__(self, root):
    self.root = pathlib.Path(root)
    self.path = self.root / "events.json"

  def load(self):
    try: data = json.loads(read_private_text(self.path, self.MAX_BYTES))
    except (FileNotFoundError, OSError, ValueError, TypeError): return []
    if not isinstance(data, list): return []
    return [item for item in data[-self.MAX_EVENTS:] if self._valid(item)]

  def append(self, kind, count=1):
    if kind not in KINDS: raise ValueError("invalid event kind")
    event = {"kind": kind, "count": max(1, min(999, int(count))), "at": int(time.time())}
    with self._lock():
      events = (self.load() + [event])[-self.MAX_EVENTS:]
      atomic_private_write(self.path, json.dumps(events, separators=(",", ":")), self.root)
      return events

  def clear(self):
    with self._lock(): self.path.unlink(missing_ok=True)

  def _lock(self):
    ensure_private_directory(self.root)
    lock_path=self.root/"events.lock"
    descriptor=os.open(lock_path,os.O_RDWR|os.O_CREAT|getattr(os,"O_NOFOLLOW",0),0o600)
    os.fchmod(descriptor,0o600)
    lock=os.fdopen(descriptor,"a+")
    fcntl.flock(lock.fileno(),fcntl.LOCK_EX)
    return lock

  @staticmethod
  def _valid(item):
    return isinstance(item, dict) and item.get("kind") in KINDS and isinstance(item.get("at"), int) and isinstance(item.get("count"), int)
