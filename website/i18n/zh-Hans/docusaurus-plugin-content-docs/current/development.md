---
title: 开发指南
---

# 开发指南

## 从源码开发

日常使用请按[快速开始](./getting-started.md)通过社区频道安装。
从源码开发需要 [Pixi](https://pixi.sh)、C 编译器、支持 TLS 的 libcurl 7.85+ 和 zlib；完整测试还要求 libcurl 支持 HTTP/2。
macOS 安装 Command Line Tools；Debian/Ubuntu 安装
`build-essential libcurl4-openssl-dev zlib1g-dev openssl`。

```sh
git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build
```

`make build` 生成 `build/req.mojoc` 和原生共享库：
Linux 下为 `build/libreq_curl.so`，macOS 下为 `build/libreq_curl.dylib`。
在仓库根目录运行示例：`pixi run mojo -I . main.mojo`。
Req 自动从 `build/` 加载共享库，无需添加链接参数。
如果在其他目录启动编译好的程序，可通过 `REQ_NATIVE_LIB` 指定共享库的绝对路径。
Pixi 配置固定 Mojo 1.1.0 和 JSON 依赖版本。

## 测试和构建

```sh
make test
make test-package
make test-docs
make test TEST_ARGS="--list"
make test TEST_ARGS="--only test_client_requests_and_reuse"
make format
make clean
```

测试使用本地 HTTP/TLS/HTTP/2 和代理服务，直接从 `tests/**/test_*.mojo` 收集用例。
`--list` 列出用例，`--only <name>` 选择单项。`build/test-results.json` 记录逐项结果。
隔离安装检查在仓库外执行预编译消费者的 `mojo run` 和编译后程序，覆盖上传、HTTP/2、代理、钩子、迭代器和原生加载错误。
`make test-docs` 编译两种语言中的完整 Mojo 示例，不访问示例外部站点。
`make build` 构建原生桥接库并预编译包。

## 文档网站

网站使用 **Docusaurus 3.10.1**、**React 19** 和 **Node.js 22+**。英文源文档位于 `website/docs`，简体中文位于 `website/i18n/zh-Hans/docusaurus-plugin-content-docs/current`。

```sh
make doc-install
make doc-start
make doc-build
make doc-serve
make doc-clean
```

`doc-install` 使用提交的 npm 锁文件。`doc-start` 启动开发服务器；中文开发使用 `npm --prefix website start -- --locale zh-Hans`。`doc-build` 构建两种语言，把断链视为错误。`doc-serve` 预览生产构建。`doc-clean` 清理 Docusaurus 生成状态和网站构建目录。

Pages 工作流校验文档 PR。`main` 上的网站变更由独立发布任务部署两种语言至 GitHub Pages。仓库 Pages 来源需设置为 **GitHub Actions**。

## 0.2.0 发布准备

正式发布步骤见仓库 [RELEASING.md](https://github.com/mojoto/req.mojo/blob/main/RELEASING.md)。
准备阶段只构建和验收产物，不创建 tag、不上传正式 Release，也不合并社区上架变更。
