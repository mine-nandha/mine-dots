#!/usr/bin/env bash

set -euo pipefail

format() {
  local text="$1" class="$2" tooltip="$3"
  jq -cn \
    --arg text "$text" \
    --arg class "$class" \
    --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}'
}

updates() {
  if ! command -v checkupdates &>/dev/null; then
    format "?" "updates" "checkupdates not found"
    return
  fi
  local count=$(checkupdates 2>/dev/null | wc -l)
  if [[ "$count" -gt 0 ]]; then
    format " ${count}" "updates has-updates" "${count} pacman updates available"
  else
    format " 0" "updates" "System up to date"
  fi
}

main() {
  case "${1:-updates}" in
    updates) updates ;;
    *)
      echo '{"text":"err","class":"error","tooltip":"unknown module"}'
      ;;
  esac
}

main "$@"
