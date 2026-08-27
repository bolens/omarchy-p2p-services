const assert = require("node:assert/strict")
const {spawnSync} = require("node:child_process")
const path = require("node:path")

const helper = path.join(__dirname,"..","scripts","select-capture-monitor")
const monitors = [
  {id:0,name:"DP-3",focused:false,x:0,y:0,width:2560,height:1440},
  {id:1,name:"DP-1",focused:true,x:-3440,y:0,width:3440,height:1440},
]
function select(active,cursor,rows=monitors) {
  return spawnSync(helper,[JSON.stringify({active,monitors:rows,cursor})],{encoding:"utf8"})
}

let result=select({monitor:0},{x:-1000,y:700})
assert.equal(result.status,0); assert.equal(result.stdout.trim(),"DP-3")
result=select({},{x:-1000,y:700})
assert.equal(result.status,0); assert.equal(result.stdout.trim(),"DP-1")
result=select({},{x:9000,y:9000})
assert.equal(result.status,0); assert.equal(result.stdout.trim(),"DP-1")
result=select({},{x:0,y:0},[])
assert.notEqual(result.status,0)
result=select({monitor:3},{x:0,y:0},[{id:3,name:"unsafe output",focused:true,x:0,y:0,width:10,height:10}])
assert.notEqual(result.status,0)
console.log("capture monitor selection tests passed")
