"""Normalize runtime events into privacy-safe service lifecycle evidence."""

import re

LIFECYCLE_KINDS = frozenset({"clean-exit", "crash", "oom", "replaced", "restart", "unhealthy", "recovered", "updated"})


def select_restart_kind(kinds):
  """Classify the evidence belonging to the latest restart sequence."""
  restart_indexes=[index for index,kind in enumerate(kinds) if kind == "restart"]
  start=restart_indexes[-2]+1 if len(restart_indexes)>1 else 0
  segment=kinds[start:restart_indexes[-1]+1] if restart_indexes else kinds
  for kind in reversed(segment):
    if kind in ("oom","crash"): return "crash"
    if kind == "updated": return "update"
    if kind in ("clean-exit","replaced"): break
  return "restart"


def classify_systemd_restart_log(text):
  """Classify bounded journal evidence without retaining journal content."""
  lowered=str(text or "").lower()
  crash_patterns=(
    r"main process exited", r"failed with result", r"oom[- ]kill",
    r"killed by .*oom", r"code=dumped", r"segmentation fault", r"\bpanic\b",
  )
  update_patterns=(
    r"\b(?:update|upgrade) (?:needed|available|complete|completed|successful|succeeded)\b",
    r"\bupdated successfully\b", r"\bhandling (?:an )?update\b",
  )
  if any(re.search(pattern,lowered) for pattern in crash_patterns): return "crash"
  if any(re.search(pattern,lowered) for pattern in update_patterns): return "update"
  return "restart"


def _attributes(event):
  actor = event.get("Actor", {}) if isinstance(event.get("Actor"), dict) else {}
  nested = actor.get("Attributes", {}) if isinstance(actor.get("Attributes"), dict) else {}
  direct = event.get("Attributes", {}) if isinstance(event.get("Attributes"), dict) else {}
  return {**direct, **nested}


def _image_name(value):
  image = str(value or "").lower().split("@", 1)[0]
  leaf = image.rsplit("/", 1)[-1]
  return leaf.rsplit(":", 1)[0] if ":" in leaf else leaf


def _service_id(attributes, services, aliases):
  candidates = {
    str(attributes.get("name", "")).lstrip("/").lower(),
    str(attributes.get("com.docker.compose.service", "")).lower(),
    _image_name(attributes.get("image", "")),
  }
  candidates.discard("")
  for service in services:
    service_id = str(service.get("id", ""))
    names = {str(value).lower() for value in aliases.get(service_id, [service_id])}
    if names.intersection(candidates): return service_id
  return ""


def classify_container_event(event):
  """Return a runtime-neutral lifecycle kind and cause."""
  if not isinstance(event, dict): return None
  attributes = _attributes(event)
  action = str(event.get("Action") or event.get("Status") or event.get("status") or "").lower()
  exit_code = str(attributes.get("exitCode", event.get("ExitCode", "")))
  kind, cause = "", ""
  if action == "oom" or "oom" in action: kind, cause = "oom", "oom"
  elif action in ("die", "died", "exited", "exit"):
    kind, cause = ("clean-exit", "clean-exit") if exit_code in ("", "0") else ("crash", "exit-code")
  elif "health_status" in action or action in ("healthy", "unhealthy"):
    kind = "unhealthy" if "unhealthy" in action else "recovered"
    cause = "healthcheck"
  elif action in ("create", "recreate"): kind, cause = "replaced", "container-replaced"
  elif action in ("restart", "start"): kind, cause = "restart", "automatic"
  elif action in ("update", "upgrade"): kind, cause = "updated", "runtime-update"
  if kind not in LIFECYCLE_KINDS: return None
  return kind, cause


def normalize_container_event(runtime, event, services, aliases):
  """Return allowlisted lifecycle evidence without container names or IDs."""
  if not isinstance(event, dict) or runtime not in ("docker", "podman"): return None
  attributes = _attributes(event)
  service_id = _service_id(attributes, services, aliases)
  classification = classify_container_event(event)
  if not service_id or not classification: return None
  kind, cause = classification
  try: at = int(event.get("time", event.get("Time", 0)) or 0)
  except (TypeError, ValueError): at = 0
  return {"serviceId": service_id, "kind": kind, "cause": cause, "at": at}
