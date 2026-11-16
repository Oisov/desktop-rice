# desktop-rice

My Hyprland desktop appearance configs, including the Dynamite Quickshell bar
and wallpaper picker. Paths mirror `$HOME`. Wallpaper images are not included.

[![Dynamite bar and wallpaper picker on a clean desktop](docs/screenshots/dynamite-wallpaper-picker.png)](docs/screenshots/dynamite-wallpaper-picker.png)

*Native 2560 × 1440 capture. Click the image to view it at full resolution.*

Wallpaper artwork by **[Alena Aenami (Aenami)](https://aenamiart.artstation.com/)**.
See [wallpaper credits and downloads](#wallpaper-credits-and-downloads) below.

## Included
- `.config/hypr` (hyprland.lua, hyprland.conf, hypridle, hyprlock, hyprpaper)
- `.config/quickshell/dynamite` (active bar, desktop clock, launcher, themes and wallpaper picker)
- `.config/systemd/user/{swww.service,hypr-wallpaper.service,hypr-wallpaper.timer}` (wallpaper daemon and time-of-day schedule)
- `.config/waybar` (rollback bar)
- `.config/rofi`, `.config/mako`, `.config/kitty`, `.config/fontconfig/fonts.conf`
- `.config/gtk-3.0` and `.config/gtk-4.0` (settings.ini, gtk.css, colors.css)
- `.local/bin`: dynamite, bar-menu-guard, bar-menu-rows, wifi-menu, hypr-power-menu, hypr-wallpaper, hypr-screenshot, hypr-startup-apps, hypr-toggle-compositor-fullscreen, hypr-kde-wallet, hypr-mattermost-scratchpad, slider-popup

Not included: backup files (`*.before-*`, `*.bak*`, `*.pre-*`, `*.orig`), caches, logs, `state.json`, generated `~/.local/state/dynamite/palette.*`, live configuration files over 1 MB (documentation screenshots are kept separately), and non-appearance scripts such as `osp-screen`.

## Update
```
./sync.sh
git add -A
git commit -m "Update desktop configuration"
git push
```
`sync.sh` copies live → repo only. Edit the `INCLUDE` array at its top to change what is tracked. Run it on the machine whose configuration you want to save; this snapshot was updated from the office desktop. Missing source paths are reported and retained from the previous snapshot. Nested Git repositories and the downloaded kitty theme collection are excluded.

## Restore
Manual: copy the files back into `$HOME` yourself. Nothing here is symlinked or installed automatically.


## Current monitor and panel behavior

The office monitor layout lives in `.config/hypr/host.lua`: workspaces 1–5 use
DP-1 on the right, workspaces 6–10 use HDMI-A-2 on the left. `bar_screen` selects
the bar independently of workspace assignment. The bar is on HDMI-A-2 and the
bottom-right desktop clock is on DP-1. Adapt these output names, positions and
application commands to your machine before copying the Hyprland configuration.

Keyboard panels open on the focused monitor and remain there until closed. On
the monitor without the bar, the panel is centered and the bar's workspace
island remains visible on the other monitor. Clicking that island brings the
overview back to the bar monitor.

- Super+D / Super+Space: launcher and overview.
- Super+W: wallpaper picker.
- Super+Shift+T: theme picker. Super+T opens the terminal scratchpad.
- Escape or the same panel shortcut: close.

Dynamite needs a compatible Quickshell build (the office desktop uses 0.3.2),
Hyprland with its Lua configuration/API, Python 3, and the Qt Quick Controls and
Qt5Compat GraphicalEffects modules. Fonts are Barlow Condensed, JetBrainsMono
Nerd Font Propo and Symbols Nerd Font. Audio, networking and brightness controls
use pactl/wpctl, NetworkManager/nmcli and brightnessctl when available. See
`.config/quickshell/dynamite/README.md` for details. This repository is a personal
configuration snapshot, not an automatic installer; legacy rollback files and
optional helpers may refer to additional locally installed programs.

## Wallpaper swapper (images not included)

The custom `.local/bin/hypr-wallpaper` script uses swww to display images and
ImageMagick (`magick`) to split panoramic images across monitors. It also needs
Bash, Python 3, hyprctl and standard GNU command-line tools.

Supply your own PNG, JPG, JPEG or WebP files in these directories:

```text
~/Pictures/wallpapers/
  morning/
  day/
  evening/
  night/
```

Set `WALLPAPER_DIR` to use another library location (export it for the shell;
set it in the wallpaper service environment too if you use the timer). Files
named `*.wide.png` (or another supported extension with `.wide.` in the name)
are split left-to-right across monitors; ordinary images are paired per monitor.
The script keeps the current slot's daily selection, and `hypr-wallpaper next`
chooses another. `hypr-wallpaper set FILE` applies a specific file.

The slots change at 05:00, 09:30, 16:30 and 20:00. Once the three user unit files
are installed, enable the schedule with:

```sh
systemctl --user daemon-reload
systemctl --user enable --now hypr-wallpaper.timer
```

Wallpaper images, thumbnails, caches and applied selection state are not part of
this repository. `wallpaper-tags.json` contains optional search tags and relative
filenames only; missing library entries are not downloaded.

## Wallpaper credits and downloads

Most wallpapers in my personal collection, including the featured desktop
background, are by **[Alena Aenami (Aenami)](https://aenamiart.artstation.com/)**.
The desktop shell and wallpaper picker are my configuration; the artwork is hers.
This is not a complete attribution list for every thumbnail or image in my library.

To get wallpapers for your own setup:

1. Browse Aenami's [official ArtStation store](https://aenamiart.artstation.com/store)
   for downloadable wallpaper packs. For example,
   [Wallpaper Pack 03](https://aenamiart.artstation.com/store/dBvng/wallpaper-pack-03-15-artworks-in-4k)
   contains 15 artworks in 4K. Her [Patreon](https://www.patreon.com/aenamiart/about)
   also offers HD wallpaper rewards; check the current membership details there.
2. Download your purchased pack from the artist's store and extract it locally.
3. Put your chosen images into the `morning`, `day`, `evening` and `night` folders
   under `~/Pictures/wallpapers`, grouped by the mood you want at each time.

```sh
mkdir -p "$HOME/Pictures/wallpapers/"{morning,day,evening,night}
# Example: copy a downloaded image into the daytime collection.
cp "/path/to/downloaded-artwork.jpg" "$HOME/Pictures/wallpapers/day/"
hypr-wallpaper next
```

The picker reads your local library; it does not fetch images automatically.
Use ordinary filenames for standard wallpapers, and reserve `.wide.` filenames
for panoramas you want split across monitors. The artwork remains separate from
the MIT-licensed configuration and is not redistributed as a wallpaper pack here.

## License

The custom code and configuration in this repository are available under the
[MIT License](LICENSE). Existing third-party copyright and license notices
continue to apply to their respective material. Wallpaper library files are not
bundled. Artwork visible in screenshots retains its original rights and is not
covered by the MIT license.

This is a personal desktop configuration: adapt the monitor layout, application
commands and home paths before using it. The older rollback configs still
contain `/home/oisov` paths that another user must replace.
