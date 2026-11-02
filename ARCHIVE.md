# Using a release archive

Prefer the community-channel installation in README.md. The platform archives
are an alternative for an existing Mojo 1.1.0 environment. They include
`req.mojoc`, the native transport, the CPU JSON 0.4.1 modules, and JSON's MIT
license and upstream notices under `licenses/json/`. The optional GPU modules
and simdjson backend binaries are not included; Req uses the native CPU parser.

Install Mojo 1.1.0, libcurl 7.85 or later, and zlib in your Pixi environment.
HTTP/2 requires an HTTP/2-enabled libcurl; HTTP/2-only mode requires 8.10 or later.
The archive's `pixi.toml` and `pixi.lock` record the source build environment.
You do not need to recreate that development environment to use the archive.

Verify the downloaded archive against the release's `SHA256SUMS`, then extract
the archive for your platform. In a Mojo workspace, set the absolute extraction
directory and native library path:

```sh
REQ_PACKAGE=/absolute/path/to/req-0.2.0-mojo-1.1.0-linux-x86_64
export REQ_NATIVE_LIB="$REQ_PACKAGE/libreq_curl.so"
pixi run mojo run -I "$REQ_PACKAGE" main.mojo
pixi run mojo build -I "$REQ_PACKAGE" main.mojo -o main
pixi run ./main
```

On macOS ARM64, select the `macos-arm64` archive and use `libreq_curl.dylib`.
Linux ARM64 uses the `linux-arm64` archive. Keep `REQ_NATIVE_LIB` set when
running the compiled program. No extra linker flags or separate JSON package
are needed. Keep the archive's `json/` directory beside `req.mojoc`.

`SOURCE_COMMIT` identifies the exact Req source. The JSON dependency is pinned
to commit `0bae1f3815d249efa6cb0a3483eb6658700635e5` (0.4.1) in `pixi.lock`.
