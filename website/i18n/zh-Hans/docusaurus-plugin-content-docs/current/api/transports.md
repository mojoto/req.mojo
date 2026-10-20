---
title: 传输层与字节流
---

# 传输层与字节流

Client 默认持有 HTTPTransport。传入 `transport=` 可以替换传输实现，
此时默认传输配置不再生效。TLS、代理、协议和连接池限制应在注入的 HTTPTransport 上配置。

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

配置方法见 [HTTP/2 与代理](../networking.md)。
显式关闭传输层会取消活动流；销毁持有者时，响应独立保留的连接池仍然有效。

## MockTransport

通过处理函数生成确定的响应，无需启动服务：

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

处理函数接收准备好的 Request，Client 仍负责钩子、Cookie、重定向和响应缓冲。

## BaseTransport 与 Transport

自定义类型实现公开的 `BaseTransport` trait：

```text
def handle_request(
    mut self, request: Request, timeout: Timeout
) raises HTTPError -> Response
def close(mut self)
```

通过 `Transport(value)` 包装，也可以利用隐式构造器直接传入需要 Transport 的位置。
副本共享状态和关闭操作。包装层校验请求，并给 HTTPError 补充方法与 URL 上下文。
重复关闭安全。

## SyncByteStream 与 ByteStream

自定义响应流实现 `SyncByteStream`：

```text
def read_chunk(mut self, max_bytes: Int) raises HTTPError -> Optional[Bytes]
def read_raw_chunk(mut self, max_bytes: Int) raises HTTPError -> Optional[Bytes]
def close(mut self)
```

EOF 时返回 `None`，每次返回的字节数不超过 `max_bytes`。
默认 `read_raw_chunk` 调用 `read_chunk`；编码前后字节不同的实现应覆盖它。
先用 `ByteStream(source)` 包装，再创建响应：

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

ByteStream 副本共享消费与关闭状态，EOF 和错误都会关闭底层流。
自定义流自行定义解码语义。
