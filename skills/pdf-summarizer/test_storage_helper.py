#!/usr/bin/env python3
import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
import storage_helper

class TestStorageHelper(unittest.TestCase):
    def test_resolve_local_path_env_vars(self):
        home = os.path.expanduser('~')

        # Test $HOME variable expansion
        res = storage_helper.resolve_local_path('$HOME/test_reading_list')
        expected = os.path.join(home, 'test_reading_list')
        self.assertEqual(res, expected)
        if os.path.exists(res):
            os.rmdir(res)

    def test_resolve_local_path_tilde(self):
        home = os.path.expanduser('~')

        # Test ~ expansion
        res = storage_helper.resolve_local_path('~/test_reading_list_tilde')
        expected = os.path.join(home, 'test_reading_list_tilde')
        self.assertEqual(res, expected)
        if os.path.exists(res):
            os.rmdir(res)

    def test_resolve_local_path_custom_fallback_to_app(self):
        # Non-creatable custom path falls back to app directory if app directory exists
        custom_path = '/mnt/chromeos/GoogleDrive/MyDrive/4hermes/Bilgi_Tabani/02_Okuma_Listesi'
        res = storage_helper.resolve_local_path(custom_path)
        app_dir = os.path.expanduser('~/app/Bilgi_Tabani/02_Okuma_Listesi')
        self.assertEqual(res, app_dir)

    def test_resolve_local_path_bilgi_tabani_fallback(self):
        # Default /Bilgi_Tabani root path should fallback to app directory if root is non-writable
        app_dir = os.path.expanduser('~/app')
        default_path = '/Bilgi_Tabani/02_Okuma_Listesi'
        res = storage_helper.resolve_local_path(default_path)
        expected = os.path.join(app_dir, 'Bilgi_Tabani/02_Okuma_Listesi')
        self.assertEqual(res, expected)

if __name__ == '__main__':
    unittest.main()
