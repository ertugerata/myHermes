#!/usr/bin/env python3
"""
Unit test suite for storage_helper.py (Open Notebook + Buzz integration).
"""

import os
import sys
import json
import unittest
from unittest.mock import patch, MagicMock
import storage_helper


class TestStorageHelper(unittest.TestCase):

    @patch("httpx.Client")
    def test_list_notebooks_success(self, mock_client_cls):
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = [{"id": "nb-1", "name": "Test Notebook"}]
        mock_client.get.return_value = mock_response
        mock_client_cls.return_value.__enter__.return_value = mock_client

        res = storage_helper.list_notebooks()
        self.assertIsNotNone(res)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0]["id"], "nb-1")
        self.assertEqual(res[0]["name"], "Test Notebook")
        mock_client.get.assert_called_once_with("http://localhost:5055/api/notebooks")

    @patch("httpx.Client")
    def test_list_notebooks_network_error(self, mock_client_cls):
        mock_client = MagicMock()
        mock_client.get.side_effect = Exception("Connection refused")
        mock_client_cls.return_value.__enter__.return_value = mock_client

        res = storage_helper.list_notebooks()
        self.assertIsNone(res)

    @patch("storage_helper.list_notebooks")
    @patch("storage_helper.create_notebook")
    def test_get_or_create_notebook_on_network_error(self, mock_create, mock_list):
        mock_list.return_value = None  # Network error

        res = storage_helper.get_or_create_notebook("Test Notebook")
        self.assertIsNone(res)
        mock_create.assert_not_called()

    @patch("storage_helper.list_notebooks")
    @patch("storage_helper.create_notebook")
    def test_get_or_create_notebook_creates_if_missing(self, mock_create, mock_list):
        mock_list.return_value = [{"id": "nb-1", "name": "Other Notebook"}]
        mock_create.return_value = {"id": "nb-new", "name": "Test Notebook"}

        res = storage_helper.get_or_create_notebook("Test Notebook")
        self.assertEqual(res, "nb-new")
        mock_create.assert_called_once_with("Test Notebook")

    @patch("storage_helper.list_notebooks")
    @patch("storage_helper.send_to_buzz")
    @patch("httpx.Client")
    def test_add_source_url_form_data_with_embed(self, mock_client_cls, mock_send_buzz, mock_list_notebooks):
        mock_list_notebooks.return_value = [{"id": "nb-1", "name": "Bilgi Tabani"}]

        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"id": "src-1", "type": "link"}
        mock_client.post.return_value = mock_response
        mock_client_cls.return_value.__enter__.return_value = mock_client

        res = storage_helper.add_source(notebook_id="nb-1", url="https://example.com/doc.pdf", notify_buzz=True)
        self.assertIsNotNone(res)
        self.assertEqual(res["id"], "src-1")
        mock_send_buzz.assert_called_once()

        # Ensure POST /api/sources receives form data with embed="true"
        expected_data = {
            "type": "link",
            "url": "https://example.com/doc.pdf",
            "notebooks": json.dumps(["nb-1"]),
            "embed": "true"
        }
        mock_client.post.assert_called_once_with(
            "http://localhost:5055/api/sources",
            data=expected_data
        )

    @patch("storage_helper.send_to_buzz")
    @patch("storage_helper.time.sleep")
    @patch("httpx.Client")
    def test_trigger_summary_transformation_and_polling(self, mock_client_cls, mock_sleep, mock_send_buzz):
        mock_client = MagicMock()

        # 1. GET /api/transformations response
        resp_trans = MagicMock()
        resp_trans.status_code = 200
        resp_trans.json.return_value = [
            {"id": "tr-summary-1", "name": "Simple Summary"}
        ]

        # 2. POST /api/sources/src-1/insights response
        resp_post_insight = MagicMock()
        resp_post_insight.status_code = 200
        resp_post_insight.json.return_value = {"id": "ins-100", "status": "pending"}

        # 3. Poll GET /api/insights/ins-100 response
        resp_poll_insight = MagicMock()
        resp_poll_insight.status_code = 200
        resp_poll_insight.json.return_value = {
            "id": "ins-100",
            "status": "completed",
            "content": "Full AI Generated Summary Content"
        }

        mock_client.get.side_effect = [resp_trans, resp_poll_insight]
        mock_client.post.return_value = resp_post_insight
        mock_client_cls.return_value.__enter__.return_value = mock_client

        res = storage_helper.trigger_summary(source_id="src-1", notify_buzz=True)
        self.assertIsNotNone(res)
        self.assertEqual(res.get("summary"), "Full AI Generated Summary Content")

        # Verify POST payload contained transformation_id
        mock_client.post.assert_called_once_with(
            "http://localhost:5055/api/sources/src-1/insights",
            json={"transformation_id": "tr-summary-1"}
        )

        # Verify Buzz message sent
        mock_send_buzz.assert_called_once()
        buzz_arg = mock_send_buzz.call_args[0][0]
        self.assertIn("Full AI Generated Summary Content", buzz_arg)

    def test_init_dirs(self):
        try:
            storage_helper.init_dirs()
        except Exception as e:
            self.fail(f"init_dirs raised exception: {e}")


if __name__ == "__main__":
    unittest.main()
