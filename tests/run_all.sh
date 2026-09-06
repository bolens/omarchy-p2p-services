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
for test_file in tests/*.test.js; do
  node "$test_file"
done
scripts/check-plugin-suite "$plugin_dir"
ruby scripts/validate-issue-forms.rb
"$python_bin" -m py_compile p2p-control backend/*.py scripts/update-screenshot-metadata

if [[ $portable == true ]]; then
  printf 'Portable validation passed; QML tooling and runtime checks skipped.\n'
  exit 0
fi

qmlformat_bin=${QMLFORMAT:-/usr/lib/qt6/bin/qmlformat}
[[ -x "$qmlformat_bin" ]] || { printf 'Qt 6 qmlformat not found: %s\n' "$qmlformat_bin" >&2; exit 1; }
scripts/lint-qml
"$qmlformat_bin" -n Button.qml WidgetButton.qml BarWidget.qml Service.qml P2P*.qml SettingsSurface.qml IntegerSetting.qml tests/qml/Runtime*.qml >/dev/null
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
    if [[ -n ${WAYLAND_DISPLAY:-} && -S "$wayland_socket" ]] \
      && { command -v quickshell >/dev/null || [[ -x "$HOME/.local/opt/quickshell-git/usr/bin/quickshell" ]]; }; then
      tests/run_qml_runtime.sh
    else
      printf 'Runtime QML tests skipped (no usable Wayland session; set P2P_RUNTIME_TESTS=always to require them).\n'
    fi
    ;;
  *) printf 'P2P_RUNTIME_TESTS must be auto, always, or never.\n' >&2; exit 2 ;;
esac
