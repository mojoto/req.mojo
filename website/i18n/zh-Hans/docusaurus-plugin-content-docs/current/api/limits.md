---
title: Limits
---

# Limits

`Limits` 配置 Client 和 HTTPTransport 的原生连接池。
模块级函数也接受该参数，但每次调用使用独立连接池。

```text
def __init__(out self)

def __init__(
    out self,
    *,
    max_connections: Optional[Int] = 100,
    max_keepalive_connections: Int = 20,
    keepalive_expiry: Optional[Float64] = 5.0,
) raises HTTPError
```

| 字段 | 含义 |
| --- | --- |
| `max_connections` | 跨目标的物理连接上限，必须为正数；`None` 取消上限。HTTP/2 流共享连接。 |
| `max_keepalive_connections` | 保留的空闲连接上限，必须非负；零表示不保留。 |
| `keepalive_expiry` | 空闲连接有效期，单位为秒，必须有限且非负；零禁用复用，`None` 禁用过期。 |

```mojo
import req


def main() raises:
    var owner = req.Client(
        limits=req.Limits(
            max_connections=10,
            max_keepalive_connections=5,
            keepalive_expiry=15.0,
        ),
        timeout=req.Timeout(pool=2.0),
    )
    with owner.context() as client:
        var response = client.get("https://example.com")
        print(response.status_code)
```

等待连接池容量，包括 HTTP/2 对端的流数量限制，使用 `Timeout.pool`；
超时抛出 `PoolTimeout`。消费完或关闭响应以释放容量。
`validate()` 重新检查三个公开字段，无效值抛出 `InvalidRequest`。

传输配置见 [HTTP/2 与代理](../networking.md)。
