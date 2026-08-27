from control_test_support import CONTROL, ROOT, ControlTestCase
from backend.p2p_settings import (
  BAR_PRESENTATIONS, GROUP_COUNT_MODES, GROUP_DIRECTIONS, GROUP_MODES,
  SETTINGS_VERSION, SORT_DIRECTIONS, SORT_MODES,
)


class SettingsIntegrationTests(ControlTestCase):
  def test_manifest_schema_defaults_are_valid_and_consistent(self):
    manifest = __import__("json").loads((ROOT / "manifest.json").read_text())
    widget = manifest["barWidget"]
    defaults = widget["defaults"]
    for entry in widget["schema"]:
      key = entry["key"]
      self.assertIn(key, defaults)
      self.assertEqual(entry["defaultValue"], defaults[key])
      if entry["type"] == "enum": self.assertIn(entry["defaultValue"], entry["options"])
      if entry["type"] in ("integer", "number"):
        self.assertLessEqual(entry["min"], entry["defaultValue"])
        self.assertGreaterEqual(entry["max"], entry["defaultValue"])

  def test_manifest_organization_options_match_runtime_validation(self):
    manifest = __import__("json").loads((ROOT / "manifest.json").read_text())
    schema = {entry["key"]: entry for entry in manifest["barWidget"]["schema"]}
    expected = {
      "serviceSortMode": SORT_MODES, "serviceSortDirection": SORT_DIRECTIONS,
      "serviceGroupMode": GROUP_MODES, "serviceGroupDirection": GROUP_DIRECTIONS,
      "groupCountMode": GROUP_COUNT_MODES, "barPresentation": BAR_PRESENTATIONS,
    }
    for key, values in expected.items():
      with self.subTest(setting=key):
        self.assertEqual(set(schema[key]["options"]), values)

  def test_settings_schema_migrates_clamps_and_removes_unknown_keys(self):
    cleaned = CONTROL.sanitize_settings({
      "refreshSeconds": "not-a-number",
      "compactCards": True,
      "serviceSortMode": "bogus",
      "favoriteServices": ["syncthing", "syncthing", 7],
      "unknownSetting": "discard",
    })
    self.assertEqual(cleaned["refreshSeconds"], 5)
    self.assertTrue(cleaned["compactCards"])
    self.assertEqual(cleaned["serviceSortMode"], "custom")
    self.assertEqual(cleaned["favoriteServices"], ["syncthing"])
    self.assertNotIn("unknownSetting", cleaned)
    self.assertEqual(cleaned["_p2pSettingsVersion"], SETTINGS_VERSION)

  def test_settings_schema_normalizes_nested_service_values(self):
    cleaned = CONTROL.sanitize_settings({
      "serviceLabels": {"syncthing": "Home sync", "bad": {"nested": True}},
      "serviceIcons": {"syncthing": "SYNC", "bad": 7},
      "serviceShowStopped": {"syncthing": False, "bad": "false"},
      "serviceConsoleUrls": {"syncthing": "https://sync.example.test/ui", "bad": "javascript:alert(1)"},
      "serviceNotificationPolicies": {"syncthing": "failures", "bad": "sometimes"},
      "categoryIcons": {"Overlay network": "MESH", "bad": 7},
    })
    self.assertEqual(cleaned["serviceLabels"], {"syncthing": "Home sync"})
    self.assertEqual(cleaned["serviceIcons"], {"syncthing": "SYNC"})
    self.assertEqual(cleaned["serviceShowStopped"], {"syncthing": False})
    self.assertEqual(cleaned["serviceConsoleUrls"], {"syncthing": "https://sync.example.test/ui"})
    self.assertEqual(cleaned["serviceNotificationPolicies"], {"syncthing": "failures"})
    self.assertEqual(cleaned["categoryIcons"], {"Overlay network": "MESH"})

  def test_settings_schema_accepts_extended_sort_controls(self):
    for mode in ("connections", "uptime", "traffic", "backend", "recent", "errors"):
      self.assertEqual(CONTROL.sanitize_settings({"serviceSortMode": mode})["serviceSortMode"], mode)
    self.assertEqual(CONTROL.sanitize_settings({"serviceSortDirection": "descending"})["serviceSortDirection"], "descending")
    self.assertEqual(CONTROL.sanitize_settings({"serviceSortDirection": "sideways"})["serviceSortDirection"], "automatic")
    self.assertFalse(CONTROL.sanitize_settings({"favoritesFirst": False})["favoritesFirst"])
    cleaned = CONTROL.sanitize_settings({"serviceGroupMode": "scope", "serviceGroupDirection": "descending",
      "groupCountMode": "active", "showGroupIcons": False, "runningFirst": True, "stableLiveSort": True,
      "savedViews": [{"name":"Transfers","filter":"running","backend":"docker","sortMode":"traffic","groupMode":"category","groupDirection":"ascending","search":"sync"}, {"name":""}, "bad"]})
    self.assertEqual(cleaned["serviceGroupMode"], "scope")
    self.assertEqual(cleaned["serviceGroupDirection"], "descending")
    self.assertEqual(cleaned["groupCountMode"], "active")
    self.assertFalse(cleaned["showGroupIcons"])
    self.assertTrue(cleaned["runningFirst"])
    self.assertEqual(cleaned["savedViews"], [{"name":"Transfers","filter":"running","backend":"docker","sortMode":"traffic","sortDirection":"automatic","groupMode":"category","groupDirection":"ascending","favoritesFirst":True,"search":"sync"}])

  def test_settings_schema_rejects_unknown_organization_values(self):
    cleaned = CONTROL.sanitize_settings({
      "serviceSortMode":"random", "serviceGroupMode":"protocol",
      "serviceGroupDirection":"sideways", "groupCountMode":"percentage",
      "showGroupIcons":"yes",
      "savedViews":[{"name":"Invalid","groupMode":"protocol","groupDirection":"sideways"}],
    })
    self.assertEqual(cleaned["serviceSortMode"], "custom")
    self.assertEqual(cleaned["serviceGroupMode"], "none")
    self.assertEqual(cleaned["serviceGroupDirection"], "automatic")
    self.assertEqual(cleaned["groupCountMode"], "active-total")
    self.assertTrue(cleaned["showGroupIcons"])
    self.assertEqual(cleaned["savedViews"][0]["groupMode"], "none")
    self.assertEqual(cleaned["savedViews"][0]["groupDirection"], "automatic")

  def test_settings_schema_bounds_visual_and_behavior_customization(self):
    cleaned = CONTROL.sanitize_settings({
      "cardDensity":"minimal", "serviceLayout":"grid", "barPresentation":"active-total", "popupWidth":9999,
      "runningColorRole":"foreground", "errorColorRole":"bogus", "defaultView":"issues",
      "showStatusRail":False, "showBackendBadge":True, "persistCollapsedGroups":True,
      "collapsedServiceGroups":{"RUNNING":True,"bad":"yes"}, "staleWarningSeconds":1,
      "notificationCooldownSeconds":999, "restartWarningThreshold":0,
      "trafficSmoothingSeconds":99, "trafficMinimumBytesPerSecond":-4,
      "barFontSize":99, "barHorizontalMargin":-1, "barVerticalPadding":99,
      "barFixedWidth":999, "barTextRotation":"clockwise",
      "barForegroundColorRole":"muted", "barActiveColorRole":"bogus",
      "barDimWhenIdle":True,
    })
    self.assertEqual(cleaned["cardDensity"], "minimal")
    self.assertEqual(cleaned["serviceLayout"], "grid")
    self.assertEqual(cleaned["barPresentation"], "active-total")
    self.assertEqual(cleaned["popupWidth"], 800)
    self.assertEqual(cleaned["runningColorRole"], "foreground")
    self.assertEqual(cleaned["errorColorRole"], "urgent")
    self.assertEqual(cleaned["defaultView"], "issues")
    self.assertFalse(cleaned["showStatusRail"])
    self.assertEqual(cleaned["collapsedServiceGroups"], {"RUNNING":True})
    self.assertEqual(cleaned["staleWarningSeconds"], 15)
    self.assertEqual(cleaned["notificationCooldownSeconds"], 300)
    self.assertEqual(cleaned["restartWarningThreshold"], 1)
    self.assertEqual(cleaned["trafficSmoothingSeconds"], 30)
    self.assertEqual(cleaned["trafficMinimumBytesPerSecond"], 0)
    self.assertEqual(cleaned["barFontSize"], 28)
    self.assertEqual(cleaned["barHorizontalMargin"], 0)
    self.assertEqual(cleaned["barVerticalPadding"], 16)
    self.assertEqual(cleaned["barFixedWidth"], 240)
    self.assertEqual(cleaned["barTextRotation"], "clockwise")
    self.assertEqual(cleaned["barForegroundColorRole"], "muted")
    self.assertEqual(cleaned["barActiveColorRole"], "accent")
    self.assertTrue(cleaned["barDimWhenIdle"])

  def test_settings_reconciliation_uses_highest_revision(self):
    shell = {"showCount": False, "_p2pRevision": 4}
    durable = {"showCount": True, "_p2pRevision": 3}
    self.assertEqual(CONTROL.reconcile_settings(shell, durable)["showCount"], False)
    self.assertEqual(CONTROL.reconcile_settings(shell, {"showCount": True, "_p2pRevision": 5})["showCount"], True)

  def test_equal_revision_reconciliation_merges_shell_and_durable_settings(self):
    merged = CONTROL.reconcile_settings(
      {"showCount": False, "widgetIcon": "shell", "_p2pRevision": 4},
      {"showCount": True, "popupWidth": 700, "_p2pRevision": 4},
    )
    self.assertTrue(merged["showCount"])
    self.assertEqual(merged["widgetIcon"], "shell")
    self.assertEqual(merged["popupWidth"], 700)
    self.assertEqual(merged["_p2pRevision"], 4)
    self.assertEqual(merged["_p2pSettingsVersion"], SETTINGS_VERSION)
