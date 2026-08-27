const assert=require("node:assert/strict"),fs=require("node:fs"),os=require("node:os"),path=require("node:path"),{spawnSync}=require("node:child_process")
const root=path.join(__dirname,".."),guard=path.join(root,"scripts","capture-environment-guard"),tmp=fs.mkdtempSync(path.join(os.tmpdir(),"p2p-capture-safety-"))
try {
  const plugin=path.join(tmp,"plugin"),qs=path.join(tmp,"qs"),fingerprint=path.join(tmp,"fingerprint"),hyprctl=path.join(tmp,"hyprctl")
  fs.mkdirSync(plugin)
  fs.writeFileSync(qs,`#!/usr/bin/env bash\n[[ $MOCK_SHELL == down ]] && exit 1\n[[ $6 == ping ]] && printf 'ok\\n' || { [[ $6 == captureContract && $MOCK_CONTRACT != lost ]] && printf '2\\n' || printf 'invalid\\n'; }\n`)
  fs.writeFileSync(fingerprint,"#!/usr/bin/env bash\nprintf '%s\\n' \"$MOCK_FINGERPRINT\"\n")
  fs.writeFileSync(hyprctl,"#!/usr/bin/env bash\nprintf '[{\"name\":\"DP-1\",\"focused\":true,\"activeWorkspace\":{\"id\":%s}}]\\n' \"$MOCK_WORKSPACE\"\n")
  fs.chmodSync(qs,0o755); fs.chmodSync(fingerprint,0o755); fs.chmodSync(hyprctl,0o755)
  const args=["101",plugin,"baseline"],env={...process.env,P2P_QS_COMMAND:qs,P2P_FINGERPRINT_COMMAND:fingerprint,MOCK_SHELL:"up",MOCK_CONTRACT:"ok",MOCK_FINGERPRINT:"baseline"}
  let result=spawnSync(guard,args,{encoding:"utf8",env}); assert.equal(result.status,0,result.stderr)
  result=spawnSync(guard,args,{encoding:"utf8",env:{...env,MOCK_SHELL:"down"}}); assert.match(result.stderr,/Shell changed/)
  result=spawnSync(guard,args,{encoding:"utf8",env:{...env,MOCK_CONTRACT:"lost"}}); assert.match(result.stderr,/contract was lost/)
  result=spawnSync(guard,args,{encoding:"utf8",env:{...env,MOCK_FINGERPRINT:"changed"}}); assert.match(result.stderr,/runtime files changed/)

  const snapshot=path.join(tmp,"snapshot"),settings=path.join(tmp,"shell.json"),durable=path.join(tmp,"settings.json"),previous=path.join(tmp,"previous.json")
  fs.mkdirSync(snapshot); fs.writeFileSync(settings,"shell"); fs.writeFileSync(durable,"durable"); fs.writeFileSync(path.join(snapshot,"shell.json"),"shell"); fs.writeFileSync(path.join(snapshot,"settings.json"),"durable")
  const verifier=path.join(root,"scripts","verify-capture-postconditions"),postArgs=[snapshot,settings,durable,previous,"DP-1","4","101","101"],postEnv={...process.env,P2P_HYPRCTL_COMMAND:hyprctl,MOCK_WORKSPACE:"4"}
  result=spawnSync(verifier,postArgs,{encoding:"utf8",env:postEnv}); assert.equal(result.status,0,result.stderr)
  fs.writeFileSync(durable,"changed"); result=spawnSync(verifier,postArgs,{encoding:"utf8",env:postEnv}); assert.match(result.stderr,/durable settings changed/)
  fs.writeFileSync(durable,"durable"); result=spawnSync(verifier,[...postArgs.slice(0,7),"202"],{encoding:"utf8",env:postEnv}); assert.match(result.stderr,/PID changed/)
  result=spawnSync(verifier,postArgs,{encoding:"utf8",env:{...postEnv,MOCK_WORKSPACE:"5"}}); assert.match(result.stderr,/workspace/)
} finally { fs.rmSync(tmp,{recursive:true,force:true}) }
console.log("capture safety tests passed")
