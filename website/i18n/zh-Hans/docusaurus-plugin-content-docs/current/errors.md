---
title: 错误处理
---

# 错误处理

HTTP 操作抛出 `HTTPError`，包含 `kind`、`message`，以及可选上下文 `method`、`url`、`status_code`。并非每个错误都填充所有字段。

```mojo
import req


def main() raises:
    try:
        var response = req.get("https://example.com")
        response.raise_for_status()
    except error:
        if error.kind == req.ErrorKind.HTTPStatusError:
            print(error.status_code.value())
        else:
            print(error.kind, error.message)
```

HTTP 4xx/5xx 默认是正常响应，调用 `raise_for_status()` 才抛错。传输失败可能发生在发送或消费响应体期间；成功收到响应头不代表流式响应体一定能完整读取。

| 错误类型 | 含义 |
| --- | --- |
| `InvalidURL`、`InvalidRequest` | URL、请求头、请求体、超时或配置无效。 |
| `ConnectError`、`ReadError`、`WriteError` | 对应阶段传输失败。 |
| `ConnectTimeout`、`ReadTimeout`、`WriteTimeout` | 对应阶段超时。 |
| `TLSError`、`ProtocolError` | TLS 验证/握手失败或 HTTP 协议错误。 |
| `TooManyRedirects`、`UnsafeRedirect` | 超过重定向次数或 HTTPS 降级。 |
| `HTTPStatusError` | 显式抛出的 HTTP 4xx/5xx 状态错误。 |
| `DecodeError`、`JSONDecodeError` | 文本/JSON 解码失败或 JSON 类型访问无效。 |
| `ClientClosed`、`StreamClosed` | 操作已关闭的客户端或流。 |
| `StreamNotRead`、`StreamConsumed` | 缓冲前或分块消费后尝试访问整个响应体。 |

Req 不自动重试请求。应用层重试时，应考虑请求操作和请求体是否能安全再次发送。
