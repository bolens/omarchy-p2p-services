"""Low-cost durable-settings change detection shared by every bar instance."""

import json
import time


class SettingsChangeTracker:
  def __init__(self, settings_file):
    self.settings_file = settings_file
    self.last_signature = None
    self.last_revision = -1

  def poll(self):
    try:
      stat = self.settings_file.stat()
      signature = (stat.st_ino, stat.st_mtime_ns, stat.st_size)
      if signature == self.last_signature: return None
      self.last_signature = signature
      payload = json.loads(self.settings_file.read_text())
      revision = int(payload.get("_p2pRevision", 0)) if isinstance(payload, dict) else -1
    except (OSError, ValueError, TypeError):
      return None
    if revision <= self.last_revision: return None
    self.last_revision = revision
    return revision


def watch_settings(settings_file, interval=0.5):
  tracker = SettingsChangeTracker(settings_file)
  while True:
    revision = tracker.poll()
    if revision is not None:
      print(json.dumps({"type":"settings-changed", "version":1, "revision":revision}, separators=(",", ":")), flush=True)
    time.sleep(interval)
