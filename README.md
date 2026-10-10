# Req.mojo

A native synchronous HTTP client for Mojo.

[Documentation](https://mojoto.github.io/req.mojo/) ·
[简体中文](https://mojoto.github.io/req.mojo/zh-Hans/)

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

## Features

- Synchronous HTTP/1.1 and HTTPS with certificate verification.
- Persistent clients with connection reuse and scoped cookies.
- Query parameters, repeated headers, forms, and native JSON.
- Basic and Bearer authentication.
- Separate connect, read, and write timeouts.
- Optional redirects with credentials removed across origins.
- Streaming downloads and incremental gzip/deflate decoding.
- Typed errors and explicit resource ownership.

Requests default to verified TLS, five-second phase timeouts, and no automatic
redirects or retries. HTTP 4xx/5xx responses return normally; call
`raise_for_status()` to raise an error.

This version supports synchronous HTTP/1.1. Async, HTTP/2, multipart, proxies,
and automatic retries are outside its scope. Clients are intended for
single-threaded use. Cookie handling has no public-suffix database and supports
IMF-fixdate Expires values. CI validates Linux x86-64, Linux ARM64, and macOS ARM64.

## Installation

Requires Mojo 1.1.0, [Pixi](https://pixi.sh), a C compiler, and libcurl 7.85+ with
TLS and gzip support. On macOS, install the Command Line Tools. On Debian/Ubuntu,
install `build-essential libcurl4-openssl-dev openssl`.

```sh
pixi install
make build
```

## Testing

```sh
make test
make test TEST_ARGS="--only test_client_requests_and_reuse"
make format
make clean
```

Tests use local HTTP/TLS fixtures. The runner automatically collects test
modules, lets Mojo's `TestSuite` discover their `test_` functions, and builds one
`.req-test-suite` executable in the project root. It removes temporary files
after the run.

## Documentation website

The documentation uses Docusaurus 3 and React, with English and Simplified
Chinese content, matching [morrow.mojo](https://github.com/mojoto/morrow.mojo).
Requires Node.js 22 or newer.

```sh
make doc-install
make doc-start
make doc-build
make doc-serve
```

`make doc-clean` removes generated site files. Pull requests validate both
languages; changes on `main` deploy automatically to GitHub Pages.

req.mojo is [MIT licensed](LICENSE).
