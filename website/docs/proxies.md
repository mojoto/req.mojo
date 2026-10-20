---
title: Proxies
---

# Proxies

## Explicit proxy

```mojo
import req


def main() raises:
    var owner = req.Client(proxy="http://127.0.0.1:8080")
    with owner.context() as client:
        var response = client.get("https://example.com")
        response.raise_for_status()
        print(response.status_code)
```

HTTP and HTTPS proxy URLs are supported, including credentials in the URL.
HTTPS targets use CONNECT. Certificate verification applies to both the proxy
and the target. An explicit `proxy` takes precedence over environment routing
and bypasses `NO_PROXY`; do not log proxy URLs containing credentials.

## Environment configuration

Environment configuration is opt-in: `trust_env=False` by default.
With `Client(trust_env=True)`, Req reads `HTTP_PROXY`, `HTTPS_PROXY`,
`ALL_PROXY`, and `NO_PROXY`, and their lowercase forms. It also reads
`SSL_CERT_FILE` and `SSL_CERT_DIR` when no explicit `ca_file` is supplied.

Module-level helpers accept `proxy` and `trust_env` too.
