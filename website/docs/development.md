---
title: Development
---

# Development

## Tests and builds

```sh
make test
make test TEST_ARGS="--only test_client_requests_and_reuse"
make format
make clean
```

Tests use local HTTP/TLS fixtures. The runner collects test modules, discovers
`test_` functions with Mojo TestSuite, and builds one `.req-test-suite` executable.
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
