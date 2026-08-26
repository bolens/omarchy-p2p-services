import os
import pathlib
import re
import subprocess
import tempfile
import textwrap
import unittest


class QmlRuntimeRunnerTests(unittest.TestCase):
  def runtime_entries(self):
    plugin_root = pathlib.Path(__file__).resolve().parents[1]
    return plugin_root, re.findall(
      r"^run_harness (Runtime\S+Test\.qml) (P2P_QML_\S+)",
      (plugin_root / "tests/run_qml_runtime.sh").read_text(),
      re.MULTILINE,
    )

  def test_every_runtime_harness_is_registered(self):
    plugin_root = pathlib.Path(__file__).resolve().parents[1]
    harnesses = {path.name for path in plugin_root.glob("Runtime*Test.qml")}
    registered = set(re.findall(
      r"^run_harness (Runtime\S+Test\.qml) ",
      (plugin_root / "tests/run_qml_runtime.sh").read_text(),
      re.MULTILINE,
    ))
    self.assertEqual(registered, harnesses)

  def test_runtime_harnesses_are_registered_once(self):
    _, entries = self.runtime_entries()
    harnesses = [harness for harness, _ in entries]
    self.assertEqual(len(harnesses), len(set(harnesses)))

  def test_runtime_success_markers_are_unique(self):
    _, entries = self.runtime_entries()
    markers = [marker for _, marker in entries]
    self.assertEqual(len(markers), len(set(markers)))

  def test_registered_marker_is_emitted_by_its_harness(self):
    plugin_root, entries = self.runtime_entries()
    mismatches = [
      f"{harness}: {marker}"
      for harness, marker in entries
      if not re.search(rf"(?<![A-Z0-9_]){re.escape(marker)}(?![A-Z0-9_])", (plugin_root / harness).read_text())
    ]
    self.assertEqual(mismatches, [])

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
        file=
        for argument do file=$argument; done
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

  def test_success_marker_does_not_mask_process_start_failure(self):
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
        printf '%s\n' 'WARN: Process failed to start, likely because the binary could not be found.'
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
      self.assertIn("runtime failure warning", result.stderr)

  def test_success_marker_does_not_mask_premature_engine_quit(self):
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
        printf '%s\n' 'WARN: Signal QQmlEngine::quit() emitted, but no receivers connected to handle it.'
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
      self.assertIn("runtime failure warning", result.stderr)

  def test_success_marker_does_not_mask_incompatible_assignment(self):
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
        printf '%s\n' 'WARN scene: @Header.qml[4:2]: Unable to assign null to QColor'
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

  def test_success_marker_does_not_mask_recursive_layout(self):
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
        printf '%s\n' 'WARN scene: Qt Quick Layouts: Detected recursive rearrange. Aborting after two iterations.'
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

  def test_success_marker_does_not_mask_polish_loop(self):
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
        printf '%s\n' 'WARN qt.quick: possible QQuickItem::polish() loop'
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


if __name__ == "__main__":
  unittest.main()
