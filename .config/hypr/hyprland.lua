-- CachyOS-inspired Hyprland test profile.
-- Keep this file small enough to audit while still giving a complete session.

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

hl.monitor({output="eDP-1", mode="preferred", position="auto", scale=2})

local mod = "SUPER"
local terminal = "kitty"
local menu = "~/.local/bin/dynamite toggle launcher"
local fileManager = "dolphin"

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("KDE_SESSION_VERSION", "6")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.config({
    -- Avoid automatic HDR mode changes when an app enters fullscreen.
    render = { cm_auto_hdr = 0 },
    cursor = {
        no_hardware_cursors = true,
    },
    input = {
        kb_layout = "no",
        follow_mouse = 1,
        sensitivity = 0,
        scroll_method = "2fg",
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
            tap_and_drag = true,
            drag_lock = true,
            scroll_factor = 1.0,
            disable_while_typing = false,
        },
    },
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = {
                colors = { "rgba(00d4ffee)", "rgba(7c3aedee)" },
                angle = 45,
            },
            inactive_border = "rgba(2f3341aa)",
        },
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },
    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size = 6,
            passes = 2,
            ignore_opacity = true,
        },
        shadow = {
            enabled = true,
            range = 18,
            render_power = 3,
            color = "rgba(00000055)",
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
    },
})

hl.curve("smooth", {
    type = "bezier",
    points = { { 0.16, 1 }, { 0.3, 1 } },
})
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "smooth" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "smooth", style = "slide" })

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.local/bin/hypr-startup-apps")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("mako")
    hl.exec_cmd("~/.local/bin/dynamite start")  -- warm before the first SUPER+D/space (cold start is ~0.4 s)
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

hl.window_rule({
    match = { class = "^(vivaldi-snapshot|Vivaldi-snapshot)$" },
    workspace = "2",
})
hl.window_rule({
    match = { class = "^(Mattermost([.]Desktop)?|mattermost)$" },
    workspace = "special:mattermost silent",
})

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("mattermost"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.local/bin/hypr-mattermost-scratchpad"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + V", hl.dsp.window.float())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("~/.local/bin/dynamite bars"))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ last = true }))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "d" }))

hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "d" }))

hl.bind(mod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
hl.bind(mod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }))
hl.bind(mod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }))

hl.bind("Print", hl.dsp.exec_cmd("~/.local/bin/hypr-screenshot"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("~/.local/bin/hypr-screenshot region"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd("~/.local/bin/hypr-screenshot full"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })

for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- OSP presentation display and shortcuts.
hl.window_rule({name="osp-title", match={class="^(osp-holding-slide)$"}, workspace="name:osp-title silent", fullscreen=true})
hl.bind("SUPER + ALT + 1", hl.dsp.exec_cmd("~/.local/bin/osp-screen title"))
hl.bind("SUPER + ALT + 2", hl.dsp.exec_cmd("~/.local/bin/osp-screen mirror"))

-- Reconcile after hotplug, unplug, and login with a display already attached.
for _, event in ipairs({"monitor.added", "monitor.removed", "hyprland.start"}) do
    hl.on(event, function()
        hl.exec_cmd("~/.local/bin/osp-screen auto >> ~/.cache/osp-screen.log 2>&1")
    end)
end

hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/hypr-wallpaper next"))

-- Clipboard history, screenshot annotation and color picker.
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p clipboard | cliphist decode | wl-copy"))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd("~/.local/bin/hypr-screenshot annotate-region"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

-- Emergency release: close pickers/menus if one is stuck holding input.
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd("pkill -x slurp; pkill -x wofi; pkill -x rofi; pkill -x hyprpicker"))

-- Dynamite shortcuts (SUPER+D above opens the same launcher).
hl.bind("SUPER + space", hl.dsp.exec_cmd("~/.local/bin/dynamite toggle launcher"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("~/.local/bin/dynamite toggle controls"))
hl.bind("SUPER + T", hl.dsp.exec_cmd("~/.local/bin/dynamite toggle themes"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("~/.local/bin/dynamite toggle wallpapers"))
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("~/.local/bin/dynamite close"))
