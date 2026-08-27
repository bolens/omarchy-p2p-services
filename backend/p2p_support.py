"""Privacy-safe, whole-plugin support report projection."""

from collections import Counter
from datetime import datetime, timezone
import re


SAFE_SETTING_KEYS = (
  "eventRefresh", "privacyFilter", "refreshSeconds", "backgroundRefreshSeconds",
  "reconcileSeconds", "serviceLayout", "cardDensity", "serviceGroupMode",
  "serviceSortMode", "showStopped", "showTrafficStats",
)


def _token(value, fallback="unknown", maximum=64):
  text = str(value or "")[:maximum]
  return text if re.fullmatch(r"[a-z0-9_-]+", text) else fallback


def support_report(manifest, settings, snapshot, monitoring=None):
  services = snapshot.get("services", []) if isinstance(snapshot, dict) else []
  diagnostics = snapshot.get("diagnostics", []) if isinstance(snapshot, dict) else []
  backends = Counter(str(item.get("backend") or "unknown") for item in services if isinstance(item, dict))
  categories = Counter(str(item.get("category") or "Other") for item in services if isinstance(item, dict))
  states = Counter("unhealthy" if item.get("hasError") else "running" if item.get("active") else "stopped"
                   for item in services if isinstance(item, dict))
  safe_settings = {key: settings.get(key) for key in SAFE_SETTING_KEYS if key in settings}
  safe_settings["privacyFilter"] = True
  warning_codes = Counter(str(item.get("code") or "unknown") for item in diagnostics if isinstance(item, dict))
  report = {
    "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
    "plugin": {"id": manifest.get("id", ""), "version": manifest.get("version", ""), "schemaVersion": manifest.get("schemaVersion", 0)},
    "privacyFiltered": True,
    "scan": {"durationMs": max(0, int(snapshot.get("durationMs", 0) or 0)), "warningCodes": dict(sorted(warning_codes.items()))},
    "services": {"total": len(services), "states": dict(sorted(states.items())), "backends": dict(sorted(backends.items())), "categories": dict(sorted(categories.items()))},
    "settings": safe_settings,
  }
  source = monitoring if isinstance(monitoring, dict) else {}
  report["monitoring"] = {
    "watcherHealth": _token(source.get("watcherHealth"), maximum=32),
    "watcherCode": _token(source.get("watcherCode")),
    "settingsWatcherHealth": _token(source.get("settingsWatcherHealth"), maximum=32),
    "settingsWatcherCode": _token(source.get("settingsWatcherCode")),
    "consecutiveRefreshFailures": max(0, min(999, int(source.get("consecutiveRefreshFailures", 0) or 0))),
    "lastRefreshAgeSeconds": max(-1, min(86400, int(source.get("lastRefreshAgeSeconds", -1) or 0))),
  }
  return report


def support_report_text(report):
  import json
  return "P2P Services support report (privacy filtered)\n" + json.dumps(report, indent=2, sort_keys=True) + "\n"
