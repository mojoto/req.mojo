---
title: Bytes 与 encode_utf8
---

# Bytes 与 encode_utf8

需要显式字节载荷而非 JSON 或表单编码时使用这些导出。

```mojo
import req


def main() raises:
    var body = req.encode_utf8("hello")
    print(len(body))
    var response = req.Response(200, request=req.Request("GET", "https://example.com"), content=body)
    print(response.text())
```

## `Bytes`

拥有的无符号字节列表，用于原始请求体和响应内容/块。len(bytes) 统计字节，不是字符；采用 Mojo List 的所有权规则，copy() 复制独立字节，^ 转移所有权。空 Bytes 和未提供请求体是不同输入。

```text
Bytes = List[UInt8]
```

## `encode_utf8`

把 String 编码为新的 UTF-8 Bytes，不添加结束符，不设置 Content-Type，不进行 I/O。需要显式原始文本请求体时与 content= 配合使用。非 ASCII 字符可能占多个字节。

```text
def encode_utf8(text: String) -> Bytes
```
