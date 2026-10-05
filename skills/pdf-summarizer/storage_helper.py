#!/usr/bin/env python3
"""
Open Notebook & Buzz Integration Helper for Hermes Agent.
Connects Hermes to Open Notebook (lfnovo/open-notebook) REST API / MCP backend,
handles document ingestion, triggers summarization, and relays notifications/summaries to Buzz channels.
"""

import os
import sys
import json
import argparse
import mimetypes
import httpx

OPEN_NOTEBOOK_URL = os.environ.get("OPEN_NOTEBOOK_URL", "http://localhost:5055").rstrip("/")
OPEN_NOTEBOOK_PASSWORD = os.environ.get("OPEN_NOTEBOOK_PASSWORD", "").strip()
DEFAULT_NOTEBOOK_NAME = os.environ.get("PDF_SUMMARIZER_OPEN_NOTEBOOK_NOTEBOOK", "Bilgi Tabani").strip()
OPEN_NOTEBOOK_ENABLED = os.environ.get("PDF_SUMMARIZER_OPEN_NOTEBOOK_ENABLED", "true").lower() in ("true", "1", "yes")
BUZZ_WEBHOOK_URL = os.environ.get("BUZZ_WEBHOOK_URL", "").strip()
DEFAULT_TIMEOUT = 30.0


def is_open_notebook_enabled() -> bool:
    if not OPEN_NOTEBOOK_ENABLED:
        sys.stderr.write("Warning: PDF_SUMMARIZER_OPEN_NOTEBOOK_ENABLED is false. Action skipped.\n")
        return False
    return True


def send_to_buzz(message: str) -> bool:
    """Posts a formatted message/summary to the configured Buzz webhook channel."""
    if not BUZZ_WEBHOOK_URL:
        sys.stderr.write("Warning: BUZZ_WEBHOOK_URL is not configured. Skipping Buzz notification.\n")
        return False

    # Truncate summary if exceeds max length to prevent webhook overflow
    if len(message) > 2000:
        message = message[:1990] + "\n...[Özet kesildi]"

    payload = {"text": message}
    try:
        with httpx.Client(timeout=15.0) as client:
            resp = client.post(BUZZ_WEBHOOK_URL, json=payload)
            return resp.status_code in (200, 201, 204)
    except Exception as e:
        sys.stderr.write(f"Failed to post message to Buzz: {str(e)}\n")
        return False


def get_headers():
    headers = {
        "Accept": "application/json"
    }
    if OPEN_NOTEBOOK_PASSWORD:
        headers["Authorization"] = f"Bearer {OPEN_NOTEBOOK_PASSWORD}"
    return headers


def list_notebooks():
    """Lists all available notebooks."""
    if not is_open_notebook_enabled():
        return []

    url = f"{OPEN_NOTEBOOK_URL}/api/notebooks"
    try:
        with httpx.Client(timeout=DEFAULT_TIMEOUT, headers=get_headers()) as client:
            resp = client.get(url)
            resp.raise_for_status()
            res = resp.json()
            print(json.dumps(res, indent=2, ensure_ascii=False))
            return res
    except Exception as e:
        sys.stderr.write(f"Error listing notebooks: {str(e)}\n")
        return []


def create_notebook(name, description=""):
    """Creates a new notebook in Open Notebook using parameter 'name'."""
    if not is_open_notebook_enabled():
        return {}

    url = f"{OPEN_NOTEBOOK_URL}/api/notebooks"
    payload = {"name": name, "description": description}
    try:
        with httpx.Client(timeout=DEFAULT_TIMEOUT, headers=get_headers()) as client:
            resp = client.post(url, json=payload)
            resp.raise_for_status()
            res = resp.json()
            print(json.dumps(res, indent=2, ensure_ascii=False))
            return res
    except Exception as e:
        sys.stderr.write(f"Error creating notebook '{name}': {str(e)}\n")
        return {}


def get_or_create_notebook(notebook_name_or_id):
    """Finds notebook by ID or name, or creates it if missing."""
    if not notebook_name_or_id:
        notebook_name_or_id = DEFAULT_NOTEBOOK_NAME

    notebooks = list_notebooks()
    if isinstance(notebooks, list):
        for nb in notebooks:
            if str(nb.get("id")) == str(notebook_name_or_id) or nb.get("name") == notebook_name_or_id:
                return nb.get("id")

    # Notebook not found, create new notebook with specified name
    res = create_notebook(notebook_name_or_id)
    return res.get("id") if isinstance(res, dict) else None


def add_source(notebook_id=None, file_path=None, url=None, notify_buzz=False):
    """Adds a file (PDF/Doc) via multipart upload or URL (type 'link') source to Open Notebook."""
    if not is_open_notebook_enabled():
        return {}

    if not notebook_id:
        notebook_id = get_or_create_notebook(DEFAULT_NOTEBOOK_NAME)

    if not notebook_id:
        sys.stderr.write("Error: Unable to resolve notebook ID.\n")
        return {}

    endpoint_url = f"{OPEN_NOTEBOOK_URL}/api/sources"
    headers = get_headers()
    source_name = ""

    try:
        with httpx.Client(timeout=60.0, headers=headers) as client:
            if url:
                payload = {
                    "type": "link",
                    "url": url,
                    "notebooks": [notebook_id]
                }
                resp = client.post(endpoint_url, json=payload)
                source_name = url
            elif file_path:
                abs_path = os.path.abspath(file_path)
                if not os.path.exists(abs_path):
                    sys.stderr.write(f"Error: File not found: {abs_path}\n")
                    return {}

                source_name = os.path.basename(abs_path)
                mime_type = mimetypes.guess_type(abs_path)[0] or "application/octet-stream"

                with open(abs_path, "rb") as f:
                    files = {"file": (source_name, f, mime_type)}
                    data = {
                        "type": "upload",
                        "notebooks": json.dumps([notebook_id])
                    }
                    resp = client.post(endpoint_url, data=data, files=files)
            else:
                sys.stderr.write("Error: Either --file-path or --url must be provided.\n")
                return {}

            resp.raise_for_status()
            res = resp.json()
            print(json.dumps(res, indent=2, ensure_ascii=False))

            if notify_buzz:
                buzz_msg = f"📄 **Doküman Eklendi**\n\n`{source_name}` başarıyla Open Notebook (Defter ID: `{notebook_id}`) içerisine kaydedildi."
                send_to_buzz(buzz_msg)

            return res
    except Exception as e:
        sys.stderr.write(f"Error adding source: {str(e)}\n")
        return {}


def trigger_summary(notebook_id=None, source_id=None, notify_buzz=False):
    """Triggers insight/summary generation in Open Notebook for a source or notebook."""
    if not is_open_notebook_enabled():
        return {}

    headers = get_headers()
    res = {}
    summary_text = ""

    try:
        with httpx.Client(timeout=60.0, headers=headers) as client:
            if source_id:
                endpoint = f"{OPEN_NOTEBOOK_URL}/api/sources/{source_id}/insights"
                resp = client.post(endpoint, json={})
            elif notebook_id:
                endpoint = f"{OPEN_NOTEBOOK_URL}/api/notebooks/{notebook_id}/insights"
                resp = client.post(endpoint, json={})
            else:
                notebook_id = get_or_create_notebook(DEFAULT_NOTEBOOK_NAME)
                endpoint = f"{OPEN_NOTEBOOK_URL}/api/notebooks/{notebook_id}/insights"
                resp = client.post(endpoint, json={})

            if resp.status_code in (200, 201, 202):
                res = resp.json() if resp.content else {"status": "processing"}
            else:
                resp.raise_for_status()

            summary_text = (
                res.get("summary")
                or res.get("content")
                or res.get("text")
                or res.get("insight")
                or "Özet talebi iletildi ve işleniyor."
            )

            print(json.dumps(res, indent=2, ensure_ascii=False))

            if notify_buzz:
                buzz_msg = f"📝 **Open Notebook Özet Raporu**\n\n{summary_text}"
                send_to_buzz(buzz_msg)

            return res
    except Exception as e:
        sys.stderr.write(f"Error triggering summary: {str(e)}\n")
        return {}


def get_summary(source_id):
    """Retrieves generated summary or content details of a source."""
    if not is_open_notebook_enabled():
        return {}

    url = f"{OPEN_NOTEBOOK_URL}/api/sources/{source_id}"
    try:
        with httpx.Client(timeout=DEFAULT_TIMEOUT, headers=get_headers()) as client:
            resp = client.get(url)
            resp.raise_for_status()
            res = resp.json()
            print(json.dumps(res, indent=2, ensure_ascii=False))
            return res
    except Exception as e:
        sys.stderr.write(f"Error getting summary for source {source_id}: {str(e)}\n")
        return {}


def init_dirs():
    """Backward compatibility helper for startup scripts."""
    print("✔ Open Notebook storage helper initialized.")


def main():
    parser = argparse.ArgumentParser(description="Open Notebook & Buzz Integration for Hermes Agent")
    parser.add_argument("--action", required=False, default="list_notebooks",
                        choices=["list_notebooks", "create_notebook", "add_source", "summarize", "get_summary", "init-dirs"],
                        help="Action to perform")
    parser.add_argument("positional_action", nargs="?", choices=["list_notebooks", "create_notebook", "add_source", "summarize", "get_summary", "init-dirs"],
                        help="Positional action fallback (e.g. init-dirs)")
    parser.add_argument("--notebook-id", type=str, help="Target Notebook ID or Name")
    parser.add_argument("--source-id", type=str, help="Target Source ID")
    parser.add_argument("--file-path", type=str, help="Path to PDF or file to attach")
    parser.add_argument("--url", type=str, help="URL source to attach")
    parser.add_argument("--title", type=str, help="Title/Name for new notebook")
    parser.add_argument("--notify-buzz", action="store_true", help="Send action result or summary to Buzz channel")

    args = parser.parse_args()
    action = args.positional_action or args.action

    if action == "init-dirs":
        init_dirs()
    elif action == "list_notebooks":
        list_notebooks()
    elif action == "create_notebook":
        if not args.title:
            sys.stderr.write("Error: --title required for create_notebook\n")
            sys.exit(1)
        create_notebook(args.title)
    elif action == "add_source":
        add_source(notebook_id=args.notebook_id, file_path=args.file_path, url=args.url, notify_buzz=args.notify_buzz)
    elif action == "summarize":
        trigger_summary(notebook_id=args.notebook_id, source_id=args.source_id, notify_buzz=args.notify_buzz)
    elif action == "get_summary":
        if not args.source_id:
            sys.stderr.write("Error: --source-id required for get_summary\n")
            sys.exit(1)
        get_summary(args.source_id)


if __name__ == "__main__":
    main()
