"""The native QML gate must execute offline as an ordinary container user."""
from pathlib import Path
import subprocess
import os
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeQmlContract(unittest.TestCase):
    def test_runtime_is_mandatory_after_real_static_gate(self):
        script = (ROOT / "scripts/woodpecker-plugin.sh").read_text()
        self.assertIn("scripts/qml-runtime-fixture.py --execute", script)
        if "scripts/lint-qml" in script:
            static_at = script.index("scripts/lint-qml")
        else:
            static_at = script.index("OMARCHY_SKIP_VALIDATE=1 npm test")
            portable = (ROOT / "tests/run_all.sh").read_text()
            if '"$plugin_dir/scripts/lint-qml"' in portable:
                portable = (ROOT / "scripts/lint-qml").read_text()
            self.assertIn('[[ -x "$qmllint_bin" ]] ||', portable)
            self.assertIn('"$qmllint_bin" "${qml_import_args[@]}"', portable)
            self.assertIn("scripts/check-qml-lint-controls.py", portable)
        self.assertLess(static_at, script.index("scripts/qml-runtime-fixture.py --execute"))
        self.assertIn("--prepared-shell \"$OMARCHY_SHELL_ROOT\"", script)
        self.assertIn("--negative-catalog scripts/qml-runtime-warnings.json", script)
        self.assertNotIn("|| true", script)

    def test_offline_nonroot_workflow_preserves_plugin_check(self):
        workflow = (ROOT / ".woodpecker/plugin.yml").read_text()
        self.assertIn("name: prepare", workflow)
        self.assertIn("name: plugin", workflow)
        self.assertIn("user: '10042:10042'", workflow)
        self.assertIn("network_mode: none", workflow)
        self.assertIn("woodpecker-plugin.sh --prepare", workflow)
        self.assertIn("woodpecker-plugin.sh --offline", workflow)
        self.assertNotIn("privileged:", workflow)
        self.assertNotIn("/var/run/docker.sock", workflow)

    def test_preparation_refuses_existing_tree_without_overwriting(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            script = root / "scripts/woodpecker-plugin.sh"
            script.write_bytes((ROOT / "scripts/woodpecker-plugin.sh").read_bytes())
            bindir = root / "bin"
            bindir.mkdir()
            fakegit = bindir / "git"
            fakegit.write_text("#!/bin/sh\nprintf called > \"$NATIVE_TEST_GIT_CALL\"\nexit 91\n")
            fakegit.chmod(0o700)
            prepared = root / ".woodpecker-qml-input"
            prepared.mkdir()
            sentinel = prepared / "preserve"
            sentinel.write_text("unrelated content")
            result = subprocess.run(["bash", str(script), "--prepare"], text=True, capture_output=True, timeout=3,
                                    env={**os.environ, "PATH": str(bindir) + ":/usr/bin:/bin", "NATIVE_TEST_GIT_CALL": str(root / "git-called")})
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((root / "git-called").exists(), "existing input must reject before any Git operation")
            self.assertEqual(sentinel.read_text(), "unrelated content")
            self.assertEqual(sorted(path.name for path in prepared.iterdir()), ["preserve"])

    def test_only_exact_ephemeral_input_is_ignored(self):
        self.assertIn("/.woodpecker-qml-input/", (ROOT / ".gitignore").read_text().splitlines())


if __name__ == "__main__":
    unittest.main()
