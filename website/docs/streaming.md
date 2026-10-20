---
title: Streaming Responses
---

# Streaming responses

`stream(method, url)` returns after response headers are available. Read the
body incrementally instead of buffering it before returning.

```mojo
import req


def main() raises:
    with req.stream("GET", "https://example.com") as body:
        body.raise_for_status()
        var total = 0
        while True:
            var chunk = body.read_chunk(65536)
            if not chunk:
                break
            total += len(chunk.value())
        print(total)
```

`read_chunk(max_bytes=65536)` returns `Optional[Bytes]`, with `None` at EOF.
The size must be positive. gzip/deflate decoding is incremental; returned
chunks contain decoded bytes. This example counts bytes; process or write each
chunk inside the loop for a download.

## Choose a consumption mode

| Operation | Behavior |
| --- | --- |
| `read()` | Consume the complete body and cache it; returns a copy of the bytes. |
| `content()`, `text()`, `json()` | Read a buffered or fully cached body. |
| `read_chunk()` | Consume chunks without building a complete body cache. |

Call `read()` before `text()` or `json()` on an untouched streamed response.
Calling those accessors too early raises `StreamNotRead`. After chunk consumption
starts, whole-body access raises `StreamConsumed`; you cannot mix both modes.
After EOF, further chunk reads return `None`.

## Close streams

A response context closes the stream on block exit. `response.close()` also
closes it explicitly. Module-level streams own their transport pool and remain
valid after the helper returns. Streams created by a Client retain its pool,
but explicit client closure or client-context exit cancels active streams.

Read or close an active response before issuing another request if you want its
connection to be available for reuse. Avoid keeping unused responses open.

## API details

[Response](./api/response.md), [Client](./api/client.md)

## Response iterators

These methods work on Response and its context:

| Method | Yields |
| --- | --- |
| `iter_bytes(chunk_size=65536)` | Decoded byte chunks, including incremental gzip/deflate decoding. |
| `iter_raw(chunk_size=65536)` | Content-encoded bytes with HTTP transfer framing removed. |
| `iter_text(chunk_size=65536, encoding=None)` | Incremental text; chunk size counts Unicode characters. |
| `iter_lines(encoding=None)` | Lines without newline delimiters, recognizing CR, LF, and CRLF. |

Byte and text chunk sizes must be positive. Supported text encodings are UTF-8,
ASCII, and Latin-1. An explicit encoding overrides the response charset; UTF-8
is the fallback. Cached bodies allow repeated decoded iteration, but cannot
reconstruct original compressed bytes for `iter_raw()`. Do not restart live
stream iterators or mix raw and decoded reads. Breaking a loop does not close
the response; use a context or explicit `close()`.

```mojo
import req


def main() raises:
    with req.stream("GET", "https://example.com") as response:
        response.raise_for_status()
        for line in response.iter_lines():
            print(line)
```
