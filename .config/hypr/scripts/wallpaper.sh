#!/usr/bin/env bash

# Ensure DBus session bus is available (may not be inherited from hyprland exec)
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
STATE_FILE="$HOME/.cache/wallpaper_state"
CURRENT_WAL_FILE="$HOME/.cache/wal/wallpaper"

# Auto-detect Hyprland instance signature
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -1)
fi

pick_random() {
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | shuf -n1
}

pick_fuzzel() {
    local selected
    selected=$(
        find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf "%f\n" 2>/dev/null | sort |
        fuzzel --dmenu --prompt="Wallpaper > "
    )
    if [ -n "$selected" ]; then
        echo "$WALLPAPER_DIR/$selected"
    fi
}

set_wallpaper() {
    local img="$1"

    hyprctl hyprpaper preload "$img" 2>/dev/null || true

    # Get monitor list (fallback to empty if jq not available)
    local monitors
    monitors=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null)
    if [ -z "$monitors" ]; then
        monitors=$(hyprctl monitors 2>/dev/null | grep -oP 'Monitor \K\S+' | head -1)
    fi
    if [ -z "$monitors" ]; then
        hyprctl hyprpaper wallpaper ",$img" 2>/dev/null || true
    else
        while IFS= read -r m; do
            hyprctl hyprpaper wallpaper "$m,$img" 2>/dev/null || true
        done <<< "$monitors"
    fi

    echo "$img" > "$STATE_FILE"
    echo "$img" > "$CURRENT_WAL_FILE"

    dunstify -i "$img" "Wallpaper" "$(basename "$img")" -t 2000 2>/dev/null
}

# Determine wallpaper source
if [ "${1:-}" = "--fuzzel" ] || [ "${1:-}" = "-f" ]; then
    WALLPAPER=$(pick_fuzzel)
    [ -z "$WALLPAPER" ] && exit 0
elif [ "${1:-}" = "--restore" ]; then
    if [ -f "$STATE_FILE" ]; then
        WALLPAPER=$(cat "$STATE_FILE")
        [ ! -f "$WALLPAPER" ] && WALLPAPER=$(pick_random)
    else
        WALLPAPER=$(pick_random)
    fi
elif [ $# -ge 1 ] && [ -f "$1" ]; then
    WALLPAPER="$1"
else
    WALLPAPER=$(pick_random)
fi

if [ -z "$WALLPAPER" ]; then
    dunstify -u critical "Wallpaper" "No wallpapers found in $WALLPAPER_DIR" 2>/dev/null
    exit 1
fi

set_wallpaper "$WALLPAPER"

# Generate pywal colors
if command -v wal &>/dev/null; then
    wal -q -i "$WALLPAPER" -o "$HOME/.config/hypr/scripts/wal-post.sh"
fi
