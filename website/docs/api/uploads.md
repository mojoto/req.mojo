---
title: RequestBody and UploadFile
---

# RequestBody and UploadFile

## RequestBody

Use `body=` to send a file without reading it all into Mojo memory, or to send
a finite list of chunks. It cannot be combined with `content`, `data`,
`json`, or `files`.

```text
RequestBody.from_file(path: String) raises HTTPError -> RequestBody
RequestBody.from_bytes(content: Bytes) raises HTTPError -> RequestBody
RequestBody.from_chunks(
    chunks: List[Bytes],
    *,
    known_length: Bool = False,
    replayable: Bool = False,
) raises HTTPError -> RequestBody

def content_length(self) raises HTTPError -> Optional[Int]
def close(mut self)
def is_closed(self) -> Bool
```

`from_file` opens the file during construction and reads it incrementally during
sending. File bodies are replayable; changing the file can cause `WriteError`.
`from_bytes` copies bytes into a replayable body. `from_chunks` copies the
provided list's bytes during construction: it is a finite in-memory source,
not a callback or unbounded producer stream. By default its length is unknown
and it is one-shot. Set `known_length=True` to advertise its byte count and
`replayable=True` to permit resending it.

```mojo
var response = req.post(
    "https://httpbin.org/post",
    body=req.RequestBody.from_file("report.csv"),
)
response.raise_for_status()
```

`content_length()` returns `None` for unknown-length bodies. RequestBody copies
share native source state: aliases of a one-shot body cannot be sent twice.
Closing one wrapper releases its reference; a prepared request can retain the
source.

## UploadFile

Use `files=` for multipart uploads. Add ordinary and repeated fields with
`data=QueryParams(...)`. Req generates a boundary and Content-Type; a manually
supplied Content-Type must contain a valid matching multipart boundary.
Do not combine `files` with `content`, `json`, or `body`.

```text
def __init__(
    out self, name: String, path: String, *,
    filename: Optional[String] = None,
    content_type: String = "application/octet-stream",
) raises HTTPError

def __init__(
    out self, name: String, body: RequestBody, *,
    filename: String = "upload",
    content_type: String = "application/octet-stream",
) raises HTTPError

UploadFile.from_bytes(
    name: String, content: Bytes, *,
    filename: String = "upload",
    content_type: String = "application/octet-stream",
) raises HTTPError -> UploadFile
```

`UploadFile(name, path)` defaults the filename to the path's basename.
The public fields are `name`, `filename`, `content_type`, and `body`.

```mojo
import req


def main() raises:
    var files = List[req.UploadFile]()
    files.append(req.UploadFile.from_bytes(
        "file", req.encode_utf8("hello\n"),
        filename="hello.txt", content_type="text/plain",
    ))
    var fields = req.QueryParams("tag=mojo&tag=http")
    var response = req.post(
        "https://httpbin.org/post", data=fields, files=files,
    )
    response.raise_for_status()
    print(response.status_code)
```

307/308 redirects preserve the body and require a replayable source; attempting
to replay a consumed one-shot upload raises `StreamConsumed`. Redirects that
convert the request to GET drop its body. Uploads work over HTTP/1.1 and HTTP/2.
