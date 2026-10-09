---
title: 流式响应
---

# 流式响应

`stream(method, url)` 收到响应头后返回，无需先缓冲整个响应体，可以逐块读取。

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

`read_chunk(max_bytes=65536)` 返回 `Optional[Bytes]`，EOF 时返回 `None`，块大小必须大于零。gzip/deflate 增量解码，返回的是解码后的字节。示例统计字节数；下载时可在循环内处理或写入每个块。

## 选择消费方式

| 操作 | 行为 |
| --- | --- |
| `read()` | 消费并缓存整个响应体，返回字节副本。 |
| `content()`、`text()`、`json()` | 访问已缓冲或完整缓存的响应体。 |
| `read_chunk()` | 分块消费，不建立整个响应体缓存。 |

对尚未消费的流式响应，先 `read()` 再调用 `text()` 或 `json()`。过早访问抛出 `StreamNotRead`。一旦开始分块消费，整包访问抛出 `StreamConsumed`，不能混用两种消费方式。EOF 后继续读取块返回 `None`。

## 关闭流

响应上下文退出时关闭流，也可以显式 `response.close()`。模块级流式调用的响应拥有传输池，辅助函数返回后仍有效。Client 创建的流式响应保留池的引用，但显式关闭客户端或退出客户端上下文会取消活动响应。

希望连接可复用时，在发起后续请求前完整读取或关闭活动响应，避免长期保留不使用的响应。
