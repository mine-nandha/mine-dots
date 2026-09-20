#!/usr/bin/env python3
"""Pause animated wallpapers when a window is focused on the active Hyprland
workspace; resume when the desktop is empty (battery saver).

Mirrors the behavior of pvtoari/mpvpaper-stop. No extra dependencies.

- Videos (mpvpaper): sends "set_property pause true/false" to every
  /tmp/mpvpaper-<monitor>.sock IPC socket.
- Animated GIFs (awww): runs `awww pause` / `awww unpause`.
- A 3-second tick re-pushes the current state to any newly-appeared mpvpaper
  socket, so a video launches with the correct pause state immediately.
"""

import json
import os
import socket
import subprocess
import sys
import time

MPV_SOCKET_DIR = os.environ.get("MPV_SOCKET_DIR", "/tmp")
TICK = 3

def hypr_socket_path():
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        try:
            for entry in sorted(os.listdir(f"{runtime}/hypr")):
                if not entry.startswith("."):
                    sig = entry
                    break
        except FileNotFoundError:
            pass
    return f"{runtime}/hypr/{sig}/.socket2.sock"

def mpv_sockets():
    if not os.path.isdir(MPV_SOCKET_DIR):
        return
    try:
        names = sorted(os.listdir(MPV_SOCKET_DIR))
    except OSError:
        return
    for name in names:
        if name.startswith("mpvpaper-"):
            yield os.path.join(MPV_SOCKET_DIR, name)

def send_pause_socket(path, paused):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1.0)
        s.connect(path)
        s.sendall(json.dumps({"command": ["set_property", "pause", paused]}).encode() + b"\n")
        s.close()
    except (OSError, ValueError):
        pass

def set_pause(paused):
    for path in mpv_sockets():
        send_pause_socket(path, paused)

def awww_pause(paused):
    """Freeze/resume animated GIFs via awww's built-in pause (no-op if daemon absent)."""
    try:
        subprocess.run(
            ["awww", "pause" if paused else "unpause"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        pass

def desktop_focused(payload):
    """True when an activewindow event payload means 'no window on the desktop'."""
    p = payload.strip() if payload else ""
    return p == "" or p == "," or p == ",," or p == "0"

state = None      # module-level: last commanded pause state (None = unknown)
known = set()     # module-level: mpvpaper sockets we have pushed state to

def handle_event(event):
    """Process one Hyprland event line; pause/unpause on activewindow changes."""
    global state
    if event.startswith("activewindow"):
        payload = event.split(">>", 1)[1] if ">>" in event else ""
        paused = not desktop_focused(payload)
        if paused != state:
            state = paused
            set_pause(paused)
            awww_pause(paused)

def resync():
    """Push the current pause state to any newly-appeared mpvpaper socket."""
    global known
    if state is not None:
        current = set(mpv_sockets())
        for spath in current - known:
            send_pause_socket(spath, state)
        known = current

def probe_current_focus():
    """Best-effort initial pause state from hyprctl. Returns None if unusable."""
    try:
        out = subprocess.run(
            ["hyprctl", "activewindow", "-j"],
            capture_output=True, text=True, timeout=2,
        ).stdout
        data = json.loads(out)
        cls = (data.get("class") or "").strip()
        return True if cls else False
    except (OSError, subprocess.SubprocessError, ValueError, json.JSONDecodeError):
        return None

def main():
    global state, known
    path = hypr_socket_path()
    state = probe_current_focus()
    known = set(mpv_sockets())
    if state is not None:
        set_pause(state)    # pre-warm existing sockets with the best guess
        awww_pause(state)   # and freeze/resume the animated GIF layer too
    while True:
        sock = None
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.settimeout(TICK)
            sock.connect(path)
            buf = b""
            while True:
                data = sock.recv(65536)
                buf += data
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    handle_event(line.decode(errors="replace"))
        except socket.timeout:
            pass  # tick — falls through to resync below
        except OSError as exc:
            print(f"mpvpaper-stop-ipc: connection error ({exc}); retrying in 2s", file=sys.stderr)
            time.sleep(2)
        finally:
            if sock is not None:
                try:
                    sock.close()
                except OSError:
                    pass
        resync()

if __name__ == "__main__":
    main()