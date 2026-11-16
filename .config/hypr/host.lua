-- Per-machine bits, rendered by chezmoi. Everything else lives in hyprland.lua.
-- Office PC: terminals/workspaces 1-5 on right DP, browser/workspaces 6-10 on left HDMI.
local main_terminal = "kitty --class kitty-main tmux new-session -A -s 0"
return {
    scale = 1,
    monitors = {
        { output = "HDMI-A-2", mode = "2560x1440@59.95", position = "0x0", scale = 1 },
        { output = "DP-1", mode = "2560x1440@59.95", position = "2560x0", scale = 1 },
    },
    primary = "DP-1",
    bar_screen = "HDMI-A-2",
    secondary = "HDMI-A-2",
    main_terminal = main_terminal,
    browser = { match = "firefox", cmd = "firefox" },
    mattermost = "flatpak run com.mattermost.Desktop",
    mail = "evolution",
    horizon = "horizon-client-next",
    polkit = "systemctl --user start hyprpolkitagent",
    autostart = {
        "~/.local/bin/hypr-wallpaper",
        "nm-applet",
        "blueman-applet",
        main_terminal,
        "firefox",
        "flatpak run com.mattermost.Desktop",
    },
}
