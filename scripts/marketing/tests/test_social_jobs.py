"""Offline approval snapshot tests; all inputs live under temporary roots."""
import copy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import social_jobs as jobs


class SocialJobsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.base = self.root / "marketing/publishing"
        self.queue = self.root / "marketing/queue"
        self.queue.mkdir(parents=True)
        self.current = datetime(2026, 10, 10, 12, tzinfo=timezone.utc)
        for name, value in (("ROOT", self.root), ("PUBLISHING", self.base),
                            ("now", lambda: self.current)):
            context = patch.object(jobs, name, value)
            context.start()
            self.addCleanup(context.stop)
        no_env = patch.object(jobs, "load_env", side_effect=AssertionError("No environment file reads"))
        no_env.start()
        self.addCleanup(no_env.stop)
        self.source = self.queue / "test-note.md"
        self.source.write_text("---\nid: test-note\ntype: threads\nchannel: threads\nstatus: draft\n---\n"
                               "## 추천안\n음악으로 전하는 마음\n", encoding="utf-8")

    def payload(self):
        return jobs.payload_from_queue(self.source, (self.current + timedelta(hours=1)).isoformat(),
                                       "00123", "test_account")

    def approved(self, payload=None):
        payload = payload if payload is not None else self.payload()
        return {"payload": payload, "approval": {"confirmed": True, "sha256": jobs.digest(payload)}}

    def test_digest_is_stable_across_mapping_order_but_sensitive_to_content(self):
        self.assertEqual(jobs.digest({"a": "한글", "b": 2}), jobs.digest({"b": 2, "a": "한글"}))
        self.assertNotEqual(jobs.digest({"text": "안녕"}), jobs.digest({"text": "안녕!"}))

    def test_approval_digest_rejects_snapshot_tampering(self):
        original = self.approved()
        for key, value in (("text", "변경된 본문"), ("account_id", "00999"),
                           ("scheduled_at", (self.current + timedelta(days=1)).isoformat()),
                           ("job_id", "another-threads")):
            with self.subTest(field=key):
                tampered = copy.deepcopy(original)
                tampered["payload"][key] = value
                with self.assertRaises(ValueError):
                    jobs.validate_job(tampered, self.base)
        tampered = copy.deepcopy(original)
        tampered["approval"]["sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            jobs.validate_job(tampered, self.base)

    def test_explicit_boolean_approval_required(self):
        for confirmed in (False, None, "true", 1):
            with self.subTest(confirmed=confirmed):
                job = self.approved()
                job["approval"]["confirmed"] = confirmed
                with self.assertRaises(ValueError):
                    jobs.validate_job(job, self.base)
        self.assertEqual(jobs.validate_job(self.approved(), self.base)["text"], "음악으로 전하는 마음")

    def test_time_requires_timezone_and_normalizes_to_utc(self):
        for value in ("2026-10-11T20:30:00", "2026-10-11"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                jobs.parse_time(value)
        self.assertEqual(jobs.parse_time("2026-10-11T20:30:00+09:00"),
                         jobs.parse_time("2026-10-11T11:30:00Z"))
        self.assertEqual(jobs.parse_time("2026-10-11T20:30:00+09:00").tzinfo, timezone.utc)

    def test_queue_approval_requires_future_timezone_aware_schedule(self):
        for value in ("2026-10-11T20:30:00", self.current.isoformat(),
                      (self.current - timedelta(seconds=1)).isoformat()):
            with self.subTest(value=value), self.assertRaises(ValueError):
                jobs.payload_from_queue(self.source, value, "00123", "test_account")

    def test_rehashed_job_still_requires_timezone_in_both_dates(self):
        for key in ("scheduled_at", "approved_at"):
            with self.subTest(field=key):
                payload = self.payload()
                payload[key] = "2026-10-11T20:30:00"
                with self.assertRaises(ValueError):
                    jobs.validate_job(self.approved(payload), self.base)

    def test_draft_payload_creation_does_not_create_job(self):
        payload = self.payload()
        self.assertEqual(payload["account_id"], "00123")
        self.assertEqual(payload["source_sha256"], jobs.file_digest(self.source))
        self.assertFalse(self.base.exists())
        self.assertIn("status: draft", self.source.read_text())

    def test_instagram_asset_mutation_rejected_despite_unchanged_approval(self):
        asset = self.base / "assets/card.jpg"
        asset.parent.mkdir(parents=True)
        asset.write_bytes(b"synthetic approved jpeg bytes")
        payload = self.payload()
        payload.update(channel="instagram", job_id="test-note-instagram",
                       image_path=str(asset.relative_to(self.root)), image_sha256=jobs.file_digest(asset))
        job = self.approved(payload)
        self.assertEqual(jobs.validate_job(job, self.base), payload)
        asset.write_bytes(b"different asset bytes")
        with self.assertRaises(ValueError):
            jobs.validate_job(job, self.base)

    def test_instagram_asset_must_be_inside_approved_asset_directory(self):
        asset = self.root / "outside.jpg"
        asset.write_bytes(b"outside")
        payload = self.payload()
        payload.update(channel="instagram", job_id="test-note-instagram",
                       image_path="outside.jpg", image_sha256=jobs.file_digest(asset))
        with self.assertRaises(ValueError):
            jobs.validate_job(self.approved(payload), self.base)

    def test_atomic_state_write_replaces_whole_json(self):
        target = self.base / "state/test.json"
        jobs.atomic_json(target, {"phase": "publishing", "container_id": "123"})
        jobs.atomic_json(target, {"phase": "published", "media_id": "456"})
        self.assertEqual(json.loads(target.read_text()), {"phase": "published", "media_id": "456"})
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)
        self.assertEqual(list(target.parent.iterdir()), [target])


if __name__ == "__main__":
    unittest.main()
