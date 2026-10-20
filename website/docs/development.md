---
title: Development
---

# Development

## Develop from source

For normal use, install from the community channel as described in
[getting started](./getting-started.md). Source development requires
[Pixi](https://pixi.sh), a C compiler, libcurl 7.85+ with TLS support (HTTP/2 builds are required for the full test suite), and zlib.
Install Command Line Tools on macOS, or
`build-essential libcurl4-openssl-dev zlib1g-dev openssl` on Debian/Ubuntu.

```sh
git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build
```

`make build` creates `build/req.mojoc` and the native shared library
`build/libreq_curl.so` on Linux or `build/libreq_curl.dylib` on macOS.
From the repository root, run an example with `pixi run mojo -I . main.mojo`.
Req finds the shared library in `build/`; no linker flags are needed.
For a binary launched from another directory, set `REQ_NATIVE_LIB` to the
absolute path of the shared library.
The Pixi manifest pins Mojo 1.1.0 and the JSON dependency.

## Tests and builds

```sh
make test
make test-package
make test-docs
make test TEST_ARGS="--list"
make test TEST_ARGS="--only test_client_requests_and_reuse"
make format
make clean
```

Tests use local HTTP/TLS/HTTP/2 and proxy fixtures and discover functions
directly from `tests/**/test_*.mojo`. `--list` lists cases and `--only <name>`
selects one. `build/test-results.json` records individual outcomes.
Isolated package checks run precompiled consumers outside the checkout with
both `mojo run` and compiled execution, covering uploads, HTTP/2, proxies,
hooks, iterators, and native loading errors.
`make test-docs` compiles complete examples in both locales without contacting
the examples' external sites. `make build` builds the native bridge and package.

## Documentation

The website uses **Docusaurus 3.10.1**, **React 19**, and **Node.js 22+**.
The English source is in
`website/docs`; Simplified Chinese lives in
`website/i18n/zh-Hans/docusaurus-plugin-content-docs/current`.

```sh
make doc-install
make doc-start
make doc-build
make doc-serve
make doc-clean
```

`doc-install` uses the committed npm lockfile. `doc-start` runs the development
server; use `npm --prefix website start -- --locale zh-Hans` for Chinese.
`doc-build` builds both locales with broken links treated as errors. `doc-serve`
previews the production output. `doc-clean` clears generated Docusaurus state
and the website build directory.

The Pages workflow validates documentation pull requests. Changes to the website
on `main` deploy both languages to GitHub Pages through a separate deployment
job. Configure the repository's Pages source as **GitHub Actions**.
