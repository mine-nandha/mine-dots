#!/usr/bin/env bash

# ─── Waybar Custom Modules ──────────────────────────────────────────────
# Usage: ./custom_modules.sh {cpu|memory|audio|network|updates|media|battery|all}

set -euo pipefail

# ── helpers ─────────────────────────────────────────────────────────────
format() {
  local text="$1" class="$2" tooltip="$3"
  jq -cn \
    --arg text "$text" \
    --arg class "$class" \
    --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}'
}

# ── cpu ─────────────────────────────────────────────────────────────────
cpu() {
  local cpu_line idle total prev_idle prev_total usage
  cpu_line=$(head -1 /proc/stat)
  read _ _ _ _ idle _ _ _ _ _ _ <<< "$cpu_line"
  total=$(awk '{for (i=2; i<=NF; i++) s+=$i} END {print s}' <<< "$cpu_line")
  prev_idle=$(cat /tmp/waybar_cpu_idle 2>/dev/null || echo 0)
  prev_total=$(cat /tmp/waybar_cpu_total 2>/dev/null || echo 0)
  echo "$idle" > /tmp/waybar_cpu_idle
  echo "$total" > /tmp/waybar_cpu_total
  if [[ "$prev_total" -eq 0 ]]; then
    format "0%" "cpu" "CPU: 0%"
    return
  fi
  usage=$(( 100 * ( (total - prev_total) - (idle - prev_idle) ) / (total - prev_total) ))
  format "${usage}%" "cpu" "CPU: ${usage}%"
}

# ── memory ──────────────────────────────────────────────────────────────
memory() {
  local total used avail pct used_gb total_gb
  read total used avail <<< "$(free -m | awk '/Mem:/ {print $2, $3, $7}')"
  pct=$((used * 100 / total))
  used_gb=$(awk "BEGIN {printf \"%.1f\", $used/1024}")
  total_gb=$(awk "BEGIN {printf \"%.1f\", $total/1024}")
  format "${used_gb}G" "memory" "RAM: ${used_gb}G / ${total_gb}G (${pct}%)"
}

# ── audio ───────────────────────────────────────────────────────────────
audio() {
  if ! command -v wpctl &>/dev/null; then
    format "N/A" "audio" "wpctl not found"
    return
  fi
  local vol_raw muted_raw
  vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
  muted_raw=$(echo "$vol_raw" | grep -oP '\[MUTED\]' || true)
  local vol=$(echo "$vol_raw" | awk '{printf "%.0f", $2 * 100}')
  if [[ -n "$muted_raw" ]]; then
    format "MUTE" "audio muted" "Volume: MUTED"
  else
    format "${vol}%" "audio" "Volume: ${vol}%"
  fi
}

# ── network ─────────────────────────────────────────────────────────────
network() {
  local ssid="Disconnected" class="network"
  if command -v iwctl &>/dev/null; then
    ssid=$(iwctl station wlan0 show 2>/dev/null | awk '/Connected network/ {print $3}' || echo "Disconnected")
  elif command -v nmcli &>/dev/null; then
    ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)
    [[ -z "$ssid" ]] && ssid="Disconnected"
  elif command -v iwgetid &>/dev/null; then
    ssid=$(iwgetid -r 2>/dev/null || echo "Disconnected")
  fi
  [[ "$ssid" == "Disconnected" ]] && class="network disconnected"
  format "$ssid" "$class" "Network: $ssid"
}

# ── updates (pacman) ────────────────────────────────────────────────────
updates() {
  if ! command -v checkupdates &>/dev/null; then
    format "?" "updates" "checkupdates not found"
    return
  fi
  local count=$(checkupdates 2>/dev/null | wc -l)
  if [[ "$count" -gt 0 ]]; then
    format "${count}" "updates has-updates" "${count} pacman updates available"
  else
    format "0" "updates" "System up to date"
  fi
}

# ── media (playerctl) ───────────────────────────────────────────────────
media() {
  if ! command -v playerctl &>/dev/null; then
    format "" "media" ""
    return
  fi
  local status=$(playerctl status 2>/dev/null)
  if [[ "$status" != "Playing" && "$status" != "Paused" ]]; then
    format "" "media" ""
    return
  fi
  local artist=$(playerctl metadata artist 2>/dev/null || echo "")
  local title=$(playerctl metadata title 2>/dev/null || echo "")
  local text=""
  local class="media"
  if [[ -n "$artist" && -n "$title" ]]; then
    text="${artist} — ${title}"
  elif [[ -n "$title" ]]; then
    text="$title"
  else
    text="$(playerctl metadata xesam:url 2>/dev/null | sed 's|.*/||' || echo "")"
  fi
  [[ "$status" == "Paused" ]] && class="media paused"
  format "${text:0:60}" "$class" "${artist:-Unknown} — ${title:-Unknown}"
}

# ── battery ─────────────────────────────────────────────────────────────
battery() {
  local bat="/sys/class/power_supply/BAT1"
  if [[ ! -d "$bat" ]]; then
    format "" "battery" ""
    return
  fi
  local cap=$(cat "$bat/capacity" 2>/dev/null || echo 0)
  local status=$(cat "$bat/status" 2>/dev/null || echo "Unknown")
  local icon class
  if [[ "$status" == "Charging" ]]; then
    icon=""
    class="battery charging"
  elif [[ "$cap" -le 15 ]]; then
    icon=""
    class="battery critical"
  elif [[ "$cap" -le 30 ]]; then
    icon=""
    class="battery low"
  elif [[ "$cap" -le 60 ]]; then
    icon=""
    class="battery"
  elif [[ "$cap" -le 85 ]]; then
    icon=""
    class="battery"
  else
    icon=""
    class="battery"
  fi
  format "${icon} ${cap}%" "$class" "Battery: ${cap}% (${status})"
}

# ── main ────────────────────────────────────────────────────────────────
main() {
  case "${1:-all}" in
    cpu)     cpu ;;
    memory)  memory ;;
    audio)   audio ;;
    network) network ;;
    updates) updates ;;
    media)   media ;;
    battery) battery ;;
    all)
      cpu
      memory
      audio
      network
      updates
      media
      battery
      ;;
    *)
      echo '{"text":"err","class":"error","tooltip":"unknown module"}'
      ;;
  esac
}

main "$@"
