"""Restore policy kept separate from discovery and CLI orchestration."""

import os

PKEXEC = "/usr/bin/pkexec"
INSTALL = "/usr/bin/install"


def restore_plan(service, source, destination, destination_mode=0o600, source_is_dir=False):
  source_text, destination_text = str(source), str(destination)
  if service.get("protectedConfig"):
    if source_is_dir: raise RuntimeError("protected directory restore is not supported")
    mode = max(0, min(0o777, int(destination_mode) & 0o777))
    return [PKEXEC, INSTALL, "--mode", format(mode, "04o"), source_text, destination_text]
  return []
