"""Pure dispatch tests; no Qt, IPC or desktop execution."""
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

PATH = Path(__file__).resolve().parents[1] / "scripts/run-qml-ipc-harness.py"
SPEC = importlib.util.spec_from_file_location("ipc_adapter", PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AdapterTests(unittest.TestCase):
    def invoke(self, label="p2p", accepted=True, audit_error=False, wrong_target=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "tests/qml").mkdir(parents=True)
            target = root / "tests/qml/RuntimeIpcTransportTest.qml"
            target.write_text("fixture")
            (root / "scripts").mkdir()
            (root / "scripts/qml-runtime-warnings.json").write_text(json.dumps({}))
            link = root / "RuntimeIpcTransportTest.qml"
            link.symlink_to(target if not wrong_target else root / "unknown.qml")
            gate = Mock()
            gate.BOOTSTRAP_CASES = {(label, link.name)}
            gate.canonical_contract.return_value = [{"file": link.name, "marker": "EXACT_OK", "deadline": 4 if label == "p2p" else 8}]
            gate.run_harness.return_value = {"accepted": accepted, "stdout_stderr": "raw"}
            gate.warning_assessment.return_value = True
            if audit_error:
                gate.fixture_helper_audit.side_effect = ValueError("missing operation")
            with patch.dict(os.environ, {"XDG_RUNTIME_DIR": str(root / "display"), "WAYLAND_DISPLAY": "wayland-1"}):
                result = MODULE.execute(gate, root, label, link, "/exact/quickshell")
            if wrong_target:
                self.fail("wrong target was accepted")
            args, kwargs = gate.run_harness.call_args
            self.assertEqual(args[0], link)
            self.assertEqual(args[1], "EXACT_OK")
            self.assertEqual(args[4], 4 if label == "p2p" else 8)
            self.assertTrue(kwargs["bootstrap_required"])
            self.assertEqual(kwargs["quickshell"], "/exact/quickshell")
            self.assertNotEqual(args[3]["XDG_RUNTIME_DIR"], str(root / "display"))
            self.assertFalse(Path(args[3]["XDG_RUNTIME_DIR"]).exists())
            self.assertEqual(args[3]["WAYLAND_DISPLAY"], str(root / "display/wayland-1"))
            self.assertEqual(gate.fixture_helper_audit.call_count, int(label == "p2p"))
            return result

    def test_two_canonical_cases_keep_exact_limits_bootstrap_and_private_runtime(self):
        for label in ("p2p", "mmw"):
            self.assertTrue(self.invoke(label)["accepted"])

    def test_public_rejection_stays_rejected(self):
        self.assertFalse(self.invoke(accepted=False)["accepted"])

    def test_missing_or_unsafe_helper_audit_fails(self):
        self.assertFalse(self.invoke(audit_error=True)["accepted"])

    def test_foreign_source_fails_before_execution(self):
        with self.assertRaises(AssertionError):
            self.invoke(wrong_target=True)


if __name__ == "__main__":
    unittest.main()
