# Benchmarks

## Run

Requires Pixi, Go, a C compiler, libcurl, and zlib. Run from the repository root:

```sh
pixi install
pixi run python benchmarks/run.py --baseline HEAD --sizes 128 65536
```

To check for regressions against a release:

```sh
pixi run python benchmarks/run.py --baseline v0.1.0 --max-regression-percent 5
```

This exits with a failure if throughput loss or client CPU/request increase
exceeds 5% in any scenario, checking both paired changes and the report's
median values. Pairing compares adjacent baseline/current trials within each round. The report and
`regression-check.json` remain available on failure. P99 is reported separately;
the guard does not gate latency, and desktop background load still requires
review or a repeat of borderline results.

The runner compares a Git revision with the working tree. The `current` column
reports the working-tree performance. Use `--baseline <ref>` for another
revision, or `--baseline-source <directory>` for a snapshot containing `req/`.

```sh
# Quick smoke test
pixi run python benchmarks/run.py --sizes 128 --concurrency 1 8 --rounds 1 --seconds 1

# 64 additional response headers
pixi run python benchmarks/run.py --headers 64 --sizes 128 --concurrency 1 32

# A different URL on every request, preserving the same origin and response
pixi run python benchmarks/run.py --vary-url --sizes 128 --concurrency 1 32 --max-regression-percent 5

# POST uploads; each response is 128 B
for size in 128 65536 1048576; do
  pixi run python benchmarks/run.py --upload-size "$size" --sizes 128 --concurrency 1 32
done
```

Defaults are five rounds of two seconds per variant/scenario, 1/8/32/128
workers, and 128 B/4 KiB/64 KiB responses. `--upload-size 0` selects GET.
`--headers` accepts 0–128 extra fields. Run measurements serially without
concurrent builds, tests, or other heavy work.

Each run creates a directory under `build/performance/` containing `REPORT.md`,
`summary.json`, `raw-results.jsonl`, `environment.json`, frozen sources, and
binaries. `--output <directory>` selects a new directory. Environment records
include compiler flags and source/binary hashes; generated artifacts are Git-ignored.

HTTP/1.1 keep-alive, one independent Client/pool per OS worker, and one Go
loopback server are used for both variants. Each worker warms up with 30
requests. Every response is fully read/copied through public `content()`;
warm-up checks all bytes, while timed requests check status, length, boundary
bytes and connection reuse. POST inputs are preallocated; the server checks
the method, length and every uploaded byte. Each trial must have zero errors
and reach its requested peak concurrency.

## Recorded results before the performance optimization

Measured on **2026-10-10 13:18–13:38 CST (UTC+8)**, using the frozen implementation identified in the raw-data directory below:

| Environment | Value |
| --- | --- |
| CPU | Apple M4 Pro, 12 logical CPUs |
| OS / architecture | macOS 27.0.1 / arm64 |
| Mojo | 1.1.0 (`8189361e`) |
| Go server | 1.26.3, standard library |
| Build | Mojo `--Werror -O3`; C `-O2 -std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror` |
| Protocol | HTTP/1.1, loopback, keep-alive |
| Trials | Five rounds × two seconds per variant/scenario |
| Host load | Active desktop with CPU-intensive background processes, including system security scans |

Throughput is the median trial rate. CPU/req is the median per-trial process
user + system time divided by timed requests, from barrier release through
worker joins. It includes request validation and cleanup; it excludes warm-up,
startup, result serialization and server CPU. P99 pools samples from one in
16 requests, capped at 65,536 samples per worker/trial.

### GET, ordinary response headers

| Response | Workers | req/s | CPU µs/req | P99 µs |
| --- | ---: | ---: | ---: | ---: |
| 128 B | 1 | 18,413 | 28.25 | 89 |
| 128 B | 8 | 49,591 | 73.94 | 291 |
| 128 B | 32 | 63,719 | 83.11 | 2,515 |
| 128 B | 128 | 62,987 | 91.00 | 10,152 |
| 64 KiB | 1 | 10,490 | 58.09 | 129 |
| 64 KiB | 8 | 27,658 | 126.93 | 497 |
| 64 KiB | 32 | 34,468 | 129.08 | 3,301 |
| 64 KiB | 128 | 28,950 | 169.09 | 24,711 |

### GET, 64 additional response headers, 128 B response

| Workers | req/s | CPU µs/req | P99 µs |
| ---: | ---: | ---: | ---: |
| 1 | 10,685 | 49.58 | 180 |
| 32 | 50,955 | 80.26 | 2,172 |

### POST, 128 B response

| Upload | Workers | req/s | CPU µs/req | P99 µs |
| --- | ---: | ---: | ---: | ---: |
| 128 B | 1 | 18,515 | 28.49 | 104 |
| 128 B | 32 | 87,504 | 64.96 | 1,804 |
| 64 KiB | 1 | 10,752 | 47.97 | 184 |
| 64 KiB | 32 | 30,424 | 95.43 | 3,723 |
| 1 MiB | 1 | 1,906 | 377.60 | 820 |
| 1 MiB | 32 | 5,849 | 779.26 | 15,362 |

The complete baseline/current measurement suite validated **160 trials and
9,682,912 timed requests with zero errors**. The client and server share CPU
and memory bandwidth; these numbers describe this local workload, not
internet/TLS performance or a shared asynchronous client. Background load was
not controlled.

Raw data for this measurement: `build/performance/refresh-20261010T044700Z`.

## CPU microbenchmarks

These drivers measure local operations without network I/O. Each invocation
runs for 0.5 seconds and validates its results.

```sh
make native
pixi run mojo build --Werror -O3 -I . \
  benchmarks/cpu.mojo -o build/cpu-bench
BENCH_CPU_MODE=headers BENCH_CPU_SIZE=64 build/cpu-bench
BENCH_CPU_MODE=token BENCH_CPU_SIZE=256 build/cpu-bench

pixi run mojo build --Werror -O3 -I . \
  benchmarks/request_cpu.mojo -o build/request-cpu
BENCH_URL_KIND=short BENCH_UPLOAD_SIZE=0 build/request-cpu
BENCH_URL_KIND=long BENCH_UPLOAD_SIZE=0 build/request-cpu
BENCH_URL_KIND=escaped BENCH_UPLOAD_SIZE=0 build/request-cpu
BENCH_URL_KIND=short BENCH_UPLOAD_SIZE=65536 build/request-cpu
BENCH_URL_KIND=short BENCH_UPLOAD_SIZE=1048576 build/request-cpu
```

`cpu.mojo` tests header lookups or token validation. `request_cpu.mojo` measures
`Client.build_request()` plus URL/body validation; client/input creation is
outside timing. `long` appends a 512-byte ASCII path; `escaped` includes percent
escapes and Unicode. Output is `RESULT operations elapsed_ns checksum`.

Current request-construction results in the same environment (median of five
trials per case; complete construction/validation loop, not network latency):

| URL / raw body | ns/op |
| --- | ---: |
| Short ASCII URL, no body | 814 |
| 512-byte ASCII path suffix, no body | 3,786 |
| Escapes and Unicode, no body | 1,301 |
| Short URL, 64 KiB body | 1,534 |
| Short URL, 1 MiB body | 14,374 |

Header/token results (median of five trials; one lookup or validation per op):

| Operation | ns/op |
| --- | ---: |
| Header lookup, 64 extra fields, mixed queries | 340 |
| Token validation, 256-byte input, valid/invalid mix | 105 |

The native header probe counts buffer reallocations for one status line and
64 fields (current result: **3**) and checks overflow, status reset and trailer
boundaries:

```sh
cc -O2 -std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror -I . \
  benchmarks/header_allocations.c -lcurl -lz -o build/header-allocations
build/header-allocations
```

Check the benchmark aggregation code with:

```sh
pixi run python -m unittest discover -s benchmarks -p 'test_*.py'
```
