#!/usr/bin/python3 -I
"""Standalone privileged Docker metadata collector; never import plugin modules."""

import http.client
import ipaddress
import json
import os
import re
import signal
import socket
import sys
import time
import urllib.parse

SOCKET = "/var/run/docker.sock"
MAX_BODY = 16 * 1024 * 1024
MAX_OUTPUT = 2 * 1024 * 1024
MAX_CONTAINERS = 128
# Canonical alias parity is checked against p2p_catalog.py before installation.
ALIASES = frozenset(['airdcpp', 'amule', 'aria2', 'btfs', 'cjdns', 'deluge', 'flood', 'freenet', 'gnunet', 'headscale', 'hyphanet', 'i2p', 'i2p-router', 'i2pd', 'ipfs', 'kubo', 'lnd', 'lokinet', 'monero', 'monerod', 'nebula', 'netbird', 'netbird-client', 'netbird-management', 'netbird-relay', 'netbird-server', 'netbird-signal', 'netclient', 'netmaker', 'netmaker-server', 'nicotine', 'nym-mixnode', 'nym-node', 'opentracker', 'qbittorrent', 'resilio', 'resilio-sync', 'retroshare', 'rtorrent', 'rutorrent', 'slskd', 'soulseek', 'syncthing', 'tahoe', 'tailscale', 'tailscaled', 'transmission', 'tribler', 'veilid', 'webtorrent', 'yggdrasil', 'zeronet', 'zerotier', 'zerotier-one'])


def text(value, limit=256):
  return value[:limit] if isinstance(value, str) else ""


def integer(value, maximum=2**63-1):
  return min(maximum, max(0, value)) if type(value) is int else 0


def image_name(value):
  value = text(value).lower().split("@", 1)[0]
  return value.rsplit(":", 1)[0] if ":" in value.rsplit("/", 1)[-1] else value


def matches(name, image, labels):
  image = image_name(image)
  values = {text(name).lstrip("/").lower(), text(labels.get("com.docker.compose.service")).lower(), image, image.rsplit("/", 1)[-1]}
  return bool(ALIASES.intersection(values))


def project(item):
  """Explicit projection: no raw inspect object, environment, mounts or logs."""
  if not isinstance(item, dict): raise ValueError("invalid container")
  config, state = item.get("Config") or {}, item.get("State") or {}
  labels = config.get("Labels") or {}
  name, image, identity = text(item.get("Name")), text(config.get("Image")), item.get("Id")
  if not isinstance(identity, str) or not re.fullmatch(r"[a-f0-9]{64}", identity): raise ValueError("invalid identity")
  if not matches(name, image, labels): return None
  kept_labels = {}
  for key in ("com.docker.compose.service", "com.docker.compose.project.working_dir", "com.docker.compose.project.config_files"):
    if isinstance(labels.get(key), str): kept_labels[key] = text(labels[key], 4096)
  for key, value in labels.items():
    if len(kept_labels) >= 35: break
    if isinstance(key, str) and re.fullmatch(r"traefik\.http\.routers\.[A-Za-z0-9_-]{1,64}\.rule", key):
      # Export Host rules only, never arbitrary router metadata or credentials.
      hosts = re.findall(r"Host\s*\(\s*[`'\"]([A-Za-z0-9.-]{1,253})[`'\"]\s*\)", text(value, 4096))
      if hosts: kept_labels[key] = " || ".join("Host(`" + host + "`)" for host in hosts[:8])
  ports = {}
  for key, bindings in (item.get("NetworkSettings", {}).get("Ports") or {}).items():
    if len(ports) >= 64: break
    if not re.fullmatch(r"[0-9]{1,5}/(?:tcp|udp)", key) or not isinstance(bindings, list): continue
    safe = []
    for binding in bindings[:8]:
      try:
        host = str(ipaddress.ip_address(binding.get("HostIp", "")))
        port = int(binding.get("HostPort", "0"))
        if 1 <= port <= 65535: safe.append({"HostIp":host,"HostPort":str(port)})
      except (ValueError, TypeError, AttributeError): continue
    ports[key] = safe
  status = state.get("Status")
  health = (state.get("Health") or {}).get("Status")
  return {"Id":identity,"Name":name,"Config":{"Image":image,"Labels":kept_labels},
    "State":{"Running":state.get("Running") is True,"Pid":integer(state.get("Pid"),2**31-1),
      "Status":status if status in ("created","running","paused","restarting","removing","exited","dead") else "",
      "Health":{"Status":health if health in ("starting","healthy","unhealthy") else ""},
      "OOMKilled":state.get("OOMKilled") is True,"ExitCode":integer(state.get("ExitCode"),255),
      "Error":"Container reported an error" if state.get("Error") else "",
      "StartedAt":text(state.get("StartedAt"),64),"FinishedAt":text(state.get("FinishedAt"),64)},
    "RestartCount":integer(item.get("RestartCount"),2**31-1),"NetworkSettings":{"Ports":ports}}


class DockerConnection(http.client.HTTPConnection):
  def __init__(self): super().__init__("localhost", timeout=1.5)
  def connect(self):
    self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    self.sock.settimeout(self.timeout)
    self.sock.connect(SOCKET)


def request(path):
  # Paths are constructed internally; no caller-supplied URL, method or socket.
  connection = DockerConnection()
  try:
    connection.request("GET", path, headers={"Connection":"close"})
    response = connection.getresponse()
    if response.status != 200: raise ValueError("Docker request failed")
    body = response.read(MAX_BODY + 1)
    if len(body) > MAX_BODY: raise ValueError("Docker response too large")
    return [json.loads(line) for line in body.splitlines() if line.strip()] if path.startswith("/events?") else json.loads(body)
  finally: connection.close()


def collect(get=request, clock=time.monotonic):
  deadline = clock() + 10
  listed = get("/containers/json?all=1")
  if not isinstance(listed, list) or len(listed) > 4096: raise ValueError("invalid inventory")
  containers, diagnostics = [], set()
  for summary in listed:
    if clock() >= deadline or len(containers) >= MAX_CONTAINERS:
      diagnostics.add("restricted_docker_partial"); break
    if not isinstance(summary, dict): raise ValueError("invalid summary")
    names, labels = summary.get("Names") or [], summary.get("Labels") or {}
    if not any(matches(name, summary.get("Image"), labels) for name in names): continue
    identity = summary.get("Id")
    if not isinstance(identity, str) or not re.fullmatch(r"[a-f0-9]{64}", identity): raise ValueError("invalid identity")
    try:
      item = project(get("/containers/" + identity + "/json"))
      if item: containers.append(item)
    except (OSError, ValueError, TypeError, AttributeError, RecursionError, http.client.HTTPException):
      diagnostics.add("restricted_docker_partial")
  for item in containers:
    if not item["State"]["Running"]: continue
    if clock() >= deadline:
      diagnostics.add("restricted_docker_stats_unavailable"); break
    try:
      stats = get("/containers/" + item["Id"] + "/stats?stream=false&one-shot=true")
      networks = stats.get("networks") or {}
      if not isinstance(networks, dict): raise ValueError("invalid counters")
      item["traffic"] = [integer(sum(integer(value.get(key)) for value in networks.values())) for key in ("rx_bytes", "tx_bytes")]
    except (OSError, ValueError, TypeError, AttributeError, RecursionError, http.client.HTTPException):
      diagnostics.add("restricted_docker_stats_unavailable")
  if containers and clock() < deadline:
    try:
      identities = {item["Id"]:item for item in containers}
      filters = urllib.parse.quote(json.dumps({"container":list(identities)},separators=(",",":")), safe="")
      until = int(time.time())
      events = get("/events?since=" + str(until-300) + "&until=" + str(until) + "&filters=" + filters)
      if not isinstance(events, list) or len(events) > 1024: raise ValueError("invalid events")
      for event in events:
        actor = event.get("Actor") or {}
        identity = actor.get("ID")
        action = event.get("Action")
        if identity not in identities or action not in ("oom", "die", "start", "restart", "create", "update", "health_status: healthy", "health_status: unhealthy"): continue
        raw_code = str((actor.get("Attributes") or {}).get("exitCode", "0"))
        code = int(raw_code) if re.fullmatch(r"[0-9]{1,3}",raw_code) else 0
        identities[identity].setdefault("events",[]).append({"Action":action,"ExitCode":min(255,code)})
    except (OSError, ValueError, TypeError, AttributeError, RecursionError, http.client.HTTPException):
      diagnostics.add("restricted_docker_events_unavailable")
  elif containers: diagnostics.add("restricted_docker_events_unavailable")
  return {"version":1,"containers":containers,"diagnostics":sorted(diagnostics)}


def main():
  if len(sys.argv) != 1 or os.geteuid() != 0: return 2
  # Hard deadline also bounds trickling socket responses and JSON work.
  signal.signal(signal.SIGALRM, lambda *_args: sys.exit(1))
  signal.alarm(12)
  try:
    output = json.dumps(collect(), separators=(",", ":"))
    if len(output.encode()) > MAX_OUTPUT: return 1
    print(output)
    return 0
  except (OSError, ValueError, TypeError, AttributeError, RecursionError, http.client.HTTPException): return 1


if __name__ == "__main__": raise SystemExit(main())
