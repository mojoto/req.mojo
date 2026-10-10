# Req.mojo

面向 Mojo 的同步 HTTP 客户端。

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

在[已配置 Mojo 的 Pixi 工作区](https://docs.modular.com/mojo/manual/install/)中，
添加官方 Modular Community 频道并安装 Req：

```bash
pixi workspace channel add --prepend https://repo.prefix.dev/modular-community
pixi add req
```

社区配方正在提交审核；上述命令在包上架后可用。
Req 使用 Mojo **1.1.0**。Pixi 会安装匹配的编译器、libcurl 和 zlib，
以及 Req 的预编译模块、CPU JSON 模块和原生共享库。
Req 自动从当前 Pixi 环境加载原生传输层，无需构建 C 库或添加链接参数。

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

直接运行示例：

```sh
pixi run mojo main.mojo
```

也可以编译后在 Pixi 环境内运行：

```sh
pixi run mojo build main.mojo -o main
pixi run ./main
```

更多示例和包集成方式见[快速开始](https://mojoto.github.io/req.mojo/zh-Hans/docs/getting-started)。

## 开发

```bash
make install-hooks  # 安装提交前格式化 hook（每次克隆后执行一次）
make test    # 运行测试
make format  # 格式化代码
make build   # 构建包
```

hook 在每次提交前执行 `make format`。如果格式化修改了文件，请检查并重新暂存后再提交；hook 不会自动暂存文件。

更多命令和文档开发说明见[开发指南](https://mojoto.github.io/req.mojo/zh-Hans/docs/development)。

Req 使用 [MIT 许可证](LICENSE)。
