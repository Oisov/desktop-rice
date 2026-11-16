# Dynamite trial

Quickshell/QML desktop shell with launcher, theme and wallpaper panels.

Install this directory at `~/.config/quickshell/dynamite` and the launcher at `~/.local/bin/dynamite`. See the repository README for dependencies and machine-specific setup.

Run `~/.local/bin/dynamite start` or use SUPER+D / SUPER+Space (overview), SUPER+Shift+T (themes), SUPER+W (wallpapers). Escape closes a panel. Stop with `~/.local/bin/dynamite stop`.

`shell.qml` owns the transparent layer surface, input region, fullscreen policy and transitions. `App.qml` owns theme, media, power, Bluetooth and helper process state. `bridge.py` adapts existing PulseAudio, brightnessctl, NetworkManager, mako and wallpaper commands without shell interpolation. Theme and wallpaper selection is independent of the persisted applied state. The Python helper uses only the standard library.

Palettes live in `themes.json`. State is stored in `~/.local/state/dynamite/state.json`; wallpapers share `~/.cache/hypr-wallpaper/state` with the existing scheduler. A shell theme also recolors Waybar, its rofi menus (power, Wi-Fi) and slider-popup through `~/.local/state/dynamite/palette.{css,rasi}`; other applications are untouched.

The laptop and office workstation autostart Dynamite instead of Waybar. Changes to active source files hot-reload, so keep a terminal available with `dynamite stop` while editing. No regression tests were added.


### Native side strips
Both sides are now Quickshell (`LeftBar.qml`, `RightBar.qml`). Waybar is kept only
as a rollback configuration. `dynamite bars` / SUPER+B toggles the side strips.
The right lower row is opaque, 38 px tall and 95% wide; its layer surface keeps a
fixed size so opening it cannot reconfigure the top row. Wallpaper hover uses an
input-free background preview; it never writes the applied wallpaper state.

### Structure
`LeftBar.qml` and `RightBar.qml` contain their surfaces, bar items and menu instances.
`App.qml` shares the right strip’s natural width with the left strip; the left
media item fills the remaining width.
`MenuFrame.qml` shares tab geometry, the two reveal strips, input regions and
hover/pin/focus timing. Plain items in `menus/` own their state, keys and persistent
L2/L3 content; the directory is imported directly. `Notifications.qml` owns the
notification server, history, DND state and deferred toast queue. IPC names map to
menu objects in `shell.qml`. `Overview.qml` combines workspace windows, frequent
apps and fuzzy search in one growing surface (300 ms hover or pinned keyboard
entry); `launcher` remains the shortcut/IPC name. `/` searches home filenames via
plocate plus recent fd results; bridge searches run asynchronously. `bridge.py`
also handles qalc and capped launch history in state.json: score = count ×
0.5^(days since last use / 14), at most 200 entries. Bluetooth lives in Wi-Fi’s
L2; keep awake lives in Power’s L2. Status, Controls and Launcher are retired.
Keyboard entry joins the opaque side strips in 150 ms, then drops the panel in
150 ms; reduced motion is instant. Themes and Wallpapers keep their own pickers.
`menus/CpuMenu.qml` owns the CPU L2 row (no L3). The bridge reads `/proc/stat`
deltas every two seconds: total usage always, per-core usage only while that menu
is open. Temperature remains in the service snapshot and appears in the CPU menu.

Overview exclusions live in `overview.json`: `hiddenApps` accepts desktop entry ids (with or without `.desktop`). The helper also filters Hidden/NoDisplay entries and missing Exec/TryExec executables, honoring XDG directory precedence. Reload the shell after editing exclusions or installing applications.


### Laptop and workstation

The same QML/Python files run on both hosts. `bin/dynamite` reads `bar_screen` (falling back to `primary`) from
`~/.config/hypr/host.lua` when present, or respects `DYNAMITE_BAR_SCREEN`.
Otherwise the shell uses an internal panel, then the first connected screen.
If the preferred screen is disconnected, the full shell moves to an available
screen. Desktop clocks follow connected screens without the bar; only the selected screen has
bars, menus and an exclusive zone. Office: HDMI-A-2 has the shell, DP-1 the bottom-right clock.
Keyboard launcher, theme and wallpaper panels open on the focused monitor. On a
monitor without the bar, they are centered; bar-monitor panels keep their top
island placement. The target stays fixed until the panel closes. The bar keeps
its workspace island while a panel is open on another monitor; clicking that
island brings the overview back to the bar monitor.
Monitor positions/scales remain compositor settings in host.lua.

`layout.py` listens to Hyprland's event socket. On clock-only monitors, a workspace
with exactly one non-floating window gets compositor-only fullscreen (internal 2,
client 0). App chrome remains visible. Opening another window or moving the window
to the bar monitor restores only fullscreen owned by this policy. Super+F can
restore the gapped layout; that override lasts until the workspace's window
membership changes. Floating windows, special workspaces, and manually fullscreened
apps are not automatically fullscreened. Stopping the shell restores owned state;
a shell restart starts a new policy session.

Battery and backlight controls disappear when unavailable. Backlight operations
explicitly target backlight devices rather than keyboard LEDs. Audio prefers a
working pactl server, falling back to wpctl; both use the current default sink.
NetworkManager supplies wired/Wi-Fi state and Wi-Fi controls. Without its tool or
service, ip supplies read-only default-route status. Unavailable services do not
prevent the rest of the shell from starting. Bluetooth controls require an adapter;
settings buttons use installed settings apps. Wi-Fi remains accessible over Ethernet.

The office machine uses a user-local Quickshell 0.3.2 build in ~/.local/bin, because
Fedora's 0.2.1 package lacks the required Hyprland API. Its source and build are in
~/.local/src/quickshell-0.3.2; rebuild after incompatible Qt upgrades. Both hosts
have Barlow Condensed, JetBrainsMono Nerd Font Propo, and Symbols Nerd Font.
Backups of the original desktop config/helpers are under
~/.local/state/dynamite/backups/20261116-portable on each machine.


### Recording

`hypr-record` (or `hypr-record toggle`) starts/stops a silent MP4 recording of the
focused monitor. Super+Shift+Print toggles it on both hosts. `hypr-record region`
selects an area; `hypr-record status` prints the active output file.
`hypr-record start /path/demo.mp4` selects a filename, and `hypr-record stop`
finishes it. Recordings default to ~/Videos/Recordings, with a matching encoder
log. Output is H.264/yuv420p, at most 1920×1080, 60 fps, CRF 24. Requires
wf-recorder and slurp (for region recording).

On the laptop, `dynamite-demo` records the 39-second shell tour with a top-right clock/calendar outro on an unused
workspace, then restores the original workspace, cursor and DND state. It uses
Hyprland, wlrctl, Quickshell IPC and hypr-record; it opens the wallpaper/theme
pickers without applying a selection and never activates the power actions.

Switching between Quicksearch, Themes and Wallpapers keeps the centre surface
open and animates its size directly between contents. Pressing the active mode
shortcut again still closes it.
