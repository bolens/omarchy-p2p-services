"""Pure command planning for service-control backends."""

CONTROL_ACTIONS = frozenset({"start", "stop", "restart"})


def container_action_commands(items, action):
  if action not in CONTROL_ACTIONS: return []
  commands = []
  for runtime in sorted(set(item.get("_runtime", "docker") for item in items)):
    owned = [item for item in items if item.get("_runtime", "docker") == runtime and not item.get("Name", "").lstrip("/").endswith("-init")]
    if action in ("stop", "restart"): owned = [item for item in owned if item.get("State", {}).get("Running")]
    elif action == "start": owned = [item for item in owned if not item.get("State", {}).get("Running")]
    targets = [item.get("Name", "").lstrip("/") for item in owned]
    if targets: commands.append([owned[0].get("_runtime_cmd") or runtime, action] + targets)
  return commands


def systemd_action_command(systemctl, unit, user, action):
  if not unit or action not in CONTROL_ACTIONS: return []
  return [systemctl] + (["--user"] if user else []) + [action, unit]
