#!/usr/bin/env python3
"""
Unit test suite for storage_helper.py (Open Notebook + Buzz integration).
"""

import unittest
from unittest.mock import patch, MagicMock
import storage_helper


class TestStorageHelper(unittest.TestCase):

    @patch("httpx.Client")
    def test_list_notebooks(self, mock_client_cls):
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = [{"id": "nb-1", "name": "Test Notebook"}]
        mock_client.get.return_value = mock_response
        mock_client_cls.return_value.__enter__.return_value = mock_client

        res = storage_helper.list_notebooks()
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["id"], "nb-1")
        self.assertEqual(res[0]["name"], "Test Notebook")
        mock_client.get.assert_called_once_with("http://localhost:5055/api/notebooks")

    @patch("storage_helper.list_notebooks")
    @patch("storage_helper.send_to_buzz")
    @patch("httpx.Client")
    def test_add_source_url_with_buzz(self, mock_client_cls, mock_send_buzz, mock_list_notebooks):
        mock_list_notebooks.return_value = [{"id": "nb-1", "name": "Bilgi Tabani"}]

        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"id": "src-1", "type": "link"}
        mock_client.post.return_value = mock_response
        mock_client_cls.return_value.__enter__.return_value = mock_client

        res = storage_helper.add_source(notebook_id="nb-1", url="https://example.com/doc.pdf", notify_buzz=True)
        self.assertEqual(res["id"], "src-1")
        mock_send_buzz.assert_called_once()
        mock_client.post.assert_called_once_with(
            "http://localhost:5055/api/sources",
            json={"type": "link", "url": "https://example.com/doc.pdf", "notebooks": ["nb-1"]}
        )

    @patch("storage_helper.send_to_buzz")
    @patch("httpx.Client")
    def test_trigger_summary_with_buzz(self, mock_client_cls, mock_send_buzz):
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.status_code = 202
        mock_response.content = b'{"summary": "This is an AI summary."}'
        mock_response.json.return_value = {"summary": "This is an AI summary."}
        mock_client.post.return_value = mock_response
        mock_client_cls.return_value.__enter__.return_value = mock_client

        res = storage_helper.trigger_summary(notebook_id="nb-1", source_id="src-1", notify_buzz=True)
        self.assertEqual(res["summary"], "This is an AI summary.")
        mock_send_buzz.assert_called_once()
        mock_client.post.assert_called_once_with("http://localhost:5055/api/sources/src-1/insights", json={})

    def test_init_dirs(self):
        # Ensure init-dirs executes gracefully for start.sh backward compatibility
        try:
            storage_helper.init_dirs()
        except Exception as e:
            self.fail(f"init_dirs raised exception: {e}")


if __name__ == "__main__":
    unittest.main()
