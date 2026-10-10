---
title: Bytes and encode_utf8
---

# Bytes and encode_utf8

Use these exports for explicit byte-oriented payloads rather than JSON or form encoding.

```mojo
import req


def main() raises:
    var body = req.encode_utf8("hello")
    print(len(body))
    var response = req.Response(200, request=req.Request("GET", "https://example.com"), content=body)
    print(response.text())
```

## `Bytes`

An owned list of unsigned bytes, used for raw request content and response content/chunks. len(bytes) counts bytes, not characters. It follows Mojo List ownership rules: copy() makes independent bytes and ^ transfers ownership. Empty Bytes and no body are distinct inputs.

```text
Bytes = List[UInt8]
```

## `encode_utf8`

Encode a String into a new Bytes containing its UTF-8 bytes. It does not add a terminator or set a Content-Type, and it performs no I/O. Use it with request content= when you need an explicit raw text body. Non-ASCII characters may occupy multiple bytes.

```text
def encode_utf8(text: String) -> Bytes
```
