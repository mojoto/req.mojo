"""Compare a Git revision or source snapshot with the working tree on one local server."""

import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import random
import shutil
import statistics
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]


def run(args, **kwargs):
    return subprocess.run(args, check=True, cwd=ROOT, **kwargs)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def percentile(samples, fraction):
    values = sorted(samples)
    return values[int((len(values) - 1) * fraction)] / 1000


def summarize(rows):
    summaries = []
    keys = sorted({(r['bytes'], r['concurrency'], r['variant']) for r in rows})
    for size, concurrency, variant in keys:
        trials = [r for r in rows if (r['bytes'], r['concurrency'], r['variant']) == (size, concurrency, variant)]
        samples = [n for r in trials for n in r['latency_ns']]
        summary = {
            'bytes': size, 'concurrency': concurrency, 'variant': variant,
            'qps_median': statistics.median(r['qps'] for r in trials),
            'qps_min': min(r['qps'] for r in trials),
            'qps_max': max(r['qps'] for r in trials),
            'p50_us': percentile(samples, .5),
            'p95_us': percentile(samples, .95),
            'p99_us': percentile(samples, .99),
            'requests': sum(r['requests'] for r in trials),
            'errors': sum(r['errors'] for r in trials),
        }
        if all('client_cpu_us' in r for r in trials):
            summary['client_cpu_us_per_request_median'] = statistics.median(
                r['client_cpu_us'] / r['requests'] for r in trials
            )
        summaries.append(summary)
    return summaries


def report(summaries, args, commit):
    lines = [
        '# HTTP performance comparison', '',
        f'Baseline: `{commit}`. Current: frozen working tree.',
        f'{args.rounds} rounds of {args.seconds} seconds per variant and scenario; fixed random order.',
        'HTTP/1.1 keep-alive; one Client/pool per OS worker; same server and payload.',
        f'{args.headers} additional response headers per request.',
        f'POST with {args.upload_size} upload bytes; the server checks every byte.' if args.upload_size else 'GET without a request body.',
        'Each request reads the full body and checks status, length, boundary bytes, and connection identity.',
        'Warm-up checks every byte. Latency samples cover one in every 16 requests.', '',
        '| Bytes | Workers | Baseline req/s | Current req/s | Change | Baseline P99 µs | Current P99 µs |',
        '| ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
    ]
    for size, concurrency in sorted({(r['bytes'], r['concurrency']) for r in summaries}):
        pair = {r['variant']: r for r in summaries if (r['bytes'], r['concurrency']) == (size, concurrency)}
        baseline, current = pair['baseline'], pair['current']
        change = (current['qps_median'] / baseline['qps_median'] - 1) * 100
        lines.append(f"| {size} | {concurrency} | {baseline['qps_median']:,.0f} | {current['qps_median']:,.0f} | {change:+.1f}% | {baseline['p99_us']:,.1f} | {current['p99_us']:,.1f} |")
    if all('client_cpu_us_per_request_median' in r for r in summaries):
        lines += [
            '', '| Bytes | Workers | Baseline client CPU µs/req | Current client CPU µs/req | Change |',
            '| ---: | ---: | ---: | ---: | ---: |',
        ]
        for size, concurrency in sorted({(r['bytes'], r['concurrency']) for r in summaries}):
            pair = {r['variant']: r for r in summaries if (r['bytes'], r['concurrency']) == (size, concurrency)}
            before = pair['baseline']['client_cpu_us_per_request_median']
            after = pair['current']['client_cpu_us_per_request_median']
            lines.append(f'| {size} | {concurrency} | {before:.2f} | {after:.2f} | {(after / before - 1) * 100:+.1f}% |')
        lines += [
            '', 'Client CPU is process user + system time from barrier release through worker joins,',
            'divided by timed requests. It includes validation and worker cleanup; it excludes',
            'warm-up, process startup, result serialization, and the server.',
        ]
    lines += [
        '', f"Validated {sum(r['requests'] for r in summaries):,} timed requests; zero errors.", '',
        'The client and server share this host. These results describe this workload and hardware;',
        'they do not establish internet/TLS performance or the maximum throughput of the client alone.',
        'Full per-trial data and min/max throughput are in raw-results.jsonl and summary.json.', '',
    ]
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    baseline = parser.add_mutually_exclusive_group()
    baseline.add_argument('--baseline', default='HEAD', help='Git revision to compare')
    baseline.add_argument('--baseline-source', type=Path, help='Frozen source directory containing req/')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--rounds', type=int, default=5)
    parser.add_argument('--seconds', type=int, default=2)
    parser.add_argument('--sizes', type=int, nargs='+', default=[128, 4096, 65536], choices=[128, 4096, 65536, 1048576])
    parser.add_argument('--concurrency', type=int, nargs='+', default=[1, 8, 32, 128])
    parser.add_argument('--headers', type=int, default=0, help='Additional response headers (0-128)')
    parser.add_argument('--upload-size', type=int, default=0, choices=[0, 128, 65536, 1048576], help='POST upload bytes; 0 selects GET')
    args = parser.parse_args()
    if args.rounds < 1 or args.seconds < 1 or any(c < 1 or c > 128 for c in args.concurrency):
        parser.error('rounds/seconds must be positive and concurrency must be between 1 and 128')
    if not 0 <= args.headers <= 128:
        parser.error('headers must be between 0 and 128')
    timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    output = (args.output or ROOT / 'build/performance' / timestamp).resolve()
    output.mkdir(parents=True, exist_ok=False)
    commit = None
    if args.baseline_source:
        shutil.copytree(args.baseline_source.resolve() / 'req', output / 'baseline/req')
        hashes = {str(p.relative_to(output / 'baseline')): digest(p) for p in sorted((output / 'baseline/req').rglob('*')) if p.is_file()}
        identity = 'snapshot:' + hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
    else:
        commit = run(['git', 'rev-parse', args.baseline + '^{commit}'], capture_output=True, text=True).stdout.strip()
        identity = commit
        archive = run(['git', 'archive', commit, 'req'], capture_output=True).stdout
        with tarfile.open(fileobj=io.BytesIO(archive)) as source:
            source.extractall(output / 'baseline', filter='data')
    shutil.copytree(ROOT / 'req', output / 'current/req')
    # Freeze the harness too: edits during a run cannot change its source identity.
    for name in ['run.py', 'client.mojo', 'threads.c', 'server.go']:
        shutil.copy2(ROOT / 'benchmarks' / name, output / name)
    cc = os.environ.get('CC', 'cc')
    flags = ['-O2', '-std=c11', '-D_POSIX_C_SOURCE=200809L', '-Wall', '-Wextra', '-Werror']
    run([cc, *flags, '-c', str(output / 'threads.c'), '-o', str(output / 'threads.o')])
    for variant in ['baseline', 'current']:
        source = output / variant
        run([cc, *flags, '-c', str(source / 'req/_transports/_curl.c'), '-o', str(source / 'curl.o')])
        run(['pixi', 'run', 'mojo', 'build', '--Werror', '-O3', '-I', str(source),
             '-Xlinker', str(source / 'curl.o'), '-Xlinker', str(output / 'threads.o'),
             '-Xlinker', '-lcurl', '-Xlinker', '-lz', str(output / 'client.mojo'),
             '-o', str(output / (variant + '-client'))])
    run(['go', 'build', '-o', str(output / 'server'), str(output / 'server.go')])
    metadata = {
        'baseline_commit': commit, 'baseline_identity': identity,
        'baseline_source': str(args.baseline_source.resolve()) if args.baseline_source else None,
        'utc': timestamp, 'platform': platform.platform(),
        'machine': platform.machine(), 'cpu_count': os.cpu_count(),
        'cpu': run(['sysctl', '-n', 'machdep.cpu.brand_string'], capture_output=True, text=True).stdout.strip() if platform.system() == 'Darwin' else platform.processor(),
        'mojo': run(['pixi', 'run', 'mojo', '--version'], capture_output=True, text=True).stdout.strip(),
        'go': run(['go', 'version'], capture_output=True, text=True).stdout.strip(),
        'c_flags': flags, 'mojo_flags': ['--Werror', '-O3'], 'seed': 20261010,
        'settings': {'rounds': args.rounds, 'seconds': args.seconds, 'sizes': args.sizes, 'concurrency': args.concurrency, 'headers': args.headers, 'upload_size': args.upload_size},
        'source_sha256': {str(p.relative_to(output)): digest(p) for p in output.rglob('*') if p.is_file() and p.suffix in ('.mojo', '.c', '.go', '.py')},
        'binary_sha256': {name: digest(output / name) for name in ['baseline-client', 'current-client', 'server']},
    }
    (output / 'environment.json').write_text(json.dumps(metadata, indent=2) + '\n')
    rows = []
    rng = random.Random(metadata['seed'])
    with (output / 'server.log').open('w') as server_log:
        server = subprocess.Popen([str(output / 'server')], stdout=subprocess.PIPE, stderr=server_log, text=True,
                                  env=os.environ | {'BENCH_HEADERS': str(args.headers), 'BENCH_UPLOAD_SIZE': str(args.upload_size)})
        try:
            address = server.stdout.readline().strip()
            if not address.startswith('127.0.0.1:'):
                raise RuntimeError('Loopback server failed to start; see server.log')
            with (output / 'raw-results.jsonl').open('w') as raw:
                for size in args.sizes:
                    for concurrency in args.concurrency:
                        for repeat in range(args.rounds):
                            order = ['baseline', 'current']
                            rng.shuffle(order)
                            for variant in order:
                                env = os.environ | {'BENCH_URL': f'http://{address}/keep/{size}', 'BENCH_SIZE': str(size), 'BENCH_CONCURRENCY': str(concurrency), 'BENCH_SECONDS': str(args.seconds), 'BENCH_HEADERS': str(args.headers), 'BENCH_UPLOAD_SIZE': str(args.upload_size)}
                                result = run([str(output / (variant + '-client'))], env=env, capture_output=True, text=True, timeout=args.seconds + 60)
                                row = json.loads(result.stdout)
                                if row['errors'] or row['requests'] <= 0 or row['client_cpu_us'] <= 0 or row['peak_inflight'] != concurrency or not row['connections_reused'] or not row['latency_ns']:
                                    raise RuntimeError(f'Invalid trial: {variant}, bytes={size}, concurrency={concurrency}')
                                row.update(variant=variant, bytes=size, concurrency=concurrency, repeat=repeat, qps=row['requests'] / (row['elapsed_ns'] / 1e9))
                                rows.append(row)
                                raw.write(json.dumps(row) + '\n')
                                raw.flush()
                                print(f"{size:7} B C={concurrency:3} round={repeat + 1} {variant:8} {row['qps']:9.0f} req/s", flush=True)
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
    summaries = summarize(rows)
    (output / 'summary.json').write_text(json.dumps(summaries, indent=2) + '\n')
    (output / 'REPORT.md').write_text(report(summaries, args, identity))
    print(f'Report: {output / "REPORT.md"}', flush=True)


if __name__ == '__main__':
    main()
