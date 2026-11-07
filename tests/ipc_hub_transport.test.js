'use strict';
// Actual proposed callback/state logic in a pure model. No real Qt/IPC claim.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const BASE=path.join(__dirname,'..'),src=fs.readFileSync(path.join(BASE,'tests/qml/RuntimeIpcTransportTest.qml'),'utf8'),hs=fs.readFileSync(path.join(BASE,'P2PIpcHub.qml'),'utf8');
function fixture(observerFirst){
 const queue=[],logs=[],ipc={running:false,command:null},service={requests:2};let quit=0;
 const hub={serviceIdentity:service,targetName:'io.github.bolens.p2p-services',entries:[],nextLease:0,routingError:'',handler:{identity:'same-handler'}};
 Object.defineProperty(hub,'widgetCount',{get(){return this.entries.length;}});service.ipcHub=hub;
 const root={announced:false,started:false,finished:false,step:0,focusMode:'valid',targetName:hub.targetName,requiredSignature:'function openSettings(page: string): string',executable:'/usr/bin/quickshell',widget:null,widgetB:null,focusedWidget:null,stableHandler:null,disposalAStarted:false,disposalBStarted:false,disposedA:false,disposedB:false};
 const shellMock={projections:[{id:root.targetName,eventRefresh:false},{id:root.targetName,eventRefresh:false}]};
 const context=vm.createContext({hub,root,ipc,sharedMock:service,shellMock,barMock:{activePopout:false,uiRequests:0},barMockB:{activePopout:false,uiRequests:0},Quickshell:{processId:17242},Qt:{callLater(fn){queue.push(fn);},quit(){quit++;}},console:{log(value){logs.push(value);}}});
 root.barMock=context.barMock;root.barMockB=context.barMockB;
 function methods(source,object){for(const m of source.matchAll(/^    function (\w+)\([^]*?^    }/gm)){vm.runInContext(m[0],context);object[m[1]]=context[m[1]];}}
 methods(hs,hub);methods(src,root);root.calls=vm.runInContext(src.match(/readonly property var calls: (\[[^]*?^    \])/m)[1],context);
 function member(name){
  const w={moduleName:hub.targetName,p2pService:service,durableSettingsLoaded:true,settingsStoreController:{loading:false,loaded:true,busy:false},opened:false,errorText:'',privacyFilterOverride:true,
   ipcFocusedPanel(){if(root.focusMode==='missing')return null;if(root.focusMode==='foreign')return {moduleName:hub.targetName,p2pService:service};if(root.focusMode==='ambiguous')return name==='A'?root.widget:root.widgetB;return root.focusedWidget;},openMainView(){throw new Error('unresolved focus executed action');},captureContractVersion(){return '2';},focusedPanelClosed(){return true;},focusedSettingsSnapshot(){return JSON.stringify({id:root.targetName,privacyFilter:true,eventRefresh:false,refreshOnOpen:false,refreshAfterSettings:false,showTrafficStats:false});},openSettings(page){assert.equal(page,'__invalid_page__');return 'invalid page';},setSettingsScroll(position){assert.equal(position,'__invalid_position__');return 'invalid position';}};
  Object.defineProperty(w,'privacyFilter',{get(){return w.privacyFilterOverride;}});
  const lease=hub.registerWidget(w,hub.targetName,service,name);
  w.destroy=()=>{if(observerFirst)root.memberDisposed(name);hub.unregisterWidget(w,lease);if(!observerFirst)root.memberDisposed(name);};
  return w;
 }
 root.widgetB=member('B');root.widget=member('A');
 const flush=()=>{let bound=100;while(queue.length){assert(bound-->0,'unbounded event queue');queue.shift()();}};
 return {root,hub,ipc,logs,flush,get quit(){return quit;}};
}
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name);}
for(const observerFirst of [false,true])test('actual extended callbacks finish focus/disposal sequence, observerFirst='+observerFirst,()=>{
 const f=fixture(observerFirst);f.root.next();assert.equal(f.ipc.command,null,'must not dispatch before bootstrap');
 f.root.announceReady();assert.equal(f.logs[0],'QML_CI_BOOTSTRAP_READY');assert.equal(f.root.startBootstrap(),'started');assert.equal(f.root.startBootstrap(),'already started');f.flush();
 const seen=[];let bound=40;
 while(!f.root.finished){
  assert(bound-->0);assert.equal(f.ipc.running,true);const call=f.root.calls[f.root.step];let output;
  assert.deepEqual(Array.from(f.ipc.command.slice(0,5)),['/usr/bin/quickshell','ipc','--no-color','--pid','17242']);
  if(call.show)output='target qml-ci-bootstrap\n  function start(): string'+(f.hub.widgetCount?'\ntarget '+f.root.targetName+'\n  '+f.root.requiredSignature:'');
  else if(call.code!==undefined)output=call.expected;
  else output=f.hub.dispatch(call.method,call.args);
  seen.push({method:call.show?'show':call.method,output,count:f.hub.widgetCount});f.ipc.running=false;
  f.root.acceptResponse(call,call.code===undefined?0:call.code,output,'');f.root.step++;f.root.next();f.flush();
 }
 assert.equal(f.quit,1);assert.equal(f.logs.filter(x=>x==='P2P_QML_IPC_TRANSPORT_OK').length,1);assert.equal(f.hub.widgetCount,0);
 assert(seen.some(x=>x.method==='privacyEnabled'&&x.output==='true'&&x.count===2));assert(seen.some(x=>x.method==='privacyEnabled'&&x.output==='false'&&x.count===2));assert(seen.some(x=>x.method==='privacyEnabled'&&x.output==='false'&&x.count===1));
 assert.equal(seen.at(-1).count,0);assert(!seen.at(-1).output.includes('target '+f.root.targetName));
});
test('extra queued events do not overlap dispatch or duplicate final marker',()=>{
 const f=fixture(false);f.root.announceReady();f.root.startBootstrap();f.flush();const first=f.ipc.command;
 f.root.next();assert.equal(f.ipc.command,first);f.root.finished=true;f.root.next();assert.equal(f.quit,0);
});
test('dynamic members have real graphical parents and statically typed host facades',()=>{
 assert(src.includes('component BarFacade: QtObject'));
 assert(src.includes('property BarFacade barMock: null'));
 assert(src.includes('property BarFacade barMockB: null'));
 assert(src.includes('Windowing.Window {\n        visible: false'));
 assert(src.includes('Item { id: memberRoot; anchors.fill: parent }'));
 assert.equal((src.match(/memberFactory.createObject\(memberRoot,/g)||[]).length,2);
 assert(!src.includes('memberFactory.createObject(root,'));
 assert(src.includes('bar: root.barMock'));
});
console.log(JSON.stringify({passed,kind:'pure actual-callback state model; no Qt engine or IPC transport execution'}));
