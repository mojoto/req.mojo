---
title: Response
---

# Response

A Response combines HTTP metadata and a body. Module-level requests and Client.request() buffer the body; stream() returns an unbuffered response. Response is movable, so you cannot implicitly copy it. Choose whole-body access or chunk consumption before reading.

```mojo
import req


def main() raises:
    var response = req.Response(
        200,
        request=req.Request("GET", "https://example.com"),
        headers=req.Headers({"Content-Type": "application/json"}),
        content=req.encode_utf8('{"name":"Mojo"}'),
    )
    response.raise_for_status()
    print(response.json()["name"].string_value())
    print(response.is_success())
```

## `Response()`

Construct an already-buffered Response, useful for tests or adapters. `status_code`
must be 100–599 or construction raises `ProtocolError`. `request` supplies the
request metadata and response URL; `headers`, `content`, `reason_phrase`, and
`http_version` provide response data. Content bytes are copied. A HEAD request
always produces an empty response body. Network operations normally construct
responses for you.

```text
def __init__(
    out self,
    status_code: Int,
    *,
    request: Request,
    headers: Headers = Headers(),
    content: Bytes = Bytes(),
    reason_phrase: String = "",
    http_version: String = "HTTP/1.1",
) raises HTTPError
```

## `from_stream`

Create an unbuffered Response from a transport CurlStream, parsing its status line and headers and taking ownership of the stream. `request` supplies request context. Invalid response framing raises `ProtocolError`; unsupported Content-Encoding raises `DecodeError`.

This is a transport integration hook. CurlStream lives in an internal module; applications obtain streamed responses through `req.stream()` or `Client.stream()`.

```text
def from_stream(
    var source: CurlStream, request: Request
) raises HTTPError -> Self
```

## `content`

Return a copy of the already buffered Bytes. This method performs no network read. An untouched stream raises StreamNotRead; a chunk-consumed stream raises StreamConsumed; an uncached closed stream raises StreamClosed. Buffered content remains readable after transport closure.

```text
def content(self) raises HTTPError -> Bytes
```

```mojo
var bytes = response.content()
print(len(bytes))
```

## `read`

Read an untouched stream to EOF and cache its full decoded body, then return a copy of Bytes. Repeated calls return the cached content. This is the bridge from streaming to text()/json(). It cannot recover a stream already consumed with read_chunk(); that raises StreamConsumed. Network, timeout, protocol, and decoding failures may occur while reading.

```text
def read(mut self) raises HTTPError -> Bytes
```

```mojo
with req.stream("GET", "https://example.com") as body:
    _ = body.read()
    print(body.text())
```

## `read_chunk`

Consume up to max_bytes decoded bytes, returning Optional[Bytes]; None means EOF. max_bytes defaults to 65536 and must be positive, otherwise InvalidRequest. On a buffered response this walks an independent offset through the cached body. On a live stream it consumes data without retaining a whole-body cache, so later read()/text()/json() raise StreamConsumed. Once EOF is reached, later calls return None.

```text
def read_chunk(
    mut self, max_bytes: Int = 65536
) raises HTTPError -> Optional[Bytes]
```

```mojo
with req.stream("GET", "https://example.com") as body:
    while True:
        var chunk = body.read_chunk(65536)
        if not chunk:
            break
        print(len(chunk.value()))
```

## `text`

Decode cached bytes to String. An explicit encoding overrides the Content-Type charset; otherwise charset is honored and the fallback is UTF-8. Supported names include utf-8/utf8, ascii/us-ascii, and iso-8859-1/latin-1/latin1. Invalid bytes or an unsupported encoding raise DecodeError. This does not buffer a stream: call read() first.

```text
def text(
    self, *, encoding: Optional[String] = None
) raises HTTPError -> String
```

## `json`

Decode the cached body as UTF-8 and parse a JSONValue. It does not require Content-Type to say application/json. Invalid UTF-8 raises DecodeError; invalid JSON raises JSONDecodeError. This does not buffer a live stream and does not return an untyped dictionary.

```text
def json(self) raises HTTPError -> JSONValue
```

```mojo
var document = response.json()
print(document.to_string())
```

## `is_success`

Return True for status codes 200–299. This inspects only HTTP status and does not validate an application-specific response body. It does not raise.

```text
def is_success(self) -> Bool
```

```mojo
if response.is_success():
    print("HTTP success")
```

## `is_redirect`

Return True only for 301, 302, 303, 307, or 308 with a Location header. A 3xx status without Location is not actionable as a redirect. This method does not follow the redirect and does not raise.

```text
def is_redirect(self) -> Bool
```

```mojo
if response.is_redirect():
    print(response.headers.get("Location"))
```

## `raise_for_status`

Raise HTTPError(kind=HTTPStatusError) for 400–599, including method, URL, and status_code context. For other statuses return normally with no result; 3xx is not rejected. Transport errors are separate and may already have occurred before this method is called.

```text
def raise_for_status(self) raises HTTPError
```

```mojo
response.raise_for_status()
```

## `close`

Close the underlying transport stream. Repeated closure is safe and buffered content is retained. Closing an unread stream does not populate its content. Use a response context for closure on both normal and exceptional paths.

```text
def close(mut self)
```

```mojo
response.close()
print(response.is_closed())
```

## `is_closed`

Return True when no live transport handle remains. An ordinary buffered Response may already report True while text(), json(), and content() still work. This is a transport-state check, not an indication that cached content was discarded.

```text
def is_closed(self) -> Bool
```

## Response fields

`status_code` is the numeric HTTP status; `reason_phrase` is the status text and may be empty. `http_version` identifies the parsed protocol. `url` is the final response URL after redirects. `headers` preserves repeated response fields; use get_all() for Set-Cookie. `request` describes the request that produced this response, including redirected method/body changes.

```text
status_code: Int
reason_phrase: String
http_version: String
url: URL
headers: Headers
request: Request
```

## Response context

The context delegates the public Response operations and closes the stream when the block exits, even on error. A named movable response must be explicitly transferred (`with response^ as body`); using the temporary returned by stream() avoids that extra ownership step. A cached buffered response can enter a context even when its transport is already closed.

```text
with req.stream("GET", url) as body: ...
```


```mojo
with req.stream("GET", "https://example.com") as body:
    _ = body.read()
    print(body.text())
```
