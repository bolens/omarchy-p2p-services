'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const BASE=__dirname;
const LABEL="p2p";
function model(label) {
 const source=fs.readFileSync(path.join(BASE,'qml/RuntimeIpcTransportTest.qml'),'utf8');
 const callsSource=source.match(/readonly property var calls: (\[[^]*?^    \])/m)[1];
 const queue=[],logs=[],ipc={command:[],running:false};let quits=0;
 const service={pendingPatch:null,effectiveSettings:{count:3},monitorNames(){return ['DP-1'];},registerWidget(){}};
 const sharedMock={requests:2,ipcHub:{widgetCount:2,handler:{}}};const widgetMock={actions:[],opened:false};
 const widget={durableSettingsLoaded:true,settingsStoreController:{loading:false,loaded:true,busy:false},p2pService:sharedMock,opened:false,errorText:''};
 const root={configPath:'/owned unique config/RuntimeIpcTransportTest.qml',executable:'/usr/bin/quickshell',announced:false,started:false,finished:false,step:0,registered:false};
 root.targetName=label==='mmw'?'multi-monitor-workspaces':'io.github.bolens.p2p-services';
 root.widget=widget;root.widgetB={...widget,settingsStoreController:{...widget.settingsStoreController}};root.barMock={activePopout:false,uiRequests:0};root.barMockB={activePopout:false,uiRequests:0};root.focusMode='valid';root.disposalAStarted=false;root.disposalBStarted=false;root.disposedA=false;root.disposedB=false;
 widget.destroy=()=>{sharedMock.ipcHub.widgetCount--;root.memberDisposed('A');};root.widgetB.destroy=()=>{sharedMock.ipcHub.widgetCount--;root.memberDisposed('B');};
 root.requiredSignature=label==='mmw'?'function activate(screen: string, workspace: int, action: string): string':'function openSettings(page: string): string';
 const context=vm.createContext({root,ipc,service,sharedMock,widgetMock,widget,shellMock:{projections:[{id:root.targetName,eventRefresh:false},{id:root.targetName,eventRefresh:false}]},barMock:root.barMock,barMockB:root.barMockB,Quickshell:{processId:4521},Qt:{callLater(fn){queue.push(fn);},quit(){quits++;}},console:{log(value){logs.push(value);}}});
 root.calls=vm.runInContext(callsSource,context);
 for(const match of source.matchAll(/^    function (\w+)\([^]*?^    }/gm)){vm.runInContext(match[0],context);root[match[1]]=context[match[1]];}
 const callbackBody=source.match(/^        onExited: function\(code\) \{([^]*?)^        }/m)[1];
 vm.runInContext('function exited(code) {'+callbackBody+'}',context);
 return {root,logs,queue,ipc,widgetMock,widget,source,get quits(){return quits;},exited(code,stdout,stderr=''){
  ipc.running=false;context.ipcOutput={text:stdout};context.ipcErrors={text:stderr};context.exited(code);
 },flush(){let bound=30;while(queue.length){assert(bound-->0);queue.shift()();}}};
}
let total=0;function check(name,fn){fn();total++;console.log('PASS '+name);}
for(const label of [LABEL]) {
 check(label+' bootstrap never self-starts; ready/start once only',()=>{
  const m=model(label);assert.equal(m.root.startBootstrap(),'not ready');assert.equal(m.queue.length,0);
  m.root.announceReady();m.root.announceReady();assert.deepEqual(m.logs,['QML_CI_BOOTSTRAP_READY']);
  assert.equal(m.root.startBootstrap(),'started');assert.equal(m.root.startBootstrap(),'already started');assert.equal(m.queue.length,1);
  m.flush();assert.equal(m.ipc.command[4],'4521');assert.equal(m.ipc.command[5],'show');assert.equal(m.root.step,0);
 });
 check(label+' actual response callback completes full planned transport table',()=>{
  const m=model(label);m.root.announceReady();m.root.startBootstrap();m.flush();
  while(!m.root.finished){
   const call=m.root.calls[m.root.step];let text=call.expected;
   if(call.show) text='target qml-ci-bootstrap\n  function start(): string'+(call.empty?'':'\ntarget '+m.root.targetName+'\n  '+m.root.requiredSignature);
   if(call.validator==='status')text=JSON.stringify({ipcVersion:1,settings:{count:3},monitors:['DP-1'],pending:false});
   if(call.validator==='settings')text=JSON.stringify({id:m.root.targetName,privacyFilter:true,eventRefresh:false,refreshOnOpen:false,refreshAfterSettings:false,showTrafficStats:false});
   if(label==='mmw' && call.method==='activate' && call.code===undefined)m.widgetMock.actions.push({id:2,action:'focus'});
   m.exited(call.code===undefined?0:call.code,text);m.flush();
  }
  assert.equal(m.quits,1);const markers=m.logs.filter(value=>!value.startsWith('IPC_TRANSPORT_REPLY_JSON '));assert.equal(markers.length,2);assert(markers[1].endsWith('_QML_IPC_TRANSPORT_OK'));
  assert.equal(m.logs.filter(value=>value.startsWith('IPC_TRANSPORT_REPLY_JSON ')).length,m.root.calls.length);
 });
 for(const fault of ['stderr','wrong-code','wrong-value','wrong-instance'])check(label+' rejects '+fault,()=>{
  const m=model(label);const c=m.root.calls.find(c=>c.code===0);
  if(fault==='stderr')assert.throws(()=>m.root.acceptResponse(c,0,c.expected,'unexpected engine warning'));
  if(fault==='wrong-code')assert.throws(()=>m.root.acceptResponse(c,255,c.expected,''));
  if(fault==='wrong-value')assert.throws(()=>m.root.acceptResponse(c,0,c.expected+'\nextra',''));
  if(fault==='wrong-instance')assert.throws(()=>m.root.acceptResponse(m.root.calls[0],0,'target host-shell\n'+m.root.requiredSignature,''));
  assert.equal(m.quits,0);assert.equal(m.root.step,0);
 });
 check(label+' no initial reload/sleep/global selection substitute',()=>{
  const m=model(label);assert(!/reloadCompleted|setTimeout|sleep|ignoreUnknownSignals|list.*--all/.test(m.source));
  assert(m.source.includes('"--pid", String(Quickshell.processId)'));
  assert.equal((m.source.match(/console.log\("QML_CI_BOOTSTRAP_READY"\)/g)||[]).length,1);
 });
}
if(LABEL==='p2p') check('P2P actual readiness waits for actual store loading and shared service identity',()=>{
 const m=model('p2p');m.widget.durableSettingsLoaded=false;m.root.announceReady();assert.equal(m.logs.length,0);
 m.widget.durableSettingsLoaded=true;m.widget.settingsStoreController.loading=true;m.root.announceReady();assert.equal(m.logs.length,0);
 m.widget.settingsStoreController.loading=false;m.root.announceReady();assert.deepEqual(m.logs,['QML_CI_BOOTSTRAP_READY']);
});
console.log(JSON.stringify({passed:total,kind:'synthetic actual-QML-callback model, no Qt/runtime execution'}));
