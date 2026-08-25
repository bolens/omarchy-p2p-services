"""Shared validation for user-controlled network locations."""

import ipaddress
import re
import urllib.parse


def safe_http_url(value):
  text = str(value or "").strip()[:2048]
  if not text or re.search(r"[\x00-\x1f\x7f]", text): return ""
  try: parsed = urllib.parse.urlsplit(text)
  except ValueError: return ""
  if parsed.scheme.lower() not in ("http", "https") or not parsed.hostname: return ""
  if parsed.username is not None or parsed.password is not None: return ""
  try: _ = parsed.port
  except ValueError: return ""
  return text


def safe_console_host(value):
  text = str(value or "").strip()
  if not text or len(text) > 253 or re.search(r"[\x00-\x20\x7f/?#]", text):
    if not (text.startswith("[") and text.endswith("]")): return ""
  candidate = text[1:-1] if text.startswith("[") and text.endswith("]") else text
  try:
    address = ipaddress.ip_address(candidate)
    return "[" + str(address) + "]" if address.version == 6 else str(address)
  except ValueError:
    pass
  hostname = r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
  if len(candidate) > 253 or any(not re.fullmatch(hostname, label) for label in candidate.split(".")): return ""
  return candidate.lower()
