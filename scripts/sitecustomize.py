import socket
import json
import os
import urllib.request
import ssl
import sys
import threading

original_getaddrinfo = socket.getaddrinfo

# Thread-local storage to prevent recursion during DoH HTTP requests
_local = threading.local()

pre_resolved_cache = {}
runtime_cache = {}

def load_dns_resolved():
    global pre_resolved_cache
    try:
        if os.path.exists("/tmp/dns-resolved.json"):
            with open("/tmp/dns-resolved.json", "r") as f:
                pre_resolved_cache = json.load(f)
    except Exception:
        pass

# Initialize cache
load_dns_resolved()

DOH_ENDPOINTS = [
    "https://1.1.1.1/dns-query",
    "https://8.8.8.8/resolve",
]

def resolve_via_doh(domain: str) -> str:
    # Try local pre-resolved cache first
    if domain in pre_resolved_cache:
        return pre_resolved_cache[domain]
    if domain in runtime_cache:
        return runtime_cache[domain]

    # Try DoH endpoints
    for endpoint in DOH_ENDPOINTS:
        try:
            url = f"{endpoint}?name={domain}&type=A"
            req = urllib.request.Request(url, headers={"Accept": "application/dns-json"})
            ctx = ssl.create_default_context()
            # Do NOT use high timeout to avoid freezing
            resp = urllib.request.urlopen(req, timeout=4, context=ctx)
            data = json.loads(resp.read().decode())
            ips = [a["data"] for a in data.get("Answer", []) if a.get("type") == 1]
            if ips:
                ip = ips[0]
                runtime_cache[domain] = ip
                return ip
        except Exception:
            continue
    return None

def patched_getaddrinfo(host, port, family=0, type=0, proto=0, flags=0):
    # Check if we are already inside a DoH resolve on this thread to avoid infinite recursion
    if getattr(_local, "in_resolve", False):
        return original_getaddrinfo(host, port, family, type, proto, flags)

    if not host or host in ("localhost", "0.0.0.0", "127.0.0.1", "::1"):
        return original_getaddrinfo(host, port, family, type, proto, flags)

    # Check if host is already an IP address
    if all(c.isdigit() or c == '.' for c in host) or ":" in host:
        return original_getaddrinfo(host, port, family, type, proto, flags)

    # First try original getaddrinfo
    try:
        return original_getaddrinfo(host, port, family, type, proto, flags)
    except (socket.gaierror, OSError):
        # Set reentrancy guard
        _local.in_resolve = True
        try:
            ip = resolve_via_doh(host)
        finally:
            _local.in_resolve = False

        if ip:
            try:
                # Resolve using the resolved IP to build the standard structure
                return original_getaddrinfo(ip, port, family, type, proto, flags)
            except Exception:
                # Fallback to manual structure construction if getaddrinfo on IP fails
                fam = family if family != 0 else socket.AF_INET
                typ = type if type != 0 else socket.SOCK_STREAM
                return [(fam, typ, proto, "", (ip, port))]
        raise

socket.getaddrinfo = patched_getaddrinfo
sys.stderr.write("[dns-fix] Python socket.getaddrinfo patched successfully\n")
sys.stderr.flush()
