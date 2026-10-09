---
title: 持久客户端
---

# 持久客户端

`Client` 复用连接，保存默认请求头、查询参数、认证、超时和 Cookie。客户端用于单线程场景。

```mojo
import req


def main() raises:
    var owner = req.Client(
        base_url="https://httpbin.org/",
        headers=req.Headers({"Accept": "application/json"}),
        timeout=req.Timeout(10.0),
    )
    with owner.context() as client:
        var first = client.get("get")
        first.raise_for_status()
        var second = client.get("headers")
        print(second.json().to_string())
```

`owner.context()` 借用持有者，在代码块退出时关闭客户端，包括发生错误时。也可显式调用 `close()`，重复关闭是安全的。关闭后请求抛出 `ClientClosed`。关闭客户端会取消活动的流式响应；已缓冲响应仍可读取。

## 基础 URL 和默认值

基础 URL 按 URL 解析规则处理相对引用。例如，`base_url="https://example.com/api/"` 配合 `get("users")` 请求 `/api/users`，而 `get("/users")` 请求 `/users`。基础 URL 表示目录时保留末尾斜杠。绝对请求 URL 替换基础 URL。

请求级请求头覆盖同名客户端请求头。查询参数按键合并：请求参数覆盖客户端参数，客户端参数覆盖 URL 中的同名参数；采用来源中的重复值会保留。客户端认证作用于基础 URL 的 origin，不自动应用到其他 origin；如需认证可显式传入请求级 `auth`。

`build_request()` 应用客户端默认值但不发送。`send(Request(...))` 发送已经构建的请求，不补充这些构建阶段的默认值。

## Cookie

服务端 Set-Cookie 更新客户端 CookieJar，选择 Cookie 时考虑 domain、path、Secure 和过期时间。显式 Cookie 请求头覆盖 jar 生成的值。持有者通过 `owner.cookies` 访问，借用上下文通过 `client.cookies()` 访问。jar 提供 `set`、`get`、`delete` 和 `clear`。

jar 没有公共后缀数据库，不是浏览器 Cookie 策略引擎。

## 重定向和 TLS

默认不跟随重定向。客户端或请求设置 `follow_redirects=True` 后开启，客户端默认 `max_redirects=20`。跨 origin 重定向移除 Authorization、Proxy-Authorization、Cookie 和 Host，再为新 URL 选择 jar Cookie。HTTPS 降级为 HTTP 会抛出 `UnsafeRedirect`。

301/302 将 POST 转为 GET，303 将非 HEAD 方法转为 GET，307/308 保留方法和请求体。方法转换时移除请求体相关头。

默认启用 TLS 验证，`ca_file="/path/to/ca.pem"` 可指定自定义 CA。`verify=False` 禁用验证，不能同时指定 CA 文件。
