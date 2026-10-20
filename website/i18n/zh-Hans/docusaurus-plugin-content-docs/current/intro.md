---
title: 简介
---

# Req.mojo

Req 是 Mojo 原生同步 HTTP 客户端，通过轻量原生桥接使用 libcurl。

- HTTP/1.1 与可选 HTTP/2，默认验证 HTTPS 证书。
- 持久连接、连接池限制和有作用域的 Cookie。
- 查询参数、重复请求头、表单、JSON、字节和 multipart 上传。
- 无需整文件缓冲的文件上传。
- Basic/Bearer 认证，以及连接、读取、写入、连接池四阶段超时。
- 重定向历史、待发送的下一跳请求和响应计时。
- 按字节、文本、行读取流，以及 gzip/deflate 增量解码。
- 请求/响应钩子，可注入 HTTP、模拟或自定义传输层。

从[安装](./getting-started.md)开始，再了解[持久客户端](./clients.md)、
[HTTP/2 与代理](./networking.md)和[流式响应](./streaming.md)。
查看 [0.2.0 版本说明](./releases/0.2.0.md)和 [API 参考](./api-reference.md)。

## 默认行为和范围

默认验证 TLS 证书，连接、读取、写入、连接池四阶段超时均为五秒。
重定向、HTTP/2、环境配置（`trust_env`）需要显式开启。
HTTP 4xx/5xx 正常返回，调用 `raise_for_status()` 后才抛出状态错误。

Client 用于单线程场景，暂不提供异步、HTTP/3、可配置的应用层自动重试和总请求截止时间。
Cookie 实现没有公共后缀数据库，Expires 支持 IMF-fixdate 格式。

CI 在 Linux x86-64、Linux ARM64、macOS ARM64 上运行测试、预编译和隔离消费者检查。
HTTP/2 要求 libcurl 构建包含相应支持；仅 HTTP/2 模式要求 libcurl 8.10 或更新版本。

Req 使用 [MIT 许可证](https://github.com/mojoto/req.mojo/blob/main/LICENSE)。
