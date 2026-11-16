#!/usr/bin/env python3
"""Small adapters for the services this desktop already runs. No shell interpolation."""
import configparser
import shlex
import shutil
import concurrent.futures
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import fcntl
import contextlib

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
    if shutil.which('pactl'):
        try:
            volume = re.search(r'(\d+)%', run('pactl', 'get-sink-volume', '@DEFAULT_SINK@'))
            return dict(available=True, backend='pactl', volume=int(volume[1]),
                        muted='yes' in run('pactl', 'get-sink-mute', '@DEFAULT_SINK@'))
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            pass
    if shutil.which('wpctl'):
        value = run('wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@')
        return dict(available=True, backend='wpctl', volume=round(float(value.split()[1]) * 100), muted='MUTED' in value)
    return dict(available=False)


def brightness():
    if not shutil.which('brightnessctl') or not any(Path('/sys/class/backlight').iterdir()):
        return dict(available=False)
    line = run('brightnessctl', '--class=backlight', '-m').split(',')
    return dict(available=True, value=int(line[3].rstrip('%')))


def networkmanager_network():
    devices = [row.split(':', 3) for row in run('nmcli', '-t', '-e', 'no', '-f', 'DEVICE,TYPE,STATE,CONNECTION', 'device').splitlines()]
    wifi = any(row[1] == 'wifi' for row in devices)
    connected = [row for row in devices if row[2] == 'connected' and row[1] in ('ethernet', 'wifi')]
    active = next((row for row in connected if row[1] == 'ethernet'), connected[0] if connected else None)
    enabled = wifi and run('nmcli', 'radio', 'wifi') == 'enabled'
    ssid, signal = '', 0
    if wifi and enabled:
        rows = run('nmcli', '-t', '--escape', 'no', '-f', 'ACTIVE,SIGNAL,SSID', 'device', 'wifi', 'list', '--rescan', 'no')
        ap = next((r.split(':', 2) for r in rows.splitlines() if r.startswith('yes:')), None)
        if ap:
            ssid, signal = ap[2], int(ap[1])
    return dict(available=True, backend='nmcli', wifiAvailable=wifi, enabled=enabled, ssid=ssid, signal=signal,
                connected=bool(active), kind=active[1] if active else '', device=active[0] if active else '',
                connection=active[3] if active else '')


def network():
    if shutil.which('nmcli'):
        try:
            return networkmanager_network()
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            pass
    # Read-only network status still works without NetworkManager.
    routes = sorted(json.loads(run('ip', '-j', 'route', 'show', 'default')), key=lambda route: route.get('metric', 0))
    device = next((row['dev'] for row in routes if 'dev' in row), '')
    wireless = bool(device) and (Path('/sys/class/net') / device / 'wireless').exists()
    return dict(available=True, backend='ip', wifiAvailable=False, enabled=False, connected=bool(device),
                kind='wifi' if wireless else 'ethernet' if device else '', device=device, ssid='', connection=device)


def settings_commands():
    choices = {
        'volume': [['pavucontrol'], ['systemsettings', 'kcm_pulseaudio'], ['gnome-control-center', 'sound']],
        'network': [['nm-connection-editor'], ['systemsettings', 'kcm_networkmanagement'], ['gnome-control-center', 'network']],
        'brightness': [['systemsettings', 'kcm_powerdevilprofilesconfig'], ['gnome-control-center', 'power']],
        'battery': [['kcmshell6', 'kcm_energyinfo'], ['gnome-control-center', 'power']],
    }
    return {key: next((cmd for cmd in commands if shutil.which(cmd[0])), []) for key, commands in choices.items()}


def wifi_list():
    if not network().get('wifiAvailable'):
        return dict(networks=[], radio=False)
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
        value = (HOME / '.cache/hypr-wallpaper/state').read_text().strip().split(' ', 2)[2]
        if value.startswith(('pair ', 'wide ')):
            return value.split(' ', 2)[1]
        return value
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


def export_hyprland(theme):
    """Persist border colours for config reloads, and update the running Lua config."""
    accent = theme['accent'][1:]
    darker = mix(theme['accent'], '#000000', 0.15)[1:]
    muted = theme['muted'][1:]
    palette = ('-- Generated by dynamite/bridge.py.\nreturn {\n'
               '    active_border = { colors = { "rgba(' + accent + 'ff)", "rgba(' + darker + 'ff)" }, angle = 45 },\n'
               '    inactive_border = "rgba(' + muted + 'aa)",\n}\n')
    target = STATE.parent / 'palette.lua'
    if not target.exists() or target.read_text() != palette:
        STATE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix='.palette-', dir=STATE.parent)
        try:
            with os.fdopen(fd, 'w') as stream:
                stream.write(palette)
            os.replace(temporary, target)
        finally:
            Path(temporary).unlink(missing_ok=True)
    # Offline exports still persist the palette for the next compositor start.
    if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        reply = run('hyprctl', 'eval', 'hl.config({general={col=dofile(' + json.dumps(str(target), ensure_ascii=False) + ')}})')
        if reply != 'ok':
            raise RuntimeError('Hyprland border update failed: ' + reply)


def firefox_palette(theme):
    """Pywalfox's default dark template uses 0 for frame, 10/13 for accents, 15 for text."""
    bg, surface, text, muted, accent = (theme[k] for k in ('bg', 'surface', 'text', 'muted', 'accent'))
    colors = [bg, surface, accent, accent, accent, accent, muted, text,
              surface, surface, accent, accent, accent, accent, muted, text]
    return dict(wallpaper='', special=dict(background=bg, foreground=text, cursor=accent),
                colors={f'color{i}': value for i, value in enumerate(colors)})


def export_firefox(theme):
    """Refresh an opted-in browser through Pywalfox; browser outages never block the shell."""
    config = Path(os.environ.get('XDG_CONFIG_HOME', HOME / '.config')) / 'dynamite/firefox-sync'
    if not config.is_file():
        return False
    target = Path(os.environ.get('XDG_CACHE_HOME', HOME / '.cache')) / 'dynamite/firefox/wal/colors.json'
    temporary = None
    try:
        data = json.dumps(firefox_palette(theme), indent=2) + '\n'
        if target.exists() and target.read_text() == data:
            return False
        target.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix='.colors-', dir=target.parent)
        with os.fdopen(fd, 'w') as stream:
            stream.write(data)
        os.replace(temporary, target)
        wrapper = HOME / '.local/bin/dynamite-firefox'
        if os.access(wrapper, os.X_OK):
            subprocess.run([str(wrapper), 'update'], capture_output=True, timeout=2, check=False)
        return True
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f'Dynamite Firefox sync: {error}', file=sys.stderr)
        return False
    finally:
        if temporary is not None:
            Path(temporary).unlink(missing_ok=True)


def export_palette(theme):
    """Hand the applied palette to Waybar, its rofi menus and slider-popup. Returns True if it changed."""
    # Same state tints as App.tone() in QML: hover 0x30/255, pressed 0x55/255 toward the accent.
    tokens = {k: theme[k] for k in ('bg', 'surface', 'text', 'muted', 'accent')}
    tokens.update(hover=mix(theme['surface'], theme['accent'], 0x30 / 255),
                  pressed=mix(theme['surface'], theme['accent'], 0x55 / 255),
                  line=mix(theme['surface'], theme['accent'], 0.25))
    export_hyprland(theme)
    changed = export_waybar_icons(theme)
    for name, text in (('palette.css', ''.join(f'@define-color {k} {v};\n' for k, v in tokens.items())),
                       ('palette.rasi', '* {\n' + ''.join(f'  {k}: {v};\n' for k, v in tokens.items()) + '}\n')):
        target = STATE.parent / name
        if not target.exists() or target.read_text() != text:
            STATE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            target.with_suffix('.tmp').write_text(text)
            os.replace(target.with_suffix('.tmp'), target)
            changed = True
    export_firefox(theme)
    return changed


def read_state():
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return {}


_lock_depth = 0


@contextlib.contextmanager
def state_lock():
    # One exclusive lock across processes for every read-modify-write of state.json (re-entrant within a process).
    global _lock_depth
    if _lock_depth == 0:
        STATE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        handle = open(STATE.with_suffix('.lock'), 'w')
        fcntl.flock(handle, fcntl.LOCK_EX)
    _lock_depth += 1
    try:
        yield
    finally:
        _lock_depth -= 1
        if _lock_depth == 0:
            handle.close()


def save_state(**changes):
    with state_lock():
        state = read_state()
        state.update(changes)
        STATE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix='.state-', dir=STATE.parent)
        try:
            with os.fdopen(fd, 'w') as stream:
                json.dump(state, stream)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, STATE)
        finally:
            Path(temporary).unlink(missing_ok=True)


def frecency():
    # Score = launch count × 0.5 ** (days since last use / 14).
    now = time.time()
    return {key: item['count'] * 0.5 ** (max(0, now - item['last']) / 86400 / 14)
            for key, item in read_state().get('launches', {}).items()}


def record_launch(identifier):
    with state_lock():
        launches = read_state().get('launches', {})
        launches[identifier] = dict(count=launches.get(identifier, {}).get('count', 0) + 1, last=time.time())
        launches = dict(sorted(launches.items(), key=lambda row: row[1]['last'], reverse=True)[:200])
        save_state(launches=launches)
    return dict(frecency=frecency())


def catalog():
    palettes = themes()
    try:
        selected = json.loads(STATE.read_text()).get('theme', 'tidepool')
    except (OSError, ValueError, AttributeError):
        selected = 'tidepool'
    applied = next((x for x in palettes if x['id'] == selected), palettes[0])
    export_palette(applied)
    return dict(themes=palettes, appliedTheme=applied['id'], dnd=read_state().get('dnd', False))


def system_sample():
    pressure = {}
    for resource in ('cpu', 'memory'):
        try:
            pressure[resource] = {
                fields[0]: {key: float(value) for key, value in
                            (part.split('=') for part in fields[1:])}
                for fields in (line.split() for line in
                               Path('/proc/pressure', resource).read_text().splitlines())}
        except (OSError, ValueError):
            pressure[resource] = {}
    memory = {}
    for line in Path('/proc/meminfo').read_text().splitlines():
        key, value = line.split(':', 1)
        if key in ('MemTotal', 'MemAvailable'):
            memory[key] = int(value.split()[0])
    temperature, limit = None, 100
    for hwmon in Path('/sys/class/hwmon').glob('hwmon*'):
        try:
            if (hwmon / 'name').read_text().strip() not in ('coretemp', 'k10temp', 'zenpower'):
                continue
            temperature = int((hwmon / 'temp1_input').read_text()) / 1000
            for name in ('temp1_max', 'temp1_crit'):
                try:
                    value = int((hwmon / name).read_text()) / 1000
                    if value > 0:
                        limit = value
                        break
                except (OSError, ValueError):
                    continue
            break
        except (OSError, ValueError):
            continue
    # Fullest of / and /home (same filesystem is counted once).
    disk = None
    for mount in ('/', '/home'):
        try:
            stat = os.statvfs(mount)
            used = 100 * (1 - stat.f_bavail / stat.f_blocks) if stat.f_blocks else 0
            if disk is None or used > disk['used']:
                disk = dict(mount=mount, used=used)
        except OSError:
            continue
    return dict(pressure=pressure, memory=memory, temperature=temperature, temperatureLimit=limit, disk=disk)


def cpu_stream(per_core):
    previous = {}
    while True:
        current = {}
        with open('/proc/stat') as stream:
            for line in stream:
                fields = line.split()
                if not fields or not fields[0].startswith('cpu'):
                    break
                if fields[0] != 'cpu' and not per_core:
                    break
                # Guest time is already included in user/nice time.
                ticks = list(map(int, fields[1:9]))
                current[fields[0]] = (sum(ticks), ticks[3] + ticks[4])
        usage = {}
        for name, (total, idle) in current.items():
            old_total, old_idle = previous.get(name, (total, idle))
            elapsed = total - old_total
            usage[name] = max(0, min(100, 100 * (1 - (idle - old_idle) / elapsed))) if elapsed > 0 else 0
        print(json.dumps(dict(total=usage.get('cpu', 0),
                              cores=[value for name, value in usage.items() if name != 'cpu'],
                              **system_sample())), flush=True)
        previous = current
        time.sleep(2)


def snapshot():
    result = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = {name: pool.submit(fn) for name, fn in
                [('audio', audio), ('brightness', brightness), ('network', network)]}
        for name, job in jobs.items():
            try:
                result[name] = job.result()
            except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as err:
                result[name] = dict(available=False, error=str(err))
    result['settings'] = settings_commands()
    result['tools'] = {name: bool(shutil.which(name)) for name in ('pactl', 'nmcli', 'wpctl')}
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
            if audio().get('backend') == 'wpctl':
                run('wpctl', 'set-volume', '@DEFAULT_AUDIO_SINK@', f'{max(0, min(100, value))}%')
                run('wpctl', 'set-mute', '@DEFAULT_AUDIO_SINK@', '0')
            else:
                run('pactl', 'set-sink-volume', '@DEFAULT_SINK@', f'{max(0, min(100, value))}%')
                run('pactl', 'set-sink-mute', '@DEFAULT_SINK@', '0')
        else:
            run('brightnessctl', '--class=backlight', '-q', 'set', f'{max(5, min(100, value))}%')
    elif name == 'mute':
        if audio().get('backend') == 'wpctl':
            run('wpctl', 'set-mute', '@DEFAULT_AUDIO_SINK@', 'toggle')
        else:
            run('pactl', 'set-sink-mute', '@DEFAULT_SINK@', 'toggle')
    elif name == 'wifi' and values[0] in ('on', 'off'):
        run('nmcli', 'radio', 'wifi', values[0])
    elif name == 'dnd' and values[0] in ('on', 'off'):
        save_state(dnd=values[0] == 'on')
    elif name == 'theme':
        theme_id = values[0]
        theme = next((t for t in themes() if t['id'] == theme_id), None)
        if theme is None:
            raise ValueError('Unknown theme')
        save_state(theme=theme_id)
        if export_palette(theme):
            subprocess.run(['pkill', '-USR2', '-x', 'waybar'])  # Waybar re-reads style.css and its palette import
        return dict(appliedTheme=theme_id)
    elif name == 'wallpaper-period' and values[0] in ('morning', 'day', 'evening', 'night'):
        run(str(HOME / '.local/bin/hypr-wallpaper'), values[0])
        return dict(appliedWallpaper=wallpaper_state())
    elif name == 'wallpaper':
        path = Path(values[0]).resolve(strict=True)
        if not path.is_file() or not path.is_relative_to(LIB.resolve()) or path.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp'):
            raise ValueError('Choose an image from your wallpaper library')
        run(str(HOME / '.local/bin/hypr-wallpaper'), 'set', str(path))
        return dict(appliedWallpaper=wallpaper_state())
    else:
        raise ValueError('Unsupported action')
    return {}


def learning():
    config = json.loads(Path(__file__).with_name('overview.json').read_text())
    return dict(learned=read_state().get('learned', []), aliases=config.get('aliases', {}), frecency=frecency())


def record_choice(query, identifier):
    query = ' '.join(query.lower().split())
    with state_lock():
        state = read_state()
        learned = state.get('learned', [])
        if query:
            old = next((r for r in learned if r['query'] == query and r['id'] == identifier), {})
            learned = [r for r in learned if not (r['query'] == query and r['id'] == identifier)]
            learned.append(dict(query=query, id=identifier, count=old.get('count', 0)+1, last=time.time()))
        launches = state.get('launches', {})
        launches[identifier] = dict(count=launches.get(identifier, {}).get('count', 0)+1, last=time.time())
        save_state(learned=sorted(learned, key=lambda r: r['last'], reverse=True)[:500],
                   launches=dict(sorted(launches.items(), key=lambda r: r[1]['last'], reverse=True)[:200]))
    return learning()


def bind_used(route):
    data = bind_catalog()['binds']
    def normal(keys):
        return ' '.join(keys.lower().replace('+', ' ').split())
    row = next((b for b in data if normal(b['keys']) == normal(route) or b['command'] == route), None)
    if row:
        with state_lock():
            counts = read_state().get('bindUse', {})
            counts[row['id']] = counts.get(row['id'], 0) + 1
            save_state(bindUse=counts)
    return {}


def bind_catalog():
    configured = []
    try:
        for line in run('lua', str(Path(__file__).with_name('binds.lua')), str(HOME / '.config/hypr/hyprland.lua')).splitlines():
            configured.append(json.loads(line))
    except (OSError, RuntimeError, subprocess.TimeoutExpired):
        pass
    def chord(keys):
        parts = [p.strip().lower() for p in keys.split('+')]
        return tuple(sorted(parts[:-1])), parts[-1]
    def live_keys(row):
        mask = row['modmask']
        mods = [name for bit, name in [(64, 'SUPER'), (4, 'Ctrl'), (8, 'Alt'), (1, 'Shift'), (2, 'Caps'), (16, 'Mod2'), (32, 'Mod3'), (128, 'Mod5')] if mask & bit]
        return ' + '.join(mods + [row['key'] or 'code:' + str(row['keycode'])])
    rows = []
    for live in json.loads(run('hyprctl', 'binds', '-j')):
        keys = live_keys(live)
        spec = next((c for c in configured if chord(c['keys']) == chord(keys)), {})
        identifier = 'bind:' + str(live['modmask']) + ':' + (live['key'] or str(live['keycode'])) + ':' + live.get('submap', '')
        rows.append(dict(id=identifier, type='bind', label=live.get('description') or spec.get('description') or spec.get('label') or (live['dispatcher'] + ' ' + live['arg']),
                         keys=keys.replace(' + ', ' '), command=spec.get('command', ''), workspace=spec.get('workspace', ''),
                         expression=spec.get('expression', ''), dispatcher=live['dispatcher'], arg=live['arg'], submap=live.get('submap', ''),
                         fields=[keys.replace(' + ', ' '), spec.get('command', ''), spec.get('label', ''), live['dispatcher']]))
    return dict(binds=rows, bindUse=read_state().get('bindUse', {}))


def run_bind(identifier):
    row = next((b for b in bind_catalog()['binds'] if b['id'] == identifier), None)
    if row is None:
        raise ValueError('Bind is no longer available')
    if row['command']:
        expression = 'hl.dsp.exec_cmd(' + json.dumps('DYNAMITE_FROM_SEARCH=1 ' + row['command'], ensure_ascii=False) + ')'
        run('hyprctl', 'eval', 'hl.dispatch(' + expression + ')')
    elif row['expression']:
        run('hyprctl', 'eval', 'hl.dispatch(' + row['expression'] + ')')
    elif row['dispatcher'].startswith('HL.'):
        raise ValueError('Lua callback is not present in the local bind catalogue')
    else:
        run('hyprctl', 'dispatch', row['dispatcher'], row['arg'])
    return {}


def overview_apps():
    config = json.loads(Path(__file__).with_name('overview.json').read_text())
    hidden = {name.removesuffix('.desktop') for name in config.get('hiddenApps', [])}
    roots = [Path(os.environ.get('XDG_DATA_HOME', HOME / '.local/share'))]
    roots += [Path(p) for p in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')]
    seen, allowed = set(), []
    removed = dict(hiddenApps=0, desktopFlags=0, missingBinary=0)
    def executable(command):
        try:
            parts = shlex.split(command)
        except ValueError:
            return False
        if not parts:
            return False
        if Path(parts[0]).name == 'env':
            parts = parts[1:]
            while parts and ('=' in parts[0] or parts[0].startswith('-')):
                option = parts.pop(0)
                if option in ('-u', '--unset', '-C', '--chdir') and parts:
                    parts.pop(0)
        return bool(parts and shutil.which(parts[0]))
    for root in roots:
        folder = root / 'applications'
        for path in sorted(folder.rglob('*.desktop')):
            entry_id = str(path.relative_to(folder)).replace('/', '-').removesuffix('.desktop')
            if entry_id in seen:
                continue
            seen.add(entry_id)
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                parser.read(path, encoding='utf-8')
                entry = parser['Desktop Entry']
                if entry.get('Type', 'Application') != 'Application':
                    continue
                if entry_id in hidden:
                    removed['hiddenApps'] += 1
                elif any(entry.get(k, '').lower() == 'true' for k in ('Hidden', 'NoDisplay')):
                    removed['desktopFlags'] += 1
                elif not executable(entry.get('Exec', '')) or entry.get('TryExec') and not executable(entry['TryExec']):
                    removed['missingBinary'] += 1
                else:
                    allowed.append(entry_id)
            except (OSError, UnicodeError, configparser.Error, KeyError):
                continue
    return dict(appIds=allowed, removed=removed)


def search(query):
    if not query.startswith('/'):
        result = ''
        if re.search(r'\d', query) and (re.search(r'[+*/^=()]|\d\s*-\s*\d|\b(to|in)\b', query) or re.fullmatch(r'[\d. ]+', query)):
            try:
                reply = subprocess.run(['qalc', '-t', query], capture_output=True, text=True, timeout=0.3)
                if reply.returncode == 0 and not re.search(r'error|warning', reply.stdout, re.I):
                    result = reply.stdout.strip().split('\n')[-1]
            except (OSError, subprocess.TimeoutExpired):
                pass
        return dict(query=query, calculator=result, files=[])
    tokens = query[1:].strip().split()
    if not tokens:
        return dict(query=query, files=[])
    pattern = max(tokens, key=len)
    excluded = {'.cache', 'node_modules', '.git', '__pycache__', 'target', 'Trash'}
    def collect(command):
        try:
            reply = subprocess.run(command, capture_output=True, timeout=4)
            return reply.stdout.decode(errors='replace').split('\0')
        except (OSError, subprocess.TimeoutExpired):
            return []
    fd = ['fd', '--type', 'f', '--changed-within', '2d', '--max-results', '500', '--print0']
    for name in sorted(excluded):
        fd += ['--exclude', name]
    # Literal hits plus basename subsequence hits (non-hidden dirs), so "/rpt" can find report.pdf.
    subsequence = '^' + re.escape(str(HOME)) + '/([^./][^/]*/)*[^/]*' + ''.join(re.escape(c) + '[^/]*' for c in pattern) + '$'
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        locate = pool.submit(collect, ['plocate', '-0', '-i', '-l', '2000', '--', pattern])
        fuzzy = pool.submit(collect, ['plocate', '-0', '-i', '-l', '2000', '--regex', '--', subsequence])
        recent = pool.submit(collect, fd + ['.', str(HOME)])
        candidates = set(locate.result() + fuzzy.result() + recent.result())
    files = []
    for name in candidates:
        path = Path(name)
        try:
            relative = path.relative_to(HOME)
            if any(part.startswith('.') or part in excluded for part in relative.parts[:-1]) or not path.is_file():
                continue
            parent = '~/' + str(relative.parent)
            parts = parent.split('/')
            if len(parts) > 4:
                parent = '/'.join(parts[:2] + ['…'] + parts[-1:])
            files.append(dict(id=str(path), path=str(path), label=path.name, parent=parent,
                              recent=0.5 ** (max(0, time.time() - path.stat().st_mtime) / 86400 / 2)))
        except (OSError, ValueError):
            continue
    return dict(query=query, files=files)


def main():
    cmd = sys.argv[1]
    if cmd == 'learning':
        return learning()
    if cmd == 'record-choice':
        return record_choice(sys.argv[2], sys.argv[3])
    if cmd == 'bind-used':
        return bind_used(sys.argv[2])
    if cmd == 'binds':
        return bind_catalog()
    if cmd == 'run-bind':
        return run_bind(sys.argv[2])
    if cmd == 'overview-apps':
        return overview_apps()
    if cmd == 'search':
        return search(sys.argv[2])
    if cmd == 'frecency':
        return dict(frecency=frecency())
    if cmd == 'record':
        return record_launch(sys.argv[2])
    if cmd == 'wifi':
        return wifi_action(sys.argv[2:])
    if cmd == 'snapshot':
        return snapshot()
    if cmd == 'catalog':
        return catalog()
    if cmd == 'wallpapers':
        try:
            tags = json.loads(Path(__file__).with_name('wallpaper-tags.json').read_text())
        except (OSError, ValueError):
            tags = {}
        slots = {}
        for slot in ('morning', 'day', 'evening', 'night'):
            folder = LIB / slot
            slots[slot] = [dict(path=str(p), name=p.name, url=p.as_uri(), keywords=tags.get(str(p.relative_to(LIB)), [])) for p in sorted(folder.glob('*'))
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
        if sys.argv[1] == 'cpu':
            cpu_stream('--cores' in sys.argv[2:])
            sys.exit(0)
        print(json.dumps(dict(ok=True, **main())))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired, IndexError) as error:
        print(json.dumps(dict(ok=False, error=str(error))))
        sys.exit(1)
