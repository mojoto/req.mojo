# Req.mojo

面向 Mojo 的原生同步 HTTP 客户端。Req 提供 HTTP/1.1 API，用于发送请求、
管理连接和 Cookie、处理 JSON 以及流式下载。

<p align="center">
  <a href="https://github.com/mojoto/req.mojo/actions/workflows/test.yml">
    <img src="https://github.com/mojoto/req.mojo/actions/workflows/test.yml/badge.svg" alt="Test" />
  </a>
  <a href="https://github.com/mojoto/req.mojo/actions/workflows/pages.yml">
    <img src="https://github.com/mojoto/req.mojo/actions/workflows/pages.yml/badge.svg" alt="Documentation" />
  </a>
  <a href="https://github.com/mojoto/req.mojo/releases">
    <img alt="GitHub release" src="https://img.shields.io/github/v/release/mojoto/req.mojo">
  </a>
</p>

语言：[English](README.md) | 中文

> 文档：https://mojoto.github.io/req.mojo/zh-Hans/

## 安装

Req 使用 Mojo 1.1.0、[Pixi](https://pixi.sh)、C 编译器和支持 TLS 及 gzip 的
libcurl 7.85+ 从源码构建。macOS 请安装 Command Line Tools；
Debian/Ubuntu 请安装 `build-essential libcurl4-openssl-dev openssl`。

```bash
git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build
```

构建会生成 `build/req.mojoc` 和原生传输桥接库 `build/libreq_curl.a`。
Pixi 环境锁定了 Mojo 编译器和原生 JSON 依赖。预编译包需要兼容的编译器，
请使用项目锁定的版本。

## 用法

将下面的示例保存为项目根目录下的 `main.mojo`：

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

运行时链接原生传输桥接库和 libcurl：

```bash
pixi run mojo run -I . \
  -Xlinker build/libreq_curl.a -Xlinker -lcurl main.mojo
```

Req 支持 HTTP、经过证书验证的 HTTPS、查询参数、重复请求头、表单、原生 JSON，
以及 Basic 和 Bearer 身份验证。持久化客户端复用连接并按作用域管理 Cookie。
流式响应支持增量 gzip/deflate 解码，并提供类型化错误和显式资源所有权。

请求默认验证 TLS，连接、读取和写入分别使用五秒超时，不自动重定向或重试。
可以按需开启重定向，跨源时会移除凭据。HTTP 4xx/5xx 响应正常返回，
调用 `raise_for_status()` 可抛出错误。

当前版本支持同步 HTTP/1.1 和单线程客户端，暂不支持异步、HTTP/2、multipart、
代理和自动重试。Cookie 处理不包含公共后缀数据库，Expires 值支持 IMF-fixdate 格式。

## 开发

源码使用 Mojo 1.1.0。运行 `make install` 安装锁定的 Pixi 环境，
然后运行 `make test build`。CI 在 Linux x86-64、Linux ARM64 和 macOS ARM64
上测试并预编译包。

| 目标 | 说明 |
| --- | --- |
| `make install` | 安装 Pixi 环境并显示 Mojo 版本 |
| `make native` | 构建原生传输桥接库 |
| `make test` | 使用本地 HTTP/TLS 测试服务运行全部测试 |
| `make test TEST_ARGS="--only test_client_requests_and_reuse"` | 运行指定测试 |
| `make format` | 格式化 `req` 和 `tests` 目录 |
| `make build` | 构建原生桥接库并将 `req` 预编译为 `build/req.mojoc` |
| `make clean` | 删除构建产物、临时测试文件和 Python 缓存 |
| `make doc-install` | 安装 Docusaurus 依赖 |
| `make doc-start` | 启动文档开发服务器 |
| `make doc-build` | 构建英文和中文文档 |
| `make doc-serve` | 预览已构建的文档站点 |
| `make doc-clean` | 删除 Docusaurus 生成文件 |

测试运行器自动收集测试模块，使用 Mojo 的 `TestSuite` 发现其中的 `test_` 函数，
并在项目根目录构建一个 `.req-test-suite` 可执行文件。运行结束后会删除临时文件。

文档相关目标需要 Node.js 22+ 和 npm。先运行 `make doc-install` 安装依赖，
再依次运行 `make doc-build` 和 `make doc-serve` 预览构建结果。

包集成方式和文档构建命令见
[快速开始](https://mojoto.github.io/req.mojo/zh-Hans/docs/getting-started)及
[开发指南](https://mojoto.github.io/req.mojo/zh-Hans/docs/development)。

Req 使用 [MIT 许可证](LICENSE)。
