---
title: Development
---

# Development

## Develop from source

For normal use, install from the community channel as described in
[getting started](./getting-started.md). Source development requires
[Pixi](https://pixi.sh), a C compiler, libcurl 7.85+ with TLS support, and zlib.
Install Command Line Tools on macOS, or
`build-essential libcurl4-openssl-dev zlib1g-dev openssl` on Debian/Ubuntu.

```sh
git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build
```

`make build` creates `build/req.mojoc` and `build/libreq_curl.a`.
The Pixi manifest pins Mojo 1.1.0 and the JSON dependency.

## Tests and builds

```sh
make test
make test TEST_ARGS="--list"
make test TEST_ARGS="--only test_client_requests_and_reuse"
make format
make clean
```

Tests use local HTTP/TLS fixtures. The runner independently collects each mapped
compatibility case and the remaining native regressions, then builds one
`.req-test-suite` executable using Mojo TestSuite. `--list` shows semantic case
names; `--only <name>` selects one case. `build/test-results.json` records the
observed result for each compatibility identity. See the
[compatibility inventory](https://github.com/mojoto/req.mojo/blob/main/tests/compat/README.md)
for coverage and API adaptations.
It removes temporary test files after the run. `make build` builds the native
bridge and precompiles `req`; `make clean` removes native/package build output.

## Documentation

The website uses **Docusaurus 3.10.1**, **React 19**, and **Node.js 22+**, matching
[morrow.mojo](https://github.com/mojoto/morrow.mojo). The English source is in
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
