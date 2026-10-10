"""Checks for benchmark aggregation, independent of local timing noise."""

import unittest

from run import percentile, summarize


class SummaryTests(unittest.TestCase):
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
