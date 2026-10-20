---
title: 事件钩子
---

# 事件钩子

向 Client 传入 `EventHooks`，检查或修改请求与响应。
回调同步执行，并按列表顺序运行；跟随重定向时，每一跳都会执行对应回调。

```text
def __init__(
    out self, *,
    request: List[RequestHook] = List[RequestHook](),
    response: List[ResponseHook] = List[ResponseHook](),
)

RequestHook(handler: def(mut Request) raises HTTPError -> None)
ResponseHook(handler: def(mut Response) raises HTTPError -> None)
```

```mojo
import req


def before_request(mut request: req.Request) raises req.HTTPError:
    request.headers.set("X-Application", "example")


def after_response(mut response: req.Response) raises req.HTTPError:
    response.raise_for_status()


def main() raises:
    var owner = req.Client(event_hooks=req.EventHooks(
        request=[req.RequestHook(before_request)],
        response=[req.ResponseHook(after_response)],
    ))
    with owner.context() as client:
        var response = client.get("https://example.com")
        print(response.status_code)
```

请求钩子接收已应用默认值、认证和 Cookie 的请求，修改后会在发送前重新校验。
请求钩子抛错会阻止发送，也不会继续运行后续钩子。

响应钩子在自动缓冲响应体之前执行。在钩子中访问 `text()` 或 `json()` 前，
先调用 `response.read()`。响应钩子抛错会关闭响应流并停止后续钩子。
传输失败不会执行响应钩子。

配置 Client 时会复制钩子列表。客户端持有者公开 `event_hooks: EventHooks`，
可以修改其中的列表，使后续请求使用新的钩子。
