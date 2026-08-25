#!/usr/bin/env bash

find_command() {
  local override=$1 name=$2 fallback=${3:-}
  if [[ -n "$override" ]]; then
    [[ -x "$override" ]] || { printf '%s override is not executable: %s\n' "$name" "$override" >&2; return 1; }
    printf '%s\n' "$override"
    return
  fi
  command -v "$name" 2>/dev/null && return
  if [[ -n "$fallback" && -x "$fallback" ]]; then printf '%s\n' "$fallback"; return; fi
  printf 'Required command not found: %s\n' "$name" >&2
  return 1
}

find_omarchy_shell_root() {
  local candidate
  if [[ -n "${OMARCHY_SHELL_ROOT:-}" ]]; then
    candidate=$OMARCHY_SHELL_ROOT
  else
    for candidate in \
      "${OMARCHY_PATH:-}/shell" \
      "${XDG_DATA_HOME:-$HOME/.local/share}/omarchy/shell" \
      "${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-overlay/shell" \
      /usr/share/omarchy/shell; do
      [[ "$candidate" != /shell && -d "$candidate/Commons" && -d "$candidate/Ui" ]] && break
      candidate=
    done
  fi
  [[ -n "$candidate" && -d "$candidate/Commons" && -d "$candidate/Ui" ]] || {
    printf 'Omarchy Shell modules not found; set OMARCHY_SHELL_ROOT\n' >&2
    return 1
  }
  printf '%s\n' "$candidate"
}
