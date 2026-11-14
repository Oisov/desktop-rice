# Dynamite trial

QuickShell/QML implementation of the adjacent `dynamite-spec.html` contract.

Installed at `/home/oisov/.config/quickshell/dynamite`. The source in this directory is an editable copy; the live installation is independent of scratch cleanup. See `../dynamite-implementation.md` for installation details, verification and rollback.

Run `~/.local/bin/dynamite start` or use SUPER+Space (launcher), SUPER+A (controls), SUPER+T (themes), SUPER+W (wallpapers). Escape closes a panel. Stop with `~/.local/bin/dynamite stop`.

`shell.qml` owns the transparent layer surface, input region, fullscreen policy and transitions. `App.qml` owns state, native media/power/Bluetooth services and process lifecycles. `bridge.py` adapts existing PulseAudio, brightnessctl, NetworkManager, mako and wallpaper commands without shell interpolation. Theme and wallpaper selection is independent of the persisted applied state. The Python helper uses only the standard library.

Palettes live in `themes.json`. State is stored in `~/.local/state/dynamite/state.json`; wallpapers share `~/.cache/hypr-wallpaper/state` with the existing scheduler. A shell theme also recolors Waybar, its rofi menus (power, Wi-Fi) and slider-popup through `~/.local/state/dynamite/palette.{css,rasi}`; other applications are untouched.

No autostart or Waybar replacement was enabled. Changes to active source files hot-reload, so keep a terminal available with `dynamite stop` while editing. No regression tests were added.


### Native side strips
Both sides are now Quickshell (`LeftBar.qml`, `RightBar.qml`). Waybar is kept only
as a rollback configuration. `dynamite bars` / SUPER+B toggles the side strips.
The right lower row is opaque, 38 px tall and 95% wide; its layer surface keeps a
fixed size so opening it cannot reconfigure the top row. Wallpaper hover uses an
input-free background preview; it never writes the applied wallpaper state.
