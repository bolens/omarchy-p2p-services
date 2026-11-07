'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const BASE=path.join(__dirname,'..'),source=fs.readFileSync(path.join(BASE,'P2PIpcHub.qml'),'utf8');
function model(){
 const service={},hub={serviceIdentity:service,targetName:'io.github.bolens.p2p-services',entries:[],nextLease:0,routingError:''};
 const context=vm.createContext({hub});
 for(const m of source.matchAll(/^    function (\w+)\([^]*?^    }/gm)){vm.runInContext(m[0],context);hub[m[1]]=context[m[1]];}
 let focus=null;
 function widget(key,privacy){return {moduleName:hub.targetName,p2pService:service,privacyFilter:privacy,key,ipcFocusedPanel(){return focus;},captureContractVersion(){return '2';},focusedPanelClosed(){return true;}};}
 return {hub,service,widget,focus(value){focus=value;},register(w){return hub.registerWidget(w,w.moduleName,service,w.key);}};
}
let passed=0;function test(name,body){body();passed++;console.log('PASS '+name);}
test('actual functions reject wrong module or service identity',()=>{const m=model(),a=m.widget('A',true);assert.equal(m.hub.registerWidget(a,'other',m.service,'A'),0);assert.equal(m.hub.registerWidget(a,a.moduleName,{},'A'),0);assert.equal(m.hub.entries.length,0);});
test('idempotent registration keeps one member and lease',()=>{const m=model(),a=m.widget('A',true),first=m.register(a);assert.equal(m.hub.registerWidget(a,a.moduleName,m.service,'renamed'),first);assert.equal(m.hub.entries.length,1);assert.equal(m.hub.entries[0].widget,a);});
test('explicit focus wins with reverse construction/registration order',()=>{const m=model(),a=m.widget('A',true),b=m.widget('B',false);m.register(b);m.register(a);m.focus(a);assert.equal(m.hub.dispatch('privacyEnabled',[]),'true');m.focus(b);assert.equal(m.hub.dispatch('privacyEnabled',[]),'false');});
test('widget disposal leaves sole surviving member with stable dispatch',()=>{const m=model(),a=m.widget('A',true),b=m.widget('B',false);const lb=m.register(b),la=m.register(a);m.focus(b);assert.equal(m.hub.unregisterWidget(a,la),true);assert.equal(m.hub.entries.length,1);assert.equal(m.hub.dispatch('privacyEnabled',[]),'false');m.hub.unregisterWidget(b,lb);assert.equal(m.hub.entries.length,0);});
test('stale destruction lease cannot remove a re-registered member',()=>{const m=model(),a=m.widget('A',true),old=m.register(a);m.hub.unregisterWidget(a,old);const fresh=m.register(a);assert(fresh>old);assert.equal(m.hub.unregisterWidget(a,old),false);assert.equal(m.hub.entries.length,1);});
test('foreign focus result is refused even with same module/service',()=>{const m=model(),a=m.widget('A',true),foreign=m.widget('foreign',false);m.register(a);m.focus(foreign);assert.equal(m.hub.dispatch('privacyEnabled',[]),'false');assert.equal(m.hub.routingError,'foreign focus result');});
test('conflicting focus capabilities fail closed',()=>{const m=model(),a=m.widget('A',true),b=m.widget('B',false);a.ipcFocusedPanel=()=>a;b.ipcFocusedPanel=()=>b;m.register(a);m.register(b);assert.equal(m.hub.focusedWidget(),null);});
test('multiple members without a focus resolver fail closed in either registration order',()=>{for(const reverse of [false,true]){const m=model(),a=m.widget('DP-1',true),b=m.widget('DP-2',false);(reverse?[b,a]:[a,b]).forEach(w=>m.register(w));assert.equal(m.hub.focusedWidget(),null);}});
test('legacy missing or duplicate key never chooses first-created',()=>{for(const keys of [['',''],['DP-1','DP-1']]){const m=model();m.register(m.widget(keys[0],true));m.register(m.widget(keys[1],false));assert.equal(m.hub.focusedWidget(),null);assert.equal(m.hub.dispatch('captureContract',[]),'2');}});
test('changed module/service member excluded from routing',()=>{const m=model(),a=m.widget('A',true);m.register(a);a.p2pService={};assert.equal(m.hub.focusedWidget(),null);});
test('bounded lease counter never wraps into stale ownership',()=>{const m=model();m.hub.nextLease=2147483647;assert.equal(m.register(m.widget('A',true)),0);assert.equal(m.hub.entries.length,0);});
test('one physical handler is Service-owned and zero widget-local handlers remain',()=>{
 const service=fs.readFileSync(path.join(BASE,'Service.qml'),'utf8'),widget=fs.readFileSync(path.join(BASE,'BarWidget.qml'),'utf8');
 assert.equal((source.match(/property IpcHandler handler: IpcHandler/g)||[]).length,1);assert(source.includes('enabled: hub.widgetCount > 0'));
 assert(service.includes('readonly property P2PIpcHub ipcHub: P2PIpcHub { serviceIdentity: root }'));assert(!widget.includes('  IpcHandler {'));
 assert(widget.includes('root.registeredIpcHub.unregisterWidget(root, root.ipcLease)'));assert(!widget.includes('ipcRoutingKey'));assert(!widget.includes('QsWindow.window'));assert(!widget.includes('Quickshell.Hyprland'));
});
test('transport extension preserves original connected0/strings/reply/bootstrap assertions',()=>{
 const next=fs.readFileSync(path.join(BASE,'tests/qml/RuntimeIpcTransportTest.qml'),'utf8');
 for(const text of ['{method:"__ci_missing__",args:[],code:0,expected:"Function not found."}','Function definition: function captureContract(): string','IPC_TRANSPORT_REPLY_JSON','QML_CI_BOOTSTRAP_READY','"--pid", String(Quickshell.processId)','interval: 4000'])assert(next.includes(text));
 assert(next.indexOf('root.widgetB = memberFactory.createObject')<next.indexOf('root.widget = memberFactory.createObject'));
 for(const text of ['root.widget.destroy()','root.widgetB.destroy()','root.disposedA && sharedMock.ipcHub.widgetCount === 1','root.disposedB && sharedMock.ipcHub.widgetCount === 0','sharedMock.ipcHub.handler === root.stableHandler'])assert(next.includes(text));
});
console.log(JSON.stringify({passed,kind:'pure actual-Hub-function/source contracts; no Qt runtime'}));
