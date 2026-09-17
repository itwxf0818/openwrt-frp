#!/usr/bin/env python3
"""Verify sample TOML and pass real HTTP traffic through frpc -> frps locally."""
import argparse
import http.server
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import urllib.request
from upstream import ROOT, metadata

p = argparse.ArgumentParser()
p.add_argument("bin_dir", type=Path)
p.add_argument("--format", choices=("toml", "ini"), default="toml")
a = p.parse_args()
suffix = ".exe" if __import__("os").name == "nt" else ""
binaries = {name: (a.bin_dir / (name + suffix)).resolve() for name in ("frpc", "frps")}
for name, binary in binaries.items():
    version = subprocess.check_output([binary, "--version"], text=True).strip()
    assert version == metadata()["PKG_VERSION"], version
    subprocess.run([binary, "verify", "-c", ROOT / "frp" / "files" / f"{name}.toml"], check=True)


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"openwrt-frp-smoke-ok")

    def log_message(self, *args):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
control, remote = free_port(), free_port()
while remote == control:
    remote = free_port()
processes = []
logs = []
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    (root / "frps.toml").write_text(f'''bindAddr = "127.0.0.1"
bindPort = {control}
proxyBindAddr = "127.0.0.1"
auth.method = "token"
auth.token = "test-only-local-token"
transport.tls.force = true
allowPorts = [{{ single = {remote} }}]
''')
    (root / "frpc.toml").write_text(f'''serverAddr = "127.0.0.1"
serverPort = {control}
auth.method = "token"
auth.token = "test-only-local-token"
transport.tls.enable = true
loginFailExit = false
[[proxies]]
name = "local-test"
type = "tcp"
localIP = "127.0.0.1"
localPort = {server.server_port}
remotePort = {remote}
''')
    if a.format == "ini":
        (root / "frps.ini").write_text(f"""[common]
bind_addr = 127.0.0.1
bind_port = {control}
proxy_bind_addr = 127.0.0.1
authentication_method = token
token = test-only-local-token
tls_only = true
allow_ports = {remote}
""")
        (root / "frpc.ini").write_text(f"""[common]
server_addr = 127.0.0.1
server_port = {control}
authentication_method = token
token = test-only-local-token
tls_enable = true
login_fail_exit = false
[local-test]
type = tcp
local_ip = 127.0.0.1
local_port = {server.server_port}
remote_port = {remote}
""")
    for name in ("frps", "frpc"):
        subprocess.run([binaries[name], "verify", "-c", root / f"{name}.{a.format}"], check=True)
    try:
        for name in ("frps", "frpc"):
            log = (root / f"{name}.log").open("w+")
            logs.append(log)
            processes.append(subprocess.Popen([binaries[name], "-c", root / f"{name}.{a.format}"], stdout=log, stderr=subprocess.STDOUT))
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        for _ in range(60):
            if any(proc.poll() is not None for proc in processes):
                raise RuntimeError("FRP exited before traffic verification")
            try:
                with opener.open(f"http://127.0.0.1:{remote}/", timeout=1) as response:
                    assert response.read() == b"openwrt-frp-smoke-ok"
                    print(f"PASS: {a.format} authenticated TLS tunnel carries real TCP/HTTP traffic")
                    break
            except OSError:
                time.sleep(0.5)
        else:
            raise RuntimeError("Tunnel did not become ready within 30 seconds")
    finally:
        for proc in processes:
            if proc.poll() is None:
                proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
        for log in logs:
            log.seek(0)
            print(log.read())
            log.close()
        server.shutdown()
        server.server_close()
