"""Run with: python3 -m unittest discover -s tests -p 'test_*.py'."""
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('dynamite_bridge', ROOT / '.config/quickshell/dynamite/bridge.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class FirefoxThemeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        self.config = self.home / 'config'
        self.cache = self.home / 'cache'
        self.marker = self.config / 'dynamite/firefox-sync'
        self.target = self.cache / 'dynamite/firefox/wal/colors.json'
        self.wrapper = self.home / '.local/bin/dynamite-firefox'
        self.wrapper.parent.mkdir(parents=True)
        self.wrapper.write_text('#!/bin/sh\nexit 0\n')
        self.wrapper.chmod(0o700)
        home_patch = patch.object(bridge, 'HOME', self.home)
        env_patch = patch.dict(os.environ, XDG_CONFIG_HOME=str(self.config), XDG_CACHE_HOME=str(self.cache))
        home_patch.start(); env_patch.start()
        self.addCleanup(home_patch.stop); self.addCleanup(env_patch.stop)
        self.palettes = bridge.themes()

    def enable(self):
        self.marker.parent.mkdir(parents=True)
        self.marker.touch()

    def test_requires_opt_in(self):
        with patch.object(bridge.subprocess, 'run') as update:
            self.assertFalse(bridge.export_firefox(self.palettes[0]))
            update.assert_not_called()
        self.assertFalse(self.target.exists())

    def test_all_theme_colors_keep_pywalfox_index_order(self):
        for theme in self.palettes:
            with self.subTest(theme=theme['id']):
                payload = bridge.firefox_palette(theme)
                self.assertEqual(list(payload['colors']), [f'color{i}' for i in range(16)])
                self.assertEqual(payload['colors']['color0'], theme['bg'])
                self.assertEqual(payload['colors']['color8'], theme['surface'])
                self.assertEqual(payload['colors']['color10'], theme['accent'])
                self.assertEqual(payload['colors']['color13'], theme['accent'])
                self.assertEqual(payload['colors']['color15'], theme['text'])
                self.assertEqual(payload['wallpaper'], '')

    def test_changes_refresh_once_and_leave_other_palette_files_alone(self):
        self.enable()
        other = self.cache / 'wal/colors.json'
        other.parent.mkdir(parents=True)
        other.write_text('existing unrelated palette\n')
        with patch.object(bridge.subprocess, 'run') as update:
            self.assertTrue(bridge.export_firefox(self.palettes[0]))
            self.assertFalse(bridge.export_firefox(self.palettes[0]))
            self.assertTrue(bridge.export_firefox(self.palettes[1]))
            self.assertEqual(update.call_count, 2)
            self.assertEqual(update.call_args.args[0], [str(self.wrapper), 'update'])
        self.assertEqual(json.loads(self.target.read_text()), bridge.firefox_palette(self.palettes[1]))
        self.assertEqual(other.read_text(), 'existing unrelated palette\n')
        self.assertEqual([p.name for p in self.target.parent.iterdir()], ['colors.json'])

    def test_disconnected_browser_does_not_break_export(self):
        self.enable()
        with patch.object(bridge.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)):
            self.assertTrue(bridge.export_firefox(self.palettes[0]))
        self.assertTrue(self.target.is_file())

    def test_timeout_preserves_valid_palette_and_cleans_temporary_file(self):
        self.enable()
        with patch.object(bridge.subprocess, 'run', side_effect=subprocess.TimeoutExpired('pywalfox', 2)):
            self.assertFalse(bridge.export_firefox(self.palettes[0]))
        self.assertEqual(json.loads(self.target.read_text()), bridge.firefox_palette(self.palettes[0]))
        self.assertEqual([p.name for p in self.target.parent.iterdir()], ['colors.json'])


class FirefoxWrapperTests(unittest.TestCase):
    def test_setup_uses_private_cache_without_nesting_exporter_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = home / 'config'
            cache = home / 'cache'
            (config / 'mozilla/firefox').mkdir(parents=True)
            bin_dir = home / '.local/bin'
            bin_dir.mkdir(parents=True)
            wrapper = bin_dir / 'dynamite-firefox'
            shutil.copy2(ROOT / '.local/bin/dynamite-firefox', wrapper)
            log = home / 'commands.jsonl'
            recorder = ("#!/usr/bin/env python3\nimport json,os,sys\n"
                        "with open(os.environ['TEST_LOG'],'a') as f:\n"
                        " f.write(json.dumps({'args':sys.argv[1:],'cache':os.environ['XDG_CACHE_HOME']})+'\\n')\n")
            native = bin_dir / 'pywalfox'
            native.write_text(recorder); native.chmod(0o700)
            exporter = config / 'quickshell/dynamite/bridge.py'
            exporter.parent.mkdir(parents=True)
            exporter.write_text(recorder)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config),
                       XDG_CACHE_HOME=str(cache), TEST_LOG=str(log),
                       PATH=str(bin_dir)+os.pathsep+os.environ['PATH'])
            subprocess.run([str(wrapper),'setup'],env=env,check=True,capture_output=True)
            calls = [json.loads(row) for row in log.read_text().splitlines()]
            self.assertEqual(len(calls),4)
            self.assertTrue(all(c['cache']==str(cache/'dynamite/firefox') for c in calls[:3]))
            self.assertEqual(calls[-1],{'args':['catalog'],'cache':str(cache)})
            self.assertTrue((config/'dynamite/firefox-sync').is_file())
            subprocess.run([str(wrapper),'manifest.json','pywalfox@frewacom.org'],env=env,check=True)
            last = json.loads(log.read_text().splitlines()[-1])
            self.assertEqual(last['args'],['manifest.json','pywalfox@frewacom.org'])
            self.assertEqual(last['cache'],str(cache/'dynamite/firefox'))


if __name__ == '__main__':
    unittest.main()
