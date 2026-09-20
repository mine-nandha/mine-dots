#!/usr/bin/env python3
"""Pause animated wallpapers when a window is focused on the active Hyprland
workspace; resume when the desktop is empty (battery saver).

Mirrors the behavior of pvtoari/mpvpaper-stop. No extra dependencies.

- Videos (mpvpaper): sends "set_property pause true/false" to every
  /tmp/mpvpaper-<monitor>.sock IPC socket.
- Animated GIFs (awww): runs `awww pause` / `awww unpause`.
- A 1-second periodic schedule (driven by select() polling, independent of
  socket traffic) re-pushes the current state to any newly-appeared mpvpaper
  socket and checks the repaint marker, so a video launches paused and a
  wallpaper switch is honored even while activewindow events keep flowing.
- A repaint grace window: when wallpaper.sh leaves a fresh repaint marker, the
  daemon forces the new wallpaper to show itself (unpauses) for ~2.5s even
  while a window is focused, then re-freezes it. See REPAINT_MARKER.
"""

import json
import os
import select
import socket
import subprocess
import sys
import time

MPV_SOCKET_DIR = os.environ.get("MPV_SOCKET_DIR", "/tmp")
TICK = 3
REPAINT_GRACE = 2.5
REPAINT_MARKER = os.environ.get(
    "REPAINT_MARKER", os.path.expanduser("~/.cache/wallpaper_repaint")
)

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

repaint_until = None  # module-level: timestamp until which we force-unpause

def repaint_tick():
    """Open a short grace window after a wallpaper switch so the new wallpaper
    becomes visible even while a window is focused; afterwards fold back into
    the real focus state (re-freeze). Trigger: wallpaper.sh touching the repaint
    marker file. Covers both mpvpaper videos and awww GIFs."""
    global state, repaint_until
    now = time.time()
    mt = repaint_pending()
    if mt is not None:
        if now - mt < REPAINT_GRACE + TICK:
            repaint_until = now + REPAINT_GRACE
        repaint_remove()
    if repaint_until is None:
        return
    if now < repaint_until:
        if state is not False:
            state = False
            set_pause(False)
            awww_pause(False)
        return
    # Grace expired: fold back into the real focus state.
    repaint_until = None
    focused = probe_current_focus()
    if focused is not None:
        paused = bool(focused)
        if paused != state:
            state = paused
            set_pause(paused)
            awww_pause(paused)

def repaint_pending():
    """mtime (float) of the repaint request marker, or None when absent."""
    try:
        return os.path.getmtime(REPAINT_MARKER)
    except (OSError, ValueError):
        return None

def repaint_remove():
    try:
        os.remove(REPAINT_MARKER)
    except OSError:
        pass

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
            sock.connect(path)
            sock.setblocking(False)
            buf = b""
            last_tick = 0.0
            while True:
                # Periodic work runs on a monotonic schedule, independent of
                # socket traffic: repaint markers and new mpvpaper sockets are
                # handled even while activewindow events keep flowing.
                now = time.monotonic()
                if now - last_tick >= 1.0:
                    last_tick = now
                    resync()
                    repaint_tick()
                ready, _, _ = select.select([sock], [], [], 0.5)
                if not ready:
                    continue
                try:
                    data = sock.recv(65536)
                except (BlockingIOError, InterruptedError):
                    continue
                if not data:
                    break  # peer closed; reconnect
                buf += data
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    handle_event(line.decode(errors="replace"))
        except OSError as exc:
            print(f"mpvpaper-stop-ipc: connection error ({exc}); retrying in 2s", file=sys.stderr)
            time.sleep(2)
        finally:
            if sock is not None:
                try:
                    sock.close()
                except OSError:
                    pass

if __name__ == "__main__":
    main()