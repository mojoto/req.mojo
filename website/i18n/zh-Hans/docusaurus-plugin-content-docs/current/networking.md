---
title: HTTP/2 与代理
---

# HTTP/2 与代理

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

## 显式代理

```mojo
import req


def main() raises:
    var owner = req.Client(proxy="http://127.0.0.1:8080")
    with owner.context() as client:
        var response = client.get("https://example.com")
        response.raise_for_status()
        print(response.status_code)
```

支持 HTTP、HTTPS 代理 URL，可在 URL 中携带认证信息。HTTPS 目标通过 CONNECT 连接。
代理与目标都进行证书验证。显式 `proxy` 优先于环境配置，并绕过 `NO_PROXY`。
不要把含凭据的代理 URL 写入日志。

## 环境配置

默认 `trust_env=False`，需要显式开启。
`Client(trust_env=True)` 读取 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`、
`NO_PROXY` 及对应的小写变量。未显式设置 `ca_file` 时，还会读取
`SSL_CERT_FILE` 和 `SSL_CERT_DIR`。

模块级函数也接受 `proxy`、`trust_env`、`limits`。
通过 [Limits](./api/limits.md) 和 [Timeout](./api/timeout.md) 限制连接数和等待时间。
当前没有可配置的应用层自动重试策略，也没有整个请求的总耗时截止时间。
