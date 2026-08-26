"""Process, systemd, container, socket, and proxy discovery adapters."""

import datetime
import json
import os
import pathlib
import re
import shutil

from p2p_metrics import parse_netio
from p2p_validation import safe_console_host


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
    rows=[]
    for line in ([] if not result else result.stdout.splitlines()):
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
      entered=int(values.get("ActiveEnterTimestampMonotonic","0")); boot=float(pathlib.Path("/proc/uptime").read_text().split()[0])*1000000
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
      ids=listed.stdout.split() if listed and listed.returncode == 0 else []
      if not ids: continue
      inspected=self.run([executable,"inspect"]+ids,10)
      if not inspected or inspected.returncode != 0: continue
      try:
        found=json.loads(inspected.stdout)
        for item in found: item["_runtime"]=runtime; item["_runtime_cmd"]=executable
        self.snapshot.containers += found
      except Exception: pass
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
      if not result or result.returncode != 0: continue
      try:
        records=json.loads(result.stdout) if result.stdout.lstrip().startswith("[") else [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
      except (ValueError,TypeError): continue
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
