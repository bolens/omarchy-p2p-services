#!/usr/bin/env bash
set -euo pipefail

plugin_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$plugin_dir/tests/tooling_env.sh"
quickshell_bin="$(find_command "${QUICKSHELL_BIN:-}" quickshell "$HOME/.local/opt/quickshell-git/usr/bin/quickshell")"
shell_root="$(find_omarchy_shell_root)"
runtime_dir="$(mktemp -d)"
trap 'rm -rf -- "$runtime_dir"' EXIT

find "$plugin_dir" -maxdepth 1 -type f -exec ln -s -- '{}' "$runtime_dir/" \;
ln -s -- "$plugin_dir/tests" "$runtime_dir/tests"
ln -s -- "$shell_root/Commons" "$runtime_dir/Commons"
ln -s -- "$shell_root/Ui" "$runtime_dir/Ui"

run_harness() {
  local file=$1 marker=$2 limit=${3:-4} output status
  set +e
  output="$(timeout "$limit" "$quickshell_bin" --no-color --path "$runtime_dir/$file" 2>&1)"
  status=$?
  set -e
  if [[ $status -ne 0 && $status -ne 124 ]]; then
    printf '%s\n' "$output" >&2
    exit "$status"
  fi
  if ! grep -q "$marker" <<<"$output"; then
    printf 'QML runtime harness %s did not emit %s\n%s\n' "$file" "$marker" "$output" >&2
    return 1
  fi
}

run_harness RuntimeModelTest.qml P2P_QML_RUNTIME_OK
run_harness RuntimeNavigationTest.qml P2P_QML_NAVIGATION_OK
run_harness RuntimeRefreshTest.qml P2P_QML_REFRESH_OK
run_harness RuntimeOrganizationTest.qml P2P_QML_ORGANIZATION_OK
run_harness RuntimeSettingsTest.qml P2P_QML_SETTINGS_OK
run_harness RuntimeAppearanceTest.qml P2P_QML_APPEARANCE_OK
run_harness RuntimeGroupHeaderTest.qml P2P_QML_GROUP_HEADER_OK
run_harness RuntimeSavedViewsTest.qml P2P_QML_SAVED_VIEWS_OK
run_harness RuntimeSettingsStoreTest.qml P2P_QML_SETTINGS_STORE_OK
run_harness RuntimeServiceEditorTest.qml P2P_QML_SERVICE_EDITOR_OK
run_harness RuntimeServiceActionsTest.qml P2P_QML_SERVICE_ACTIONS_OK
run_harness RuntimeSettingsNavigationTest.qml P2P_QML_SETTINGS_NAVIGATION_OK
run_harness RuntimeServiceCardTest.qml P2P_QML_SERVICE_CARD_OK
run_harness RuntimeFilterBarTest.qml P2P_QML_FILTER_BAR_OK
run_harness RuntimeHeaderTest.qml P2P_QML_HEADER_OK
run_harness RuntimeMessageSurfaceTest.qml P2P_QML_MESSAGE_SURFACE_OK
run_harness RuntimeSettingsControlsTest.qml P2P_QML_SETTINGS_CONTROLS_OK
run_harness RuntimeSettingsStoreIoTest.qml P2P_QML_SETTINGS_STORE_IO_OK
run_harness RuntimeRefreshFailureTest.qml P2P_QML_REFRESH_FAILURE_OK
run_harness RuntimeServiceListTest.qml P2P_QML_SERVICE_LIST_OK
run_harness RuntimeDiscoverySettingsTest.qml P2P_QML_DISCOVERY_SETTINGS_OK
run_harness RuntimeGeneralSettingsTest.qml P2P_QML_GENERAL_SETTINGS_OK
run_harness RuntimePackagesSettingsTest.qml P2P_QML_PACKAGES_SETTINGS_OK
run_harness RuntimeServiceLifecycleTest.qml P2P_QML_SERVICE_LIFECYCLE_OK
run_harness RuntimeSettingsResetTest.qml P2P_QML_SETTINGS_RESET_OK
run_harness RuntimeSettingsTransferTest.qml P2P_QML_SETTINGS_TRANSFER_OK
run_harness RuntimeActionRunnerTest.qml P2P_QML_ACTION_RUNNER_OK
run_harness RuntimeDeferredRefreshTest.qml P2P_QML_DEFERRED_REFRESH_OK
run_harness RuntimeConfirmationTest.qml P2P_QML_CONFIRMATION_OK
run_harness RuntimeCatalogControllerTest.qml P2P_QML_CATALOG_CONTROLLER_OK
run_harness RuntimeSettingsTransferResultTest.qml P2P_QML_SETTINGS_TRANSFER_RESULT_OK
run_harness RuntimePluginSmokeTest.qml P2P_QML_PLUGIN_SMOKE_OK 7
run_harness RuntimeWatcherIntegrationTest.qml P2P_QML_WATCHER_INTEGRATION_OK
run_harness RuntimeWatcherDisableTest.qml P2P_QML_WATCHER_DISABLE_OK
run_harness RuntimeWatcherPollingTest.qml P2P_QML_WATCHER_POLLING_OK
run_harness RuntimeLoadingIndicatorTest.qml P2P_QML_LOADING_INDICATOR_OK
run_harness RuntimeServiceLoadingTest.qml P2P_QML_SERVICE_LOADING_OK
run_harness RuntimeSettingsLoadingFailureTest.qml P2P_QML_SETTINGS_LOADING_FAILURE_OK
run_harness RuntimeMinimumLoadingStateTest.qml P2P_QML_MINIMUM_LOADING_STATE_OK
run_harness RuntimeProcessTimeoutTest.qml P2P_QML_PROCESS_TIMEOUT_OK
run_harness RuntimeEventJournalTest.qml P2P_QML_EVENT_JOURNAL_OK
