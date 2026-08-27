"""Privacy-aware service status projection."""

import os

from backend.p2p_validation import safe_http_url


def public_web_fields(url, private):
  valid = safe_http_url(url)
  return (("Available" if valid else ""), "", bool(valid)) if private else (valid, valid, bool(valid))


class ServiceInspector:
  def __init__(self, probe, snapshot, socket_query, config_resolver):
    self.probe = probe
    self.snapshot = snapshot
    self.socket_query = socket_query
    self.config_resolver = config_resolver

  def inspect(self, service, private, console_host=""):
    pids=self.probe.pids_for(service["processes"])
    docker_items=self.probe.docker_matches(service)
    running_items=[item for item in docker_items if item.get("State",{}).get("Running")]
    pids=sorted(set(pids+[int(item.get("State",{}).get("Pid",0)) for item in running_items if int(item.get("State",{}).get("Pid",0))>0]))
    user_unit,user_active=self.probe.unit_state(service["units"],True)
    system_unit,system_active=self.probe.unit_state(service["units"],False)
    unit_pids=[self.probe.unit_main_pid(user_unit,True),self.probe.unit_main_pid(system_unit,False)]
    pids=sorted(set(pids+[pid for pid in unit_pids if pid>0]))
    active=bool(pids) or user_active or system_active or bool(running_items)
    container_error=any((item.get("State",{}).get("Health",{}).get("Status") == "unhealthy") or item.get("State",{}).get("Status") in ("restarting","dead") or item.get("State",{}).get("OOMKilled") or bool(item.get("State",{}).get("Error")) for item in running_items)
    has_error=active and (container_error or self.probe.unit_has_error(user_unit,True) or self.probe.unit_has_error(system_unit,False))
    restart_count,last_transition,failure_reason=self.probe.service_diagnostics(user_unit,system_unit,running_items,docker_items)
    connected,listening,endpoints=self.socket_query(pids,private)
    uptimes=[self.probe.unit_uptime(user_unit,True),self.probe.unit_uptime(system_unit,False)] + [self.probe.container_uptime(item) for item in running_items]
    uptimes += [self.probe.pid_uptime(pid) for pid in pids]
    uptime=max(uptimes or [0])
    configs=self.config_resolver(service,docker_items)
    config=configs[0] if configs else os.path.expanduser(service["config"])
    routes=self.probe.proxy_candidates(docker_items)
    discovered_web=safe_http_url((routes[0][1] if routes else "") or self.probe.published_url(service,docker_items,console_host) or service["web"])
    proxy=(routes[0][2] if routes else "")
    web_value,default_web,has_web=public_web_fields(discovered_web,private)
    stats=self.snapshot.container_stats or {}; totals=[stats.get((item.get("_runtime","docker"),str(item.get("Name","")).lstrip("/"))) for item in running_items]
    totals=[value for value in totals if value is not None]; rx_bytes=sum(value[0] for value in totals); tx_bytes=sum(value[1] for value in totals)
    return dict(id=service["id"],name=service["name"],icon=service["icon"],category=service["category"],installed=True,
      active=active,hasError=has_error,health=("error" if has_error else ("healthy" if active else "stopped")),pids=[] if private else pids,processCount=len(pids),uptime=uptime,
      connections=connected,listeners=listening,endpoints=endpoints,rxBytes=rx_bytes,txBytes=tx_bytes,trafficAvailable=bool(totals),
      unit=user_unit or system_unit,unitScope="user" if user_unit else ("system" if system_unit else ""),
      config="Hidden" if private else config,configExists=bool(configs),
      web=web_value,defaultWeb=default_web,hasWeb=has_web,
      containers=[] if private else [item.get("Name","").lstrip("/") for item in docker_items],containerCount=len(docker_items),
      runtimes=sorted(set(item.get("_runtime","docker") for item in docker_items)),
      backend="+".join(sorted(set(item.get("_runtime","docker") for item in docker_items))) if docker_items else ("systemd" if user_unit or system_unit else "process"),proxy=proxy,
      restartCount=restart_count,lastTransition=last_transition,failureReason=("Service reported an error" if private and failure_reason else failure_reason),
      custom=service.get("custom",False),controllable=service.get("controllable",True) is True,
      privacyFiltered=private)
  
  def diagnostics_text(self, service, private=True):
    entry=self.inspect(service,private)
    lines=[entry["name"]+" ("+entry["id"]+")", "State: "+entry["health"], "Backend: "+entry["backend"], "Restarts: "+str(entry["restartCount"])]
    if entry.get("unit"): lines.append("Unit: "+entry["unit"])
    if entry.get("lastTransition"): lines.append("Last transition: "+entry["lastTransition"])
    if entry.get("failureReason"): lines.append("Failure: "+entry["failureReason"])
    lines.append("Privacy filtered: "+("yes" if private else "no"))
    return "\n".join(lines)+"\n"
  
