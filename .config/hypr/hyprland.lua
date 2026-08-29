-- =========================================================
-- HYPRLAND CONFIG
-- =========================================================

------------------
-- MONITORS
------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.25,
})

------------------
-- PROGRAMS
------------------

local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "fuzzel"
local editor      = "zeditor"
local browser     = "google-chrome-stable"

------------------
-- AUTOSTART
------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("dunst")
    hl.exec_cmd("hyprpolkitagent")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("sleep 0.5 && dunstctl set-paused false")
    hl.exec_cmd("sleep 1 && /home/nandha/.config/hypr/scripts/wallpaper.sh --restore")

    -- Clipboard
    hl.exec_cmd("wl-paste --type text --watch cliphist store")

    -- XDG
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- GNOME Keyring
    hl.exec_cmd("eval $(gnome-keyring-daemon --start --components=secrets)")
end)

------------------
-- ENVIRONMENT
------------------

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("XCURSOR_SIZE", "24")

------------------
-- LOOK AND FEEL
------------------

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        layout      = "dwindle",
    },

    decoration = {
        rounding = 8,

        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
        },
    },

    animations = {
        enabled = true,
    },

    gestures = {
        workspace_swipe_distance    = 300,
        workspace_swipe_invert      = true,
        workspace_swipe_cancel_ratio = 0.3,
        workspace_swipe_create_new  = false,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
    },
    input = {
        touchpad = {
            natural_scroll = true,
        },
    },
})

------------------
-- GESTURES
------------------

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

------------------
-- KEYBINDINGS
------------------

-- Applications
hl.bind(mainMod .. " + T",     hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E",     hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + B",     hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + C",     hl.dsp.exec_cmd(editor))

-- Clipboard
hl.bind(
    mainMod .. " + V",
    hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu | cliphist decode | wl-copy")
)

-- Window management
hl.bind("ALT + F4",             hl.dsp.window.close())
hl.bind(mainMod .. " + F",      hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + M",      hl.dsp.window.pseudo())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())

-- Lock / night light
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(
    mainMod .. " + O",
    hl.dsp.exec_cmd("pkill hyprsunset || hyprsunset --temperature 4500")
)

-- Wallpaper
hl.bind(
    mainMod .. " + W",
    hl.dsp.exec_cmd("/home/nandha/.config/hypr/scripts/wallpaper.sh")
)

hl.bind(
    mainMod .. " + SHIFT + W",
    hl.dsp.exec_cmd("/home/nandha/.config/hypr/scripts/wallpaper.sh --fuzzel")
)

------------------
-- WINDOW FOCUS
------------------

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

------------------
-- MOVE WINDOWS
------------------

hl.bind(mainMod .. " + SHIFT + left",
    hl.dsp.window.move({ direction = "left" }))

hl.bind(mainMod .. " + SHIFT + right",
    hl.dsp.window.move({ direction = "right" }))

hl.bind(mainMod .. " + SHIFT + up",
    hl.dsp.window.move({ direction = "up" }))

hl.bind(mainMod .. " + SHIFT + down",
    hl.dsp.window.move({ direction = "down" }))

------------------
-- RESIZE WINDOWS
------------------

hl.bind(mainMod .. " + CTRL + left",
    hl.dsp.window.resize({ x = -50, y = 0, relative = true }))

hl.bind(mainMod .. " + CTRL + right",
    hl.dsp.window.resize({ x = 50, y = 0, relative = true }))

hl.bind(mainMod .. " + CTRL + up",
    hl.dsp.window.resize({ x = 0, y = -50, relative = true }))

hl.bind(mainMod .. " + CTRL + down",
    hl.dsp.window.resize({ x = 0, y = 50, relative = true }))

------------------
-- WORKSPACES
------------------

for i = 1, 10 do
    local key = i % 10

    hl.bind(
        mainMod .. " + " .. key,
        hl.dsp.focus({ workspace = i })
    )

    hl.bind(
        mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i })
    )
end

------------------
-- SCREENSHOTS
------------------

hl.bind(
    "PRINT",
    hl.dsp.exec_cmd("hyprshot -m window")
)

hl.bind(
    mainMod .. " + SHIFT + S",
    hl.dsp.exec_cmd("hyprshot -m region")
)

------------------
-- AUDIO
------------------

hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true }
)

------------------
-- BRIGHTNESS
------------------

hl.bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl set +5%"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl set 1%-"),
    { locked = true, repeating = true }
)

------------------
-- MOUSE
------------------

hl.bind(
    mainMod .. " + mouse:272",
    hl.dsp.window.drag(),
    { mouse = true }
)

hl.bind(
    mainMod .. " + mouse:273",
    hl.dsp.window.resize(),
    { mouse = true }
)
