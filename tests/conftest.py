"""Deterministic HTTP fixtures used only by the test runner."""

import gzip
import json
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_):
        pass

    def handle(self):
        try:
            super().handle()
        except (ConnectionError, ssl.SSLError):
            pass

    def respond(self, body=b"", status=200, headers=()):
        self.send_response(status)
        for name, value in headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def dispatch(self):
        path = urlsplit(self.path)
        query = parse_qs(path.query, keep_blank_values=True)
        if path.path == "/stall-upload":
            time.sleep(1)
            self.close_connection = True
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        if path.path == "/echo-bytes":
            self.respond(body, headers=[("Content-Type", "application/octet-stream")])
        elif path.path == "/echo-headers":
            values = self.headers.get_all("X-Repeated", [])
            self.respond(json.dumps({"values": values}).encode(), headers=[("Content-Type", "application/json")])
        elif path.path == "/headers-growth":
            self.wfile.write(b"HTTP/1.1 103 Early Hints\r\nX-Interim: ignored\r\n\r\n")
            count = 64 if query.get("overflow") else 60
            headers = [(f"X-Growth-{i}", "v" * 4096) for i in range(count)]
            headers += [("X-Repeated", "first"), ("X-Repeated", "second")]
            self.respond(b"ok", headers=headers)
        elif path.path == "/redirect":
            self.respond(status=int(query.get("code", ["302"])[0]), headers=[("Location", query.get("to", ["/echo"])[0])])
        elif path.path == "/redirect-chain":
            count = int(query.get("count", ["0"])[0])
            if count:
                self.respond(status=302, headers=[("Location", f"/redirect-chain?count={count - 1}")])
            else:
                self.respond(b"finished")
        elif path.path == "/redirect-cookie":
            value = "session=active; Path=/; Max-Age=1209600"
            if query.get("delete"):
                value = "session=gone; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
            self.respond(status=303, headers=[("Location", "/echo"), ("Set-Cookie", value)])
        elif path.path == "/encoded":
            kind = query.get("kind", ["identity"])[0]
            plain = b"" if query.get("empty") else b"test 123"
            if query.get("payload") == ["binary"]:
                plain = bytes(range(256)) * 8
            if kind == "gzip":
                encoded = gzip.compress(plain)
            elif kind == "deflate":
                encoded = zlib.compress(plain)
            elif kind == "raw-deflate":
                compressor = zlib.compressobj(wbits=-zlib.MAX_WBITS)
                encoded = compressor.compress(plain) + compressor.flush()
            elif kind == "multi":
                encoded = gzip.compress(zlib.compress(plain))
            elif kind == "multi-raw":
                compressor = zlib.compressobj(wbits=-zlib.MAX_WBITS)
                encoded = gzip.compress(compressor.compress(plain) + compressor.flush())
            elif kind in ["five", "six"]:
                encoded = plain
                for _ in range(5 if kind == "five" else 6):
                    encoded = gzip.compress(encoded)
            elif kind == "ambiguous-deflate":
                plain = b"A" * 156
                encoded = b"\x78\x9c\x00\x63\xff" + plain + b"\x03\x00"
            else:
                encoded = plain
            encoding = {"raw-deflate": "deflate", "ambiguous-deflate": "deflate", "multi": "deflate, gzip", "multi-raw": "deflate, gzip", "five": ", ".join(["gzip"] * 5), "six": ", ".join(["gzip"] * 6)}.get(kind, kind)
            if query.get("invalid"):
                encoded = b"invalid"
            if query.get("zero"):
                encoded = b""
            if query.get("truncate"):
                encoded = encoded[:-1]
            if query.get("concatenate"):
                encoded += gzip.compress(plain)
            if query.get("fragment"):
                self.send_response(200)
                self.send_header("Content-Encoding", encoding)
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                for offset in range(0, len(encoded), 3):
                    fragment = encoded[offset:offset + 3]
                    self.wfile.write(f"{len(fragment):x}\r\n".encode() + fragment + b"\r\n")
                    self.wfile.flush()
                self.wfile.write(b"0\r\n\r\n")
            else:
                self.respond(encoded, headers=[("Content-Encoding", encoding)])
        elif path.path == "/loop":
            self.respond(status=302, headers=[("Location", "/loop")])
        elif path.path == "/cookies/set":
            self.respond(b"ok", headers=[("Set-Cookie", "a=one; Path=/"), ("Set-Cookie", "b=two; Path=/cookies")])
        elif path.path == "/slow-headers":
            time.sleep(0.35)
            self.respond(b"slow")
        elif path.path == "/slow-body":
            self.send_response(200)
            self.send_header("Content-Length", "8")
            self.end_headers()
            self.wfile.write(b"part")
            self.wfile.flush()
            time.sleep(0.35)
            self.wfile.write(b"rest")
        elif path.path == "/truncated":
            self.send_response(200)
            self.send_header("Content-Length", "100")
            self.end_headers()
            self.wfile.write(b"short")
            self.wfile.flush()
            self.close_connection = True
        elif path.path == "/chunked":
            self.send_response(200)
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            self.wfile.write(b"5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n")
        elif path.path == "/bytes":
            self.respond(b"0123456789" * 20000)
        elif path.path in ["/gzip", "/deflate"]:
            plain = b"decoded content " * 10000
            encoded = gzip.compress(plain) if path.path == "/gzip" else zlib.compress(plain)
            self.respond(encoded, headers=[("Content-Encoding", path.path[1:])])
        elif path.path == "/bad-gzip":
            self.respond(b"invalid compressed body", headers=[("Content-Encoding", "gzip")])
        elif path.path == "/unsupported-encoding":
            self.respond(b"content", headers=[("Content-Encoding", "unknown")])
        elif path.path == "/empty":
            self.respond(status=204)
        elif path.path == "/invalid-utf8":
            self.respond(b"\xff")
        elif path.path.startswith("/status/"):
            self.respond(b"status", status=int(path.path.rsplit("/", 1)[1]))
        else:
            result = {"method": self.command, "path": path.path, "query": path.query,
                      "body": body.decode("utf-8"), "headers": dict(self.headers),
                      "connection": self.client_address[1]}
            self.respond(json.dumps(result).encode(), headers=[("Content-Type", "application/json")])

    do_GET = do_HEAD = do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = dispatch


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, *_):
        pass


class Fixtures:
    def __enter__(self):
        self.directory = tempfile.TemporaryDirectory(prefix="req-tests-")
        root = Path(self.directory.name)
        cert, key = root / "cert.pem", root / "key.pem"
        config = root / "openssl.cnf"
        config.write_text("[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=localhost\n[ext]\nsubjectAltName=DNS:localhost\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,digitalSignature,keyCertSign\n")
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-config", str(config), "-keyout", str(key), "-out", str(cert)], check=True, capture_output=True)
        self.servers = [Server(("127.0.0.1", 0), Handler) for _ in range(3)]
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        self.servers[2].socket = context.wrap_socket(self.servers[2].socket, server_side=True)
        self.blackhole = socket.socket()
        self.blackhole.bind(("127.0.0.1", 0))
        self.blackhole.listen()
        self.stopping = threading.Event()
        self.connections = []

        def accept():
            self.blackhole.settimeout(0.1)
            while not self.stopping.is_set():
                try:
                    connection, _ = self.blackhole.accept()
                    self.connections.append(connection)
                except TimeoutError:
                    pass

        self.accept_thread = threading.Thread(target=accept, daemon=True)
        self.accept_thread.start()
        self.threads = [threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True) for server in self.servers]
        for thread in self.threads:
            thread.start()
        self.environment = {
            "REQ_TEST_URL": f"http://127.0.0.1:{self.servers[0].server_port}",
            "REQ_TEST_OTHER_URL": f"http://127.0.0.1:{self.servers[1].server_port}",
            "REQ_TEST_TLS_URL": f"https://localhost:{self.servers[2].server_port}",
            "REQ_TEST_BLACKHOLE_URL": f"https://127.0.0.1:{self.blackhole.getsockname()[1]}",
            "REQ_TEST_CA_FILE": str(cert),
        }
        return self

    def __exit__(self, *_):
        self.stopping.set()
        self.accept_thread.join()
        self.blackhole.close()
        for connection in self.connections:
            connection.close()
        for server in self.servers:
            server.shutdown()
            server.server_close()
        self.directory.cleanup()
