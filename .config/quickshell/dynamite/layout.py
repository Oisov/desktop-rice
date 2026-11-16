#!/usr/bin/env python3
"""Compositor-only fullscreen for lone tiled windows on clock-only screens."""
import json
import os
from pathlib import Path
import select
import signal
import socket
import subprocess
import sys
import time


def hypr(*args):
    result = subprocess.run(['hyprctl', *args], capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout


def fullscreen(window, internal, client):
    reply = hypr('eval', 'hl.dispatch(hl.dsp.window.fullscreen_state({window=' +
                 json.dumps('address:' + window['address']) + ',internal=' + str(internal) +
                 ',client=' + str(client) + ',action="set"}))')
    if reply.strip() != 'ok':
        raise RuntimeError(reply)


def main():
    primary = sys.argv[1]
    owned, suppressed, membership = {}, set(), {}
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    signature = os.environ['HYPRLAND_INSTANCE_SIGNATURE']
    path = Path(os.environ['XDG_RUNTIME_DIR']) / 'hypr' / signature / '.socket2.sock'
    with socket.socket(socket.AF_UNIX) as events:
        events.connect(str(path))
        events.setblocking(False)
        pending = True
        try:
            while not stopping:
                if pending:
                    windows = json.loads(hypr('clients', '-j'))
                    monitors = json.loads(hypr('monitors', '-j'))
                    clock_ids = {m['id'] for m in monitors if m['name'] != primary and m.get('mirrorOf', 'none') in ('none', '')}
                    by_address = {w['address']: w for w in windows}
                    groups = {}
                    for w in windows:
                        if w['monitor'] in clock_ids and w['workspace']['id'] > 0 and not w.get('hidden', False):
                            groups.setdefault(w['workspace']['id'], []).append(w)
                    current = {ws: frozenset(w['address'] for w in group) for ws, group in groups.items()}
                    for ws in set(membership) | set(current):
                        if membership.get(ws) != current.get(ws):
                            suppressed.difference_update(membership.get(ws, frozenset()) | current.get(ws, frozenset()))
                    membership = current
                    suppressed.intersection_update(by_address)
                    lone = {group[0]['address'] for group in groups.values() if len(group) == 1 and not group[0]['floating']}
                    for address in list(owned):
                        w = by_address.get(address)
                        if not w:
                            del owned[address]
                        elif w['fullscreen'] != 2 or w['fullscreenClient'] != 0:
                            # A user/app changed it: respect that until the workspace's windows change.
                            suppressed.add(address)
                            del owned[address]
                        elif address not in lone:
                            original = owned.pop(address)
                            fullscreen(w, *original)
                    for address in lone - owned.keys() - suppressed:
                        w = by_address[address]
                        if w['fullscreen'] == 0 and w['fullscreenClient'] == 0:
                            owned[address] = (0, 0)
                            try:
                                fullscreen(w, 2, 0)
                            except Exception:
                                del owned[address]
                                raise
                    pending = False
                ready, _, _ = select.select([events], [], [], 0.5)
                if ready:
                    data = events.recv(65536)
                    if not data:
                        break
                    # Coalesce compositor bursts without polling idle desktops.
                    time.sleep(0.06)
                    while select.select([events], [], [], 0)[0]:
                        if not events.recv(65536):
                            stopping = True
                            break
                    pending = True
        finally:
            # Reloading/stopping the shell must not leave policy-owned windows fullscreen.
            try:
                for w in json.loads(hypr('clients', '-j')):
                    if w['address'] in owned and w['fullscreen'] == 2 and w['fullscreenClient'] == 0:
                        fullscreen(w, *owned[w['address']])
            except (OSError, RuntimeError, subprocess.TimeoutExpired):
                pass


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        print(f'Dynamite layout: {error}', file=sys.stderr)
        sys.exit(1)
