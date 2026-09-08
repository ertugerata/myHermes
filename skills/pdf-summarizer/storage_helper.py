#!/usr/bin/env python3
"""
Storage Helper for PDF Summarizer Skill
Handles both Local directory and WebDAV folder operations seamlessly.
"""

import os
import sys
import json
import shutil
import argparse
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path

# Try loading .env if available
def load_env_files():
    candidates = [
        os.path.expanduser('~/.hermes/.env'),
        os.path.expanduser('~/.config/hermes/.env'),
        os.path.expanduser('~/app/.env'),
        '.env'
    ]
    for c in candidates:
        if os.path.exists(c):
            with open(c, 'r', encoding='utf-8') as f:
                for line in f:
                    line_str = line.strip()
                    if line_str and not line_str.startswith('#') and '=' in line_str:
                        k, v = line_str.split('=', 1)
                        k = k.strip()
                        v = v.strip().strip("'").strip('"')
                        if k not in os.environ:
                            os.environ[k] = v

load_env_files()

def get_config():
    target_type = os.environ.get('PDF_SUMMARIZER_TARGET_TYPE', os.environ.get('PDF_TARGET_TYPE', 'local')).lower()

    local_reading_list = os.environ.get('PDF_SUMMARIZER_LOCAL_READING_LIST', '/Bilgi_Tabani/02_Okuma_Listesi')
    local_shelves = os.environ.get('PDF_SUMMARIZER_LOCAL_SHELVES', '/Bilgi_Tabani/03_Akilli_Raflar')

    webdav_url = os.environ.get('PDF_SUMMARIZER_WEBDAV_URL', os.environ.get('WEBDAV_URL', '')).rstrip('/')
    webdav_user = os.environ.get('PDF_SUMMARIZER_WEBDAV_USERNAME', os.environ.get('WEBDAV_USERNAME', ''))
    webdav_pass = os.environ.get('PDF_SUMMARIZER_WEBDAV_PASSWORD', os.environ.get('WEBDAV_PASSWORD', ''))
    webdav_reading_list = os.environ.get('PDF_SUMMARIZER_WEBDAV_READING_LIST', '/Bilgi_Tabani/02_Okuma_Listesi')
    webdav_shelves = os.environ.get('PDF_SUMMARIZER_WEBDAV_SHELVES', '/Bilgi_Tabani/03_Akilli_Raflar')

    return {
        'target_type': target_type,
        'local_reading_list': local_reading_list,
        'local_shelves': local_shelves,
        'webdav_url': webdav_url,
        'webdav_user': webdav_user,
        'webdav_pass': webdav_pass,
        'webdav_reading_list': webdav_reading_list,
        'webdav_shelves': webdav_shelves
    }

class WebDAVClient:
    def __init__(self, base_url, username, password):
        self.base_url = base_url.rstrip('/')
        self.username = username
        self.password = password

        # Use httpx if available, fallback to urllib
        try:
            import httpx
            self.use_httpx = True
            self.httpx = httpx
        except ImportError:
            self.use_httpx = False

    def _get_auth_header(self):
        import base64
        auth_str = f"{self.username}:{self.password}"
        encoded = base64.b64encode(auth_str.encode('utf-8')).decode('utf-8')
        return f"Basic {encoded}"

    def request(self, method, path, data=None, headers=None):
        full_url = f"{self.base_url}/{path.lstrip('/')}"
        req_headers = headers or {}
        if self.username and self.password:
            req_headers['Authorization'] = self._get_auth_header()

        if self.use_httpx:
            with self.httpx.Client(timeout=30.0, follow_redirects=True) as client:
                res = client.request(method, full_url, content=data, headers=req_headers)
                return res.status_code, res.content, res.headers
        else:
            import urllib.request
            req = urllib.request.Request(full_url, data=data, headers=req_headers, method=method)
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    return resp.status, resp.read(), resp.headers
            except urllib.error.HTTPError as e:
                return e.code, e.read(), e.headers

    def list_dir(self, remote_path):
        headers = {'Depth': '1'}
        status, body, _ = self.request('PROPFIND', remote_path, headers=headers)
        if status not in (207, 200):
            raise Exception(f"WebDAV PROPFIND failed with status {status}: {body.decode('utf-8', errors='ignore')}")

        files = []
        try:
            root = ET.fromstring(body)
            # WebDAV namespace
            ns = {'d': 'DAV:'}
            for response in root.findall('d:response', ns) or root.findall('{DAV:}response'):
                href_el = response.find('d:href', ns) or response.find('{DAV:}href')
                if href_el is None or not href_el.text:
                    continue
                href = urllib.parse.unquote(href_el.text)

                # Check if collection (directory)
                is_dir = False
                propstat = response.find('d:propstat', ns) or response.find('{DAV:}propstat')
                if propstat is not None:
                    prop = propstat.find('d:prop', ns) or propstat.find('{DAV:}prop')
                    if prop is not None:
                        res_type = prop.find('d:resourcetype', ns) or prop.find('{DAV:}resourcetype')
                        if res_type is not None:
                            if res_type.find('d:collection', ns) is not None or res_type.find('{DAV:}collection') is not None:
                                is_dir = True

                filename = os.path.basename(href.rstrip('/'))
                if filename and not is_dir:
                    files.append({
                        'name': filename,
                        'href': href,
                        'remote_path': os.path.join(remote_path, filename)
                    })
        except Exception as e:
            raise Exception(f"Failed to parse WebDAV response: {e}")
        return files

    def ensure_dir(self, remote_path):
        parts = [p for p in remote_path.split('/') if p]
        curr = ''
        for p in parts:
            curr += '/' + p
            status, _, _ = self.request('PROPFIND', curr, headers={'Depth': '0'})
            if status == 404:
                mk_status, body, _ = self.request('MKCOL', curr)
                if mk_status not in (201, 200, 205):
                    raise Exception(f"Failed to create directory {curr} on WebDAV (status {mk_status}): {body}")

    def download_file(self, remote_path, local_dest):
        status, content, _ = self.request('GET', remote_path)
        if status != 200:
            raise Exception(f"Failed to download {remote_path} (status {status})")
        os.makedirs(os.path.dirname(local_dest), exist_ok=True)
        with open(local_dest, 'wb') as f:
            f.write(content)

    def upload_file(self, local_file, remote_path):
        with open(local_file, 'rb') as f:
            data = f.read()
        status, body, _ = self.request('PUT', remote_path, data=data)
        if status not in (200, 201, 204):
            raise Exception(f"Failed to upload {local_file} to {remote_path} (status {status}): {body}")

    def move_file(self, source_remote_path, dest_remote_path):
        dest_url = f"{self.base_url}/{dest_remote_path.lstrip('/')}"
        headers = {'Destination': dest_url, 'Overwrite': 'T'}
        status, body, _ = self.request('MOVE', source_remote_path, headers=headers)
        if status not in (200, 201, 204):
            raise Exception(f"Failed to move {source_remote_path} to {dest_remote_path} (status {status}): {body}")


def cmd_status():
    cfg = get_config()
    print("=== PDF Summarizer Target Storage Configuration ===")
    print(f"Target Storage Type: {cfg['target_type'].upper()}")

    if cfg['target_type'] == 'webdav':
        print(f"WebDAV Server URL: {cfg['webdav_url']}")
        print(f"WebDAV Username:   {cfg['webdav_user']}")
        print(f"WebDAV Reading List: {cfg['webdav_reading_list']}")
        print(f"WebDAV Shelves Dir:  {cfg['webdav_shelves']}")
        if not cfg['webdav_url']:
            print("❌ WARNING: WEBDAV_URL is not set!")
        else:
            client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
            try:
                files = client.list_dir(cfg['webdav_reading_list'])
                print(f"✅ WebDAV Connection successful. Found {len(files)} items in reading list.")
            except Exception as e:
                print(f"❌ WebDAV Connection check failed: {e}")
    else:
        print(f"Local Reading List: {cfg['local_reading_list']}")
        print(f"Local Shelves Dir:  {cfg['local_shelves']}")
        rl_path = Path(cfg['local_reading_list'])
        shelves_path = Path(cfg['local_shelves'])

        if rl_path.exists():
            files = [f.name for f in rl_path.iterdir() if f.is_file()]
            print(f"✅ Local Reading List directory exists ({len(files)} files found).")
        else:
            print(f"⚠️  Local Reading List directory '{rl_path}' does not exist yet (will be created on use).")

def cmd_list():
    cfg = get_config()
    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        files = client.list_dir(cfg['webdav_reading_list'])
        valid_extensions = ('.pdf', '.doc', '.docx', '.txt', '.epub')
        matched = [f for f in files if f['name'].lower().endswith(valid_extensions)]
        print(json.dumps(matched, indent=2, ensure_ascii=False))
    else:
        rl_dir = Path(cfg['local_reading_list'])
        matched = []
        if rl_dir.exists():
            valid_extensions = ('.pdf', '.doc', '.docx', '.txt', '.epub')
            for item in rl_dir.iterdir():
                if item.is_file() and item.name.lower().endswith(valid_extensions):
                    matched.append({
                        'name': item.name,
                        'local_path': str(item)
                    })
        print(json.dumps(matched, indent=2, ensure_ascii=False))

def cmd_download(filename, dest_path):
    cfg = get_config()
    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        remote_src = os.path.join(cfg['webdav_reading_list'], filename)
        client.download_file(remote_src, dest_path)
        print(f"Downloaded WebDAV file {remote_src} to {dest_path}")
    else:
        src_path = os.path.join(cfg['local_reading_list'], filename)
        if not os.path.exists(src_path):
            raise FileNotFoundError(f"Local file not found: {src_path}")
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        shutil.copy2(src_path, dest_path)
        print(f"Copied local file {src_path} to {dest_path}")

def cmd_ensure_shelf(category_name):
    cfg = get_config()
    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        cat_dir = os.path.join(cfg['webdav_shelves'], category_name)
        client.ensure_dir(cat_dir)
        print(f"Ensured WebDAV category folder: {cat_dir}")
    else:
        cat_dir = os.path.join(cfg['local_shelves'], category_name)
        os.makedirs(cat_dir, exist_ok=True)
        print(f"Ensured local category folder: {cat_dir}")

def cmd_upload_summary(local_summary_file, category_name, summary_filename):
    cfg = get_config()
    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        cat_dir = os.path.join(cfg['webdav_shelves'], category_name)
        client.ensure_dir(cat_dir)
        target_remote = os.path.join(cat_dir, summary_filename)
        client.upload_file(local_summary_file, target_remote)
        print(f"Uploaded summary report to WebDAV: {target_remote}")
    else:
        cat_dir = os.path.join(cfg['local_shelves'], category_name)
        os.makedirs(cat_dir, exist_ok=True)
        target_local = os.path.join(cat_dir, summary_filename)
        shutil.copy2(local_summary_file, target_local)
        print(f"Saved summary report to local shelf: {target_local}")

def cmd_move_to_shelf(filename, category_name, new_filename=None):
    target_name = new_filename if new_filename else filename
    cfg = get_config()
    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        cat_dir = os.path.join(cfg['webdav_shelves'], category_name)
        client.ensure_dir(cat_dir)

        src_remote = os.path.join(cfg['webdav_reading_list'], filename)
        dest_remote = os.path.join(cat_dir, target_name)
        client.move_file(src_remote, dest_remote)
        print(f"Moved WebDAV file from {src_remote} to {dest_remote}")
    else:
        cat_dir = os.path.join(cfg['local_shelves'], category_name)
        os.makedirs(cat_dir, exist_ok=True)

        src_local = os.path.join(cfg['local_reading_list'], filename)
        dest_local = os.path.join(cat_dir, target_name)
        shutil.move(src_local, dest_local)
        print(f"Moved local file from {src_local} to {dest_local}")

def main():
    parser = argparse.ArgumentParser(description="PDF Summarizer Storage Helper")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("status", help="Show current storage configuration and test connection")
    subparsers.add_parser("list", help="List document files in the reading list directory")

    dl_p = subparsers.add_parser("download", help="Download/fetch file from reading list")
    dl_p.add_argument("filename", help="Filename in reading list")
    dl_p.add_argument("dest", help="Local destination path")

    es_p = subparsers.add_parser("ensure-shelf", help="Ensure category shelf directory exists")
    es_p.add_argument("category", help="Category name")

    us_p = subparsers.add_parser("upload-summary", help="Upload summary report markdown file")
    us_p.add_argument("summary_file", help="Local summary file path")
    us_p.add_argument("category", help="Category name")
    us_p.add_argument("filename", help="Summary filename on target")

    mv_p = subparsers.add_parser("move-to-shelf", help="Move processed document to category shelf")
    mv_p.add_argument("filename", help="Filename in reading list")
    mv_p.add_argument("category", help="Category name")
    mv_p.add_argument("--new-name", help="New filename in shelf (optional)", default=None)

    args = parser.parse_args()

    if args.command == "status":
        cmd_status()
    elif args.command == "list":
        cmd_list()
    elif args.command == "download":
        cmd_download(args.filename, args.dest)
    elif args.command == "ensure-shelf":
        cmd_ensure_shelf(args.category)
    elif args.command == "upload-summary":
        cmd_upload_summary(args.summary_file, args.category, args.filename)
    elif args.command == "move-to-shelf":
        cmd_move_to_shelf(args.filename, args.category, args.new_name)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
