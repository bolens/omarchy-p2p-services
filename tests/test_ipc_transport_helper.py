import ast
import contextlib
import io
import json
from pathlib import Path
import runpy
import unittest

BASE=Path(__file__).resolve().parent
HELPER=BASE/'fixtures/ipc-transport-helper'
MODULE=runpy.run_path(str(HELPER),run_name='ipc_helper_contract')
class HelperTests(unittest.TestCase):
    def test_events_only_empty_list(self):
        self.assertEqual(MODULE['response'](['events-list']),'[]')
    def test_settings_object_preserves_unicode_and_values(self):
        value={'privacyFilter':True,'eventRefresh':False,'label':'é/日本語; $(ignored)'}
        self.assertEqual(json.loads(MODULE['response'](['settings-reconcile',json.dumps(value)])),value)
    def test_all_external_operations_rejected(self):
        for operation in ['status','watch','settings-watch','settings-save','settings-patch','events-add','events-clear','catalog','start','stop','install','uninstall','copy-support-report','sh','/bin/sh']:
            with self.subTest(operation=operation),self.assertRaises(ValueError):MODULE['response']([operation])
    def test_bad_arity_json_type_and_size_rejected(self):
        for arguments in [[],['events-list','extra'],['settings-reconcile'],['settings-reconcile','{}','extra'],['settings-reconcile','null'],['settings-reconcile','[]'],['settings-reconcile','bad-json'],['settings-reconcile',' '*65537]]:
            with self.subTest(arguments=arguments[:1]),self.assertRaises((ValueError,TypeError)):MODULE['response'](arguments)
    def test_main_logs_operation_without_payload_then_returns(self):
        records=[];main=MODULE['main'];old=main.__globals__['audit'];main.__globals__['audit']=lambda op,accepted:records.append((op,accepted))
        try:
            stdout=io.StringIO();stderr=io.StringIO()
            with contextlib.redirect_stdout(stdout),contextlib.redirect_stderr(stderr):code=main(['events-list'])
            self.assertEqual(code,0);self.assertEqual(stdout.getvalue(),'[]');self.assertEqual(stderr.getvalue(),'');self.assertEqual(records,[('events-list',True)])
            with contextlib.redirect_stdout(io.StringIO()),contextlib.redirect_stderr(io.StringIO()):code=main(['start','private-data'])
            self.assertEqual(code,64);self.assertEqual(records[-1],('start',False))
        finally:main.__globals__['audit']=old
    def test_no_process_sleep_network_or_dynamic_execution(self):
        source=HELPER.read_text();tree=ast.parse(source)
        self.assertNotIn('sleep',source.replace('sleeps',''))
        for node in ast.walk(tree):
            if isinstance(node,ast.Import):self.assertTrue(all(x.name in {'json','os','stat','sys'}for x in node.names))
            if isinstance(node,ast.Call)and isinstance(node.func,ast.Name):self.assertNotIn(node.func.id,{'eval','exec','compile','__import__'})
        self.assertIn('os.O_NOFOLLOW',source);self.assertIn('info.st_nlink != 1',source)
    def test_transport_remains_registered_once_in_canonical_runner(self):
        import re
        source=(BASE/'run_qml_runtime.sh').read_text()
        calls=re.findall(r'^run_harness (Runtime\w+Test\.qml) (\w+)',source,re.M)
        self.assertEqual(sum(name=='RuntimeIpcTransportTest.qml' for name,_marker in calls),1)
        self.assertIn(('RuntimeIpcTransportTest.qml','P2P_QML_IPC_TRANSPORT_OK'),calls)
if __name__=='__main__':unittest.main()
