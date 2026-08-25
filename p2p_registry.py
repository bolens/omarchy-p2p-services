"""Validation and normalization for built-in and user-defined services."""

import re

from p2p_validation import safe_http_url


def validate_registry(services, package_ids, alias_ids, installer_ids):
  seen = set()
  required = {"id": str, "name": str, "icon": str, "category": str, "commands": list, "processes": list, "units": list, "config": str, "web": str}
  for index, service in enumerate(services):
    missing = [key for key in required if key not in service]
    if missing: raise ValueError("service registry row %d is missing %s" % (index, ",".join(missing)))
    invalid = [key for key, kind in required.items() if not isinstance(service[key], kind)]
    if invalid: raise TypeError("service registry row %d has invalid %s" % (index, ",".join(invalid)))
    service_id = service["id"]
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", service_id): raise ValueError("invalid service id: " + service_id)
    if service_id in seen: raise ValueError("duplicate service id: " + service_id)
    seen.add(service_id)
    if not service["category"].strip(): raise ValueError("service category must not be empty")
    if any(not isinstance(value, str) or not value for key in ("commands", "processes", "units") for value in service[key]):
      raise TypeError("service registry command, process, and unit values must be non-empty strings")
  if set(package_ids) - seen or set(alias_ids) - seen or set(installer_ids) - seen:
    raise ValueError("service metadata references unknown ids")
  return frozenset(seen)


def normalize_custom_services(raw, reserved_ids):
  if not isinstance(raw, list): return []
  result, seen = [], set(reserved_ids)
  for row in raw[:32]:
    if not isinstance(row, dict): continue
    service_id = str(row.get("id", "")).strip().lower()
    if not service_id.startswith("custom-") or not re.fullmatch(r"custom-[a-z0-9][a-z0-9-]{0,47}", service_id) or service_id in seen: continue
    name = str(row.get("name", "")).strip()[:64]
    icon = str(row.get("icon", "󰒍")).strip()[:8] or "󰒍"
    def names(key, pattern):
      values = row.get(key, [])
      if not isinstance(values, list): return []
      return list(dict.fromkeys(str(value) for value in values[:12] if isinstance(value, str) and re.fullmatch(pattern, value)))
    commands = names("commands", r"[A-Za-z0-9_.+-]+")
    processes = names("processes", r"[A-Za-z0-9_.+-]+")
    units = names("units", r"[A-Za-z0-9_.@+-]+\.service")
    config = str(row.get("config", "")).strip()[:512]
    web = safe_http_url(row.get("web", ""))
    if not name or not (commands or processes or units): continue
    if config and ("\x00" in config or "\n" in config): continue
    result.append(dict(id=service_id, name=name, icon=icon, category="Custom", commands=commands, processes=processes, units=units, config=config, web=web, custom=True, controllable=False))
    seen.add(service_id)
  return result
