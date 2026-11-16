-- Shared Hyprland config (laptop + office). Machine specifics: host.lua.
local host = require("host")
local pad = require("scratchpad")

local mod = "SUPER"
local terminal = "kitty"
local main_terminal = host.main_terminal or terminal
local menu = "~/.local/bin/dynamite toggle launcher"
local fileManager = "dolphin"

-- Monitors: explicit ones from host.lua, catch-all for anything else.
for _, m in ipairs(host.monitors or {}) do hl.monitor(m) end
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = host.scale or 1 })

hl.env("DYNAMITE_BAR_SCREEN", host.bar_screen or host.primary or "")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.config({
    cursor = {
        no_hardware_cursors = true,
    },
    input = {
        kb_layout = "no",
        kb_options = "lv3:ralt_switch",
        numlock_by_default = true,
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

-- Two screens: 1-5 live on the primary, 6-10 on the secondary. SUPER+N then
-- jumps to the assigned screen by itself. Hyprland moves workspaces off an
-- unplugged screen; rehome() puts them back when it returns.
local function home(i)
    return (i <= 5 or not host.secondary) and host.primary or host.secondary
end

if host.primary then
    for i = 1, 10 do
        hl.workspace_rule({ workspace = tostring(i), monitor = home(i), default = (i == 1 or i == 6) })
    end
end

local function rehome()
    if not host.primary then return end
    for _, ws in ipairs(hl.get_workspaces()) do
        local i = tonumber(ws.name)
        if i and i >= 1 and i <= 10 and hl.get_monitor(home(i)) then
            hl.dispatch(hl.dsp.workspace.move({ workspace = i, monitor = home(i) }))
        end
    end
end
hl.on("monitor.added", rehome)
hl.on("config.reloaded", rehome)

-- Cycle occupied workspaces plus one spare, within the focused monitor's bank.
local function workspace_cycle(workspaces, first, count)
    local occupied, last = {}, first - 1
    for _, workspace in ipairs(workspaces) do
        local id = tonumber(workspace.name)
        if id and id >= first and id < first + count and workspace.windows > 0 then
            occupied[id] = true
            last = math.max(last, id)
        end
    end
    -- Put the spare after the last used workspace, wrapping if the bank is full.
    for offset = 1, count do
        local id = first + ((last - first + offset) % count)
        if not occupied[id] then
            occupied[id] = true
            break
        end
    end
    local choices = {}
    for id in pairs(occupied) do choices[#choices + 1] = id end
    table.sort(choices)
    return choices
end

local function cycle_workspace(step)
    local monitor = hl.get_active_monitor()
    if not monitor then return end
    local first = (host.secondary and monitor.name == host.secondary) and 6 or 1
    local count = host.secondary and 5 or 10
    local choices = workspace_cycle(hl.get_workspaces(), first, count)
    local workspace = hl.get_active_workspace(monitor)
    local current = workspace and tonumber(workspace.name) or first
    local target = step > 0 and choices[1] or choices[#choices]
    for i, id in ipairs(choices) do
        if id == current then
            target = choices[1 + ((i - 1 + step) % #choices)]
            break
        elseif (step > 0 and id > current) or (step < 0 and id < current) then
            target = id
            if step > 0 then break end
        end
    end
    local special = hl.get_active_special_workspace(monitor)
    if special then
        hl.dispatch(hl.dsp.workspace.toggle_special(special.name:gsub("^special:", "")))
    end
    hl.dispatch(hl.dsp.focus({ workspace = target }))
end
hl.bind("SHIFT + Prior", function() cycle_workspace(-1) end)
hl.bind("SHIFT + Next", function() cycle_workspace(1) end)
hl.bind(mod .. " + Prior", function() cycle_workspace(1) end)
hl.bind(mod .. " + Next", function() cycle_workspace(-1) end)

-- Scratchpads (follow the focused monitor).
pad.define("mattermost", { match = "mattermost", cmd = host.mattermost })
if host.mail then pad.define("mail", { match = "evolution", cmd = host.mail }) end
pad.define("term", { match = "scratch-term", cmd = terminal .. " --class scratch-term", float = true })

hl.on("hyprland.start", function()
    hl.exec_cmd(host.polkit)
    hl.exec_cmd("~/.local/bin/dynamite start")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --watch cliphist store")
    for _, cmd in ipairs(host.autostart or {}) do hl.exec_cmd(cmd) end
    if host.mail then hl.exec_cmd(host.mail) end
end)

hl.window_rule({
    match = { class = "(?i)" .. host.browser.match },
    workspace = host.secondary and "6" or "2",
})

if host.main_terminal then
    hl.window_rule({ match = { class = "kitty-main" }, workspace = "1" })
end

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("~/.local/bin/dynamite toggle wallpapers"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + S", function() pad.toggle("mattermost") end)
hl.bind(mod .. " + T", function() pad.toggle("term") end)
if host.mail then hl.bind(mod .. " + SHIFT + M", function() pad.toggle("mail") end) end
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + SHIFT + underscore", hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mod .. " + V", hl.dsp.window.float())
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))
-- Compositor-only fullscreen: browser keeps its tabs/sidebars, gaps dropped.
hl.bind(mod .. " + F", function()
    local window = hl.get_active_window()
    if not window then return end
    hl.workspace_rule({ workspace = window.workspace.name, gaps_out = window.fullscreen == 0 and 0 or 8 })
    hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }))
end)
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("~/.local/bin/dynamite bars"))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.local/bin/dynamite toggle themes"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/hypr-wallpaper next"))
hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))
hl.bind(mod .. " + SHIFT + Tab", hl.dsp.focus({ last = true }))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- App keys: Realforce JIS keys (hwdb → prog1-4 → XF86Launch1-4) and the
-- Ctrl+Alt fallbacks used on GNOME.
local apps = {
    { "XF86Launch1", "M", "mattermost", host.mattermost },
    { "XF86Launch2", "F", host.browser.match, host.browser.cmd },
    { "XF86Launch3", "K", "kitty", main_terminal, "kitty-main" },
    { "XF86Launch4", "H", "horizon", host.horizon },
}
for _, a in ipairs(apps) do
    if a[4] then
        local f = function() pad.focus_or_launch(a[3], a[4], a[5]) end
        hl.bind(a[1], f)
        hl.bind("CTRL + ALT + " .. a[2], f)
    end
end

-- Arrows cross screens on their own; ALT variants jump/move whole screens.
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "d" }))

hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "d" }))

hl.bind(mod .. " + ALT + left", hl.dsp.focus({ monitor = "l" }))
hl.bind(mod .. " + ALT + right", hl.dsp.focus({ monitor = "r" }))
hl.bind(mod .. " + SHIFT + ALT + left", hl.dsp.window.move({ monitor = "l" }))
hl.bind(mod .. " + SHIFT + ALT + right", hl.dsp.window.move({ monitor = "r" }))

hl.bind(mod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
hl.bind(mod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }))
hl.bind(mod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }))

hl.bind("Print", hl.dsp.exec_cmd("~/.local/bin/hypr-screenshot"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("~/.local/bin/hypr-screenshot region"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd("~/.local/bin/hypr-screenshot copy-region"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +10%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })

for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("~/.local/bin/hypr-record toggle"), { description = "Toggle screen recording" })
