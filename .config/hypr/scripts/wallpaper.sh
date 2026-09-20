#!/usr/bin/env bash

# Ensure DBus session bus is available (may not be inherited from hyprland exec)
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
STATE_FILE="$HOME/.cache/wallpaper_state"          # static / poster path — every consumer reads this
ANIM_STATE_FILE="$HOME/.cache/wallpaper_animated"  # actual animated file (gif/apng/mp4/webm) when active
POSTER_FILE="$HOME/.cache/wallpaper_poster.png"    # generated still frame for pywal/hyprlock
CURRENT_WAL_FILE="$HOME/.cache/wal/wallpaper"

MPV_SOCKET_DIR="${MPV_SOCKET_DIR:-/tmp}"

# Auto-detect Hyprland instance signature
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "$XDG_RUNTIME_DIR/hypr" ]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -1)
fi

is_animated() {
    case "$1" in
        *.gif|*.apng|*.webp) return 0 ;;
        *) return 1 ;;
    esac
}

is_video() {
    case "$1" in
        *.mp4|*.mkv|*.webm|*.mov|*.m4v) return 0 ;;
        *) return 1 ;;
    esac
}

pick_random() {
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
        -o -iname '*.gif' -o -iname '*.apng' -o -iname '*.mp4' -o -iname '*.webm' \
        -o -iname '*.mkv' -o -iname '*.mov' \) 2>/dev/null | shuf -n1
}

pick_fuzzel() {
    local selected
    selected=$(
        find "$WALLPAPER_DIR" -maxdepth 1 -type f \( \
            -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
            -o -iname '*.gif' -o -iname '*.apng' -o -iname '*.mp4' -o -iname '*.webm' \
            -o -iname '*.mkv' -o -iname '*.mov' \) -printf "%f\n" 2>/dev/null | sort |
        fuzzel --dmenu --prompt="Wallpaper > "
    )
    if [ -n "$selected" ]; then
        echo "$WALLPAPER_DIR/$selected"
    fi
}

get_monitors() {
    local monitors
    monitors=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null)
    if [ -z "$monitors" ]; then
        monitors=$(hyprctl monitors 2>/dev/null | grep -oP 'Monitor \K\S+' | head -1)
    fi
    [ -z "$monitors" ] && monitors="eDP-1"
    printf '%s\n' "$monitors"
}

stop_video_wallpaper() {
    # Only mpvpaper invocations (they always carry "-o ..."), never the pause daemon.
    pkill -f 'mpvpaper -o ' 2>/dev/null || true
    pkill -x mpvpaper 2>/dev/null || true
}

make_poster() {
    # Extract a single still frame from animated/video files, for pywal + hyprlock.
    local src="$1"
    ffmpeg -y -loglevel error -i "$src" -frames:v 1 \
        -vf "scale='min(2560,iw)':-2" "$POSTER_FILE" 2>/dev/null
}

apply_swww() {
    local img="$1"
    local monitors outputs
    monitors=$(get_monitors)
    if [ "$(printf '%s\n' "$monitors" | wc -l)" -gt 1 ]; then
        outputs=$(printf '%s\n' "$monitors" | paste -sd, -)
        awww img -o "$outputs" "$img" --transition-type fade --transition-duration 2 2>/dev/null || true
    else
        awww img "$img" --transition-type fade --transition-duration 2 2>/dev/null || true
    fi
}

apply_mpvpaper() {
    local video="$1"
    local m
    awww clear 2>/dev/null || true
    while IFS= read -r m; do
        # Restart-loop: if mpvpaper exits while this video is still the active
        # wallpaper, relaunch it after a short pause (self-healing).
        (
            while :; do
                mpvpaper -o "--no-audio --loop-file=inf --input-ipc-server=${MPV_SOCKET_DIR}/mpvpaper-${m}.sock" \
                    "$m" "$video"
                [ -f "$video" ] || exit 0
                [ "$(cat "$ANIM_STATE_FILE" 2>/dev/null)" = "$video" ] || exit 0
                sleep 2
            done
        ) &
    done <<< "$(get_monitors)"
    sleep 0.3
}

set_wallpaper() {
    local img="$1"
    local poster="$img"

    if is_video "$img" || is_animated "$img"; then
        make_poster "$img" && [ -f "$POSTER_FILE" ] && poster="$POSTER_FILE"
    fi

    # Update the animated-state FIRST so any mpvpaper restart-loop sees the
    # change and stops itself instead of resurrecting the old video.
    if is_video "$img" || is_animated "$img"; then
        echo "$img" > "$ANIM_STATE_FILE"
    else
        rm -f "$ANIM_STATE_FILE"
    fi

    stop_video_wallpaper

    if is_video "$img"; then
        apply_mpvpaper "$img"
    else
        apply_swww "$img"
    fi

    # Ask the pause daemon to let the new wallpaper show itself for a short
    # repaint grace window even while a window is focused, then re-freeze it.
    touch "$HOME/.cache/wallpaper_repaint"

    echo "$poster" > "$STATE_FILE"
    echo "$poster" > "$CURRENT_WAL_FILE"

    # pywal colors from the poster (always a real static image)
    if command -v wal &>/dev/null && [ -f "$poster" ]; then
        wal -q -i "$poster" -o "$HOME/.config/hypr/scripts/wal-post.sh"
    fi
}

# Determine wallpaper source
if [ "${1:-}" = "--fuzzel" ] || [ "${1:-}" = "-f" ]; then
    WALLPAPER=$(pick_fuzzel)
    [ -z "$WALLPAPER" ] && exit 0
elif [ "${1:-}" = "--restore" ]; then
    if [ -f "$ANIM_STATE_FILE" ]; then
        WALLPAPER=$(cat "$ANIM_STATE_FILE")
        [ ! -f "$WALLPAPER" ] && WALLPAPER=$(pick_random)
    else
        WALLPAPER=""
    fi
    if [ -z "${WALLPAPER:-}" ]; then
        if [ -f "$STATE_FILE" ]; then
            WALLPAPER=$(cat "$STATE_FILE")
            [ ! -f "$WALLPAPER" ] && WALLPAPER=$(pick_random)
        else
            WALLPAPER=$(pick_random)
        fi
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