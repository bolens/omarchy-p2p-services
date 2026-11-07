#!/usr/bin/env python3
"""Legacy manual entrypoint for the canonical owned IPC bootstrap case only."""
import argparse
import importlib.util
import json
import os
import tempfile
from pathlib import Path


def load_gate(checkout):
    spec = importlib.util.spec_from_file_location("qml_public_runtime", checkout / "scripts/qml-runtime-fixture.py")
    gate = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gate)
    return gate


def execute(gate, checkout, label, path, quickshell):
    canonical = [row for row in gate.canonical_contract(checkout, label)
                 if row["file"] == "RuntimeIpcTransportTest.qml"]
    assert len(canonical) == 1
    row = canonical[0]
    assert path.name == row["file"] and path.is_symlink()
    assert path.resolve() == (checkout / "tests/qml" / row["file"]).resolve()
    assert (label, row["file"]) in gate.BOOTSTRAP_CASES
    with tempfile.TemporaryDirectory(prefix="qml-owned-ipc-run-") as temporary:
        runtime = Path(temporary)
        runtime.chmod(0o700)
        (runtime / "quickshell").mkdir(mode=0o700)
        environment = dict(os.environ, XDG_RUNTIME_DIR=str(runtime))
        # Preserve the caller's existing display while isolating this case's IPC.
        display = os.environ.get("WAYLAND_DISPLAY", "")
        if display and not Path(display).is_absolute():
            original_runtime = os.environ.get("XDG_RUNTIME_DIR")
            if not original_runtime:
                raise ValueError("Relative Wayland display requires the original runtime directory")
            environment["WAYLAND_DISPLAY"] = str(Path(original_runtime) / display)
        result = gate.run_harness(path, row["marker"], checkout, environment,
                                  row["deadline"], quickshell=quickshell,
                                  bootstrap_required=True)
        result["warnings_accepted"] = gate.warning_assessment(
            result["stdout_stderr"], checkout, label, row["file"],
            json.loads((checkout / "scripts/qml-runtime-warnings.json").read_text()))
        result["accepted"] &= result["warnings_accepted"]
        if label == "p2p":
            try:
                result["fixture_helper_audit"] = gate.fixture_helper_audit(runtime / "qml-ipc-helper-audit.jsonl")
            except (OSError, ValueError, AssertionError) as error:
                result["fixture_helper_audit_error"] = str(error) or type(error).__name__
                result["accepted"] = False
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", choices=("p2p", "mmw"), required=True)
    parser.add_argument("--harness", type=Path, required=True)
    parser.add_argument("--quickshell", required=True)
    args = parser.parse_args()
    checkout = Path(__file__).resolve().parents[1]
    result = execute(load_gate(checkout), checkout, args.repository,
                     args.harness.absolute(), args.quickshell)
    print(json.dumps(result))
    raise SystemExit(0 if result["accepted"] else 1)


if __name__ == "__main__":
    main()
