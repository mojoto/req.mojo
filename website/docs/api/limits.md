---
title: Limits
---

# Limits

`Limits` controls the native connection pool used by Client and HTTPTransport.
Module-level helpers also accept it, but each call owns an independent pool.

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

| Field | Meaning |
| --- | --- |
| `max_connections` | Maximum physical connections across origins. Must be positive; `None` removes the limit. HTTP/2 streams share connections. |
| `max_keepalive_connections` | Maximum retained idle connections. Must be nonnegative; zero disables retention. |
| `keepalive_expiry` | Idle lifetime in seconds. Must be finite and nonnegative; zero disables reuse and `None` disables expiry. |

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

Waiting for pool capacity, including an HTTP/2 peer's stream limit, uses
`Timeout.pool` and raises `PoolTimeout` when it expires. Consume or close
responses to release capacity. `validate()` rechecks the three public fields
and raises `InvalidRequest` for invalid values.

See [HTTP/2](../http2.md) for stream capacity and connection reuse.
