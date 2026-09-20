#!/usr/bin/env bash
# volume_action.sh — change volume and tell the bar to flash the new value
set -euo pipefail

SINK="@DEFAULT_AUDIO_SINK@"

case "${1:-}" in
  up)   wpctl set-volume "$SINK" 1%+ ;;
  down) wpctl set-volume "$SINK" 1%- ;;
  mute) wpctl set-mute "$SINK" toggle ;;
  *)    echo "usage: $0 up|down|mute" >&2; exit 1 ;;
esac

date +%s > "${HOME}/.cache/volume_popup_stamp"
pkill -RTMIN+10 waybar 2>/dev/null || true