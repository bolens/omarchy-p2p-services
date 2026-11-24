"""Clients for sealed metadata discovery and explicitly authorized lifecycle control."""

import json
import os
import pathlib
import re
import stat
import signal
import subprocess
import xml.etree.ElementTree as ET

from backend.p2p_catalog import DOCKER_ALIASES
from backend.p2p_docker_helper import MAX_OUTPUT, MAX_CONTAINERS, project

CONTROL_HELPER = pathlib.Path("/usr/local/libexec/omarchy-p2p-control")
CONTROL_POLICY = pathlib.Path("/usr/share/polkit-1/actions/io.github.bolens.p2p-services.docker-control.policy")
CONTROL_ACTION_ID = "io.github.bolens.p2p-services.docker-control"
HELPER = pathlib.Path("/usr/local/libexec/omarchy-p2p-discover")
SAFE_DIAGNOSTICS = frozenset({"restricted_docker_partial", "restricted_docker_stats_unavailable", "restricted_docker_events_unavailable"})


def trusted_helper(path=HELPER, executable=True):
  """Never elevate a user-writable or symlinked helper, including its parents."""
  try:
    for candidate in (path, *path.parents):
      info = candidate.lstat()
      if info.st_uid != 0 or info.st_mode & 0o022 or stat.S_ISLNK(info.st_mode): return False
      if candidate == path:
        if not stat.S_ISREG(info.st_mode) or (executable and not info.st_mode & 0o111): return False
      elif not stat.S_ISDIR(info.st_mode): return False
    return True
  except OSError: return False


def controls_available():
  if not trusted_helper(CONTROL_HELPER) or not trusted_helper(CONTROL_POLICY, executable=False): return False
  try:
    with CONTROL_POLICY.open("rb") as stream: content = stream.read(16385)
    if len(content) > 16384: return False
    policy = ET.fromstring(content)
    actions = policy.findall("action")
    if policy.tag != "policyconfig" or len(actions) != 1 or actions[0].get("id") != CONTROL_ACTION_ID: return False
    action = actions[0]
    if [action.findtext("defaults/" + scope) for scope in ("allow_any","allow_inactive","allow_active")] != ["no","no","auth_admin"]: return False
    annotations = {node.get("key"):node.text for node in action.findall("annotate")}
    return len(action.findall("annotate")) == 1 and annotations == {"org.freedesktop.policykit.exec.path":str(CONTROL_HELPER)}
  except (OSError,ET.ParseError,ValueError): return False


def control_command(service, action, items, check=False):
  if not controls_available() or service.get("id") not in DOCKER_ALIASES or service.get("custom") or service.get("controllable") is False:
    raise RuntimeError("Authorized Docker controls are unavailable")
  if action not in ("start","stop","restart") or not items or any(not item.get("_discovery_only") for item in items):
    raise ValueError("Invalid restricted control request")
  targets = sorted(set(item.get("Id", "") for item in items if not str(item.get("Name", "")).endswith("-init")))
  if not targets or len(targets) > 16 or any(not re.fullmatch(r"[a-f0-9]{64}",identity) for identity in targets):
    raise ValueError("Invalid restricted container selection")
  return ["/usr/bin/pkexec","--disable-internal-agent",str(CONTROL_HELPER)] + (["--check"] if check else []) + [action,service["id"]] + targets


def authorized_control(service, action, items):
  command = control_command(service,action,items)
  print('{"phase":"authorization"}',flush=True)
  # A new session owns only this request's pkexec/helper, never the desktop.
  process = subprocess.Popen(command,stdin=subprocess.DEVNULL,stderr=subprocess.PIPE,start_new_session=True,text=True)
  def terminate():
    try: os.killpg(process.pid,signal.SIGTERM)
    except (ProcessLookupError,PermissionError): pass
    # After privilege elevation the caller cannot signal a root process. Its
    # pidfd guard notices this CLI exiting and prevents subsequent requests.
  previous = {}
  def cancelled(signum,_frame):
    terminate()
    raise SystemExit(128+signum)
  try:
    for kind in (signal.SIGTERM,signal.SIGINT): previous[kind] = signal.signal(kind,cancelled)
    try: _stdout,errors = process.communicate(timeout=225)
    except subprocess.TimeoutExpired:
      terminate()
      raise RuntimeError("Docker control timed out; refresh to check the resulting state") from None
    if process.returncode == 126: raise subprocess.CalledProcessError(126,command)
    if process.returncode != 0:
      # Never echo arbitrary polkit/daemon output or container identifiers.
      completed = 0
      try:
        payload = json.loads(errors or "{}")
        count = payload.get("completed",0)
        if type(count) is int and 0 <= count <= 16: completed = count
      except (ValueError,TypeError,AttributeError): pass
      raise RuntimeError("Docker control failed or authorization was denied; " + str(completed) + " container requests accepted; refresh to check the resulting state")
  finally:
    for kind,handler in previous.items(): signal.signal(kind,handler)


def discover(run, snapshot):
  if not trusted_helper(): return None
  result = run(["/usr/bin/sudo", "-n", "--", str(HELPER)], 15)
  if not result or result.returncode != 0:
    snapshot.warning("restricted_docker_unavailable", runtime="docker")
    return None
  try:
    if len(result.stdout.encode()) > MAX_OUTPUT: raise ValueError("oversized snapshot")
    payload = json.loads(result.stdout)
    if type(payload.get("version")) is not int or payload["version"] != 1: raise ValueError("unknown protocol")
    rows = payload["containers"]
    if not isinstance(rows, list) or len(rows) > MAX_CONTAINERS: raise ValueError("invalid inventory")
    containers = []
    authorized = controls_available()
    for source in rows:
      item = project(source)
      if item is None: raise ValueError("uncatalogued service")
      item.update(_runtime="docker", _runtime_cmd="", _discovery_only=True, _authorization_control=authorized)
      traffic = source.get("traffic")
      if isinstance(traffic, list) and len(traffic) == 2 and all(type(n) is int and 0 <= n <= 2**63-1 for n in traffic):
        item["_discovery_stats"] = tuple(traffic)
      events = source.get("events", [])
      if not isinstance(events, list) or len(events) > 1024: raise ValueError("invalid event list")
      item["_discovery_events"] = []
      for event in events:
        action = event.get("Action")
        code = event.get("ExitCode")
        if action not in ("oom", "die", "start", "restart", "create", "update", "health_status: healthy", "health_status: unhealthy"):
          raise ValueError("invalid event action")
        if type(code) is not int or not 0 <= code <= 255: raise ValueError("invalid exit status")
        item["_discovery_events"].append({"Action":action,"ExitCode":code})
      containers.append(item)
    diagnostics = payload.get("diagnostics", [])
    if not isinstance(diagnostics, list) or any(code not in SAFE_DIAGNOSTICS for code in diagnostics): raise ValueError("invalid diagnostics")
    for code in sorted(set(diagnostics)): snapshot.warning(code, runtime="docker")
    return containers
  except (KeyError, ValueError, TypeError, AttributeError, RecursionError):
    snapshot.warning("restricted_docker_invalid", runtime="docker")
    return None
