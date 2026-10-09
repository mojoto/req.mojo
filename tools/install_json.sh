#!/bin/sh
set -eu

revision="$1"
destination=".deps/json"
if [ -f "$destination/.revision" ] && [ "$(cat "$destination/.revision")" = "$revision" ]; then
    exit 0
fi
mkdir -p .deps
temporary="$(mktemp -d .deps/json-download.XXXXXX)"
trap 'rm -rf "$temporary"' EXIT HUP INT TERM
curl -fsSL --retry 3 "https://codeload.github.com/ehsanmok/json/tar.gz/$revision" -o "$temporary/source.tar.gz"
mkdir "$temporary/source"
tar -xzf "$temporary/source.tar.gz" --strip-components=1 -C "$temporary/source"
printf '%s\n' "$revision" > "$temporary/source/.revision"
if [ -d "$destination" ]; then
    mv "$destination" "$temporary/previous"
fi
mv "$temporary/source" "$destination"
