---
title: 开发指南
---

# 开发指南

## 测试和构建

```sh
make test
make test TEST_ARGS="--only test_client_requests_and_reuse"
make format
make clean
```

测试使用本地 HTTP/TLS 服务。运行器收集测试模块，用 Mojo TestSuite 发现 `test_` 函数，构建一个 `.req-test-suite` 可执行文件，运行后清理临时文件。`make build` 构建原生桥接库并预编译 `req`；`make clean` 清理原生和包构建产物。

## 文档网站

网站使用 **Docusaurus 3.10.1**、**React 19** 和 **Node.js 22+**，与 [morrow.mojo](https://github.com/mojoto/morrow.mojo) 一致。英文源文档位于 `website/docs`，简体中文位于 `website/i18n/zh-Hans/docusaurus-plugin-content-docs/current`。

```sh
make doc-install
make doc-start
make doc-build
make doc-serve
make doc-clean
```

`doc-install` 使用提交的 npm 锁文件。`doc-start` 启动开发服务器；中文开发使用 `npm --prefix website start -- --locale zh-Hans`。`doc-build` 构建两种语言，把断链视为错误。`doc-serve` 预览生产构建。`doc-clean` 清理 Docusaurus 生成状态和网站构建目录。

Pages 工作流校验文档 PR。`main` 上的网站变更由独立发布任务部署两种语言至 GitHub Pages。仓库 Pages 来源需设置为 **GitHub Actions**。
