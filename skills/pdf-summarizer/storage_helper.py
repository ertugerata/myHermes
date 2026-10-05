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
import urllib.request
import urllib.error

OPEN_NOTEBOOK_URL = os.environ.get("OPEN_NOTEBOOK_URL", "http://localhost:5055").rstrip("/")
OPEN_NOTEBOOK_PASSWORD = os.environ.get("OPEN_NOTEBOOK_PASSWORD", "")
BUZZ_WEBHOOK_URL = os.environ.get("BUZZ_WEBHOOK_URL", "")


def send_to_buzz(message: str) -> bool:
    """Posts a formatted message/summary to the configured Buzz webhook channel."""
    if not BUZZ_WEBHOOK_URL:
        sys.stderr.write("Warning: BUZZ_WEBHOOK_URL is not configured. Skipping Buzz notification.\n")
        return False

    payload = json.dumps({"text": message}).encode("utf-8")
    req = urllib.request.Request(
        BUZZ_WEBHOOK_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as response:
            return response.status in (200, 201, 204)
    except Exception as e:
        sys.stderr.write(f"Failed to post message to Buzz: {str(e)}\n")
        return False


def get_headers():
    headers = {
        "Content-Type": "application/json"
    }
    if OPEN_NOTEBOOK_PASSWORD:
        headers["Authorization"] = f"Bearer {OPEN_NOTEBOOK_PASSWORD}"
    return headers


def make_request(endpoint, method="GET", payload=None):
    url = f"{OPEN_NOTEBOOK_URL}{endpoint}"
    headers = get_headers()
    data = json.dumps(payload).encode("utf-8") if payload else None

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode("utf-8")
            return json.loads(res_body) if res_body else {}
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        sys.stderr.write(f"HTTP Error {e.code}: {err_msg}\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"Request failed: {str(e)}\n")
        sys.exit(1)


def list_notebooks():
    """Lists all available notebooks."""
    res = make_request("/api/v1/notebooks", method="GET")
    print(json.dumps(res, indent=2, ensure_ascii=False))
    return res


def create_notebook(title, description=""):
    """Creates a new notebook in Open Notebook."""
    payload = {"title": title, "description": description}
    res = make_request("/api/v1/notebooks", method="POST", payload=payload)
    print(json.dumps(res, indent=2, ensure_ascii=False))
    return res


def add_source(notebook_id, file_path=None, url=None, notify_buzz=False):
    """Adds a file (PDF/Doc) or URL source to an Open Notebook."""
    payload = {
        "notebook_id": notebook_id,
    }
    source_name = ""

    if url:
        payload["type"] = "url"
        payload["content"] = url
        source_name = url
    elif file_path:
        payload["type"] = "file"
        payload["file_path"] = os.path.abspath(file_path)
        source_name = os.path.basename(file_path)
    else:
        sys.stderr.write("Error: Either --file-path or --url must be provided.\n")
        sys.exit(1)

    res = make_request(f"/api/v1/notebooks/{notebook_id}/sources", method="POST", payload=payload)
    print(json.dumps(res, indent=2, ensure_ascii=False))

    if notify_buzz:
        buzz_msg = f"📄 **Doküman Eklendi**\n\n`{source_name}` başarıyla Open Notebook (ID: `{notebook_id}`) içerisine kaydedildi."
        send_to_buzz(buzz_msg)

    return res


def trigger_summary(notebook_id, source_id=None, notify_buzz=False):
    """Triggers transformation / summarization pipeline in Open Notebook and optionally sends to Buzz."""
    endpoint = f"/api/v1/notebooks/{notebook_id}/summarize"
    payload = {}
    if source_id:
        payload["source_id"] = source_id

    res = make_request(endpoint, method="POST", payload=payload)
    print(json.dumps(res, indent=2, ensure_ascii=False))

    summary_text = res.get("summary") or res.get("content") or "Özet oluşturuldu ancak metin alınamadı."

    if notify_buzz:
        buzz_msg = f"📝 **Open Notebook Özet Raporu**\n\n{summary_text}"
        send_to_buzz(buzz_msg)

    return res


def get_summary(source_id):
    """Retrieves generated summary or content details of a source."""
    res = make_request(f"/api/v1/sources/{source_id}", method="GET")
    print(json.dumps(res, indent=2, ensure_ascii=False))
    return res


def main():
    parser = argparse.ArgumentParser(description="Open Notebook & Buzz Integration for Hermes Agent")
    parser.add_argument("--action", required=True, choices=["list_notebooks", "create_notebook", "add_source", "summarize", "get_summary"])
    parser.add_argument("--notebook-id", type=str, help="Target Notebook ID")
    parser.add_argument("--source-id", type=str, help="Target Source ID")
    parser.add_argument("--file-path", type=str, help="Path to PDF or file to attach")
    parser.add_argument("--url", type=str, help="URL source to attach")
    parser.add_argument("--title", type=str, help="Title for new notebook")
    parser.add_argument("--notify-buzz", action="store_true", help="Send action result or summary to Buzz channel")

    args = parser.parse_args()

    if args.action == "list_notebooks":
        list_notebooks()
    elif args.action == "create_notebook":
        if not args.title:
            sys.stderr.write("Error: --title required for create_notebook\n")
            sys.exit(1)
        create_notebook(args.title)
    elif args.action == "add_source":
        if not args.notebook_id:
            sys.stderr.write("Error: --notebook-id required for add_source\n")
            sys.exit(1)
        add_source(args.notebook_id, file_path=args.file_path, url=args.url, notify_buzz=args.notify_buzz)
    elif args.action == "summarize":
        if not args.notebook_id:
            sys.stderr.write("Error: --notebook-id required for summarize\n")
            sys.exit(1)
        trigger_summary(args.notebook_id, source_id=args.source_id, notify_buzz=args.notify_buzz)
    elif args.action == "get_summary":
        if not args.source_id:
            sys.stderr.write("Error: --source-id required for get_summary\n")
            sys.exit(1)
        get_summary(args.source_id)


if __name__ == "__main__":
    main()
