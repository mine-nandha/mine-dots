#!/usr/bin/env bash

WALLPAPER=$(cat "$HOME/.cache/wallpaper_state" 2>/dev/null || echo "")

# Source pywal colors
[ -f "$HOME/.cache/wal/colors.sh" ] && source "$HOME/.cache/wal/colors.sh"

# --- Waybar: symlink wal template output ---
if [ -f "$HOME/.cache/wal/colors-waybar.css" ]; then
    ln -sf "$HOME/.cache/wal/colors-waybar.css" "$HOME/.config/waybar/colors.css"
fi

# --- Dunst: patch colors in-place ---
DUNSTRC="$HOME/.config/dunst/dunstrc"
if [ -f "$DUNSTRC" ] && [ -n "${background:-}" ]; then
    sed -i "/^\[global\]/,/^\[/{
        s|^\(\s*background\s*=\).*|\1 \"${background}\"|
        s|^\(\s*foreground\s*=\).*|\1 \"${foreground}\"|
        s|^\(\s*frame_color\s*=\).*|\1 \"${color0}\"|
        s|^\(\s*separator_color\s*=\).*|\1 \"${color8}\"|
    }" "$DUNSTRC"

    sed -i "/^\[urgency_low\]/,/^\[/{
        s|^\(\s*background\s*=\).*|\1 \"${background}\"|
        s|^\(\s*foreground\s*=\).*|\1 \"${foreground}\"|
        s|^\(\s*frame_color\s*=\).*|\1 \"${color8}\"|
    }" "$DUNSTRC"

    sed -i "/^\[urgency_normal\]/,/^\[/{
        s|^\(\s*background\s*=\).*|\1 \"${background}\"|
        s|^\(\s*foreground\s*=\).*|\1 \"${foreground}\"|
        s|^\(\s*frame_color\s*=\).*|\1 \"${color4}\"|
    }" "$DUNSTRC"

    sed -i "/^\[urgency_critical\]/,\${
        s|^\(\s*background\s*=\).*|\1 \"${background}\"|
        s|^\(\s*foreground\s*=\).*|\1 \"${color1}\"|
        s|^\(\s*frame_color\s*=\).*|\1 \"${color1}\"|
    }" "$DUNSTRC"
fi

# --- Hyprlock: update wallpaper path ---
HYPRLOCK="$HOME/.config/hypr/hyprlock.conf"
if [ -f "$HYPRLOCK" ] && [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    if grep -q "^[[:space:]]*path\s*=" "$HYPRLOCK"; then
        sed -i "s|^\([[:space:]]*path\s*=\).*|\1 ${WALLPAPER}|" "$HYPRLOCK"
    fi
fi

# Reload daemons
# wallpaper-rotation.service runs this in its own cgroup; KillMode=process on that
# unit is what lets this backgrounded waybar outlive the oneshot service.
pkill -SIGTERM waybar 2>/dev/null || true
sleep 0.5
waybar &
disown
dunstctl reload 2>/dev/null || true
