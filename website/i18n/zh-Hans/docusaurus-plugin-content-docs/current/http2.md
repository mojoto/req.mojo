---
title: HTTP/2
---

# HTTP/2

## 启用 HTTP/2

默认使用 HTTP/1.1。通过持久 Client 开启 HTTP/2：

```mojo
import req

def main() raises:
    var owner = req.Client(http2=True)
    with owner.context() as client:
        var response = client.get("https://example.com")
        response.raise_for_status()
        print(response.http_version)
```

`http1=True, http2=True` 时，HTTPS 通过 ALPN 协商 HTTP/2，也可以回退到 HTTP/1.1。
设置 `http1=False, http2=True` 可只使用 HTTP/2。两者都关闭会抛出 `InvalidRequest`。
模块级函数使用 HTTP/1.1；协议选择通过 Client 或 HTTPTransport 配置。

原生 libcurl 必须支持 HTTP/2；仅 HTTP/2 模式还要求 libcurl 8.10 或更新版本。
不满足要求时，创建客户端会抛出 `InvalidRequest`。
支持连接复用和多个重叠的 HTTP/2 响应流，Client 仍用于单线程场景。

通过 [Limits](./api/limits.md) 管理物理连接数，通过 [Timeout.pool](./api/timeout.md) 限制等待流容量的时间。
