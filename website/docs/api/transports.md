---
title: Transports and Byte Streams
---

# Transports and byte streams

Client normally owns an HTTPTransport. Pass `transport=` to inject a custom
transport; this replaces the built-in transport configuration. Configure TLS,
proxies, protocols, and limits on the injected HTTPTransport itself.

## HTTPTransport

```text
def __init__(
    out self, *,
    verify: Bool = True,
    ca_file: Optional[String] = None,
    proxy: Optional[String] = None,
    trust_env: Bool = False,
    limits: Limits = Limits(),
    http1: Bool = True,
    http2: Bool = False,
) raises HTTPError

def handle_request(
    mut self, request: Request, timeout: Timeout = Timeout()
) raises HTTPError -> Response
def close(mut self)
def is_closed(self) -> Bool
```

See [HTTP/2](../http2.md) for protocol selection and [proxies](../proxies.md) for routing. Closing the transport cancels active
streams; destroying its owner leaves independently retained response pools alive.

## MockTransport

Use a handler to produce deterministic responses without a server:

```mojo
import req


def handle(request: req.Request) raises req.HTTPError -> req.Response:
    return req.Response(
        200, request=request, content=req.encode_utf8("offline"),
    )


def main() raises:
    var owner = req.Client(transport=req.MockTransport(handle))
    with owner.context() as client:
        var response = client.get("https://example.com")
        print(response.text())
```

The handler receives the prepared Request. Client still applies hooks, cookies,
redirects, and response buffering around it.

## BaseTransport and Transport

A custom type conforms to the public `BaseTransport` trait:

```text
def handle_request(
    mut self, request: Request, timeout: Timeout
) raises HTTPError -> Response
def close(mut self)
```

Wrap it with `Transport(value)`, or pass it directly where Transport is expected
through its implicit constructor. Transport copies share state and closure.
The wrapper validates requests and adds method/URL context to HTTPError.
Closing it is idempotent.

## SyncByteStream and ByteStream

A custom response stream conforms to `SyncByteStream`:

```text
def read_chunk(mut self, max_bytes: Int) raises HTTPError -> Optional[Bytes]
def read_raw_chunk(mut self, max_bytes: Int) raises HTTPError -> Optional[Bytes]
def close(mut self)
```

Return `None` at EOF and never return more than `max_bytes`. The default
`read_raw_chunk` delegates to `read_chunk`; override it when encoded bytes
differ. Wrap the stream in `ByteStream(source)`, then construct a response:

```text
Response.from_byte_stream(
    var source: ByteStream,
    request: Request,
    *,
    status_code: Int = 200,
    headers: Headers = Headers(),
    http_version: String = "HTTP/1.1",
) raises HTTPError -> Response
```

ByteStream copies share consumption and closure. EOF and errors close the
underlying stream. Custom streams supply their own decoding semantics.
