# desktop-rice

Private copy of my Hyprland desktop appearance configs. Paths mirror `$HOME`.

## Included
- `.config/hypr` (hyprland.lua, hyprland.conf, hypridle, hyprlock, hyprpaper)
- `.config/quickshell/dynamite` (active bar)
- `.config/waybar` (rollback bar)
- `.config/rofi`, `.config/mako`, `.config/kitty`, `.config/fontconfig/fonts.conf`
- `.config/gtk-3.0` and `.config/gtk-4.0` (settings.ini, gtk.css, colors.css)
- `.local/bin`: dynamite, bar-menu-guard, bar-menu-rows, wifi-menu, hypr-power-menu, hypr-wallpaper, hypr-screenshot, hypr-startup-apps, hypr-toggle-compositor-fullscreen, hypr-kde-wallet, hypr-mattermost-scratchpad, slider-popup

Not included: backup files (`*.before-*`, `*.bak*`, `*.pre-*`, `*.orig`), caches, logs, `state.json`, generated `~/.local/state/dynamite/palette.*`, files over 1 MB (none at the moment), and non-appearance scripts such as `osp-screen`.

## Update
```
./sync.sh
jj commit -m "..." && jj git push
```
`sync.sh` copies live → repo only. Edit the `INCLUDE` array at its top to change what is tracked.

## Restore
Manual: copy the files back into `$HOME` yourself. Nothing here is symlinked or installed automatically.
