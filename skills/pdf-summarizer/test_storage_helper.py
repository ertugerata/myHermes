#!/usr/bin/env python3
import os
import sys
import json
import shutil
import tempfile
import unittest
from unittest.mock import patch, MagicMock
from pathlib import Path

sys.path.insert(0, os.path.dirname(__file__))
import storage_helper


class TestStorageHelper(unittest.TestCase):

    def setUp(self):
        self.orig_env = dict(os.environ)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self.orig_env)

    def test_fix_leading_slash(self):
        self.assertEqual(storage_helper.fix_leading_slash('mnt/c/data'), '/mnt/c/data')
        self.assertEqual(storage_helper.fix_leading_slash('/mnt/c/data'), '/mnt/c/data')
        self.assertEqual(storage_helper.fix_leading_slash('~/data'), '~/data')
        self.assertEqual(storage_helper.fix_leading_slash('Bilgi_Tabani/02'), '/Bilgi_Tabani/02')
        self.assertEqual(storage_helper.fix_leading_slash('custom/folder'), 'custom/folder')

    def test_expand_vars(self):
        home = os.path.expanduser('~')
        res = storage_helper.expand_vars('$HOME/test_reading_list')
        expected = os.path.join(home, 'test_reading_list')
        self.assertEqual(res, expected)

        res_tilde = storage_helper.expand_vars('~/test_reading_list_tilde')
        expected_tilde = os.path.join(home, 'test_reading_list_tilde')
        self.assertEqual(res_tilde, expected_tilde)

    def test_fallback_to_app(self):
        app_dir = os.path.expanduser('~/app')
        default_path = '/Bilgi_Tabani/02_Okuma_Listesi'
        res = storage_helper.fallback_to_app(default_path)
        expected = os.path.join(app_dir, 'Bilgi_Tabani/02_Okuma_Listesi')
        self.assertEqual(res, expected)

    def test_resolve_local_path_bilgi_tabani_fallback(self):
        app_dir = os.path.expanduser('~/app')
        default_path = '/Bilgi_Tabani/02_Okuma_Listesi'
        res = storage_helper.resolve_local_path(default_path)
        expected = os.path.join(app_dir, 'Bilgi_Tabani/02_Okuma_Listesi')
        self.assertEqual(res, expected)

    def test_safe_filename_valid(self):
        self.assertEqual(storage_helper.safe_filename('Rapor.pdf'), 'Rapor.pdf')
        self.assertEqual(storage_helper.safe_filename('My Report 2026.pdf'), 'My Report 2026.pdf')
        self.assertEqual(storage_helper.safe_filename('dokuman_v1.0.docx'), 'dokuman_v1.0.docx')

    def test_safe_filename_path_traversal(self):
        invalid_filenames = [
            '../etc/passwd',
            '../../secret.txt',
            '/etc/passwd',
            'C:\\Windows\\System32\\cmd.exe',
            '..\\windows\\system32',
            'subfolder/file.pdf',
            'file.pdf\x00.exe',
            '',
            None
        ]
        for bad_fn in invalid_filenames:
            with self.subTest(filename=bad_fn):
                with self.assertRaises(ValueError):
                    storage_helper.safe_filename(bad_fn)

    def test_safe_category_valid_and_invalid(self):
        self.assertEqual(storage_helper.safe_category('Yazilim'), 'Yazilim')
        self.assertEqual(storage_helper.safe_category('Yapay Zeka'), 'Yapay Zeka')

        invalid_categories = [
            '../Yazilim',
            '/Yazilim',
            'Yazilim/AltKategori',
            'Yazilim\x00',
            '',
            None
        ]
        for bad_cat in invalid_categories:
            with self.subTest(category=bad_cat):
                with self.assertRaises(ValueError):
                    storage_helper.safe_category(bad_cat)

    def test_cmd_upload_summary_local(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            shelves_dir = os.path.join(tmpdir, 'shelves')
            os.environ['PDF_SUMMARIZER_TARGET_TYPE'] = 'local'
            os.environ['PDF_SUMMARIZER_LOCAL_SHELVES'] = shelves_dir

            summary_src = os.path.join(tmpdir, 'summary_temp.md')
            with open(summary_src, 'w', encoding='utf-8') as f:
                f.write("# Summary Test Content")

            storage_helper.cmd_upload_summary(summary_src, 'Yazilim', 'Rapor_Ozet.md')

            expected_target = os.path.join(shelves_dir, 'Yazilim', 'Rapor_Ozet.md')
            self.assertTrue(os.path.exists(expected_target))
            with open(expected_target, 'r', encoding='utf-8') as f:
                self.assertIn("# Summary Test Content", f.read())

    def test_cmd_move_to_shelf_local(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            rl_dir = os.path.join(tmpdir, 'reading_list')
            shelves_dir = os.path.join(tmpdir, 'shelves')
            os.makedirs(rl_dir, exist_ok=True)

            os.environ['PDF_SUMMARIZER_TARGET_TYPE'] = 'local'
            os.environ['PDF_SUMMARIZER_LOCAL_READING_LIST'] = rl_dir
            os.environ['PDF_SUMMARIZER_LOCAL_SHELVES'] = shelves_dir

            doc_path = os.path.join(rl_dir, 'Makale.pdf')
            with open(doc_path, 'w', encoding='utf-8') as f:
                f.write("PDF Content")

            storage_helper.cmd_move_to_shelf('Makale.pdf', 'Yazilim', new_filename='Makale_v2.pdf')

            self.assertFalse(os.path.exists(doc_path))
            expected_target = os.path.join(shelves_dir, 'Yazilim', 'Makale_v2.pdf')
            self.assertTrue(os.path.exists(expected_target))

    @patch.object(storage_helper.WebDAVClient, 'request')
    def test_cmd_upload_summary_webdav(self, mock_request):
        # Mock WebDAV responses (PROPFIND 200/207, PUT 200/201)
        mock_request.return_value = (200, b"", {})

        os.environ['PDF_SUMMARIZER_TARGET_TYPE'] = 'webdav'
        os.environ['PDF_SUMMARIZER_WEBDAV_URL'] = 'https://webdav.example.com'
        os.environ['PDF_SUMMARIZER_WEBDAV_USERNAME'] = 'user'
        os.environ['PDF_SUMMARIZER_WEBDAV_PASSWORD'] = 'pass'
        os.environ['PDF_SUMMARIZER_WEBDAV_SHELVES'] = '/Bilgi_Tabani/03_Akilli_Raflar'

        with tempfile.TemporaryDirectory() as tmpdir:
            summary_src = os.path.join(tmpdir, 'summary_temp.md')
            with open(summary_src, 'w', encoding='utf-8') as f:
                f.write("# WebDAV Summary")

            storage_helper.cmd_upload_summary(summary_src, 'Yazilim', 'Rapor_Ozet.md')

            # Verify that PUT request was executed for WebDAV upload
            put_calls = [call for call in mock_request.call_args_list if call[0][0] == 'PUT']
            self.assertTrue(len(put_calls) > 0)
            uploaded_remote_path = put_calls[0][0][1]
            self.assertEqual(uploaded_remote_path, '/Bilgi_Tabani/03_Akilli_Raflar/Yazilim/Rapor_Ozet.md')

    @patch.object(storage_helper.WebDAVClient, 'request')
    def test_cmd_move_to_shelf_webdav(self, mock_request):
        mock_request.return_value = (200, b"", {})

        os.environ['PDF_SUMMARIZER_TARGET_TYPE'] = 'webdav'
        os.environ['PDF_SUMMARIZER_WEBDAV_URL'] = 'https://webdav.example.com'
        os.environ['PDF_SUMMARIZER_WEBDAV_USERNAME'] = 'user'
        os.environ['PDF_SUMMARIZER_WEBDAV_PASSWORD'] = 'pass'
        os.environ['PDF_SUMMARIZER_WEBDAV_READING_LIST'] = '/Bilgi_Tabani/02_Okuma_Listesi'
        os.environ['PDF_SUMMARIZER_WEBDAV_SHELVES'] = '/Bilgi_Tabani/03_Akilli_Raflar'

        storage_helper.cmd_move_to_shelf('Döküman.pdf', 'Yazilim', new_filename='Döküman_Raf.pdf')

        move_calls = [call for call in mock_request.call_args_list if call[0][0] == 'MOVE']
        self.assertTrue(len(move_calls) > 0)
        source_remote_path = move_calls[0][0][1]
        headers = move_calls[0][1].get('headers', {})
        self.assertEqual(source_remote_path, '/Bilgi_Tabani/02_Okuma_Listesi/Döküman.pdf')
        self.assertEqual(headers.get('Destination'), 'https://webdav.example.com/Bilgi_Tabani/03_Akilli_Raflar/Yazilim/Döküman_Raf.pdf')

    @patch.object(storage_helper.WebDAVClient, 'request')
    def test_cmd_download_webdav(self, mock_request):
        mock_request.return_value = (200, b"Fake WebDAV Content", {})

        os.environ['PDF_SUMMARIZER_TARGET_TYPE'] = 'webdav'
        os.environ['PDF_SUMMARIZER_WEBDAV_URL'] = 'https://webdav.example.com'
        os.environ['PDF_SUMMARIZER_WEBDAV_READING_LIST'] = '/Bilgi_Tabani/02_Okuma_Listesi'

        with tempfile.TemporaryDirectory() as tmpdir:
            dest_file = os.path.join(tmpdir, 'downloaded.pdf')
            storage_helper.cmd_download('Döküman.pdf', dest_file)

            self.assertTrue(os.path.exists(dest_file))
            with open(dest_file, 'rb') as f:
                self.assertEqual(f.read(), b"Fake WebDAV Content")

    def test_cmd_status_json(self):
        os.environ['PDF_SUMMARIZER_TARGET_TYPE'] = 'local'
        status = storage_helper.cmd_status(json_output=True)
        self.assertEqual(status['target_type'], 'local')
        self.assertTrue(status['connected'])

    def test_cmd_list_local(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            os.environ['PDF_SUMMARIZER_TARGET_TYPE'] = 'local'
            os.environ['PDF_SUMMARIZER_LOCAL_READING_LIST'] = tmpdir

            doc1 = os.path.join(tmpdir, 'Rapor.pdf')
            doc2 = os.path.join(tmpdir, 'Notlar.txt')
            ignored = os.path.join(tmpdir, 'Resim.png')

            for p in (doc1, doc2, ignored):
                with open(p, 'w') as f:
                    f.write("content")

            items = storage_helper.cmd_list(json_output=False)
            names = [i['name'] for i in items]
            self.assertIn('Rapor.pdf', names)
            self.assertIn('Notlar.txt', names)
            self.assertNotIn('Resim.png', names)

    @patch('importlib.util.find_spec')
    @patch('subprocess.check_call')
    def test_ensure_dependencies_missing_package(self, mock_check_call, mock_find_spec):
        def side_effect(mod_name):
            if mod_name == 'pypdf':
                return None
            return MagicMock()

        mock_find_spec.side_effect = side_effect
        missing = storage_helper.ensure_dependencies(quiet=True)
        self.assertIn('pypdf>=4.0.0', missing)
        mock_check_call.assert_called_once()

    @patch('importlib.util.find_spec')
    def test_ensure_dependencies_all_present(self, mock_find_spec):
        mock_find_spec.return_value = MagicMock()
        missing = storage_helper.ensure_dependencies(quiet=True)
        self.assertEqual(missing, [])

    @patch('storage_helper.ensure_dependencies')
    @patch('storage_helper.cmd_init_dirs')
    def test_cmd_setup(self, mock_cmd_init_dirs, mock_ensure_deps):
        storage_helper.cmd_setup()
        mock_ensure_deps.assert_called_once_with(quiet=False)
        mock_cmd_init_dirs.assert_called_once()


if __name__ == '__main__':
    unittest.main()
