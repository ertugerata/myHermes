#!/usr/bin/env python3
"""
Unit/Integration test suite for storage_helper.py (Open Notebook + Buzz integration).
"""

import unittest
from unittest.mock import patch, MagicMock
import storage_helper


class TestStorageHelper(unittest.TestCase):

    @patch("urllib.request.urlopen")
    def test_list_notebooks(self, mock_urlopen):
        mock_response = MagicMock()
        mock_response.read.return_value = b'[{"id": "nb-1", "title": "Test Notebook"}]'
        mock_urlopen.return_value.__enter__.return_value = mock_response

        res = storage_helper.list_notebooks()
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["id"], "nb-1")

    @patch("storage_helper.send_to_buzz")
    @patch("urllib.request.urlopen")
    def test_add_source_with_buzz(self, mock_urlopen, mock_send_buzz):
        mock_response = MagicMock()
        mock_response.read.return_value = b'{"id": "src-1", "status": "uploaded"}'
        mock_urlopen.return_value.__enter__.return_value = mock_response

        res = storage_helper.add_source("nb-1", file_path="/tmp/test.pdf", notify_buzz=True)
        self.assertEqual(res["id"], "src-1")
        mock_send_buzz.assert_called_once()

    @patch("storage_helper.send_to_buzz")
    @patch("urllib.request.urlopen")
    def test_trigger_summary_with_buzz(self, mock_urlopen, mock_send_buzz):
        mock_response = MagicMock()
        mock_response.read.return_value = b'{"summary": "This is an AI summary."}'
        mock_urlopen.return_value.__enter__.return_value = mock_response

        res = storage_helper.trigger_summary("nb-1", source_id="src-1", notify_buzz=True)
        self.assertEqual(res["summary"], "This is an AI summary.")
        mock_send_buzz.assert_called_once()


if __name__ == "__main__":
    unittest.main()
