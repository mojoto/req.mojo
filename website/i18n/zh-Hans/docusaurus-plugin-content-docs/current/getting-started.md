---
title: 快速开始
---

# 快速开始

安装 Req，用 Mojo 发起你的第一个 HTTP 请求。

## 环境要求

需要 Mojo **1.1.0**、[Pixi](https://pixi.sh)、C 编译器，以及支持 TLS 和 gzip 的 libcurl **7.85+**。macOS 安装 Command Line Tools（`xcode-select --install`）；Debian/Ubuntu 安装 `build-essential libcurl4-openssl-dev openssl`。

## 从源码构建

```sh
git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build
```

`make build` 生成 `build/libreq_curl.a` 和 `build/req.mojoc`。Pixi 配置固定编译器和原生 JSON 依赖版本。预编译 `.mojoc` 文件要求编译器兼容，请使用项目固定的版本。

## 发起请求

在仓库根目录创建 `main.mojo`：

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

运行时同时链接原生桥接库和 libcurl：

```sh
pixi run mojo run -I . \
  -Xlinker build/libreq_curl.a -Xlinker -lcurl main.mojo
```

`-I .` 导入源码包。如果其他项目使用预编译包，需要把包所在目录加入导入路径，并同样链接桥接库和 libcurl。仅 `import req` 不会自动链接 C 传输层。

访问外部站点的示例需要网络；项目测试使用本地服务。继续阅读[请求指南](./requests.md)或[持久客户端](./clients.md)。
