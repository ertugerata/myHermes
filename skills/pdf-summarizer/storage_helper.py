#!/usr/bin/env python3
"""
PDF Summarizer Skill için Depolama Yardımcısı (Storage Helper)
Hem yerel dizin hem de WebDAV klasör operasyonlarını sorunsuz yönetir.
"""

import os
import sys
import json
import shutil
import argparse
import urllib.parse
import xml.etree.ElementTree as ET
from pathlib import Path, PurePath
from typing import Any, Dict, List, Optional, Tuple


def load_env_files() -> None:
    """Sistem genelindeki veya uygulama dizinindeki .env dosyalarını yükler."""
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


def fix_leading_slash(path_str: str) -> str:
    """
    Sistem kök dizinleri ile başlayan ancak başında '/' bulunmayan yolları düzeltir.
    Örn: 'mnt/c/...' -> '/mnt/c/...'
    """
    if not path_str:
        return path_str
    path_str = path_str.strip().strip("'").strip('"')
    if (
        not path_str.startswith('/')
        and not path_str.startswith('~')
        and not path_str.startswith('$')
        and not path_str.startswith('.')
    ):
        first_segment = path_str.split('/', 1)[0]
        common_roots = {
            'mnt', 'media', 'home', 'Users', 'opt', 'var',
            'tmp', 'etc', 'srv', 'Bilgi_Tabani'
        }
        if first_segment in common_roots:
            return '/' + path_str
    return path_str


def expand_vars(path_str: str) -> str:
    """
    Ortam değişkenlerini ($HOME vb.) ve tilde (~) simgesini genişletir.
    Öncesinde başında '/' eksik olan yaygın yolları düzeltir.
    """
    if not path_str:
        return path_str
    fixed = fix_leading_slash(path_str)
    return os.path.expandvars(os.path.expanduser(fixed))


def fallback_to_app(path_str: str, original_path_str: str = '') -> str:
    """
    Yazma izni olmaması veya dizin oluşturulamaması durumunda,
    varsayılan ~/app/Bilgi_Tabani yedek dizin yolunu döndürür ve oluşturur.
    """
    check_str = original_path_str or path_str
    if check_str.startswith('/Bilgi_Tabani') or check_str.startswith('Bilgi_Tabani'):
        fallback_p = Path(os.path.expanduser('~/app')) / check_str.lstrip('/')
        try:
            fallback_p.mkdir(parents=True, exist_ok=True)
        except (PermissionError, OSError):
            pass
        return str(fallback_p)

    if 'Bilgi_Tabani/02_Okuma_Listesi' in check_str:
        app_p = Path(os.path.expanduser('~/app/Bilgi_Tabani/02_Okuma_Listesi'))
        if app_p.exists():
            return str(app_p)
    elif 'Bilgi_Tabani/03_Akilli_Raflar' in check_str:
        app_p = Path(os.path.expanduser('~/app/Bilgi_Tabani/03_Akilli_Raflar'))
        if app_p.exists():
            return str(app_p)

    return path_str


def resolve_local_path(path_str: str) -> str:
    """
    Yerel dizin yolunu çözer.
    Eksik eğik çizgi düzeltme, ortam değişkeni genişletme ve
    yazılamayan kök dizinler için yedekleme adımlarını birleştirir.
    """
    if not path_str:
        return path_str

    original_raw = path_str
    expanded = expand_vars(path_str)

    if os.path.isabs(expanded):
        p = Path(expanded)
    else:
        p = Path(expanded).resolve()

    if p.exists():
        return str(p)

    try:
        p.mkdir(parents=True, exist_ok=True)
        return str(p)
    except (PermissionError, OSError):
        return fallback_to_app(str(p), original_raw)


def safe_filename(filename: str) -> str:
    """
    Path traversal ve komut/dosya enjeksiyonu önleme kontrolü.
    pathlib.PurePath, os.path.basename ve katı karakter kontrolleri uygular.
    """
    if not filename or not isinstance(filename, str):
        raise ValueError("Geçersiz veya boş dosya adı / Invalid filename.")

    if '\x00' in filename:
        raise ValueError(f"Güvenli olmayan dosya adı (null byte tespiti): {filename}")

    if '/' in filename or '\\' in filename or ':' in filename:
        raise ValueError(f"Güvenli olmayan dosya adı (yol ayırıcı tespiti): {filename}")

    pure_name = PurePath(filename).name
    base_name = os.path.basename(filename)

    if filename != pure_name or filename != base_name:
        raise ValueError(f"Güvenli olmayan dosya adı (path traversal tespiti): {filename}")

    if '..' in filename:
        raise ValueError(f"Güvenli olmayan dosya adı (path traversal tespiti): {filename}")

    return pure_name


def safe_category(category_name: str) -> str:
    """
    Kategori adları için path traversal önleme kontrolü.
    """
    if not category_name or not isinstance(category_name, str):
        raise ValueError("Geçersiz veya boş kategori adı.")

    if '\x00' in category_name:
        raise ValueError(f"Güvenli olmayan kategori adı (null byte tespiti): {category_name}")

    pure_name = PurePath(category_name).name
    if category_name != pure_name or '..' in category_name or '/' in category_name or '\\' in category_name:
        raise ValueError(f"Güvenli olmayan kategori adı (path traversal tespiti): {category_name}")

    return pure_name


def get_config() -> Dict[str, str]:
    """Sistem ortam değişkenlerinden depolama yapılandırmasını okur ve çözer."""
    target_type = os.environ.get(
        'PDF_SUMMARIZER_TARGET_TYPE', os.environ.get('PDF_TARGET_TYPE', 'local')
    ).lower()

    local_reading_list = os.environ.get(
        'PDF_SUMMARIZER_LOCAL_READING_LIST',
        os.path.expanduser('~/app/Bilgi_Tabani/02_Okuma_Listesi')
    )
    local_shelves = os.environ.get(
        'PDF_SUMMARIZER_LOCAL_SHELVES',
        os.path.expanduser('~/app/Bilgi_Tabani/03_Akilli_Raflar')
    )

    webdav_url = os.environ.get(
        'PDF_SUMMARIZER_WEBDAV_URL', os.environ.get('WEBDAV_URL', '')
    ).rstrip('/')
    webdav_user = os.environ.get(
        'PDF_SUMMARIZER_WEBDAV_USERNAME', os.environ.get('WEBDAV_USERNAME', '')
    )
    webdav_pass = os.environ.get(
        'PDF_SUMMARIZER_WEBDAV_PASSWORD', os.environ.get('WEBDAV_PASSWORD', '')
    )
    webdav_reading_list = os.environ.get(
        'PDF_SUMMARIZER_WEBDAV_READING_LIST', '/Bilgi_Tabani/02_Okuma_Listesi'
    )
    webdav_shelves = os.environ.get(
        'PDF_SUMMARIZER_WEBDAV_SHELVES', '/Bilgi_Tabani/03_Akilli_Raflar'
    )

    if target_type == 'local':
        local_reading_list = resolve_local_path(local_reading_list)
        local_shelves = resolve_local_path(local_shelves)

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
    """WebDAV sunucusu ile iletişim sağlayan istemci sınıfı."""

    def __init__(self, base_url: str, username: str, password: str) -> None:
        self.base_url = base_url.rstrip('/')
        self.username = username
        self.password = password

        try:
            import httpx
            self.use_httpx = True
            self.httpx = httpx
        except ImportError:
            self.use_httpx = False

    def _get_auth_header(self) -> str:
        import base64
        auth_str = f"{self.username}:{self.password}"
        encoded = base64.b64encode(auth_str.encode('utf-8')).decode('utf-8')
        return f"Basic {encoded}"

    def request(
        self,
        method: str,
        path: str,
        data: Optional[Any] = None,
        headers: Optional[Dict[str, str]] = None
    ) -> Tuple[int, bytes, Any]:
        """WebDAV HTTP isteklerini yürütür."""
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

    def list_dir(self, remote_path: str) -> List[Dict[str, str]]:
        """WebDAV dizin içeriğini PROPFIND metodu ile listeler."""
        headers = {'Depth': '1'}
        status, body, _ = self.request('PROPFIND', remote_path, headers=headers)
        if status not in (207, 200):
            raise Exception(f"WebDAV PROPFIND başarısız (durum {status}): {body.decode('utf-8', errors='ignore')}")

        files: List[Dict[str, str]] = []
        try:
            root = ET.fromstring(body)
            ns = {'d': 'DAV:'}
            responses = root.findall('d:response', ns)
            if not responses:
                responses = root.findall('{DAV:}response')
            for response in responses:
                href_el = response.find('d:href', ns)
                if href_el is None:
                    href_el = response.find('{DAV:}href')
                if href_el is None or not href_el.text:
                    continue
                href = urllib.parse.unquote(href_el.text)

                is_dir = False
                propstat = response.find('d:propstat', ns)
                if propstat is None:
                    propstat = response.find('{DAV:}propstat')
                if propstat is not None:
                    prop = propstat.find('d:prop', ns)
                    if prop is None:
                        prop = propstat.find('{DAV:}prop')
                    if prop is not None:
                        res_type = prop.find('d:resourcetype', ns)
                        if res_type is None:
                            res_type = prop.find('{DAV:}resourcetype')
                        if res_type is not None:
                            col = res_type.find('d:collection', ns)
                            if col is None:
                                col = res_type.find('{DAV:}collection')
                            if col is not None:
                                is_dir = True

                filename = os.path.basename(href.rstrip('/'))
                if filename and not is_dir:
                    files.append({
                        'name': filename,
                        'href': href,
                        'remote_path': os.path.join(remote_path, filename)
                    })
        except Exception as e:
            raise Exception(f"WebDAV yanıtı ayrıştırılamadı: {e}")
        return files

    def ensure_dir(self, remote_path: str) -> None:
        """Uzak WebDAV klasörünün varlığını doğrular veya oluşturur."""
        parts = [p for p in remote_path.split('/') if p]
        curr = ''
        for p in parts:
            curr += '/' + p
            status, _, _ = self.request('PROPFIND', curr, headers={'Depth': '0'})
            if status == 404:
                mk_status, body, _ = self.request('MKCOL', curr)
                if mk_status not in (201, 200, 205):
                    raise Exception(f"WebDAV dizin oluşturma başarısız {curr} (durum {mk_status}): {body}")

    def download_file(self, remote_path: str, local_dest: str) -> None:
        """WebDAV üzerindeki dosyayı yerel hedefe indirir."""
        status, content, _ = self.request('GET', remote_path)
        if status != 200:
            raise Exception(f"WebDAV indirme başarısız {remote_path} (durum {status})")
        os.makedirs(os.path.dirname(local_dest), exist_ok=True)
        with open(local_dest, 'wb') as f:
            f.write(content)

    def upload_file(self, local_file: str, remote_path: str) -> None:
        """Yerel dosyayı WebDAV hedefine yükler (PUT)."""
        with open(local_file, 'rb') as f:
            data = f.read()
        status, body, _ = self.request('PUT', remote_path, data=data)
        if status not in (200, 201, 204):
            raise Exception(f"WebDAV yükleme başarısız {local_file} -> {remote_path} (durum {status}): {body}")

    def move_file(self, source_remote_path: str, dest_remote_path: str) -> None:
        """WebDAV üzerindeki dosyayı taşır (MOVE)."""
        dest_url = f"{self.base_url}/{dest_remote_path.lstrip('/')}"
        headers = {'Destination': dest_url, 'Overwrite': 'T'}
        status, body, _ = self.request('MOVE', source_remote_path, headers=headers)
        if status not in (200, 201, 204):
            raise Exception(f"WebDAV taşıma başarısız {source_remote_path} -> {dest_remote_path} (durum {status}): {body}")


def cmd_init_dirs() -> None:
    """Okuma listesi ve akıllı raflar dizinlerini ilklendirir."""
    cfg = get_config()
    if cfg['target_type'] == 'webdav':
        if not cfg['webdav_url']:
            print("❌ WebDAV dizinleri ilklendirilemedi: WEBDAV_URL tanımlı değil.")
            return
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        try:
            client.ensure_dir(cfg['webdav_reading_list'])
            print(f"✔ WebDAV okuma listesi dizini doğrulandı/oluşturuldu: {cfg['webdav_reading_list']}")
            client.ensure_dir(cfg['webdav_shelves'])
            print(f"✔ WebDAV akıllı raflar dizini doğrulandı/oluşturuldu: {cfg['webdav_shelves']}")
        except Exception as e:
            print(f"❌ WebDAV dizinleri ilklendirilemedi: {e}")
    else:
        rl_path = Path(cfg['local_reading_list'])
        shelves_path = Path(cfg['local_shelves'])
        try:
            os.makedirs(rl_path, exist_ok=True)
            print(f"✔ Yerel okuma listesi dizini doğrulandı/oluşturuldu: {rl_path}")
            os.makedirs(shelves_path, exist_ok=True)
            print(f"✔ Yerel akıllı raflar dizini doğrulandı/oluşturuldu: {shelves_path}")
        except Exception as e:
            print(f"❌ Yerel dizinler oluşturulamadı: {e}")


def cmd_status(json_output: bool = False) -> Dict[str, Any]:
    """Mevcut depolama yapılandırmasını kontrol eder ve durum bilgisini döner."""
    cfg = get_config()
    status_info: Dict[str, Any] = {
        'target_type': cfg['target_type'],
        'connected': False,
        'items_count': 0,
        'details': {}
    }

    if cfg['target_type'] == 'webdav':
        status_info['details'] = {
            'webdav_url': cfg['webdav_url'],
            'webdav_user': cfg['webdav_user'],
            'webdav_reading_list': cfg['webdav_reading_list'],
            'webdav_shelves': cfg['webdav_shelves']
        }
        if cfg['webdav_url']:
            client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
            try:
                cmd_init_dirs()
                files = client.list_dir(cfg['webdav_reading_list'])
                status_info['connected'] = True
                status_info['items_count'] = len(files)
            except Exception as e:
                status_info['error'] = str(e)

        if not json_output:
            print("=== PDF Summarizer Hedef Depolama Yapılandırması ===")
            print(f"Hedef Depolama Tipi: {cfg['target_type'].upper()}")
            print(f"WebDAV Sunucu URL: {cfg['webdav_url']}")
            print(f"WebDAV Kullanıcı:  {cfg['webdav_user']}")
            print(f"WebDAV Okuma Listesi: {cfg['webdav_reading_list']}")
            print(f"WebDAV Raflar Dizin:  {cfg['webdav_shelves']}")
            if not cfg['webdav_url']:
                print("❌ UYARI: WEBDAV_URL ortam değişkeni tanımlı değil!")
            elif status_info['connected']:
                print(f"✅ WebDAV Bağlantısı başarılı. Okuma listesinde {status_info['items_count']} öğe bulundu.")
            else:
                print(f"❌ WebDAV Bağlantı kontrolü başarısız: {status_info.get('error', 'Bilinmeyen hata')}")
    else:
        cmd_init_dirs()
        rl_path = Path(cfg['local_reading_list'])
        files = [f.name for f in rl_path.iterdir() if f.is_file()] if rl_path.exists() else []
        status_info['connected'] = True
        status_info['items_count'] = len(files)
        status_info['details'] = {
            'local_reading_list': cfg['local_reading_list'],
            'local_shelves': cfg['local_shelves']
        }

        if not json_output:
            print("=== PDF Summarizer Hedef Depolama Yapılandırması ===")
            print(f"Hedef Depolama Tipi: {cfg['target_type'].upper()}")
            print(f"Yerel Okuma Listesi: {cfg['local_reading_list']}")
            print(f"Yerel Raflar Dizin:  {cfg['local_shelves']}")
            print(f"✅ Yerel Okuma Listesi dizini hazır ({len(files)} dosya bulundu).")

    if json_output:
        print(json.dumps(status_info, indent=2, ensure_ascii=False))

    return status_info


def cmd_list(json_output: bool = True) -> List[Dict[str, str]]:
    """Okuma listesindeki desteklenen dökümanları listeler."""
    cfg = get_config()
    valid_extensions = ('.pdf', '.doc', '.docx', '.txt', '.epub')
    matched: List[Dict[str, str]] = []

    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        files = client.list_dir(cfg['webdav_reading_list'])
        matched = [f for f in files if f['name'].lower().endswith(valid_extensions)]
    else:
        rl_dir = Path(cfg['local_reading_list'])
        if rl_dir.exists():
            for item in rl_dir.iterdir():
                if item.is_file() and item.name.lower().endswith(valid_extensions):
                    matched.append({
                        'name': item.name,
                        'local_path': str(item)
                    })

    if json_output:
        print(json.dumps(matched, indent=2, ensure_ascii=False))

    return matched


def cmd_download(filename: str, dest_path: str) -> None:
    """Okuma listesinden bir dosyayı hedefe indirir/kopya oluşturur."""
    clean_filename = safe_filename(filename)
    cfg = get_config()
    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        remote_src = os.path.join(cfg['webdav_reading_list'], clean_filename)
        client.download_file(remote_src, dest_path)
        print(f"✔ WebDAV dosyası indirildi: {remote_src} -> {dest_path}")
    else:
        src_path = os.path.join(cfg['local_reading_list'], clean_filename)
        if not os.path.exists(src_path):
            raise FileNotFoundError(f"Yerel dosya bulunamadı: {src_path}")
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        shutil.copy2(src_path, dest_path)
        print(f"✔ Yerel dosya kopyalandı: {src_path} -> {dest_path}")


def cmd_ensure_shelf(category_name: str) -> None:
    """Ilgili kategori raf klasörünün varlığını garanti eder."""
    clean_category = safe_category(category_name)
    cfg = get_config()
    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        cat_dir = os.path.join(cfg['webdav_shelves'], clean_category)
        client.ensure_dir(cat_dir)
        print(f"✔ WebDAV kategori klasörü doğrulandı/oluşturuldu: {cat_dir}")
    else:
        cat_dir = os.path.join(cfg['local_shelves'], clean_category)
        os.makedirs(cat_dir, exist_ok=True)
        print(f"✔ Yerel kategori klasörü doğrulandı/oluşturuldu: {cat_dir}")


def cmd_upload_summary(local_summary_file: str, category_name: str, summary_filename: str) -> None:
    """Oluşturulan özet raporunu ilgili kategori rafına yükler."""
    clean_category = safe_category(category_name)
    clean_summary_filename = safe_filename(summary_filename)
    cfg = get_config()

    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        cat_dir = os.path.join(cfg['webdav_shelves'], clean_category)
        client.ensure_dir(cat_dir)
        target_remote = os.path.join(cat_dir, clean_summary_filename)
        client.upload_file(local_summary_file, target_remote)
        print(f"✔ Özet raporu WebDAV'a yüklendi: {target_remote}")
    else:
        cat_dir = os.path.join(cfg['local_shelves'], clean_category)
        os.makedirs(cat_dir, exist_ok=True)
        target_local = os.path.join(cat_dir, clean_summary_filename)
        shutil.copy2(local_summary_file, target_local)
        print(f"✔ Özet raporu yerel rafa kaydedildi: {target_local}")


REQUIRED_PACKAGES = {
    'httpx': 'httpx>=0.24.0',
    'pypdf': 'pypdf>=4.0.0',
    'pdfplumber': 'pdfplumber>=0.10.0',
    'docx': 'python-docx>=1.0.0',
}


def ensure_dependencies(quiet: bool = False) -> List[str]:
    """
    pdf-summarizer için gerekli tüm Python paketlerinin (httpx, pypdf, pdfplumber, python-docx)
    kurulu olup olmadığını kontrol eder ve eksik olanları otomatik kurar.
    """
    import importlib.util
    import subprocess

    missing = []
    for mod_name, pkg_spec in REQUIRED_PACKAGES.items():
        if importlib.util.find_spec(mod_name) is None:
            missing.append(pkg_spec)

    if missing:
        if not quiet:
            print(f"📦 PDF Summarizer eksik bağımlılıklar tespit edildi, kuruluyor: {', '.join(missing)}")
        try:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", "--no-cache-dir"] + missing
            )
            if not quiet:
                print("✅ Bağımlılıklar başarıyla kuruldu.")
        except Exception as e:
            if not quiet:
                print(f"⚠️ Bağımlılıklar kurulurken bir hata oluştu: {e}")
            raise e
    else:
        if not quiet:
            print("✅ Tüm PDF Summarizer bağımlılıkları mevcut.")
    return missing


def cmd_setup() -> None:
    """Bağımlılıkları kontrol eder/kurar ve okuma listesi ile akıllı raflar dizinlerini ilklendirir."""
    print("🚀 PDF Summarizer Başlangıç Kurulumu ve Doğrulama Başlatılıyor...")
    ensure_dependencies(quiet=False)
    cmd_init_dirs()
    print("✅ PDF Summarizer kullanım için hazır.")


def cmd_move_to_shelf(filename: str, category_name: str, new_filename: Optional[str] = None) -> None:
    """İşlenen dökümanı okuma listesinden kategori rafına taşır."""
    clean_filename = safe_filename(filename)
    clean_category = safe_category(category_name)
    clean_new_filename = safe_filename(new_filename) if new_filename else None

    target_name = clean_new_filename if clean_new_filename else clean_filename
    cfg = get_config()

    if cfg['target_type'] == 'webdav':
        client = WebDAVClient(cfg['webdav_url'], cfg['webdav_user'], cfg['webdav_pass'])
        cat_dir = os.path.join(cfg['webdav_shelves'], clean_category)
        client.ensure_dir(cat_dir)

        src_remote = os.path.join(cfg['webdav_reading_list'], clean_filename)
        dest_remote = os.path.join(cat_dir, target_name)
        client.move_file(src_remote, dest_remote)
        print(f"✔ WebDAV dosyası taşındı: {src_remote} -> {dest_remote}")
    else:
        cat_dir = os.path.join(cfg['local_shelves'], clean_category)
        os.makedirs(cat_dir, exist_ok=True)

        src_local = os.path.join(cfg['local_reading_list'], clean_filename)
        dest_local = os.path.join(cat_dir, target_name)
        shutil.move(src_local, dest_local)
        print(f"✔ Yerel dosya taşındı: {src_local} -> {dest_local}")


def main() -> None:
    parser = argparse.ArgumentParser(description="PDF Summarizer Depolama Yardımcısı")
    parser.add_argument('--json', action='store_true', help='Çıktıyı JSON formatında sunar (status ve list komutları için)')
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("setup", help="Gerekli Python paketlerini kurar ve okuma/raf dizinlerini ilklendirir")
    subparsers.add_parser("check-deps", help="Gerekli Python paketlerinin varlığını kontrol eder ve eksikleri kurar")
    subparsers.add_parser("init-dirs", help="Varsayılan okuma listesi ve raf dizinlerini ilklendirir")
    subparsers.add_parser("status", help="Mevcut depolama yapılandırmasını gösterir ve bağlantıyı test eder")
    subparsers.add_parser("list", help="Okuma listesindeki döküman dosyalarını listeler")

    dl_p = subparsers.add_parser("download", help="Okuma listesinden dosya indirir/alır")
    dl_p.add_argument("filename", help="Okuma listesindeki dosya adı")
    dl_p.add_argument("dest", help="Yerel hedef yol")

    es_p = subparsers.add_parser("ensure-shelf", help="Kategori raf dizininin varlığını garanti eder")
    es_p.add_argument("category", help="Kategori adı")

    us_p = subparsers.add_parser("upload-summary", help="Özet rapor markdown dosyasını yükler/kaydeder")
    us_p.add_argument("summary_file", help="Yerel özet dosya yolu")
    us_p.add_argument("category", help="Kategori adı")
    us_p.add_argument("filename", help="Hedefteki özet dosya adı")

    mv_p = subparsers.add_parser("move-to-shelf", help="İşlenen dökümanı kategori rafına taşır")
    mv_p.add_argument("filename", help="Okuma listesindeki dosya adı")
    mv_p.add_argument("category", help="Kategori adı")
    mv_p.add_argument("--new-name", help="Raftaki yeni dosya adı (isteğe bağlı)", default=None)

    args = parser.parse_args()

    if args.command == "setup":
        cmd_setup()
    elif args.command == "check-deps":
        ensure_dependencies(quiet=False)
    elif args.command == "init-dirs":
        cmd_init_dirs()
    elif args.command == "status":
        cmd_status(json_output=args.json)
    elif args.command == "list":
        cmd_list(json_output=True)
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
