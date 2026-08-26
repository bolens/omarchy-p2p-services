"""Versioned validation and reconciliation for P2P plugin settings."""

import json
import pathlib
import re

from p2p_validation import safe_http_url

SETTINGS_VERSION = 1
PLUGIN_DEFAULTS = json.loads((pathlib.Path(__file__).parent / "manifest.json").read_text())["barWidget"]["defaults"]

BOOLEAN_KEYS = {key: PLUGIN_DEFAULTS[key] for key in (
  "privacyFilter", "showStopped", "showCount", "notifyOnControlChanges",
  "autoStartAfterInstall", "showTrafficStats", "compactCards", "eventRefresh",
  "favoritesFirst", "runningFirst", "stableLiveSort", "showStatusRail",
  "showFavoriteMarker", "showBackendBadge", "showCardSummary", "showQuickActions",
  "showGroupCounts", "compactHeader", "hideZeroCount", "persistCollapsedGroups",
  "refreshOnOpen", "refreshAfterSettings", "refreshAfterActions",
  "notifyUnexpectedStops", "notifyRecovery", "notifyUnhealthy",
  "notifyRestartEvents", "barDimWhenIdle",
  "showGroupIcons", "enableEventJournal",
)}
INTEGER_KEYS = {
  "refreshSeconds": (2, 60), "backgroundRefreshSeconds": (15, 300),
  "reconcileSeconds": (30, 600), "popupMaxHeight": (360, 900),
  "backupRetention": (1, 50), "popupWidth": (420, 800),
  "staleWarningSeconds": (15, 600), "notificationCooldownSeconds": (0, 300),
  "restartWarningThreshold": (1, 100), "trafficSmoothingSeconds": (1, 30),
  "trafficMinimumBytesPerSecond": (0, 10485760), "barFontSize": (8, 28),
  "barHorizontalMargin": (0, 24), "barVerticalPadding": (0, 16),
  "barFixedWidth": (0, 240),
  "eventJournalLimit": (5, 100),
}
INTEGER_KEYS = {key: (bounds[0], bounds[1], PLUGIN_DEFAULTS[key]) for key, bounds in INTEGER_KEYS.items()}
STRING_KEYS = {key: PLUGIN_DEFAULTS[key] for key in ("widgetIcon", "consoleHost", "defaultSavedView")}
LIST_KEYS = {"enabledServices", "favoriteServices", "serviceOrder"}
MAP_KEYS = {
  "serviceLabels", "serviceIcons", "serviceShowStopped", "serviceConsoleUrls",
  "serviceNotificationPolicies",
  "categoryIcons",
}
SORT_MODES = {"custom", "name", "category", "status", "activity", "connections", "uptime", "traffic", "backend", "recent", "errors"}
SORT_DIRECTIONS = {"automatic", "ascending", "descending"}
GROUP_MODES = {"none", "status", "backend", "category", "scope", "favorite"}
GROUP_DIRECTIONS = {"automatic", "ascending", "descending"}
GROUP_COUNT_MODES = {"active-total", "active", "total"}
VIEW_FILTERS = {"all", "running", "stopped", "issues"}
CARD_DENSITIES = {"comfortable", "compact", "minimal"}
SERVICE_LAYOUTS = {"list", "grid"}
BAR_PRESENTATIONS = {"icon", "active", "active-total", "health", "category-active", "category-active-total"}
BAR_TEXT_ROTATIONS = {"normal", "clockwise", "counterclockwise"}
THEME_ROLES = {"bar-active", "urgent", "accent", "foreground", "muted"}
GROUP_HEADER_STYLES = {"surfaced", "dense"}
NOTIFICATION_POLICIES = {"inherit", "always", "failures", "silent"}


def _revision(value):
  try: return max(0, int(value))
  except (TypeError, ValueError): return 0


def _sanitize_map(key, values):
  clean = {}
  for raw_key, value in list(values.items())[:256]:
    if not isinstance(raw_key, str) or not raw_key: continue
    item_key = raw_key[:64]
    if key == "serviceShowStopped" and isinstance(value, bool): clean[item_key] = value
    elif key == "serviceNotificationPolicies" and value in NOTIFICATION_POLICIES: clean[item_key] = value
    elif key == "serviceConsoleUrls":
      url = safe_http_url(value)
      if url: clean[item_key] = url
    elif key == "serviceLabels" and isinstance(value, str) and value.strip(): clean[item_key] = value.strip()[:128]
    elif key in ("serviceIcons", "categoryIcons") and isinstance(value, str) and value.strip(): clean[item_key] = value.strip()[:16]
  return clean


def sanitize_settings(data):
  source = data if isinstance(data, dict) else {}
  clean = {}
  for key, default in BOOLEAN_KEYS.items():
    if key in source: clean[key] = source[key] if isinstance(source[key], bool) else default
  for key, (minimum, maximum, default) in INTEGER_KEYS.items():
    if key in source:
      try: value = int(source[key])
      except (TypeError, ValueError): value = default
      clean[key] = max(minimum, min(maximum, value))
  for key, default in STRING_KEYS.items():
    if key in source: clean[key] = str(source[key])[:512] if source[key] is not None else default
  for key in LIST_KEYS:
    if key in source and isinstance(source[key], list):
      clean[key] = list(dict.fromkeys(value for value in source[key][:256] if isinstance(value, str) and value))
  for key in MAP_KEYS:
    if key in source and isinstance(source[key], dict):
      clean[key] = _sanitize_map(key, source[key])
  if "customServices" in source and isinstance(source["customServices"], list): clean["customServices"] = source["customServices"][:32]
  if "serviceSortMode" in source: clean["serviceSortMode"] = source["serviceSortMode"] if source["serviceSortMode"] in SORT_MODES else PLUGIN_DEFAULTS["serviceSortMode"]
  if "serviceSortDirection" in source: clean["serviceSortDirection"] = source["serviceSortDirection"] if source["serviceSortDirection"] in SORT_DIRECTIONS else PLUGIN_DEFAULTS["serviceSortDirection"]
  if "serviceGroupMode" in source: clean["serviceGroupMode"] = source["serviceGroupMode"] if source["serviceGroupMode"] in GROUP_MODES else PLUGIN_DEFAULTS["serviceGroupMode"]
  if "serviceGroupDirection" in source: clean["serviceGroupDirection"] = source["serviceGroupDirection"] if source["serviceGroupDirection"] in GROUP_DIRECTIONS else PLUGIN_DEFAULTS["serviceGroupDirection"]
  if "groupCountMode" in source: clean["groupCountMode"] = source["groupCountMode"] if source["groupCountMode"] in GROUP_COUNT_MODES else PLUGIN_DEFAULTS["groupCountMode"]
  if "cardDensity" in source: clean["cardDensity"] = source["cardDensity"] if source["cardDensity"] in CARD_DENSITIES else PLUGIN_DEFAULTS["cardDensity"]
  if "serviceLayout" in source: clean["serviceLayout"] = source["serviceLayout"] if source["serviceLayout"] in SERVICE_LAYOUTS else PLUGIN_DEFAULTS["serviceLayout"]
  if "barPresentation" in source: clean["barPresentation"] = source["barPresentation"] if source["barPresentation"] in BAR_PRESENTATIONS else PLUGIN_DEFAULTS["barPresentation"]
  if "barTextRotation" in source: clean["barTextRotation"] = source["barTextRotation"] if source["barTextRotation"] in BAR_TEXT_ROTATIONS else PLUGIN_DEFAULTS["barTextRotation"]
  if "defaultView" in source: clean["defaultView"] = source["defaultView"] if source["defaultView"] in VIEW_FILTERS else PLUGIN_DEFAULTS["defaultView"]
  if "groupHeaderStyle" in source: clean["groupHeaderStyle"] = source["groupHeaderStyle"] if source["groupHeaderStyle"] in GROUP_HEADER_STYLES else PLUGIN_DEFAULTS["groupHeaderStyle"]
  for role_key in ("runningColorRole","stoppedColorRole","errorColorRole","favoriteColorRole","activityColorRole","barForegroundColorRole","barActiveColorRole"):
    fallback = PLUGIN_DEFAULTS[role_key]
    if role_key in source: clean[role_key] = source[role_key] if source[role_key] in THEME_ROLES else fallback
  if "collapsedServiceGroups" in source and isinstance(source["collapsedServiceGroups"], dict):
    clean["collapsedServiceGroups"] = {str(key)[:64]: value for key,value in list(source["collapsedServiceGroups"].items())[:64] if isinstance(key,str) and key and isinstance(value,bool)}
  if "savedViews" in source and isinstance(source["savedViews"], list):
    views = []
    for view in source["savedViews"][:12]:
      if not isinstance(view, dict): continue
      name = str(view.get("name", "")).strip()[:32]
      if not name: continue
      saved_view = {
        "name": name,
        "filter": view.get("filter") if view.get("filter") in VIEW_FILTERS else "all",
        "sortMode": view.get("sortMode") if view.get("sortMode") in SORT_MODES else "custom",
        "sortDirection": view.get("sortDirection") if view.get("sortDirection") in SORT_DIRECTIONS else "automatic",
        "groupMode": view.get("groupMode") if view.get("groupMode") in GROUP_MODES else "none",
        "groupDirection": view.get("groupDirection") if view.get("groupDirection") in GROUP_DIRECTIONS else "automatic",
        "favoritesFirst": view.get("favoritesFirst") if isinstance(view.get("favoritesFirst"), bool) else True,
        "search": str(view.get("search", "")).strip()[:128],
      }
      backend = str(view.get("backend", "")).strip().lower()[:64]
      if backend: saved_view["backend"] = backend
      views.append(saved_view)
    clean["savedViews"] = views
  clean["_p2pSettingsVersion"] = SETTINGS_VERSION
  clean["_p2pRevision"] = _revision(source.get("_p2pRevision"))
  clean["_p2pUpdatedAt"] = max(0, _revision(source.get("_p2pUpdatedAt")))
  return clean


def reconcile_settings(shell, durable):
  left, right = sanitize_settings(shell), sanitize_settings(durable)
  left_revision, right_revision = left.get("_p2pRevision", 0), right.get("_p2pRevision", 0)
  if left_revision > right_revision: return left
  if right_revision > left_revision: return right
  merged = dict(left)
  merged.update(right)
  merged["_p2pSettingsVersion"] = SETTINGS_VERSION
  return merged
