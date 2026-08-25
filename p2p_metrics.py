"""Pure parsers for container traffic counters."""

import re


def parse_size(value):
  match = re.fullmatch(r"\s*([0-9]+(?:\.[0-9]+)?)\s*([KMGTPE]?i?B)\s*", str(value or ""), re.I)
  if not match: return 0
  number = float(match.group(1))
  unit = match.group(2).upper()
  binary = "I" in unit
  power = "BKMGTPE".index(unit[0]) if unit[0] != "B" else 0
  return int(number * ((1024 if binary else 1000) ** power))


def parse_netio(value):
  parts = str(value or "").split("/")
  return (parse_size(parts[0]), parse_size(parts[1])) if len(parts) == 2 else (0, 0)
