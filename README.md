# Req.mojo

A native synchronous HTTP client for Mojo. Req provides an HTTP/1.1 API for
sending requests, managing connections and cookies, working with JSON, and
streaming downloads.

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

Language: English | [中文](README.zh-CN.md)

> Documentation: https://mojoto.github.io/req.mojo/

## Installation

Req builds from source with Mojo 1.1.0, [Pixi](https://pixi.sh), a C compiler,
libcurl 7.85+ with TLS support, and zlib. On macOS, install the Command Line
Tools. On Debian/Ubuntu, install
`build-essential libcurl4-openssl-dev zlib1g-dev openssl`.

```bash
git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build
```

The build creates `build/req.mojoc` and the native transport bridge
`build/libreq_curl.a`. The Pixi environment pins the Mojo compiler and native
JSON dependency. Precompiled packages require a compatible compiler; use the
project's pinned version.

## Usage

Save the following example as `main.mojo` in the repository root:

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

Run it with the native transport bridge, libcurl, and zlib linked:

```bash
pixi run mojo run -I . \
  -Xlinker build/libreq_curl.a -Xlinker -lcurl -Xlinker -lz main.mojo
```

Req supports HTTP and verified HTTPS, query parameters, repeated headers,
forms, native JSON, and Basic or Bearer authentication. Persistent clients
reuse connections and manage scoped cookies. Streaming responses support
incremental gzip/deflate decoding, with typed errors and explicit resource
ownership.

Requests verify TLS by default, use separate five-second connect, read, and
write timeouts, and do not automatically redirect or retry. Enable redirects
when needed; credentials are removed across origins. HTTP 4xx/5xx responses
return normally, so call `raise_for_status()` to raise an error.

This version supports synchronous HTTP/1.1 and single-threaded clients. Async,
HTTP/2, multipart, proxies, and automatic retries are outside its scope.
Cookie handling has no public-suffix database and supports IMF-fixdate Expires
values.

## Development

Source builds use Mojo 1.1.0. Run `make install` to install the pinned Pixi
environment, then run `make test build`. CI tests and precompiles the package
on Linux x86-64, Linux ARM64, and macOS ARM64.

| Target | Description |
| --- | --- |
| `make install` | Install the Pixi environment and show the Mojo version |
| `make native` | Build the native transport bridge |
| `make test` | Run the full test suite with local HTTP/TLS fixtures |
| `make test TEST_ARGS="--only test_client_requests_and_reuse"` | Run a selected test |
| `make format` | Format the `req` and `tests` directories |
| `make build` | Build the native bridge and precompile `req` as `build/req.mojoc` |
| `make clean` | Remove build output, temporary test files, and Python caches |
| `make doc-install` | Install Docusaurus dependencies |
| `make doc-start` | Start the documentation development server |
| `make doc-build` | Build the English and Chinese documentation |
| `make doc-serve` | Preview the built documentation site |
| `make doc-clean` | Remove generated Docusaurus files |

The test runner collects test modules, lets Mojo's `TestSuite` discover their
`test_` functions, and builds one `.req-test-suite` executable in the project
root. It removes temporary files after the run.

The documentation targets require Node.js 22+ and npm. Run `make doc-install`
before building the documentation, then use `make doc-build` followed by
`make doc-serve` to preview the built site.

The [compatibility scenarios](tests/compat/README.md) record the pinned baseline,
native test mappings, API adaptations, and exclusions. The runner validates this
inventory before executing the tests.

See the [getting started guide](https://mojoto.github.io/req.mojo/docs/getting-started)
and [development guide](https://mojoto.github.io/req.mojo/docs/development) for
package integration and documentation build commands.

Req is [MIT licensed](LICENSE).
