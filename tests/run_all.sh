#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$plugin_dir"
portable=false
if [[ ${1:-} == --portable ]]; then portable=true; shift; fi
[[ $# -eq 0 ]] || { printf 'Usage: tests/run_all.sh [--portable]\n' >&2; exit 2; }
# shellcheck disable=SC1091
source "$plugin_dir/tests/tooling_env.sh"
python_bin="$(find_command "${PYTHON_BIN:-}" python3)"

"$python_bin" -m unittest discover -s tests -p '*_test.py'
node tests/model.test.js
node tests/path_utils.test.js
node tests/contracts.test.js
node tests/security.test.js
node tests/release.test.js
node tests/documentation.test.js
node tests/site.test.js
node tests/site_build.test.js
node tests/validation.test.js
node tests/capture_transaction.test.js
node tests/capture_recovery.test.js
node tests/capture_fingerprint.test.js
node tests/capture_monitor.test.js
node tests/capture_safety.test.js
node tests/fleet_hardening.test.js
scripts/check-plugin-suite "$plugin_dir"
ruby scripts/validate-issue-forms.rb
"$python_bin" -m py_compile p2p-control backend/*.py scripts/update-screenshot-metadata

if [[ $portable == true ]]; then
  printf 'Portable validation passed; QML tooling and runtime checks skipped.\n'
  exit 0
fi

shell_root="$(find_omarchy_shell_root)"
qmllint -I "$shell_root" -I . Button.qml WidgetButton.qml BarWidget.qml Service.qml P2P*.qml SettingsSurface.qml IntegerSetting.qml tests/qml/Runtime*.qml
qmlformat -n Button.qml WidgetButton.qml BarWidget.qml Service.qml P2P*.qml SettingsSurface.qml IntegerSetting.qml tests/qml/Runtime*.qml >/dev/null
validation_dir=$(mktemp -d)
trap 'rm -rf -- "$validation_dir"' EXIT
git archive HEAD | tar -x -C "$validation_dir"
omarchy plugin validate "$validation_dir"
rm -rf -- "$validation_dir"
trap - EXIT

runtime_mode=${P2P_RUNTIME_TESTS:-auto}
case "$runtime_mode" in
  always) tests/run_qml_runtime.sh ;;
  never) printf 'Runtime QML tests skipped (P2P_RUNTIME_TESTS=never).\n' ;;
  auto)
    wayland_socket=${XDG_RUNTIME_DIR:-}/${WAYLAND_DISPLAY:-}
    if [[ -n ${WAYLAND_DISPLAY:-} && -S $wayland_socket ]] \
      && { command -v quickshell >/dev/null || [[ -x $HOME/.local/opt/quickshell-git/usr/bin/quickshell ]]; }; then
      tests/run_qml_runtime.sh
    else
      printf 'Runtime QML tests skipped (no usable Wayland session; set P2P_RUNTIME_TESTS=always to require them).\n'
    fi
    ;;
  *) printf 'P2P_RUNTIME_TESTS must be auto, always, or never.\n' >&2; exit 2 ;;
esac
