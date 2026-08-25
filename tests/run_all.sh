#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$plugin_dir"
# shellcheck source=tests/tooling_env.sh
source "$plugin_dir/tests/tooling_env.sh"
python_bin="$(find_command "${PYTHON_BIN:-}" python3)"
shell_root="$(find_omarchy_shell_root)"

"$python_bin" -m unittest discover -s tests -p '*_test.py'
node tests/model.test.js
node tests/path_utils.test.js
node tests/contracts.test.js
node tests/security.test.js
node tests/release.test.js
node tests/documentation.test.js
node tests/site.test.js
ruby scripts/validate-issue-forms.rb
"$python_bin" -m py_compile p2p-control p2p_*.py
qmllint -I "$shell_root" BarWidget.qml Service.qml P2P*.qml SettingsSurface.qml IntegerSetting.qml Runtime*.qml
qmlformat -n BarWidget.qml Service.qml P2P*.qml SettingsSurface.qml IntegerSetting.qml Runtime*.qml >/dev/null
omarchy plugin validate .
