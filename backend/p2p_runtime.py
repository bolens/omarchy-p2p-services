"""Process, systemd, container, socket, and proxy discovery adapters."""

import datetime
import json
import os
import pathlib
import re
import shutil

from backend.p2p_metrics import parse_netio
from backend.p2p_lifecycle import classify_container_event, classify_systemd_restart_log, select_restart_kind
from backend.p2p_validation import safe_console_host


def parse_json_records(text):
  """Accept a JSON object, array, or newline-delimited object stream."""
  content=str(text or "").strip()
  if not content: return []
  try: decoded=json.loads(content)
  except (TypeError,ValueError,json.JSONDecodeError):
    decoded=[json.loads(line) for line in content.splitlines() if line.strip()]
  records=decoded if isinstance(decoded,list) else [decoded]
  if not all(isinstance(record,dict) for record in records): raise ValueError("JSON records must be objects")
  return records


class RuntimeProbe:
  def __init__(self, snapshot, run_command, services, ps, systemctl, aliases):
    self.snapshot = snapshot
    self.run = run_command
    self.services = services
    self.ps = ps
    self.systemctl = systemctl
    self.aliases = aliases

  
  def process_rows(self):
    """Return one process snapshot shared by detection, PID, and uptime queries."""
    if self.snapshot.process_rows is not None: return self.snapshot.process_rows
    result=self.run([self.ps,"-eo","uid=,pid=,etimes=,comm=,args="],3)
    if not result or result.returncode != 0:
      self.snapshot.warning("process_snapshot_unavailable")
      self.snapshot.process_rows=[]
      return self.snapshot.process_rows
    rows=[]
    for line in result.stdout.splitlines():
      fields=line.strip().split(None,4)
      if len(fields)<4 or not all(value.isdigit() for value in fields[:3]): continue
      uid,pid,etimes,comm=int(fields[0]),int(fields[1]),int(fields[2]),fields[3]
      argv0=os.path.basename(fields[4].split(None,1)[0]) if len(fields)>4 and fields[4] else ""
      rows.append((uid,pid,etimes,comm,argv0))
    self.snapshot.process_rows=rows
    return self.snapshot.process_rows
  
  def pids_for(self, names, current_user_only=False):
    """Match names from the shared process snapshot; optionally restrict mutation targets."""
    wanted=set(names)
    cache_key=(tuple(sorted(wanted)),current_user_only)
    if cache_key in self.snapshot.process_matches: return self.snapshot.process_matches[cache_key]
    found=[]
    for uid,pid,_etimes,comm,argv0 in self.process_rows():
      if (comm in wanted or argv0 in wanted) and (not current_user_only or uid==os.getuid()): found.append(pid)
    self.snapshot.process_matches[cache_key]=sorted(set(found))
    return self.snapshot.process_matches[cache_key]
  
  def pid_uptime(self, pid):
    if self.snapshot.process_by_pid is None:
      self.snapshot.process_by_pid={row_pid:etimes for _uid,row_pid,etimes,_comm,_argv0 in self.process_rows()}
    return self.snapshot.process_by_pid.get(pid,0)
  
  def unit_snapshot(self, user):
    """Batch every declared unit into one user or system systemctl query."""
    if user in self.snapshot.unit_snapshots: return self.snapshot.unit_snapshots[user]
    units=sorted(set(unit for service in self.services() for unit in service["units"]))
    prefix=[self.systemctl] + (["--user"] if user else [])
    properties="Id,LoadState,ActiveState,SubState,Result,ExecMainStatus,MainPID,ActiveEnterTimestampMonotonic,ActiveStateChangeTimestamp,NRestarts"
    result=self.run(prefix+["show"]+units+["--property="+properties,"--no-pager"],8) if units else None
    records={}; current={}
    if units and (not result or result.returncode != 0):
      self.snapshot.warning("systemd_snapshot_unavailable",scope="user" if user else "system")
    for line in ([] if not result else result.stdout.splitlines())+[""]:
      if not line.strip():
        unit=current.get("Id","")
        if unit: records[unit]=current
        current={}; continue
      if "=" in line:
        key,value=line.split("=",1); current[key]=value
    self.snapshot.unit_snapshots[user]=records
    return records
  
  def unit_state(self, units, user):
    snapshot=self.unit_snapshot(user)
    for unit in units:
      values=snapshot.get(unit,{})
      if values.get("LoadState") == "loaded": return unit, values.get("ActiveState") == "active"
    return "", False
  
  def unit_main_pid(self, unit, user):
    if not unit: return 0
    value=self.unit_snapshot(user).get(unit,{}).get("MainPID","")
    return int(value) if value.isdigit() and int(value)>0 else 0
  
  def unit_has_error(self, unit, user):
    if not unit: return False
    values=self.unit_snapshot(user).get(unit,{})
    return values.get("ActiveState") == "failed" or values.get("SubState") in ("failed","auto-restart") or values.get("Result", "success") not in ("","success") or values.get("ExecMainStatus","0") not in ("","0")
  
  def unit_uptime(self, unit, user):
    if not unit: return 0
    values=self.unit_snapshot(user).get(unit,{})
    try:
      entered=int(values.get("ActiveEnterTimestampMonotonic","0"))
      if self.snapshot.boot_uptime_microseconds is None:
        self.snapshot.boot_uptime_microseconds=float(pathlib.Path("/proc/uptime").read_text().split()[0])*1000000
      boot=self.snapshot.boot_uptime_microseconds
      return max(0,int((boot-entered)/1000000)) if values.get("ActiveState") == "active" and entered else 0
    except (OSError,ValueError,IndexError): return 0
  
  def service_diagnostics(self, user_unit, system_unit, running_items, docker_items):
    unit_values=self.unit_snapshot(True).get(user_unit,{}) if user_unit else self.unit_snapshot(False).get(system_unit,{}) if system_unit else {}
    restart_count=int(unit_values.get("NRestarts","0") or 0)
    restart_count += sum(int(item.get("RestartCount",0) or 0) for item in docker_items)
    transition=str(unit_values.get("ActiveStateChangeTimestamp","") or "")
    if not transition and docker_items:
      transition=max((str(item.get("State",{}).get("StartedAt") or item.get("State",{}).get("FinishedAt") or "") for item in docker_items),default="")
    reasons=[]
    result=str(unit_values.get("Result","") or "")
    status=str(unit_values.get("ExecMainStatus","0") or "0")
    if result not in ("","success"): reasons.append(result)
    if status not in ("","0"): reasons.append("exit "+status)
    for item in docker_items:
      state=item.get("State",{})
      health=(state.get("Health",{}) or {}).get("Status","")
      if health == "unhealthy": reasons.append("container unhealthy")
      if state.get("OOMKilled"): reasons.append("container OOM-killed")
      if state.get("Error"): reasons.append(str(state.get("Error"))[:160])
    return restart_count,transition,"; ".join(dict.fromkeys(reasons))

  def service_restart_kind(self, unit, user, docker_items, restart_count):
    """Classify the latest automatic restart without exposing journal content."""
    if restart_count <= 0: return ""
    recent_items=[]
    for item in docker_items:
      state=item.get("State",{})
      latest=str(state.get("StartedAt") or state.get("FinishedAt") or "").replace("Z","+00:00")
      try: age=(datetime.datetime.now(datetime.timezone.utc)-datetime.datetime.fromisoformat(latest).astimezone(datetime.timezone.utc)).total_seconds()
      except (TypeError,ValueError): age=301
      if age > 300: continue
      recent_items.append((item,latest))
      if state.get("OOMKilled") or state.get("Error") or state.get("ExitCode") not in (None,0,"0"):
        return "crash"
    event_kinds=[]
    until=datetime.datetime.now(datetime.timezone.utc).isoformat()
    for item,latest in recent_items:
      if int(item.get("RestartCount",0) or 0) <= 0: continue
      command=item.get("_runtime_cmd")
      name=str(item.get("Name","")).lstrip("/")
      if not command or not name: continue
      cache_key=(item.get("_runtime"),name,int(item.get("RestartCount",0) or 0),latest)
      if cache_key not in self.snapshot.lifecycle_kinds:
        output_format="{{json .}}" if item.get("_runtime") == "docker" else "json"
        result=self.run([command,"events","--since","5m","--until",until,"--filter","container="+name,"--format",output_format],4)
        kinds=[]
        if not result or result.returncode != 0:
          self.snapshot.warning("container_events_unavailable",runtime=str(item.get("_runtime") or "container"))
        else:
          invalid=False
          for line in result.stdout.splitlines():
            if not line.strip(): continue
            try: classification=classify_container_event(json.loads(line))
            except (TypeError,ValueError,json.JSONDecodeError): classification=None; invalid=True
            if classification: kinds.append(classification[0])
          if invalid: self.snapshot.warning("container_events_invalid",runtime=str(item.get("_runtime") or "container"))
        self.snapshot.lifecycle_kinds[cache_key]=select_restart_kind(kinds)
      event_kinds.append(self.snapshot.lifecycle_kinds[cache_key])
    if "oom" in event_kinds or "crash" in event_kinds: return "crash"
    if "update" in event_kinds: return "update"
    if not unit: return "restart"
    uptime=self.unit_uptime(unit,user)
    if uptime > 300: return "restart"
    cache_key=("systemd",user,unit,restart_count)
    if cache_key in self.snapshot.lifecycle_kinds: return self.snapshot.lifecycle_kinds[cache_key]
    journalctl=os.path.join(os.path.dirname(self.systemctl),"journalctl")
    command=[journalctl] + (["--user"] if user else []) + ["--unit",unit,"--lines=80","--no-pager","--output=cat"]
    result=self.run(command,4)
    if not result or result.returncode != 0:
      self.snapshot.warning("systemd_journal_unavailable",scope="user" if user else "system")
      return "restart"
    lines=result.stdout.splitlines()
    markers=[index for index,line in enumerate(lines) if "scheduled restart job" in line.lower()]
    if markers:
      end=markers[-1]+1
      start=markers[-2]+1 if len(markers)>1 else max(0,end-40)
      text="\n".join(lines[start:end]).lower()
    else:
      text="\n".join(lines[-40:]).lower()
    kind=classify_systemd_restart_log(text)
    self.snapshot.lifecycle_kinds[cache_key]=kind
    return kind

  def service_stop_kind(self, unit, user, process_names, active):
    """Return a confirmed stop cause; absence of evidence stays unclassified."""
    if active: return "", ""
    if unit:
      values=self.unit_snapshot(user).get(unit,{})
      result=str(values.get("Result","") or "")
      status=str(values.get("ExecMainStatus","0") or "0")
      if result not in ("","success") or status not in ("","0"):
        return "crash", "systemd-failure"
      return "", ""
    if self.snapshot.recent_coredumps is None:
      coredumpctl=os.path.join(os.path.dirname(self.systemctl),"coredumpctl")
      result=self.run([coredumpctl,"list","--json=short","--since=-2min","--no-pager"],4)
      stderr=str(getattr(result,"stderr","") or "") if result else ""
      no_records=bool(result and result.returncode == 1 and "no coredumps found" in stderr.lower() and "failed" not in stderr.lower())
      if no_records:
        self.snapshot.recent_coredumps=[]
      elif not result or result.returncode != 0:
        self.snapshot.warning("coredump_snapshot_unavailable")
        self.snapshot.recent_coredumps=[]
      else:
        try:
          self.snapshot.recent_coredumps=parse_json_records(result.stdout)
        except (TypeError,ValueError,json.JSONDecodeError):
          self.snapshot.warning("coredump_snapshot_invalid")
          self.snapshot.recent_coredumps=[]
    wanted={str(name) for name in process_names}
    for record in self.snapshot.recent_coredumps:
      executable=str(record.get("exe") or record.get("EXE") or record.get("COREDUMP_EXE") or "")
      command=str(record.get("comm") or record.get("COMM") or record.get("COREDUMP_COMM") or "")
      if os.path.basename(executable) in wanted or command in wanted: return "crash", "core-dump"
    return "", ""
  
  def container_uptime(self, item):
    if not item.get("State",{}).get("Running"): return 0
    try:
      started=str(item.get("State",{}).get("StartedAt","")).replace("Z","+00:00")
      then=datetime.datetime.fromisoformat(started).astimezone(datetime.timezone.utc)
      return max(0,int((datetime.datetime.now(datetime.timezone.utc)-then).total_seconds()))
    except (ValueError,TypeError): return 0
  
  def containers(self):
    if self.snapshot.containers is not None: return self.snapshot.containers
    self.snapshot.containers=[]
    for runtime in ("docker","podman"):
      executable=shutil.which(runtime)
      if not executable: continue
      executable=os.path.realpath(executable)
      listed=self.run([executable,"ps","-aq" if self.snapshot.all_containers else "-q"],4)
      if not listed or listed.returncode != 0:
        self.snapshot.warning("container_list_unavailable",runtime=runtime)
        continue
      ids=listed.stdout.split() if listed and listed.returncode == 0 else []
      if not ids: continue
      inspected=self.run([executable,"inspect"]+ids,10)
      if not inspected or inspected.returncode != 0:
        self.snapshot.warning("container_inspect_unavailable",runtime=runtime)
        continue
      try:
        found=json.loads(inspected.stdout)
        if not isinstance(found,list): raise ValueError("container inspection is not a list")
        for item in found: item["_runtime"]=runtime; item["_runtime_cmd"]=executable
        self.snapshot.containers += found
      except (TypeError,ValueError,json.JSONDecodeError):
        self.snapshot.warning("container_inspect_invalid",runtime=runtime)
    self.snapshot.containers.sort(key=lambda item:(item.get("_runtime","docker"),str(item.get("Name","")).lstrip("/")))
    return self.snapshot.containers
  
  def container_stats(self, items):
    """Collect counters only for running containers matched to P2P services."""
    if self.snapshot.container_stats is not None: return self.snapshot.container_stats
    self.snapshot.container_stats={}
    groups={}
    for item in items:
      if not item.get("State",{}).get("Running"): continue
      runtime=item.get("_runtime","docker"); command=item.get("_runtime_cmd")
      name=str(item.get("Name","")).lstrip("/")
      if command and name: groups.setdefault((runtime,command),[]).append(name)
    for (runtime,command),names in groups.items():
      args=[command,"stats","--no-stream"] + (["--format","{{json .}}"] if runtime=="docker" else ["--format","json"]) + names
      result=self.run(args,15)
      if not result or result.returncode != 0:
        self.snapshot.warning("container_stats_unavailable",runtime=runtime)
        continue
      try:
        records=json.loads(result.stdout) if result.stdout.lstrip().startswith("[") else [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
      except (ValueError,TypeError,json.JSONDecodeError):
        self.snapshot.warning("container_stats_invalid",runtime=runtime)
        continue
      for record in records:
        name=str(record.get("Name") or record.get("Container") or record.get("name") or "").lstrip("/")
        netio=record.get("NetIO") or record.get("NetInput") or record.get("netio") or ""
        if name: self.snapshot.container_stats[(runtime,name)]=parse_netio(netio)
    return self.snapshot.container_stats
  
  def container_matches_service(self, service, item):
    aliases={alias.lower() for alias in self.aliases.get(service["id"],[service["id"]])}
    labels=(item.get("Config",{}).get("Labels") or {})
    image=str(item.get("Config",{}).get("Image","")).lower().split("@",1)[0]
    image=image.rsplit(":",1)[0] if ":" in image.rsplit("/",1)[-1] else image
    values={str(item.get("Name","")).lstrip("/").lower(),str(labels.get("com.docker.compose.service","")).lower(),image,image.rsplit("/",1)[-1]}
    return bool(aliases.intersection(value for value in values if value))
  
  def docker_matches(self, service):
    service_id=service["id"]
    if self.snapshot.container_matches is None:
      items=self.containers()
      self.snapshot.container_matches={}
      for declared in self.services():
        self.snapshot.container_matches[declared["id"]]=[item for item in items if self.container_matches_service(declared,item)]
    return self.snapshot.container_matches.get(service_id,[])
  
  def proxy_candidates(self, items):
    candidates=[]
    for item in items:
      labels=(item.get("Config",{}).get("Labels") or {})
      for key,value in labels.items():
        if key.startswith("traefik.http.routers.") and key.endswith(".rule"):
          for host in re.findall(r"Host\s*\(\s*[`'\"]([^`'\"]+)",str(value)):
            clean=safe_console_host(host)
            if clean: candidates.append((0,"https://"+clean+"/","traefik"))
      workdir=labels.get("com.docker.compose.project.working_dir","")
      compose_files=[path for path in labels.get("com.docker.compose.project.config_files","").split(",") if path]
      try:
        root=pathlib.Path(workdir).resolve(strict=True)
        trusted=any(pathlib.Path(path).resolve(strict=True).is_relative_to(root) for path in compose_files)
      except (OSError,ValueError): trusted=False
      if not trusted: continue
      for relative,proxy in [("caddy_snippet.conf","caddy"),("Caddyfile","caddy"),("haproxy.cfg","haproxy"),("nginx.conf","nginx"),("conf.d/default.conf","nginx")]:
        path=pathlib.Path(os.path.join(workdir,relative))
        try:
          stat=path.stat()
          if not path.is_file() or stat.st_size > 1048576: continue
          cache_key=(str(path),stat.st_mtime_ns,stat.st_size)
          content=self.snapshot.proxy_files.get(cache_key)
          if content is None:
            content=path.read_text(errors="replace")
            self.snapshot.proxy_files[cache_key]=content
        except Exception: continue
        hosts=[]
        if proxy=="caddy":
          for line in content.splitlines():
            route=line.strip().split("{")[0].strip().rstrip(",").replace("http://","").replace("https://","")
            if route and " " not in route and re.match(r"^[A-Za-z0-9.-]+$",route): hosts.append(route)
        elif proxy=="nginx": hosts += re.findall(r"server_name\s+([^;]+);",content)
        else: hosts += re.findall(r"hdr\s*\(host\)\s+-i\s+([A-Za-z0-9.-]+)",content,re.I)
        for group in hosts:
          for host in str(group).split():
            if re.match(r"^[A-Za-z0-9.-]+$",host):
              score=1 if host.endswith((".home",".local",".home.arpa")) else 0
              candidates.append((score,"https://"+host+"/",proxy))
    return sorted(set(candidates))
  
  def published_url(self, service, items, console_host):
    console_host=safe_console_host(console_host)
    match=re.search(r":(\d+)(?:/|$)",service["web"] or ""); target=(match.group(1)+"/tcp") if match else ""
    for item in items:
      bindings=(item.get("NetworkSettings",{}).get("Ports") or {}).get(target) if target else None
      if bindings:
        host=bindings[0].get("HostIp",""); port=bindings[0].get("HostPort","")
        if port: return "http://"+(console_host or ("127.0.0.1" if host in ("","0.0.0.0","::") else host))+":"+port+"/"
    return ""
