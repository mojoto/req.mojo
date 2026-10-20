# Releasing Req

Preparation builds artifacts without publishing them. Do not create or push a
tag, pass a `tag` workflow input, merge a community-channel update, or publish a
GitHub Release until the release is explicitly authorized.

## Prepare and validate

1. Keep `pixi.toml`, website metadata, English/Chinese guides, API signatures,
   and the release draft in `.github/release-notes/<version>.md` aligned.
   Release notes describe installation, runnable usage, defaults, and upgrade
   behavior; they are not pages in the user documentation site.
2. Run `make test build test-package test-docs` and `make doc-build`.
   Complete documentation examples compile without contacting external sites.
3. Push the preparation branch and open a draft PR. The test and package workflows
   cover Linux x86-64, Linux ARM64, and macOS ARM64; the documentation workflow
   builds both locales without deploying PRs.
4. Require all three package jobs and the bundle job on the same preparation
   commit. Each package job runs tests, precompiles the module, verifies isolated
   consumers, and repeats consumer tests after extracting its archive.
   The `release-bundle` CI artifact contains three `.tar.gz` archives and a
   verified `SHA256SUMS`. A branch/PR build skips the publishing job.
5. For another preparation build, dispatch `build.yml` on the preparation branch
   **without** a `tag` input. Never dispatch `pages.yml` for a preparation branch:
   its manual trigger deploys the website.
6. Update `recipes/req` in `modular/modular-community` on a separate branch:
   the release version, immutable source commit, pinned Mojo version, native
   dependencies, description, and installed-consumer tests. Reuse the source package smoke
   test and its HTTP/TLS/HTTP/2/proxy fixtures instead of maintaining a smaller
   duplicate suite. Render the recipe for `linux-64`, `linux-aarch64`, and
   `osx-arm64`; build/test natively where available.
7. Record exact source commits, CI run URLs, artifact checksums, recipe render
   results, and any unavailable public-channel checks in the PRs. A recipe render
   is not a native package build, and a recipe merge is not proof of channel
   publication.

## After release authorization

1. Confirm the release commit and community source pin match the intended source.
   If the source or recipe changes, repeat the relevant validation.
2. Create the version tag only after approval. The tag workflow checks the
   manifest version, builds and verifies all three archives, and publishes with
   the prepared English notes. It does not use generated commit lists as notes.
3. Merge the reviewed community recipe when publication is authorized. Verify
   real installation in fresh workspaces on all three platforms, including
   `pixi add "req==<version>"`, `mojo run`, and compiled execution with automatic
   native loading. HTTP/2 requires a capable libcurl; HTTP/2-only mode requires
   libcurl 8.10 or later.
4. Verify GitHub assets and `SHA256SUMS`, the public channel version, and deployed
   documentation independently. Update any remaining prepublication wording
   only after the corresponding publication is confirmed.
