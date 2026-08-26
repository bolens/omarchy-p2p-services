import os
import pathlib
import re
import subprocess
import tempfile
import textwrap
import unittest


class QmlRuntimeRunnerTests(unittest.TestCase):
  def test_every_runtime_harness_is_registered(self):
    plugin_root = pathlib.Path(__file__).resolve().parents[1]
    harnesses = {path.name for path in plugin_root.glob("Runtime*Test.qml")}
    registered = set(re.findall(
      r"^run_harness (Runtime\S+Test\.qml) ",
      (plugin_root / "tests/run_qml_runtime.sh").read_text(),
      re.MULTILINE,
    ))
    self.assertEqual(registered, harnesses)

  def test_requested_harnesses_run_without_the_full_matrix(self):
    plugin_root = pathlib.Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      shell_root = root / "shell"
      (shell_root / "Commons").mkdir(parents=True)
      (shell_root / "Ui").mkdir()
      trace = root / "trace"
      quickshell = root / "quickshell"
      quickshell.write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        file=${@: -1}
        name=${file##*/}
        printf '%s\n' "$name" >> "$QML_FAKE_TRACE"
        case "$name" in
          RuntimeHeaderTest.qml) printf '%s\n' P2P_QML_HEADER_OK ;;
          RuntimeFilterBarTest.qml) printf '%s\n' P2P_QML_FILTER_BAR_OK ;;
        esac
      """))
      quickshell.chmod(0o755)
      env = os.environ | {
        "OMARCHY_SHELL_ROOT": str(shell_root),
        "QUICKSHELL_BIN": str(quickshell),
        "QML_FAKE_TRACE": str(trace),
      }
      result = subprocess.run(
        [plugin_root / "tests/run_qml_runtime.sh", "RuntimeHeaderTest.qml", "RuntimeFilterBarTest.qml"],
        cwd=plugin_root,
        env=env,
        capture_output=True,
        text=True,
      )
      self.assertEqual(result.returncode, 0, result.stderr + "\ntrace=" + (trace.read_text() if trace.exists() else "missing"))
      self.assertEqual(trace.read_text().splitlines(), ["RuntimeFilterBarTest.qml", "RuntimeHeaderTest.qml"])

  def test_unknown_harness_is_rejected(self):
    plugin_root = pathlib.Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      shell_root = root / "shell"
      (shell_root / "Commons").mkdir(parents=True)
      (shell_root / "Ui").mkdir()
      quickshell = root / "quickshell"
      quickshell.write_text("#!/usr/bin/env bash\nexit 0\n")
      quickshell.chmod(0o755)
      env = os.environ | {"OMARCHY_SHELL_ROOT": str(shell_root), "QUICKSHELL_BIN": str(quickshell)}
      result = subprocess.run(
        [plugin_root / "tests/run_qml_runtime.sh", "RuntimeMissingTest.qml"],
        cwd=plugin_root,
        env=env,
        capture_output=True,
        text=True,
      )
      self.assertEqual(result.returncode, 2)
      self.assertIn("Unknown QML runtime harness", result.stderr)

  def test_success_marker_does_not_mask_runtime_warnings(self):
    plugin_root = pathlib.Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      shell_root = root / "shell"
      (shell_root / "Commons").mkdir(parents=True)
      (shell_root / "Ui").mkdir()
      quickshell = root / "quickshell"
      quickshell.write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        printf '%s\n' P2P_QML_HEADER_OK
        printf '%s\n' 'WARN scene: @Header.qml: Binding loop detected for property "width"'
      """))
      quickshell.chmod(0o755)
      env = os.environ | {"OMARCHY_SHELL_ROOT": str(shell_root), "QUICKSHELL_BIN": str(quickshell)}
      result = subprocess.run(
        [plugin_root / "tests/run_qml_runtime.sh", "RuntimeHeaderTest.qml"],
        cwd=plugin_root,
        env=env,
        capture_output=True,
        text=True,
      )
      self.assertEqual(result.returncode, 1)
      self.assertIn("runtime exception or binding loop", result.stderr)

  def test_success_marker_does_not_mask_generic_qml_error(self):
    plugin_root = pathlib.Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      shell_root = root / "shell"
      (shell_root / "Commons").mkdir(parents=True)
      (shell_root / "Ui").mkdir()
      quickshell = root / "quickshell"
      quickshell.write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        printf '%s\n' P2P_QML_HEADER_OK
        printf '%s\n' 'WARN scene: @Header.qml[12:4]: Error: component callback failed'
      """))
      quickshell.chmod(0o755)
      env = os.environ | {"OMARCHY_SHELL_ROOT": str(shell_root), "QUICKSHELL_BIN": str(quickshell)}
      result = subprocess.run(
        [plugin_root / "tests/run_qml_runtime.sh", "RuntimeHeaderTest.qml"],
        cwd=plugin_root,
        env=env,
        capture_output=True,
        text=True,
      )
      self.assertEqual(result.returncode, 1)
      self.assertIn("runtime exception or binding loop", result.stderr)

  def test_success_marker_does_not_mask_harness_timeout(self):
    plugin_root = pathlib.Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      shell_root = root / "shell"
      (shell_root / "Commons").mkdir(parents=True)
      (shell_root / "Ui").mkdir()
      quickshell = root / "quickshell"
      quickshell.write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        printf '%s\n' P2P_QML_HEADER_OK
        sleep 0.2
      """))
      quickshell.chmod(0o755)
      env = os.environ | {
        "OMARCHY_SHELL_ROOT": str(shell_root),
        "QUICKSHELL_BIN": str(quickshell),
        "QML_RUNTIME_LIMIT": "0.05",
      }
      result = subprocess.run(
        [plugin_root / "tests/run_qml_runtime.sh", "RuntimeHeaderTest.qml"],
        cwd=plugin_root,
        env=env,
        capture_output=True,
        text=True,
      )
      self.assertEqual(result.returncode, 1)
      self.assertIn("timed out", result.stderr)

  def test_success_marker_must_be_a_complete_log_token(self):
    plugin_root = pathlib.Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory() as directory:
      root = pathlib.Path(directory)
      shell_root = root / "shell"
      (shell_root / "Commons").mkdir(parents=True)
      (shell_root / "Ui").mkdir()
      quickshell = root / "quickshell"
      quickshell.write_text("#!/usr/bin/env bash\nprintf '%s\\n' NOT_P2P_QML_HEADER_OK_SUFFIX\n")
      quickshell.chmod(0o755)
      env = os.environ | {"OMARCHY_SHELL_ROOT": str(shell_root), "QUICKSHELL_BIN": str(quickshell)}
      result = subprocess.run(
        [plugin_root / "tests/run_qml_runtime.sh", "RuntimeHeaderTest.qml"],
        cwd=plugin_root,
        env=env,
        capture_output=True,
        text=True,
      )
      self.assertEqual(result.returncode, 1)
      self.assertIn("did not emit P2P_QML_HEADER_OK", result.stderr)


if __name__ == "__main__":
  unittest.main()
