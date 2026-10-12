# SPDX-License-Identifier: GPL-3.0-only
import datetime as dt
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('backend', Path(__file__).parents[1]/'extension/backend.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

class BackendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ['TZ'] = 'UTC'
        time.tzset()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.now = dt.datetime(2026, 10, 13, 12, tzinfo=dt.timezone.utc)

    def tearDown(self):
        self.temp.cleanup()

    def write(self, rows, name='session.jsonl'):
        (self.root/name).write_text(''.join(json.dumps(row)+'\n' for row in rows))

    def codex_row(self, stamp, input_tokens, output_tokens, cache=0):
        return {'timestamp': stamp, 'type': 'event_msg', 'payload': {'type': 'token_count', 'info': {'total_token_usage': {'input_tokens': input_tokens, 'output_tokens': output_tokens, 'cached_input_tokens': cache}}}}

    def test_codex_baseline_dedup_and_daily_calendar_bins(self):
        rows = [{'type': 'turn_context', 'payload': {'model': 'gpt-6.1-sol'}},
                self.codex_row('2026-10-06T23:59:00Z', 100, 20),
                self.codex_row('2026-10-07T01:00:00Z', 130, 30, 10),
                self.codex_row('2026-10-13T10:00:00Z', 230, 40, 30),
                self.codex_row('2026-10-14T10:00:00Z', 999, 99)]
        self.write(rows)
        self.write(rows, 'fork.jsonl')
        result = b.history('codex', now=self.now, roots=[self.root])
        self.assertEqual(len(result['days']), 7)
        self.assertEqual(result['days'][0]['tokens'], 40)
        self.assertEqual(result['days'][-1]['tokens'], 110)
        self.assertEqual(result['tokens'], 150)
        self.assertAlmostEqual(result['usd'], (100*2+30*.1+20*10)/1e6)

    def test_claude_streamed_chunks_merged_and_cache_cost(self):
        def row(output):
            return {'type': 'assistant', 'timestamp': '2026-10-13T10:00:00Z', 'message': {'id': 'same-message', 'model': 'claude-sonnet-4-5-20250929', 'usage': {'input_tokens': 100, 'cache_read_input_tokens': 200, 'cache_creation_input_tokens': 50, 'cache_creation': {'ephemeral_1h_input_tokens': 20}, 'output_tokens': output}}}
        self.write([row(10), row(30)])
        result = b.history('claude', now=self.now, roots=[self.root])
        self.assertEqual(result['tokens'], 380)
        self.assertAlmostEqual(result['usd'], (100*3+200*.3+30*3*1.25+20*3*2+30*15)/1e6)

    def test_unknown_model_malformed_log_and_private_text(self):
        self.write([{'type': 'assistant', 'timestamp': '2026-10-13T10:00:00Z', 'message': {'id': 'm', 'model': 'unknown', 'content': 'private text', 'usage': {'input_tokens': 7}}}])
        with (self.root/'session.jsonl').open('a') as f:
            f.write('{"usage": invalid}\n')
        result = b.history('claude', now=self.now, roots=[self.root])
        self.assertEqual(result['unpriced'], 7)
        self.assertTrue(result['incomplete'])
        self.assertNotIn('private text', json.dumps(result))

    def test_missing_history_and_symlinks(self):
        self.assertFalse(b.history('claude', now=self.now, roots=[self.root/'absent'])['available'])
        outside = self.root/'nested'
        outside.mkdir()
        (outside/'hidden.jsonl').write_text('broken usage\n')
        (self.root/'linked.jsonl').symlink_to(outside/'hidden.jsonl')
        result = b.history('codex', now=self.now, roots=[self.root])
        self.assertFalse(result['incomplete'])

    def test_claude_requires_consent_before_credentials(self):
        with patch.object(b, 'credentials', side_effect=AssertionError('must not read credentials')):
            with self.assertRaises(b.UsageError) as result:
                b.claude(False)
            self.assertEqual(result.exception.key, 'Bağlı değil')

    def test_bad_credentials_and_redirect_rejected(self):
        self.assertIsNone(b.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://other.invalid'))
        p = self.root/'credentials.json'
        p.write_text(json.dumps({'claudeAiOauth': {'accessToken': 'bad\nsecret'}}))
        with self.assertRaises(b.UsageError): b.credentials(p)

    def test_numeric_quota_validation_and_clamping(self):
        result = b.windows({'rateLimits': {'primary': {'usedPercent': 120, 'windowDurationMins': 300}, 'secondary': {'usedPercent': 20, 'windowDurationMins': 10080}}}, 'codex')
        self.assertEqual(result['remaining'], 0)
        self.assertEqual(result['windows'][1]['title'], 'Haftalık')
        with self.assertRaises(b.UsageError): b.windows({'five_hour': {'utilization': True}}, 'claude')
        self.assertEqual(b.number({'x': float('nan')}, 'x'), 0)

    def test_codex_rpc_only_reads_limits_and_terminates_child(self):
        executable = self.root/'codex'
        trace = self.root/'calls'
        executable.write_text('#!/usr/bin/env python3\nimport json,sys\nfrom pathlib import Path\nfor line in sys.stdin:\n r=json.loads(line)\n with Path('+repr(str(trace))+').open("a") as f: f.write(r["method"]+"\\n")\n if "id" in r:\n  result={} if r["id"]==1 else {"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":300}}}\n  print(json.dumps({"id":r["id"],"result":result}),flush=True)\n')
        executable.chmod(0o755)
        self.assertEqual(b.codex(str(executable))['remaining'], 75)
        self.assertEqual(trace.read_text().splitlines(), ['initialize', 'initialized', 'account/rateLimits/read'])

if __name__ == '__main__': unittest.main()
