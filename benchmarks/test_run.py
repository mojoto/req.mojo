"""Checks for benchmark aggregation, independent of local timing noise."""

import unittest

from run import find_regressions, percentile, summarize


class SummaryTests(unittest.TestCase):
    def test_guard_also_checks_report_medians(self):
        rows = []
        for repeat, (before, after) in enumerate(zip(
            [123, 127, 128, 127, 122], [120, 123, 120, 120, 123]
        )):
            for variant, qps in [('baseline', before), ('current', after)]:
                rows.append(dict(bytes=65536, concurrency=1, repeat=repeat,
                                 variant=variant, qps=qps, requests=qps * 2,
                                 client_cpu_us=qps * 20))
        self.assertEqual(len(find_regressions(rows, 5)), 1)

    def test_guard_normalizes_cpu_and_pairs_rounds(self):
        rows = []
        for repeat, baseline in enumerate([100, 20, 200]):
            for variant, scale in [('baseline', 1), ('current', 1.02)]:
                requests = baseline * scale * 2
                rows.append(dict(bytes=128, concurrency=8, repeat=repeat,
                                 variant=variant, qps=baseline * scale,
                                 requests=requests, client_cpu_us=requests * 10))
        self.assertEqual(find_regressions(rows, 5), [])

    def test_guard_detects_throughput_and_cpu_regressions(self):
        for qps, cpu in [(90, 10), (100, 12)]:
            rows = [dict(bytes=128, concurrency=1, repeat=0, variant='baseline',
                         qps=100, requests=200, client_cpu_us=2000),
                    dict(bytes=128, concurrency=1, repeat=0, variant='current',
                         qps=qps, requests=qps * 2, client_cpu_us=qps * 2 * cpu)]
            failure, = find_regressions(rows, 5)
            self.assertEqual((failure['bytes'], failure['concurrency']), (128, 1))
            self.assertEqual(len(find_regressions(rows, 25)), 0)

    def test_trial_median_and_combined_latency(self):
        rows = [
            dict(bytes=128, concurrency=1, variant='current', qps=rate,
                 requests=rate * 2, errors=0, latency_ns=[1000, 2000, 3000])
            for rate in [100, 300, 200]
        ]
        result, = summarize(rows)
        self.assertEqual(result['qps_median'], 200)
        self.assertEqual((result['qps_min'], result['qps_max']), (100, 300))
        self.assertEqual(result['requests'], 1200)
        self.assertEqual(result['p50_us'], 2)
        self.assertEqual(result['p99_us'], 3)
        self.assertEqual(percentile([3000, 1000, 2000], .5), 2)
        self.assertNotIn('client_cpu_us_per_request_median', result)

    def test_client_cpu_normalized_per_trial(self):
        rows = [
            dict(bytes=128, concurrency=1, variant='current', qps=rate,
                 requests=rate * 2, client_cpu_us=100000, errors=0,
                 latency_ns=[1000])
            for rate in [100, 300, 200]
        ]
        result, = summarize(rows)
        self.assertAlmostEqual(result['client_cpu_us_per_request_median'], 250)


if __name__ == '__main__':
    unittest.main()
