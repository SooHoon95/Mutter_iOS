"""토큰 갱신 저장 순서/실패를 합성 인증값만으로 검증."""
from datetime import datetime, timezone
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import social_jobs as jobs
import social_publish as publisher


class TokenPersistenceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.current = datetime(2026, 10, 10, 12, tzinfo=timezone.utc)
        self.timestamp = int(self.current.timestamp())
        self.env = {'THREADS_ACCESS_TOKEN': 'synthetic-old-threads', 'IG_ACCESS_TOKEN': 'synthetic-ig'}
        self.metadata = {channel: {'kind': 'long_lived_dashboard',
            'issued_at': self.timestamp - 45 * 86400,
            'expires_at': self.timestamp + (2 if channel == 'threads' else 30) * 86400,
            'fingerprint': publisher.token_fingerprint(self.env[prefix + '_ACCESS_TOKEN'])}
            for channel, prefix in publisher.TOKEN_KEYS.items()}
        jobs.atomic_json(self.base / 'token_state.json', self.metadata)
        self.api = Mock()
        self.api.refresh_token.return_value = {'access_token':'synthetic-new-threads', 'expires_in':60*86400}
        self.api_class = Mock(return_value=self.api)
        item = patch.object(publisher, 'now', return_value=self.current)
        item.start()
        self.addCleanup(item.stop)

    def test_refresh_commits_env_before_metadata_then_revalidates_fingerprint(self):
        order = []
        original = publisher.atomic_json
        def persist_env(pairs):
            order.append('env')
            self.assertEqual(pairs, {'THREADS_ACCESS_TOKEN':'synthetic-new-threads'})
            disk = jobs.read_json(self.base / 'token_state.json')
            self.assertEqual(disk, self.metadata)
        def persist_metadata(path, value):
            order.append('metadata')
            original(path, value)
        with patch.object(publisher, 'update_env', side_effect=persist_env), patch.object(publisher, 'atomic_json', side_effect=persist_metadata):
            result = publisher.maintain_tokens(self.env, self.api_class, self.base)
        self.assertIs(result, self.api)
        self.assertEqual(order, ['env', 'metadata'])
        self.api.refresh_token.assert_called_once_with('threads')
        metadata = jobs.read_json(self.base / 'token_state.json')
        self.assertEqual(metadata['threads']['expires_at'], self.timestamp + 60 * 86400)
        self.assertEqual(metadata['threads']['issued_at'], self.timestamp)
        publisher.token_env(self.env, metadata, self.timestamp)

    def test_env_save_failure_does_not_advance_metadata_or_memory(self):
        with patch.object(publisher, 'update_env', side_effect=OSError('synthetic disk error')):
            with self.assertRaises(OSError):
                publisher.maintain_tokens(self.env, self.api_class, self.base)
        self.assertEqual(self.env['THREADS_ACCESS_TOKEN'], 'synthetic-old-threads')
        self.assertEqual(jobs.read_json(self.base / 'token_state.json'), self.metadata)

    def test_metadata_save_failure_leaves_detectable_mismatch_after_env_commit(self):
        persisted_env = {}
        def persist(pairs):
            persisted_env.update(self.env)
            persisted_env.update(pairs)
        with patch.object(publisher, 'update_env', side_effect=persist), patch.object(publisher, 'atomic_json', side_effect=OSError('synthetic metadata error')):
            with self.assertRaises(OSError):
                publisher.maintain_tokens(self.env, self.api_class, self.base)
        self.assertEqual(persisted_env['THREADS_ACCESS_TOKEN'], 'synthetic-new-threads')
        old = jobs.read_json(self.base / 'token_state.json')
        with self.assertRaises(ValueError):
            publisher.token_env(persisted_env, old, self.timestamp)

    def test_unknown_changed_or_expired_token_blocks_before_refresh(self):
        for case in ('changed', 'expired', 'unknown'):
            with self.subTest(case=case):
                metadata = jobs.read_json(self.base / 'token_state.json')
                if case == 'changed':
                    metadata['threads']['fingerprint'] = '0' * 64
                elif case == 'expired':
                    metadata['threads']['expires_at'] = self.timestamp - 1
                else:
                    metadata.pop('threads')
                with self.assertRaises(ValueError):
                    publisher.token_env(self.env, metadata, self.timestamp)
        self.api_class.assert_not_called()

    def test_young_token_not_refreshed(self):
        metadata = jobs.read_json(self.base / 'token_state.json')
        metadata['threads']['issued_at'] = self.timestamp - 3600
        jobs.atomic_json(self.base / 'token_state.json', metadata)
        with patch.object(publisher, 'update_env', side_effect=AssertionError('No writes')):
            with self.assertRaises(ValueError):
                publisher.maintain_tokens(self.env, self.api_class, self.base)
        self.api.refresh_token.assert_not_called()

    def test_invalid_refresh_response_does_not_write_credentials(self):
        self.api.refresh_token.return_value = {'access_token':'synthetic-new', 'expires_in':1}
        with patch.object(publisher, 'update_env') as persist:
            with self.assertRaises(ValueError):
                publisher.maintain_tokens(self.env, self.api_class, self.base)
        persist.assert_not_called()
        self.assertEqual(jobs.read_json(self.base / 'token_state.json'), self.metadata)


if __name__ == '__main__':
    unittest.main()
