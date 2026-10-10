"""TLS HTTP/2 fixture with controlled windows, settings, and wire faults."""

import gzip
import hashlib
import json
import select
import time
from socketserver import BaseRequestHandler
from urllib.parse import parse_qs, urlsplit

from h2.config import H2Configuration
from h2.connection import H2Connection
from h2.events import ConnectionTerminated, DataReceived, RequestReceived, StreamEnded, StreamReset
from h2.exceptions import H2Error
from h2.settings import SettingCodes
from hyperframe.frame import GoAwayFrame, HeadersFrame, PingFrame


class HTTP2Handler(BaseRequestHandler):
    def handle(self):
        if self.request.selected_alpn_protocol() != "h2":
            self.server.http1_handler(self.request, self.client_address, self.server)
            return
        connection = H2Connection(H2Configuration(client_side=False, header_encoding="utf-8"))
        connection.initiate_connection()
        connection.update_settings({SettingCodes.MAX_CONCURRENT_STREAMS: self.server.max_streams,
                                    SettingCodes.INITIAL_WINDOW_SIZE: 1024})
        requests, pending, modes = {}, {}, {}
        scheduled, wire = [], bytearray()
        terminated = False
        self.request.settimeout(2)

        def later(action, delay=0.15):
            scheduled.append((time.monotonic() + delay, action))

        def goaway(stream, code=0):
            frame = GoAwayFrame(0)
            frame.last_stream_id, frame.error_code = stream, code
            wire.extend(frame.serialize())

        def disconnect():
            nonlocal terminated
            terminated = True

        def reply(stream, request):
            path = urlsplit(request["headers"][":path"])
            query = parse_qs(path.query)
            mode = path.path
            method = request["headers"][":method"]
            modes[stream] = mode
            headers, status = [], 200
            if mode == "/reset":
                connection.reset_stream(stream, error_code=2)
                return
            if mode == "/refused-once":
                # A new stream or connection must retry this request only once.
                with self.server.fault_lock:
                    first = path.query not in self.server.refused_tokens
                    self.server.refused_tokens.add(path.query)
                if first:
                    connection.reset_stream(stream, error_code=7)
                    return
            if mode == "/eof-headers":
                disconnect()
                return
            if mode == "/bad-frame":
                # PING must contain exactly eight bytes, on stream zero.
                wire.extend(b"\x00\x00\x01\x06\x00\x00\x00\x00\x00x")
                later(disconnect)
                return
            if mode in ("/bad-headers", "/bad-hpack"):
                frame = HeadersFrame(stream)
                frame.flags.update(["END_HEADERS", "END_STREAM"])
                frame.data = b"\x80" if mode == "/bad-hpack" else connection.encoder.encode([("content-length", "0")])
                wire.extend(frame.serialize())  # Missing mandatory :status.
                later(disconnect)
                return
            if mode == "/slow-headers":
                request["headers"][":path"] = "/echo"
                later(lambda: reply(stream, request))
                return
            if mode == "/settings":
                connection.update_settings({SettingCodes.MAX_CONCURRENT_STREAMS: int(query["max"][0])})
            if mode == "/settings-increase":
                later(lambda: connection.update_settings({SettingCodes.MAX_CONCURRENT_STREAMS: 100}))
            if mode == "/extension":
                wire.extend(b"\x00\x00\x00\xfa\x00\x00\x00\x00\x00")
            if mode == "/ping":
                ping = PingFrame(0)
                ping.opaque_data = b"req-ping"
                wire.extend(ping.serialize())
            if mode in ("/bytes", "/settings-increase"):
                body = bytes(index % 251 for index in range(200000))
            elif mode == "/gzip":
                body = gzip.compress(b"HTTP/2 compressed response")
                headers.append(("content-encoding", "gzip"))
            elif mode == "/redirect":
                status = int(query.get("code", [307])[0])
                body = b""
                headers.append(("location", query.get("to", ["/echo"])[0]))
            elif mode == "/no-content":
                status, body = 204, b""
            elif mode == "/trailers":
                body = b"body with trailers"
            elif mode == "/informational":
                connection.send_headers(stream, [(":status", "103"), ("link", "</early>")])
                body = b"final response"
            elif mode in ("/reset-body", "/goaway-body", "/eof-body", "/slow-body", "/bad-length"):
                body = b"part"
            else:
                body = json.dumps({"method": method, "headers": request["headers"],
                                   "body": request["body"].decode(errors="replace"),
                                   "size": request["size"], "sha256": request["digest"].hexdigest(),
                                   "window_updates": request["window_updates"],
                                   "connection": self.client_address[1], "stream": stream}).encode()
                headers.append(("content-type", "application/json"))
            length = 8 if mode in ("/reset-body", "/goaway-body", "/eof-body", "/slow-body", "/bad-length") else len(body)
            connection.send_headers(stream, [(":status", str(status)),
                                            ("content-length", str(length)),
                                            ("x-connection", str(self.client_address[1])),
                                            ("x-stream", str(stream)), *headers],
                                    end_stream=method == "HEAD" or not body)
            if method == "HEAD" or not body:
                return
            if mode in ("/reset-body", "/goaway-body", "/eof-body", "/slow-body"):
                connection.send_data(stream, body)
                if mode == "/reset-body":
                    later(lambda: connection.reset_stream(stream, error_code=2))
                elif mode == "/goaway-body":
                    later(lambda: goaway(0, 2))
                elif mode == "/eof-body":
                    later(disconnect)
                else:
                    later(lambda: connection.send_data(stream, b"rest", end_stream=True))
            elif mode == "/settings-increase":
                # Leave the response open without a paused DATA backlog so
                # the peer can process the new setting while another stream waits.
                later(lambda: pending.update({stream: memoryview(body)}), 0.2)
            else:
                pending[stream] = memoryview(body)

        try:
            self.request.sendall(connection.data_to_send())
            while not terminated:
                for deadline, action in list(scheduled):
                    if deadline <= time.monotonic():
                        scheduled.remove((deadline, action))
                        try:
                            action()
                        except H2Error:
                            pass  # A client may cancel a scheduled stream.
                for stream, body in list(pending.items()):
                    while body:
                        size = min(len(body), connection.local_flow_control_window(stream),
                                   connection.max_outbound_frame_size)
                        if size <= 0:
                            break
                        final = size == len(body)
                        connection.send_data(stream, body[:size].tobytes(),
                                             end_stream=final and modes[stream] != "/trailers")
                        body = body[size:]
                    if body:
                        pending[stream] = body
                    else:
                        del pending[stream]
                        if modes[stream] == "/trailers":
                            connection.send_headers(stream, [("x-trailer", "finished")], end_stream=True)
                        elif modes[stream] == "/goaway":
                            goaway(stream)
                output = connection.data_to_send() + bytes(wire)
                wire.clear()
                if output:
                    self.request.sendall(output)
                if terminated:
                    return
                if not self.request.pending() and not select.select([self.request], [], [], 0.01)[0]:
                    continue
                data = self.request.recv(65536)
                if not data:
                    return
                for event in connection.receive_data(data):
                    stream = getattr(event, "stream_id", None)
                    if isinstance(event, ConnectionTerminated):
                        # Older nghttp2 versions reject malformed responses with
                        # GOAWAY instead of RST_STREAM. Complete the shutdown.
                        disconnect()
                    elif isinstance(event, RequestReceived):
                        requests[stream] = {"headers": dict(event.headers), "digest": hashlib.sha256(),
                                            "size": 0, "body": bytearray(), "window_updates": 0}
                    elif isinstance(event, DataReceived):
                        request = requests[stream]
                        request["digest"].update(event.data)
                        request["size"] += len(event.data)
                        if len(request["body"]) < 1048576:
                            request["body"].extend(event.data)
                        mode = urlsplit(request["headers"][":path"]).path
                        if mode == "/stall-upload":
                            continue  # Intentionally exhaust both receive windows.
                        if event.flow_controlled_length:
                            connection.increment_flow_control_window(event.flow_controlled_length)
                            connection.increment_flow_control_window(event.flow_controlled_length, stream)
                            request["window_updates"] += 1
                    elif isinstance(event, StreamEnded):
                        reply(stream, requests.pop(stream))
                    elif isinstance(event, StreamReset):
                        requests.pop(stream, None)
                        pending.pop(stream, None)
        except (ConnectionError, TimeoutError, H2Error):
            pass
