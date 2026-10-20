---
title: 代理
---

# 代理

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

模块级函数也接受 `proxy` 和 `trust_env`。
