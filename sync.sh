#!/usr/bin/env bash
# Copy live desktop appearance configs from $HOME into this repo (live -> repo only).
set -euo pipefail

INCLUDE=(
  .config/hypr
  .config/quickshell/dynamite
  .config/systemd/user/swww.service
  .config/systemd/user/hypr-wallpaper.service
  .config/systemd/user/hypr-wallpaper.timer
  .config/waybar
  .config/rofi
  .config/mako
  .config/kitty
  .config/gtk-3.0/settings.ini
  .config/gtk-3.0/gtk.css
  .config/gtk-3.0/colors.css
  .config/gtk-4.0/settings.ini
  .config/gtk-4.0/gtk.css
  .config/gtk-4.0/colors.css
  .config/fontconfig/fonts.conf
  .local/bin/dynamite
  .local/bin/bar-menu-guard
  .local/bin/bar-menu-rows
  .local/bin/wifi-menu
  .local/bin/hypr-power-menu
  .local/bin/hypr-wallpaper
  .local/bin/hypr-screenshot
  .local/bin/hypr-startup-apps
  .local/bin/hypr-toggle-compositor-fullscreen
  .local/bin/hypr-kde-wallet
  .local/bin/hypr-mattermost-scratchpad
  .local/bin/slider-popup
)

EXCLUDES=('*.before-*' '*.bak*' '*.pre-*' '*.orig' '__pycache__' '*.log' 'state.json' '.cache' '.git' 'kitty-themes' '*.pyc')

cd "$(dirname "$0")"
args=(-a --relative --delete --prune-empty-dirs --max-size=1M)
for e in "${EXCLUDES[@]}"; do args+=(--exclude="$e"); done
for p in "${INCLUDE[@]}"; do
  [ -e "$HOME/$p" ] || { echo "missing: $p" >&2; continue; }
  args+=("$HOME/./$p")
done
rsync "${args[@]}" .

echo "Files over 1 MB skipped:"
for p in "${INCLUDE[@]}"; do
  [ -e "$HOME/$p" ] && find "$HOME/$p" -type f -size +1M -printf '  %p\n'
done
