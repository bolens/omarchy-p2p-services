"""Bounded privacy-safe operational event journal."""

import json
import pathlib
import time

from p2p_secure_files import atomic_private_write, read_private_text

KINDS = {"stopped", "unhealthy", "recovered", "restarts", "action-success", "action-failure", "watcher-fallback"}


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
    events = (self.load() + [event])[-self.MAX_EVENTS:]
    atomic_private_write(self.path, json.dumps(events, separators=(",", ":")), self.root)
    return events

  def clear(self):
    self.path.unlink(missing_ok=True)

  @staticmethod
  def _valid(item):
    return isinstance(item, dict) and item.get("kind") in KINDS and isinstance(item.get("at"), int) and isinstance(item.get("count"), int)
