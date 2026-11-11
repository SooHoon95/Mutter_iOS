"""승인 CLI의 preview 해시 계약. 실제 환경 파일/API는 사용하지 않는다."""
import contextlib
from datetime import datetime, timedelta, timezone
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import social_jobs as jobs
import social_publish as publisher


class SocialCLITests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.base = self.root / 'marketing/publishing'
        self.queue = self.root / 'marketing/queue/test-note.md'
        self.queue.parent.mkdir(parents=True)
        self.queue.write_text('---\nid: test-note\ntype: threads\nchannel: threads\nstatus: draft\n---\n'
                              '## 추천안\n승인 대상 본문\n\n## 대안\nB안은 제외\n\n## 메모\n메모 제외\n')
        self.env = {'THREADS_USER_ID': '00123', 'IG_USER_ID': '00456',
                    'MARKETING_EXPECTED_USERNAME': 'mu_sic_letter'}
        self.at = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
        for module in (jobs, publisher):
            self.start(patch.object(module, 'ROOT', self.root))
            self.start(patch.object(module, 'PUBLISHING', self.base))
        self.start(patch.object(publisher, 'load_env', return_value=self.env))
        self.start(patch.object(publisher, 'lock', side_effect=lambda: contextlib.nullcontext()))
        original = publisher.enqueue
        self.start(patch.object(publisher, 'enqueue', side_effect=lambda payload: original(payload, self.base)))

    def start(self, item):
        result = item.start()
        self.addCleanup(item.stop)
        return result

    def call(self, *arguments):
        output, error = io.StringIO(), io.StringIO()
        with patch.object(sys, 'argv', ['social_publish.py', *arguments]), contextlib.redirect_stdout(output), contextlib.redirect_stderr(error):
            code = publisher.main()
        return code, output.getvalue(), error.getvalue()

    def preview(self):
        code, output, error = self.call('preview', str(self.queue), '--at', self.at)
        self.assertEqual(code, 0, error)
        return json.loads(output)

    def approve(self, preview, confirmed=True):
        arguments = ['approve', str(self.queue), '--at', self.at,
                     '--preview-sha', preview['preview_sha256']]
        if confirmed:
            arguments.append('--confirmed')
        return self.call(*arguments)

    def test_preview_is_not_approval_and_excludes_notes_and_alternatives(self):
        result = self.preview()
        self.assertEqual(result['payload']['text'], '승인 대상 본문')
        self.assertEqual(result['preview_sha256'], jobs.digest(result['payload']))
        self.assertFalse((self.base / 'jobs').exists())
        self.assertIn('status: draft', self.queue.read_text())

    def test_explicit_confirmation_required(self):
        result = self.preview()
        self.assertEqual(self.approve(result, confirmed=False)[0], 2)
        self.assertFalse((self.base / 'jobs').exists())

    def test_wrong_preview_hash_cannot_approve(self):
        result = self.preview()
        result['preview_sha256'] = '0' * 64
        self.assertEqual(self.approve(result)[0], 2)
        self.assertFalse((self.base / 'jobs').exists())

    def test_edited_queue_after_preview_requires_reapproval(self):
        result = self.preview()
        self.queue.write_text(self.queue.read_text().replace('승인 대상 본문', '변경된 본문'))
        self.assertEqual(self.approve(result)[0], 2)
        self.assertFalse((self.base / 'jobs').exists())

    def test_changed_account_after_preview_requires_reapproval(self):
        result = self.preview()
        self.env['THREADS_USER_ID'] = '99999'
        self.assertEqual(self.approve(result)[0], 2)
        self.assertFalse((self.base / 'jobs').exists())

    def test_valid_preview_approval_fixes_job_and_marks_queue_scheduled(self):
        result = self.preview()
        code, _, error = self.approve(result)
        self.assertEqual(code, 0, error)
        job = jobs.read_json(self.base / 'jobs/test-note-threads.json')
        payload = jobs.validate_job(job, self.base)
        self.assertEqual(payload['text'], result['payload']['text'])
        self.assertEqual(payload['account_id'], '00123')
        self.assertEqual(payload['scheduled_at'], result['payload']['scheduled_at'])
        self.assertIn('status: scheduled', self.queue.read_text())
        self.assertFalse((self.base / 'state').exists())
        self.assertEqual(self.approve(result)[0], 2)

    def test_queue_status_write_failure_reports_successful_reservation(self):
        result = self.preview()
        original = Path.write_text
        def fail_queue(path, *args, **kwargs):
            if path == self.queue:
                raise OSError('synthetic readonly queue')
            return original(path, *args, **kwargs)
        with patch.object(Path, 'write_text', fail_queue):
            code, output, error = self.approve(result)
        self.assertEqual(code, 0)
        self.assertIn('예약 등록:', output)
        self.assertIn('WARN:', error)
        self.assertTrue((self.base / 'jobs/test-note-threads.json').exists())
        self.assertIn('status: draft', self.queue.read_text())

    def test_personal_username_configuration_is_rejected(self):
        self.env['MARKETING_EXPECTED_USERNAME'] = 'personal_account'
        self.assertEqual(self.call('preview', str(self.queue), '--at', self.at)[0], 2)
        self.assertFalse((self.base / 'jobs').exists())

    def test_pause_does_not_wait_for_active_worker_lock(self):
        with patch.object(publisher, 'lock', side_effect=BlockingIOError('worker active')):
            code, _, error = self.call('pause')
        self.assertEqual(code, 0, error)
        self.assertTrue((self.base / 'PUBLISH_DISABLED').exists())


if __name__ == '__main__':
    unittest.main()
