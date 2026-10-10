---
title: 简介
---

# Req.mojo

Req 是 Mojo 原生同步 HTTP/1.1 客户端。Mojo API 通过轻量原生传输桥接使用 libcurl。

- HTTP 和 HTTPS，默认验证证书。
- 持久连接和有作用域的 Cookie。
- 查询参数、重复请求头、表单、JSON 和原始字节。
- Basic 和 Bearer 认证，独立的连接、读取和写入超时。
- 显式重定向、流式响应，以及 gzip/deflate 增量解码。

从[安装和第一个请求](./getting-started.md)开始，然后了解[持久客户端](./clients.md)和[流式响应](./streaming.md)。[API 参考](./api-reference.md)介绍所有公开导出。

## 默认行为和范围

默认验证 TLS 证书，各阶段超时为五秒。默认不跟随重定向，没有自动重试。HTTP 4xx/5xx 响应正常返回，调用 `raise_for_status()` 后才会抛出状态错误。

当前版本支持同步 HTTP/1.1，不提供异步、HTTP/2、multipart、代理和自动重试。客户端用于单线程场景。Cookie 实现没有公共后缀数据库，Expires 支持 IMF-fixdate 格式。本地运行验证覆盖 macOS ARM64；Linux x86-64 的执行尚未验证。

Req 使用 [MIT 许可证](https://github.com/mojoto/req.mojo/blob/main/LICENSE)。
