#!/usr/bin/env bash
set -euo pipefail

profile=$(powerprofilesctl get)
case "$profile" in
  performance) icon="" ;;
  balanced)    icon="" ;;
  power-saver) icon="" ;;
esac

jq -cn --arg text "$icon" --arg class "$profile" --arg tooltip "Profile: ${profile^}" \
  '{text: $text, class: $class, tooltip: $tooltip}'
