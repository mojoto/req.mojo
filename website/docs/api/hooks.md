---
title: Event Hooks
---

# Event hooks

Pass `EventHooks` to Client to inspect or modify requests and responses.
Callbacks are synchronous and run in list order for every request/response
exchange, including each followed redirect.

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

Request hooks receive the prepared request after defaults, authentication,
and cookies are applied. Mutated requests are validated before dispatch.
A request-hook error prevents sending and stops later hooks.

Response hooks receive the response before its body is automatically buffered.
Call `response.read()` before accessing `text()` or `json()` in a hook.
A response-hook error closes the response stream and stops later hooks.
Transport failures do not invoke response hooks.

The hook lists are copied when configuring Client. The owning client exposes
`event_hooks: EventHooks`; its lists can also be updated for later exchanges.
