#!/usr/bin/env python3
"""Small adapters for the services this desktop already runs. No shell interpolation."""
import concurrent.futures
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

HOME = Path.home()
STATE = Path(os.environ.get('XDG_STATE_HOME', HOME / '.local/state')) / 'dynamite/state.json'
LIB = Path(os.environ.get('WALLPAPER_DIR', HOME / 'Pictures/wallpapers'))


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=45 if args[:3] in (('nmcli', 'connection', 'up'), ('nmcli', 'device', 'wifi')) else 8,
                            env={**os.environ, 'LC_ALL': 'C'})
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f'{args[0]} failed')
    return result.stdout.strip()


def audio():
    volume = re.search(r'(\d+)%', run('pactl', 'get-sink-volume', '@DEFAULT_SINK@'))
    return dict(available=True, volume=int(volume[1]), muted='yes' in run('pactl', 'get-sink-mute', '@DEFAULT_SINK@'))


def brightness():
    line = run('brightnessctl', '-m').split(',')
    return dict(available=True, value=int(line[3].rstrip('%')))


def network():
    enabled = run('nmcli', 'radio', 'wifi') == 'enabled'
    # No rescan: opening the panel must not wait for a radio scan.
    rows = run('nmcli', '-t', '--escape', 'no', '-f', 'ACTIVE,SIGNAL,SSID', 'device', 'wifi', 'list', '--rescan', 'no')
    active = next((r.split(':', 2) for r in rows.splitlines() if r.startswith('yes:')), None)
    return dict(available=True, enabled=enabled, signal=int(active[1]) if active else 0,
                ssid=active[2] if active else '')


def wifi_list():
    saved, active = {}, {}
    for row in run('nmcli', '-t', '-e', 'no', '-f', 'UUID,TYPE,ACTIVE', 'connection', 'show').splitlines():
        uuid, kind, enabled = row.split(':', 2)
        if kind != '802-11-wireless':
            continue
        ssid = run('nmcli', '-g', '802-11-wireless.ssid', '-e', 'no', 'connection', 'show', 'uuid', uuid)
        if ssid:
            saved.setdefault(ssid, uuid)
            if enabled == 'yes':
                saved[ssid] = active[ssid] = uuid
    networks = {}
    for row in run('nmcli', '-t', '-e', 'no', '-f', 'IN-USE,SIGNAL,SECURITY,SSID',
                   'device', 'wifi', 'list', '--rescan', 'no').splitlines():
        used, signal, security, ssid = row.split(':', 3)
        if not ssid:
            continue
        item = dict(ssid=ssid, signal=int(signal), secured=security not in ('', '--'),
                    connected=used == '*', uuid=saved.get(ssid, ''), activeUuid=active.get(ssid, ''))
        old = networks.get(ssid)
        if old is None or (item['connected'], item['signal']) > (old['connected'], old['signal']):
            networks[ssid] = item
    return dict(networks=sorted(networks.values(),
                key=lambda n: (not n['connected'], not bool(n['uuid']), -n['signal'])),
                radio=run('nmcli', 'radio', 'wifi') == 'enabled')


def wifi_action(args):
    name, *values = args
    if name == 'connect':
        ssid, uuid, *password = values
        if uuid:
            run('nmcli', 'connection', 'up', 'uuid', uuid)
        elif password:
            run('nmcli', 'device', 'wifi', 'connect', ssid, 'password', password[0])
        else:
            run('nmcli', 'device', 'wifi', 'connect', ssid)
    elif name == 'disconnect':
        run('nmcli', 'connection', 'down', 'uuid', values[0])
    elif name == 'radio' and values[0] in ('on', 'off'):
        run('nmcli', 'radio', 'wifi', values[0])
    elif name == 'rescan':
        run('nmcli', 'device', 'wifi', 'rescan')
    elif name != 'list':
        raise ValueError('Unsupported Wi-Fi action')
    return wifi_list()


def notifications():
    active = json.loads(run('makoctl', 'list', '-j'))
    history = json.loads(run('makoctl', 'history', '-j'))
    modes = run('makoctl', 'mode').splitlines()
    # Active items first; retain only one item per id when history overlaps.
    seen = set()
    items = []
    for item in active + history:
        if item['id'] not in seen:
            seen.add(item['id'])
            items.append({k: item.get(k, '') for k in ('id', 'app_name', 'summary', 'body')})
    return dict(available=True, dnd='do-not-disturb' in modes, activeCount=len(active), items=items[:30])


def themes():
    data = json.loads(Path(__file__).with_name('themes.json').read_text())
    valid = [x for x in data if isinstance(x, dict) and isinstance(x.get('id'), str)
             and isinstance(x.get('name'), str)
             and all(isinstance(x.get(k), str) and re.fullmatch(r'#[0-9a-fA-F]{6}', x[k])
                     for k in ('bg', 'surface', 'text', 'muted', 'accent'))]
    if not valid:
        raise RuntimeError('No valid palettes in themes.json')
    return valid


def wallpaper_state():
    try:
        return (HOME / '.cache/hypr-wallpaper/state').read_text().strip().split(' ', 2)[2]
    except (OSError, IndexError):
        return ''


def mix(base, tint, amount):
    a, b = (bytes.fromhex(c[1:]) for c in (base, tint))
    return '#' + bytes(round(x + (y - x) * amount) for x, y in zip(a, b)).hex()


TASK_ICON_THEME = HOME / '.local/share/icons/dynamite-waybar'
# Waybar-only monochrome marks traced from each app's own artwork; nothing else uses this theme.
TASK_ICONS = {'vivaldi-snapshot': Path('/usr/share/pixmaps/vivaldi-snapshot.png'),
              'vivaldi-stable': Path('/usr/share/pixmaps/vivaldi.png'),
              't3code': HOME / '.local/share/icons/com.t3tools.T3Code.desktop.png'}
# T3's own entry names an absolute PNG, so Waybar alone is pointed at t3code.desktop (Icon=t3code).
# shortcut: relies on ~/.local/share/applications/t3code.desktop existing; without it Waybar guesses an icon.


def export_task_icons(color):
    """Keep the light glyph of each app icon in the accent colour; its dark tile becomes transparent."""
    try:
        from PIL import Image, ImageChops
    except ImportError:
        return False
    folder = TASK_ICON_THEME / 'apps'
    folder.mkdir(parents=True, exist_ok=True)
    index = '[Icon Theme]\nName=dynamite-waybar\nInherits=hicolor\nDirectories=apps\n\n[apps]\nSize=128\nMinSize=8\nMaxSize=512\nType=Scalable\n'
    changed = False
    if not (TASK_ICON_THEME / 'index.theme').exists() or (TASK_ICON_THEME / 'index.theme').read_text() != index:
        (TASK_ICON_THEME / 'index.theme').write_text(index)
        changed = True
    for name, source in TASK_ICONS.items():
        if not source.exists():
            continue
        image = Image.open(source).convert('RGBA').resize((128, 128), Image.LANCZOS)
        glyph = image.convert('L').point(lambda v: max(0, min(255, (v - 170) * 255 // 55)))
        mark = Image.new('RGBA', image.size, color)
        mark.putalpha(ImageChops.multiply(glyph, image.getchannel('A')))
        target = folder / f'{name}.png'
        old = Image.open(target).tobytes() if target.exists() else b''
        if old != mark.tobytes():
            mark.save(target.with_suffix('.tmp'), 'PNG')
            os.replace(target.with_suffix('.tmp'), target)
            changed = True
    return changed


def export_waybar_icons(theme):
    """Pango spans color glyphs only; CSS keeps their adjacent labels neutral."""
    path = HOME / '.config/waybar/config.jsonc'
    if not path.exists():
        return False
    icons_changed = export_task_icons(theme['accent'])
    config = json.loads(path.read_text())
    before = json.dumps(config)
    def icon(glyph, color=None, extra=''):
        return f"<span foreground='{color or theme['accent']}'{extra}>{glyph}</span>"
    formats = {
        'backlight': {'format': icon('󰃠') + ' {percent}%'},
        'pulseaudio': {'format': icon('{icon}', extra=" size='125%' rise='-1pt'") + ' {volume}%',
                      'format-muted': icon('󰝟', theme['muted'], " size='125%' rise='-1pt'") + ' {volume}%'},
        'network': {'format-wifi': icon('󰤨') + ' {essid}', 'format-ethernet': icon('󰈀'),
                    'format-linked': icon('󰈀'), 'format-disconnected': icon('󰤭', theme['muted'])},
        'battery': {'format': icon('{icon}') + ' {capacity}%',
                    'format-charging': icon('󰂄') + ' {capacity}%',
                    'format-plugged': icon('󰚥') + ' {capacity}%',
                    'format-warning': icon('{icon}', '#dfb479') + ' {capacity}%',
                    'format-critical': icon('{icon}', '#e18593') + ' {capacity}%'},
        'temperature': {'format': icon('') + ' {temperatureC}°C',
                        'format-critical': icon('', '#dfb479') + ' {temperatureC}°C'},
        'custom/media': {'format': icon('{icon}') + ' {text}'},
    }
    if (TASK_ICON_THEME / 'index.theme').exists():
        formats['wlr/taskbar'] = {'icon-theme': ['dynamite-waybar'],
                                  'app_ids-mapping': {'com.t3tools.T3Code': 't3code'}}
    for module, values in formats.items():
        if module in config:
            config[module].update(values)
    if json.dumps(config) == before:
        return icons_changed
    fd, temporary = tempfile.mkstemp(prefix='.icons-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(config, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return True


def export_palette(theme):
    """Hand the applied palette to Waybar, its rofi menus and slider-popup. Returns True if it changed."""
    # Same state tints as App.tone() in QML: hover 0x30/255, pressed 0x55/255 toward the accent.
    tokens = {k: theme[k] for k in ('bg', 'surface', 'text', 'muted', 'accent')}
    tokens.update(hover=mix(theme['surface'], theme['accent'], 0x30 / 255),
                  pressed=mix(theme['surface'], theme['accent'], 0x55 / 255),
                  line=mix(theme['surface'], theme['accent'], 0.25))
    changed = export_waybar_icons(theme)
    for name, text in (('palette.css', ''.join(f'@define-color {k} {v};\n' for k, v in tokens.items())),
                       ('palette.rasi', '* {\n' + ''.join(f'  {k}: {v};\n' for k, v in tokens.items()) + '}\n')):
        target = STATE.parent / name
        if not target.exists() or target.read_text() != text:
            STATE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            target.with_suffix('.tmp').write_text(text)
            os.replace(target.with_suffix('.tmp'), target)
            changed = True
    return changed


def catalog():
    palettes = themes()
    try:
        selected = json.loads(STATE.read_text()).get('theme', 'tidepool')
    except (OSError, ValueError, AttributeError):
        selected = 'tidepool'
    applied = next((x for x in palettes if x['id'] == selected), palettes[0])
    export_palette(applied)
    return dict(themes=palettes, appliedTheme=applied['id'])


def snapshot():
    result = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = {name: pool.submit(fn) for name, fn in
                [('audio', audio), ('brightness', brightness), ('network', network), ('notifications', notifications)]}
        for name, job in jobs.items():
            try:
                result[name] = job.result()
            except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as err:
                result[name] = dict(available=False, error=str(err))
    result['temperature'] = None
    for hwmon in Path('/sys/class/hwmon').glob('hwmon*'):
        try:
            if (hwmon / 'name').read_text().strip() == 'coretemp':
                result['temperature'] = int((hwmon / 'temp1_input').read_text()) / 1000
                break
        except (OSError, ValueError):
            continue
    result['appliedWallpaper'] = wallpaper_state()
    return result


def action(args):
    name, *values = args
    if name in ('volume', 'brightness'):
        value = round(float(values[0]))
        if name == 'volume':
            run('pactl', 'set-sink-volume', '@DEFAULT_SINK@', f'{max(0, min(100, value))}%')
            run('pactl', 'set-sink-mute', '@DEFAULT_SINK@', '0')
        else:
            run('brightnessctl', '-q', 'set', f'{max(5, min(100, value))}%')
    elif name == 'mute':
        run('pactl', 'set-sink-mute', '@DEFAULT_SINK@', 'toggle')
    elif name == 'wifi' and values[0] in ('on', 'off'):
        run('nmcli', 'radio', 'wifi', values[0])
    elif name == 'focus':
        run('makoctl', 'mode', '-t', 'do-not-disturb')
    elif name == 'theme':
        theme_id = values[0]
        theme = next((t for t in themes() if t['id'] == theme_id), None)
        if theme is None:
            raise ValueError('Unknown theme')
        STATE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix='.state-', dir=STATE.parent)
        try:
            with os.fdopen(fd, 'w') as stream:
                json.dump({'theme': theme_id}, stream)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, STATE)
        finally:
            Path(temporary).unlink(missing_ok=True)
        if export_palette(theme):
            subprocess.run(['pkill', '-USR2', '-x', 'waybar'])  # Waybar re-reads style.css and its palette import
        return dict(appliedTheme=theme_id)
    elif name == 'wallpaper':
        path = Path(values[0]).resolve(strict=True)
        if not path.is_file() or not path.is_relative_to(LIB.resolve()) or path.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp'):
            raise ValueError('Choose an image from your wallpaper library')
        run(str(HOME / '.local/bin/hypr-wallpaper'), 'set', str(path))
        return dict(appliedWallpaper=wallpaper_state())
    else:
        raise ValueError('Unsupported action')
    return {}


def main():
    cmd = sys.argv[1]
    if cmd == 'wifi':
        return wifi_action(sys.argv[2:])
    if cmd == 'snapshot':
        return snapshot()
    if cmd == 'catalog':
        return catalog()
    if cmd == 'wallpapers':
        slots = {}
        for slot in ('morning', 'day', 'evening', 'night'):
            folder = LIB / slot
            slots[slot] = [dict(path=str(p), name=p.name, url=p.as_uri()) for p in sorted(folder.glob('*'))
                           if p.is_file() and p.suffix.lower() in ('.png', '.jpg', '.jpeg', '.webp') and '.wide.' not in p.name.lower()]
        return dict(wallpapers=slots, appliedWallpaper=wallpaper_state())
    if cmd == 'motion':
        try:
            reduced = run('gsettings', 'get', 'org.gnome.desktop.interface', 'enable-animations') == 'false'
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            reduced = False
        return dict(reducedMotion=os.environ.get('DYNAMITE_REDUCED_MOTION') == '1' or reduced)
    if cmd == 'action':
        return action(sys.argv[2:])
    raise ValueError('Unsupported command')


if __name__ == '__main__':
    try:
        print(json.dumps(dict(ok=True, **main())))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired, IndexError) as error:
        print(json.dumps(dict(ok=False, error=str(error))))
        sys.exit(1)
