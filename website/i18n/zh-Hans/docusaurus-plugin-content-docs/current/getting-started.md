---
title: 快速开始
---

# 快速开始

安装 Req，用 Mojo 发起你的第一个 HTTP 请求。

## 通过 Pixi 安装

在[已配置 Mojo 的 Pixi 工作区](https://docs.modular.com/mojo/manual/install/)中，
添加官方 Modular Community 频道并安装 Req：

```sh
pixi workspace channel add --prepend https://repo.prefix.dev/modular-community
pixi add req
```

社区配方正在提交审核；上述命令在包上架后可用。
Req 0.1.0 使用 Mojo **1.1.0**。Pixi 会安装匹配的编译器、libcurl 和 zlib，
以及 Req 的预编译模块、CPU JSON 模块和原生共享库。
Req 自动从当前 Pixi 环境加载原生传输层，无需构建 C 库或添加链接参数。

支持 Linux x86-64、Linux ARM64 和 macOS ARM64。

## 发起请求

在 Pixi 工作区根目录创建 `main.mojo`：

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

直接运行示例：

```sh
pixi run mojo main.mojo
```

也可以编译后在 Pixi 环境内运行：

```sh
pixi run mojo build main.mojo -o main
pixi run ./main
```

源码构建和开发依赖见[开发指南](./development.md)。

访问外部站点的示例需要网络；项目测试使用本地服务。继续阅读[请求指南](./requests.md)或[持久客户端](./clients.md)。
