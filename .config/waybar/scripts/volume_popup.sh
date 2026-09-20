#!/usr/bin/env bash
# volume_popup.sh — icon-only volume chip; flashes the level for ~2s after a change.
set -euo pipefail

OUT=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
PCT=$(awk -F'Volume: ' '{print $2}' <<<"$OUT" | awk '{printf "%d", $1*100}')
PCT=${PCT:-100}

STAMP=""
if [[ -f "${HOME}/.cache/volume_popup_stamp" ]]; then
  STAMP=$(cat "${HOME}/.cache/volume_popup_stamp")
fi
NOW=$(date +%s)
AGE=$(( 10#$NOW - 10#${STAMP:-0} ))

MUTE_ICON=""   # volume-off
LOW_ICON=""    # volume-down
HIGH_ICON=""   # volume-up

if [[ "$OUT" == *MUTED* ]]; then
  jq -cn --arg icon "$MUTE_ICON" '{text: $icon, class: "muted", tooltip: "Muted"}'
elif (( AGE >= 0 && AGE < 2 )); then
  jq -cn --arg icon "$HIGH_ICON" --arg pct "$PCT" \
    '{text: ($icon + " " + $pct + "%"), class: "popup", tooltip: ($pct + "% volume")}'
else
  if (( PCT == 0 )); then   ICON="$MUTE_ICON";
  elif (( PCT < 50 )); then ICON="$LOW_ICON";
  else                      ICON="$HIGH_ICON"; fi
  jq -cn --arg icon "$ICON" --arg pct "$PCT" \
    '{text: $icon, class: "volume", tooltip: ($pct + "% volume")}'
fi