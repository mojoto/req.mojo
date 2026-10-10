---
title: Response
---

# Response

Response 包含 HTTP 元数据和响应体。模块级普通请求与 Client.request() 缓冲响应体；stream() 返回未缓冲响应。Response 可移动，不能隐式复制。读取前先选择整包访问或分块消费。

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

构造已缓冲的 Response，适合测试或适配器。`status_code` 必须为 100–599，否则抛出 `ProtocolError`。
`request` 提供请求元数据和响应 URL；`headers`、`content`、`reason_phrase`、`http_version` 提供响应数据。响应体字节会复制，HEAD 请求的响应体始终为空。普通网络调用会自动构造响应。

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

从传输层的 CurlStream 创建未缓冲 Response，解析状态行和响应头，并接管流的所有权。`request` 提供请求上下文。格式错误抛出 `ProtocolError`；不支持的 Content-Encoding 抛出 `DecodeError`。

这是传输层集成入口，`CurlStream` 位于内部模块；普通应用通过 `req.stream()` 或 `Client.stream()` 创建流式响应。

```text
def from_stream(
    var source: CurlStream, request: Request
) raises HTTPError -> Self
```

## `content`

返回已缓冲 Bytes 的副本，不执行网络读取。尚未读取的流抛出 StreamNotRead，已经分块消费的流抛出 StreamConsumed，未缓存且已关闭的流抛出 StreamClosed。关闭传输后仍能读取已缓存内容。

```text
def content(self) raises HTTPError -> Bytes
```

```mojo
var bytes = response.content()
print(len(bytes))
```

## `read`

把尚未消费的流读取至 EOF，缓存完整解码后的响应体，返回 Bytes 副本。重复调用返回缓存；调用后可使用 text()/json()。不能重新拼回已经 read_chunk() 消费的流，此时抛出 StreamConsumed。读取期间可能发生网络、超时、协议和解码错误。

```text
def read(mut self) raises HTTPError -> Bytes
```

```mojo
with req.stream("GET", "https://example.com") as body:
    _ = body.read()
    print(body.text())
```

## `read_chunk`

消费最多 max_bytes 个解码后的字节，返回 Optional[Bytes]；None 表示 EOF。默认 65536，必须大于零，否则抛出 InvalidRequest。已缓冲响应通过独立偏移遍历缓存；活动流只消费数据，不保留整包缓存，因此后续 read()/text()/json() 抛出 StreamConsumed。到达 EOF 后继续调用返回 None。

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

将缓存字节解码为 String。显式 encoding 覆盖 Content-Type 的 charset；未指定时采用声明的字符集，否则回退 UTF-8。支持 utf-8/utf8、ascii/us-ascii、iso-8859-1/latin-1/latin1。字节无效或不支持该编码时抛出 DecodeError。此方法不会自动缓冲流，请先调用 read()。

```text
def text(
    self, *, encoding: Optional[String] = None
) raises HTTPError -> String
```

## `json`

将缓存响应体按 UTF-8 解码并解析为 JSONValue，不要求 Content-Type 必须是 application/json。UTF-8 无效抛出 DecodeError，JSON 无效抛出 JSONDecodeError。不会自动缓冲活动流，返回值不是无类型字典。

```text
def json(self) raises HTTPError -> JSONValue
```

```mojo
var document = response.json()
print(document.to_string())
```

## `is_success`

状态为 200–299 时返回 True，只检查 HTTP 状态，不校验业务响应体，不抛出错误。

```text
def is_success(self) -> Bool
```

```mojo
if response.is_success():
    print("HTTP success")
```

## `is_redirect`

状态为 301、302、303、307、308 且存在 Location 头时返回 True。没有 Location 的 3xx 不视为可跟随重定向。不执行跟随操作，不抛出错误。

```text
def is_redirect(self) -> Bool
```

```mojo
if response.is_redirect():
    print(response.headers.get("Location"))
```

## `raise_for_status`

400–599 时抛出 HTTPError(kind=HTTPStatusError)，包含 method、URL、status_code 上下文。其他状态正常返回，无返回值；3xx 不被拒绝。传输错误单独处理，可能早于该调用发生。

```text
def raise_for_status(self) raises HTTPError
```

```mojo
response.raise_for_status()
```

## `close`

关闭底层传输流，重复关闭安全，保留已缓存内容。关闭未读取的流不会补充其响应体。使用响应上下文可同时处理正常和异常退出。

```text
def close(mut self)
```

```mojo
response.close()
print(response.is_closed())
```

## `is_closed`

没有活动传输句柄时返回 True。普通缓冲 Response 可能已经返回 True，但 text()/json()/content() 仍可使用。该方法检查传输状态，不表示缓存已删除。

```text
def is_closed(self) -> Bool
```

## 响应字段

`status_code` 是数字 HTTP 状态，`reason_phrase` 是状态文本，可能为空。`http_version` 表示解析出的协议。`url` 是重定向后的最终 URL。`headers` 保留重复响应字段，Set-Cookie 用 get_all() 读取。`request` 描述产生此响应的请求，包括重定向导致的方法和请求体变化。

```text
status_code: Int
reason_phrase: String
http_version: String
url: URL
headers: Headers
request: Request
```

## 响应上下文

上下文转发 Response 的公开操作，在退出代码块时关闭流，包括异常路径。具名的可移动响应必须显式转移（`with response^ as body`）；直接使用 stream() 返回的临时值可省去此步骤。已缓存的缓冲响应即便传输关闭，也可进入上下文。

```text
with req.stream("GET", url) as body: ...
```


```mojo
with req.stream("GET", "https://example.com") as body:
    _ = body.read()
    print(body.text())
```
