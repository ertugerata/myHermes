#!/usr/bin/env python3
"""
Open Notebook & Buzz Integration Helper for Hermes Agent.
Connects Hermes to Open Notebook (lfnovo/open-notebook) REST API / MCP backend,
handles document ingestion, triggers summarization via transformations, polls insights,
and relays notifications/summaries to Buzz channels.
"""

import os
import sys
import time
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
    """Lists all available notebooks. Returns None on error."""
    if not is_open_notebook_enabled():
        return None

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
        return None


def create_notebook(name, description=""):
    """Creates a new notebook in Open Notebook using parameter 'name'. Returns None on error."""
    if not is_open_notebook_enabled():
        return None

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
        return None


def get_or_create_notebook(notebook_name_or_id):
    """Finds notebook by ID or name, or creates it if missing. Returns None on error."""
    if not notebook_name_or_id:
        notebook_name_or_id = DEFAULT_NOTEBOOK_NAME

    notebooks = list_notebooks()
    if notebooks is None:
        sys.stderr.write("Error: Failed to retrieve notebooks list due to network/API error.\n")
        return None

    if isinstance(notebooks, list):
        for nb in notebooks:
            if str(nb.get("id")) == str(notebook_name_or_id) or nb.get("name") == notebook_name_or_id:
                return nb.get("id")

    # Notebook not found, create new notebook with specified name
    res = create_notebook(notebook_name_or_id)
    return res.get("id") if isinstance(res, dict) else None


def add_source(notebook_id=None, file_path=None, url=None, notify_buzz=False):
    """
    Adds a file (PDF/Doc) via multipart upload or URL link source to Open Notebook.
    Uses form data (type 'link') with embed='true' to ensure vector embedding.
    """
    if not is_open_notebook_enabled():
        return None

    if not notebook_id:
        notebook_id = get_or_create_notebook(DEFAULT_NOTEBOOK_NAME)

    if not notebook_id:
        sys.stderr.write("Error: Unable to resolve notebook ID.\n")
        return None

    endpoint_url = f"{OPEN_NOTEBOOK_URL}/api/sources"
    headers = get_headers()
    source_name = ""

    try:
        with httpx.Client(timeout=60.0, headers=headers) as client:
            if url:
                # POST /api/sources expects Form data for links with embed="true"
                data = {
                    "type": "link",
                    "url": url,
                    "notebooks": json.dumps([notebook_id]),
                    "embed": "true"
                }
                resp = client.post(endpoint_url, data=data)
                source_name = url
            elif file_path:
                abs_path = os.path.abspath(file_path)
                if not os.path.exists(abs_path):
                    sys.stderr.write(f"Error: File not found: {abs_path}\n")
                    return None

                source_name = os.path.basename(abs_path)
                mime_type = mimetypes.guess_type(abs_path)[0] or "application/octet-stream"

                with open(abs_path, "rb") as f:
                    files = {"file": (source_name, f, mime_type)}
                    data = {
                        "type": "upload",
                        "notebooks": json.dumps([notebook_id]),
                        "embed": "true"
                    }
                    resp = client.post(endpoint_url, data=data, files=files)
            else:
                sys.stderr.write("Error: Either --file-path or --url must be provided.\n")
                return None

            resp.raise_for_status()
            res = resp.json()
            print(json.dumps(res, indent=2, ensure_ascii=False))

            if notify_buzz:
                buzz_msg = f"📄 **Doküman Eklendi**\n\n`{source_name}` başarıyla Open Notebook (Defter ID: `{notebook_id}`) içerisine kaydedildi ve vektör dizinine eklendi."
                send_to_buzz(buzz_msg)

            return res
    except Exception as e:
        sys.stderr.write(f"Error adding source: {str(e)}\n")
        return None


def get_transformation_id(client: httpx.Client) -> str:
    """Retrieves transformation ID for summary generation ('Simple Summary' or fallback)."""
    url = f"{OPEN_NOTEBOOK_URL}/api/transformations"
    try:
        resp = client.get(url)
        resp.raise_for_status()
        transformations = resp.json()

        if isinstance(transformations, list) and transformations:
            # 1. Exact match for 'Simple Summary'
            for t in transformations:
                if t.get("name") == "Simple Summary":
                    return str(t.get("id"))

            # 2. Case-insensitive match for summary/özet
            for t in transformations:
                t_name = t.get("name", "").lower()
                if "summary" in t_name or "özet" in t_name:
                    return str(t.get("id"))

            # 3. Fallback to first available transformation
            return str(transformations[0].get("id"))
    except Exception as e:
        sys.stderr.write(f"Error fetching transformations: {str(e)}\n")

    return None


def get_notebook_sources(client: httpx.Client, notebook_id: str) -> list:
    """Helper to fetch sources belonging to a notebook."""
    # Try fetching notebook details first
    try:
        nb_resp = client.get(f"{OPEN_NOTEBOOK_URL}/api/notebooks/{notebook_id}")
        if nb_resp.status_code == 200:
            nb_data = nb_resp.json()
            sources = nb_data.get("sources")
            if isinstance(sources, list) and sources:
                return sources
    except Exception:
        pass

    # Fallback to GET /api/sources
    try:
        src_resp = client.get(f"{OPEN_NOTEBOOK_URL}/api/sources")
        if src_resp.status_code == 200:
            all_sources = src_resp.json()
            if isinstance(all_sources, list):
                matched = []
                for s in all_sources:
                    nbs = s.get("notebooks") or []
                    if notebook_id in nbs or str(s.get("notebook_id")) == str(notebook_id):
                        matched.append(s)
                return matched
    except Exception as e:
        sys.stderr.write(f"Error fetching sources: {str(e)}\n")

    return []


def trigger_summary(notebook_id=None, source_id=None, notify_buzz=False):
    """
    Triggers summary generation for a source in Open Notebook using a valid transformation_id,
    polls until insight status is completed, and returns/posts the final summary text.
    """
    if not is_open_notebook_enabled():
        return None

    headers = get_headers()

    try:
        with httpx.Client(timeout=60.0, headers=headers) as client:
            # Step 1: Find transformation ID
            transformation_id = get_transformation_id(client)
            if not transformation_id:
                sys.stderr.write("Error: Unable to find a valid transformation ID in Open Notebook.\n")
                return None

            # Step 2: Resolve target source ID
            target_source_id = source_id
            if not target_source_id:
                if not notebook_id:
                    notebook_id = get_or_create_notebook(DEFAULT_NOTEBOOK_NAME)

                if not notebook_id:
                    sys.stderr.write("Error: Unable to resolve notebook ID for summary.\n")
                    return None

                sources = get_notebook_sources(client, notebook_id)
                if not sources:
                    sys.stderr.write(f"Error: No sources found in notebook '{notebook_id}' to summarize.\n")
                    return None

                # Select the latest source
                latest_source = sources[-1]
                target_source_id = latest_source.get("id") if isinstance(latest_source, dict) else str(latest_source)

            if not target_source_id:
                sys.stderr.write("Error: Unable to resolve target source ID.\n")
                return None

            # Step 3: Trigger insight creation on source
            insight_url = f"{OPEN_NOTEBOOK_URL}/api/sources/{target_source_id}/insights"
            payload = {"transformation_id": transformation_id}
            post_resp = client.post(insight_url, json=payload)
            post_resp.raise_for_status()

            post_data = post_resp.json()
            insight_id = post_data.get("id")

            if not insight_id:
                # If immediate result returned
                summary_text = post_data.get("content") or post_data.get("summary") or post_data.get("text")
                if summary_text:
                    if notify_buzz:
                        send_to_buzz(f"📝 **Open Notebook Özet Raporu**\n\n{summary_text}")
                    print(json.dumps(post_data, indent=2, ensure_ascii=False))
                    return post_data
                sys.stderr.write("Error: Insight creation did not return an ID or immediate content.\n")
                return None

            # Step 4: Poll insight until completion
            poll_url = f"{OPEN_NOTEBOOK_URL}/api/insights/{insight_id}"
            max_attempts = 30
            poll_data = {}
            summary_text = ""

            for attempt in range(max_attempts):
                time.sleep(2.0)
                poll_resp = client.get(poll_url)
                if poll_resp.status_code == 200:
                    poll_data = poll_resp.json()
                    status = str(poll_data.get("status", "")).lower()
                    content = (
                        poll_data.get("content")
                        or poll_data.get("summary")
                        or poll_data.get("text")
                        or poll_data.get("insight")
                    )

                    if status in ("completed", "finished", "done", "success") or (content and status not in ("pending", "running", "processing")):
                        summary_text = content
                        break
                    elif status in ("failed", "error"):
                        sys.stderr.write(f"Error: Insight generation failed with status '{status}': {poll_data}\n")
                        return None

            if not summary_text:
                summary_text = poll_data.get("content") or poll_data.get("summary") or "Özet oluşturma işlemi zaman aşımına uğradı."

            poll_data["summary"] = summary_text
            print(json.dumps(poll_data, indent=2, ensure_ascii=False))

            if notify_buzz and summary_text:
                buzz_msg = f"📝 **Open Notebook Özet Raporu**\n\n{summary_text}"
                send_to_buzz(buzz_msg)

            return poll_data
    except Exception as e:
        sys.stderr.write(f"Error triggering summary: {str(e)}\n")
        return None


def get_summary(source_id):
    """Retrieves generated summary or content details of a source."""
    if not is_open_notebook_enabled():
        return None

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
        return None


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

    res = None
    if action == "init-dirs":
        init_dirs()
        res = True
    elif action == "list_notebooks":
        res = list_notebooks()
    elif action == "create_notebook":
        if not args.title:
            sys.stderr.write("Error: --title required for create_notebook\n")
            sys.exit(1)
        res = create_notebook(args.title)
    elif action == "add_source":
        res = add_source(notebook_id=args.notebook_id, file_path=args.file_path, url=args.url, notify_buzz=args.notify_buzz)
    elif action == "summarize":
        res = trigger_summary(notebook_id=args.notebook_id, source_id=args.source_id, notify_buzz=args.notify_buzz)
    elif action == "get_summary":
        if not args.source_id:
            sys.stderr.write("Error: --source-id required for get_summary\n")
            sys.exit(1)
        res = get_summary(args.source_id)

    if res is None:
        sys.exit(1)


if __name__ == "__main__":
    main()
