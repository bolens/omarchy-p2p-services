"""No-follow private storage primitives for predictable plugin paths."""

import os
import pathlib
import stat
import uuid


def ensure_private_directory(path, base=None):
  target = pathlib.Path(path)
  if base is not None:
    anchor = pathlib.Path(base)
    anchor.mkdir(mode=0o700, parents=True, exist_ok=True)
    try: relative = target.absolute().relative_to(anchor.absolute())
    except ValueError as error: raise RuntimeError("storage directory escapes its root") from error
    current = anchor
    for part in relative.parts:
      current = current/part
      if current.is_symlink(): raise RuntimeError("unsafe symlinked storage directory")
      current.mkdir(mode=0o700, exist_ok=True)
  else:
    if target.is_symlink(): raise RuntimeError("unsafe symlinked storage directory")
    target.mkdir(mode=0o700, parents=True, exist_ok=True)
  if target.is_symlink() or not target.is_dir(): raise RuntimeError("unsafe storage directory")
  if base is not None and not target.resolve(strict=True).is_relative_to(pathlib.Path(base).resolve(strict=True)):
    raise RuntimeError("storage directory escapes its root")
  os.chmod(target, 0o700)
  return target


def atomic_private_write(path, content, base=None):
  target = pathlib.Path(path)
  ensure_private_directory(target.parent, base)
  temporary = target.with_name(target.name + ".tmp-" + uuid.uuid4().hex)
  flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
  descriptor = os.open(temporary, flags, 0o600)
  try:
    with os.fdopen(descriptor, "w") as stream:
      descriptor = -1
      stream.write(content)
      stream.flush()
      os.fsync(stream.fileno())
    os.replace(temporary, target)
  finally:
    if descriptor >= 0: os.close(descriptor)
    temporary.unlink(missing_ok=True)


def read_or_create_secret(path, factory, max_bytes=4096, base=None):
  target = pathlib.Path(path)
  ensure_private_directory(target.parent, base)
  flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
  try:
    descriptor = os.open(target, flags)
  except FileNotFoundError:
    value = str(factory())
    create_flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(target, create_flags, 0o600)
    with os.fdopen(descriptor, "w") as stream:
      stream.write(value + "\n")
      stream.flush()
      os.fsync(stream.fileno())
    return value
  with os.fdopen(descriptor, "r") as stream:
    if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode): raise RuntimeError("unsafe secret file")
    value = stream.read(max_bytes + 1).strip()
  if not value or len(value.encode("utf-8")) > max_bytes: raise RuntimeError("invalid secret file")
  os.chmod(target, 0o600, follow_symlinks=False)
  return value


def read_private_text(path, max_bytes=131072):
  target = pathlib.Path(path)
  descriptor = os.open(target, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
  with os.fdopen(descriptor, "r") as stream:
    if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode): raise RuntimeError("unsafe input file")
    content = stream.read(max_bytes + 1)
  if len(content.encode("utf-8")) > max_bytes: raise RuntimeError("input file is too large")
  return content
