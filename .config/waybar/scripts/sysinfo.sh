#!/usr/bin/env bash
set -euo pipefail

bar() {
  local pct=$1
  local filled=$(( pct * 8 / 100 ))
  [[ $filled -gt 8 ]] && filled=8
  [[ $filled -lt 0 ]] && filled=0
  local empty=$(( 8 - filled ))
  local chars=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
  local out=""
  for ((i=0; i<filled; i++)); do out="${out}${chars[$i]}"; done
  for ((i=0; i<empty; i++)); do out="${out} "; done
  echo "$out"
}

battery_info() {
  local pct cap status icon
  if [[ -d /sys/class/power_supply/BAT0 ]]; then
    cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0)
    status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
  elif [[ -d /sys/class/power_supply/BAT1 ]]; then
    cap=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0)
    status=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo "Unknown")
  else
    echo " No BAT"
    return
  fi

  if [[ "$status" == "Charging" ]]; then
    icon=""
  elif [[ "$cap" -le 15 ]]; then
    icon=""
  elif [[ "$cap" -le 30 ]]; then
    icon=""
  elif [[ "$cap" -le 60 ]]; then
    icon=""
  elif [[ "$cap" -le 80 ]]; then
    icon=""
  else
    icon=""
  fi

  local bat_bar
  bat_bar=$(bar "$cap")
  echo "$icon $bat_bar $cap%"
}

case "${1:-}" in
  battery)
    text=$(battery_info)
    jq -cn --arg text "$text" --arg class "battery-bar" '{text: $text, class: $class}'
    ;;
  *)
    cpu=$(top -bn1 | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print int(100 - $1)}')
    mem=$(free | grep Mem | awk '{print int($3/$2 * 100)}')

    cpu_bar=$(bar "$cpu")
    mem_bar=$(bar "$mem")

    jq -cn \
      --arg cpu "$cpu_bar" \
      --arg cpu_pct "$cpu%" \
      --arg mem "$mem_bar" \
      --arg mem_pct "$mem%" \
      '{text: (" " + $cpu + " " + $cpu_pct + "   " + $mem + " " + $mem_pct), class: "sysinfo"}'
    ;;
esac
