#!/usr/bin/python3 -I
"""Standalone administrator-authorized lifecycle control of existing P2P containers."""
import fcntl
import http.client
import json
import os
import re
import select
import signal
import socket
import stat
import sys
import time

SOCKET = "/var/run/docker.sock"
LOCK = "/run/omarchy-p2p-control.lock"
MAX_TARGETS = 16
MAX_BODY = 2 * 1024 * 1024
ACTIONS = frozenset({"start", "stop", "restart"})
SERVICE_ALIASES = {'yggdrasil': ['yggdrasil'], 'tailscale': ['tailscale', 'tailscaled'], 'zerotier': ['zerotier', 'zerotier-one'], 'nebula': ['nebula'], 'headscale': ['headscale'], 'netbird': ['netbird', 'netbird-client'], 'netbird-server': ['netbird-server', 'netbird-management', 'netbird-signal', 'netbird-relay'], 'netmaker': ['netmaker', 'netmaker-server'], 'netclient': ['netclient'], 'i2pd': ['i2pd'], 'i2p': ['i2p-router', 'i2p'], 'freenet': ['freenet'], 'hyphanet': ['hyphanet'], 'airdcpp': ['airdcpp'], 'nicotine': ['nicotine'], 'slskd': ['slskd', 'soulseek'], 'deluge': ['deluge'], 'qbittorrent': ['qbittorrent'], 'transmission': ['transmission'], 'aria2': ['aria2'], 'ipfs': ['ipfs', 'kubo'], 'syncthing': ['syncthing'], 'resilio': ['resilio', 'resilio-sync'], 'zeronet': ['zeronet'], 'gnunet': ['gnunet'], 'retroshare': ['retroshare'], 'cjdns': ['cjdns'], 'lokinet': ['lokinet'], 'veilid': ['veilid'], 'tahoe': ['tahoe'], 'amule': ['amule'], 'rtorrent': ['rtorrent', 'flood', 'rutorrent'], 'tribler': ['tribler'], 'webtorrent': ['webtorrent'], 'btfs': ['btfs'], 'opentracker': ['opentracker'], 'nym': ['nym-node', 'nym-mixnode'], 'lnd': ['lnd'], 'monerod': ['monero', 'monerod']}


class ControlError(Exception):
  def __init__(self, code, completed=0):
    super().__init__(code)
    self.code, self.completed = code, completed


class DockerConnection(http.client.HTTPConnection):
  def __init__(self): super().__init__("localhost", timeout=8)
  def connect(self):
    self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    self.sock.settimeout(self.timeout)
    self.sock.connect(SOCKET)


def request(method, path):
  connection = DockerConnection()
  try:
    connection.request(method, path, body=b"" if method == "POST" else None, headers={"Connection":"close"})
    response = connection.getresponse()
    body = response.read(MAX_BODY + 1)
    if len(body) > MAX_BODY: raise ControlError("response_too_large")
    if method == "GET":
      if response.status != 200: raise ControlError("target_unavailable")
      return json.loads(body)
    if response.status not in (204, 304): raise ControlError("operation_failed")
    return None
  finally: connection.close()


def parse_arguments(arguments):
  check = bool(arguments and arguments[0] == "--check")
  values = arguments[1:] if check else arguments
  if len(values) < 3 or len(values) > MAX_TARGETS + 2: raise ControlError("invalid_request")
  action, service, *identities = values
  if action not in ACTIONS or service not in SERVICE_ALIASES: raise ControlError("invalid_request")
  if len(set(identities)) != len(identities) or any(not re.fullmatch(r"[a-f0-9]{64}",value) for value in identities):
    raise ControlError("invalid_targets")
  return check, action, service, identities


def inspect_target(service, identity, api):
  item = api("GET", "/containers/" + identity + "/json")
  if not isinstance(item, dict) or item.get("Id") != identity: raise ControlError("identity_changed")
  config = item.get("Config") or {}
  labels = config.get("Labels") or {}
  name, image = item.get("Name", ""), config.get("Image", "")
  if not isinstance(name,str) or not isinstance(image,str) or not isinstance(labels,dict): raise ControlError("invalid_target")
  image = image.lower().split("@",1)[0]
  if ":" in image.rsplit("/",1)[-1]: image = image.rsplit(":",1)[0]
  alias = labels.get("com.docker.compose.service", "")
  values = {name.lstrip("/").lower(), image, image.rsplit("/",1)[-1], alias.lower() if isinstance(alias,str) else ""}
  if name.endswith("-init") or not set(SERVICE_ALIASES[service]).intersection(values): raise ControlError("service_mismatch")
  state = item.get("State") or {}
  if not isinstance(state,dict) or type(state.get("Running")) is not bool: raise ControlError("invalid_target_state")
  return state["Running"]


def control(arguments, api=request, clock=time.monotonic, sleep=time.sleep, progress=None):
  check, action, service, identities = parse_arguments(arguments)
  # Verify the entire immutable-ID selection before the first POST.
  for identity in identities: inspect_target(service,identity,api)
  if check: return {"checked":len(identities),"completed":0,"mutated":False}
  if progress: progress("applying")
  completed = 0
  try:
    for identity in identities:
      running = inspect_target(service,identity,api)
      if (action == "start" and running) or (action in ("stop","restart") and not running): continue
      suffix = "/" + action + ("?t=5" if action in ("stop","restart") else "")
      api("POST", "/containers/" + identity + suffix)
      completed += 1
      if progress: progress("verifying")
      deadline = clock() + 5
      while True:
        active = inspect_target(service,identity,api)
        if active == (action != "stop"): break
        if clock() >= deadline: raise ControlError("state_not_confirmed")
        sleep(0.1)
      if progress: progress("applying")
  except ControlError as error:
    raise ControlError(error.code,completed) from None
  except (OSError,ValueError,TypeError,AttributeError,RecursionError,http.client.HTTPException):
    raise ControlError("docker_unavailable",completed) from None
  return {"checked":len(identities),"completed":completed,"mutated":completed>0}


def acquire_lock():
  descriptor = os.open(LOCK,os.O_WRONLY|os.O_CREAT|os.O_NOFOLLOW|os.O_CLOEXEC,0o600)
  try:
    info = os.fstat(descriptor)
    if info.st_uid != 0 or not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077 or info.st_nlink != 1:
      raise ControlError("unsafe_lock")
    try: fcntl.flock(descriptor,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError: raise ControlError("control_busy") from None
    return descriptor
  except BaseException:
    os.close(descriptor)
    raise


def emit_phase(phase):
  print(json.dumps({"phase":phase},separators=(",",":")),flush=True)


def caller_guard():
  # pkexec preserves the invoking uid. The direct child is exec'd in place,
  # so the parent is our unprivileged CLI, not a long-lived authorization agent.
  raw_uid = os.environ.get("PKEXEC_UID", "")
  if not re.fullmatch(r"[0-9]{1,10}",raw_uid): raise ControlError("invalid_caller")
  parent = os.getppid()
  if parent <= 1 or os.stat("/proc/" + str(parent)).st_uid != int(raw_uid): raise ControlError("invalid_caller")
  descriptor = os.pidfd_open(parent,0)
  def guarded_request(method,path):
    if select.select([descriptor],[],[],0)[0]: raise ControlError("caller_cancelled")
    return request(method,path)
  return descriptor,guarded_request


def operation_timeout(_signum,_frame):
  raise ControlError("operation_timeout")


def main():
  if os.geteuid() != 0: return 2
  lock, caller = None, None
  try:
    parse_arguments(sys.argv[1:])
    signal.signal(signal.SIGALRM,operation_timeout)
    signal.signal(signal.SIGTERM,lambda *_: sys.exit(143))
    signal.signal(signal.SIGINT,lambda *_: sys.exit(130))
    signal.alarm(90)
    caller,api = caller_guard()
    lock = acquire_lock()
    result = control(sys.argv[1:],api=api,progress=emit_phase)
    print(json.dumps(result,separators=(",",":")),flush=True)
    return 0
  except ControlError as error:
    print(json.dumps({"error":error.code,"completed":error.completed},separators=(",",":")),file=sys.stderr)
    return 1
  except (OSError,ValueError,TypeError,AttributeError,RecursionError,http.client.HTTPException):
    print('{"error":"docker_unavailable","completed":0}',file=sys.stderr)
    return 1
  finally:
    if lock is not None: os.close(lock)
    if caller is not None: os.close(caller)


if __name__ == "__main__": raise SystemExit(main())
