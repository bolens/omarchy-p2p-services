"""Atomic short-lived status cache shared by per-monitor widget instances."""

import fcntl
import hashlib
import json
import os
import pathlib
import time


def _read_fresh(path, ttl):
  try:
    stat = path.stat()
    if time.time() - stat.st_mtime > ttl: return None
    value = json.loads(path.read_text())
    return value if isinstance(value, dict) else None
  except (OSError, ValueError, TypeError): return None


def _prune_payloads(root, keep, max_entries):
  try: payloads = sorted(root.glob("*.json"), key=lambda path: path.stat().st_mtime, reverse=True)
  except OSError: return
  keepers = {keep}
  for path in payloads:
    if len(keepers) < max(1, int(max_entries)): keepers.add(path)
  for path in payloads:
    if path in keepers: continue
    try: path.unlink()
    except OSError: pass


def cached_status(key, producer, root, ttl=1.5, bypass=False, max_entries=32):
  root = pathlib.Path(root)
  digest = hashlib.sha256(str(key).encode("utf-8")).hexdigest()
  target, lock_path = root/(digest + ".json"), root/(digest + ".lock")
  try:
    if root.is_symlink(): return producer()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    if root.is_symlink(): return producer()
    os.chmod(root, 0o700)
    lock = lock_path.open("a+")
    os.chmod(lock_path, 0o600)
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
  except OSError:
    try: lock.close()
    except (NameError, OSError): pass
    return producer()
  with lock:
    try:
      if bypass:
        for stale in root.glob("*.json"):
          try: stale.unlink()
          except OSError: pass
      else:
        existing = _read_fresh(target, ttl)
        if existing is not None: return existing
    except OSError: pass
    payload = producer()
    temporary = target.with_suffix(".tmp-" + str(os.getpid()))
    try:
      temporary.write_text(json.dumps(payload, separators=(",", ":")))
      os.chmod(temporary, 0o600)
      os.replace(temporary, target)
      _prune_payloads(root, target, max_entries)
    except OSError:
      pass
    finally:
      try: temporary.unlink(missing_ok=True)
      except OSError: pass
    return payload
