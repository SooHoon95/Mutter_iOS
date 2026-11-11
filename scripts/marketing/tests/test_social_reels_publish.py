"""Offline Reels approval/worker safety. Tiny ftyp fixtures are NOT rendered videos.

Only validate_reel is substituted: rendering/decoding belongs to its own suite.
Every source, preview, token ledger and approved asset lives in a temporary ROOT.
"""
import contextlib
import copy
from datetime import datetime, timedelta, timezone
import io
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, call, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import social_api
import social_jobs as jobs
import social_publish as publisher

MP4 = (24).to_bytes(4, "big") + b"ftypisom\x00\x00\x00\x00isommp42" + (8).to_bytes(4, "big") + b"mdat"
MAX_VIDEO = 45 * 1024 * 1024
VIDEO_SPEC = {"width": 1080, "height": 1920, "fps": 30, "duration": 15.0,
              "video_codec": "h264", "pixel_format": "yuv420p", "progressive": True,
              "audio_codec": "aac", "sample_rate": 48000, "channels": 2,
              "faststart": True, "frames": 450, "size_bytes": len(MP4)}


class SocialReelsPublishTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.base = self.root / "marketing/publishing"
        self.queue = self.root / "marketing/queue"
        self.video_dir = self.root / "marketing/video/synthetic"
        self.queue.mkdir(parents=True)
        self.video_dir.mkdir(parents=True)
        self.video = self.video_dir / "clip.mp4"
        self.video.write_bytes(MP4)
        self.current = datetime(2026, 10, 10, 12, tzinfo=timezone.utc)
        self.env = {"THREADS_USER_ID": "00123", "IG_USER_ID": "00456",
                    "THREADS_ACCESS_TOKEN": "synthetic-threads-token",
                    "IG_ACCESS_TOKEN": "synthetic-instagram-token",
                    "MARKETING_EXPECTED_USERNAME": "mu_sic_letter"}
        for module in (jobs, publisher):
            self.patch(module, "ROOT", self.root)
            self.patch(module, "PUBLISHING", self.base)
            self.patch(module, "now", lambda: self.current)
            self.patch(module, "load_env", side_effect=AssertionError("No environment file reads"))
            self.patch(module, "update_env", side_effect=AssertionError("No environment file writes"))
        self.patch(social_api, "urlopen", side_effect=AssertionError("No network"))
        # A mock module avoids importing a renderer still being implemented, or invoking FFmpeg.
        renderer = types.ModuleType("render_reel")
        self.validator = Mock(side_effect=self.synthetic_validation)
        renderer.validate_reel = self.validator
        self.start(patch.dict(sys.modules, {"render_reel": renderer}))
        self.sleep = Mock()
        self.api = Mock(spec=social_api.SocialAPI)
        self.api.upload_video.return_value = "https://example.invalid/synthetic.mp4"
        self.api.upload_image.return_value = "https://example.invalid/synthetic.jpg"
        self.api.create_reel.return_value = "007"
        self.api.create_container.return_value = "009"
        self.api.container_status.return_value = "FINISHED"
        self.api.publish.return_value = "008"
        self.api.permalink.return_value = "https://www.instagram.com/reel/synthetic/"
        self.api_class = Mock(return_value=self.api)
        execute = publisher.execute_job
        self.patch(publisher, "execute_job", side_effect=lambda payload, api, base:
                   execute(payload, api, base, sleep=self.sleep))
        stamp = int(self.current.timestamp())
        jobs.atomic_json(self.base / "token_state.json", {
            channel: {"kind": "long_lived_dashboard", "issued_at": stamp - 2 * 86400,
                      "expires_at": stamp + 30 * 86400,
                      "fingerprint": publisher.token_fingerprint(self.env[prefix + "_ACCESS_TOKEN"])}
            for channel, prefix in publisher.TOKEN_KEYS.items()
        })
        self.source = self.make_queue("test-reel")

    def start(self, item):
        result = item.start()
        self.addCleanup(item.stop)
        return result

    def patch(self, target, attribute, *args, **kwargs):
        return self.start(patch.object(target, attribute, *args, **kwargs))

    def synthetic_validation(self, path):
        path = Path(path)
        if not 0 < path.stat().st_size <= MAX_VIDEO:
            raise ValueError("Synthetic validator: outside local video size limit")
        return {**VIDEO_SPEC, "size_bytes": path.stat().st_size}

    def make_queue(self, name, kind="instagram_reel", video_file=None, caption="음악으로 전하는 마음"):
        source = self.queue / (name + ".md")
        file = str(self.video.relative_to(self.root)) if video_file is None else video_file
        channel = "threads" if kind == "threads" else "instagram"
        header = f"---\nid: {name}\ntype: {kind}\nchannel: {channel}\nstatus: draft\n"
        if kind == "instagram_reel":
            header += f"video_file: {file}\n"
        body = "## 추천안\n텍스트 편지\n" if kind == "threads" else ""
        if kind == "instagram_card":
            body += "## 카드 제목\n한 곡의 마음\n## 카드 본문\n오늘의 편지\n"
        if caption is not None and channel == "instagram":
            body += "## 캡션\n" + caption + "\n"
        source.write_text(header + "---\n" + body, encoding="utf-8")
        return source

    def payload(self, source=None, minutes=10):
        return jobs.payload_from_queue(source or self.source,
            (self.current + timedelta(minutes=minutes)).isoformat(),
            self.env["IG_USER_ID"], self.env["MARKETING_EXPECTED_USERNAME"])

    def approved(self, payload):
        return {"payload": payload, "approval": {"confirmed": True, "sha256": jobs.digest(payload)}}

    def enqueue(self, payload=None):
        payload = payload if payload is not None else self.payload()
        publisher.enqueue(payload, self.base)
        return payload

    def due(self):
        payload = self.enqueue()
        self.current += timedelta(minutes=11)
        return payload

    def state(self, payload):
        return jobs.read_json(self.base / "state" / (payload["job_id"] + ".json"))

    def run_due(self, live=True):
        return publisher.run_due(self.env, live=live, base=self.base, api_class=self.api_class)

    def assert_no_media_calls(self):
        for name in ("upload_video", "upload_image", "create_reel", "create_container", "publish"):
            getattr(self.api, name).assert_not_called()

    def test_reel_queue_requires_nested_local_mp4_and_caption_and_records_spec(self):
        payload = self.payload()
        self.validator.assert_called_once_with(self.video.resolve())
        self.assertEqual(payload["channel"], "instagram")
        self.assertEqual(payload["media_type"], "REELS")
        self.assertIs(payload["share_to_feed"], True)
        self.assertEqual(payload["video_path"], str(self.video.relative_to(self.root)))
        self.assertEqual(payload["video_sha256"], jobs.file_digest(self.video))
        self.assertEqual(payload["video_spec"], VIDEO_SPEC)
        self.assertEqual(payload["text"], "음악으로 전하는 마음")
        self.assertNotIn("image_path", payload)
        self.assertFalse((self.base / "jobs").exists())

    def test_missing_empty_or_oversized_caption_is_rejected(self):
        for index, caption in enumerate((None, "", " " , "x" * 2201)):
            with self.subTest(caption=index):
                source = self.make_queue("caption-" + str(index), caption=caption)
                with self.assertRaises(ValueError):
                    self.payload(source)
        self.validator.assert_not_called()

    def test_source_outside_video_tree_wrong_extension_missing_or_traversal_rejected(self):
        outside = self.root / "outside.mp4"
        outside.write_bytes(MP4)
        wrong = self.video.with_suffix(".jpg")
        wrong.write_bytes(MP4)
        paths = ("outside.mp4", str(outside), "marketing/video/../../outside.mp4",
                 "marketing/video/synthetic/clip.jpg", "marketing/video/missing.mp4", "")
        for index, value in enumerate(paths):
            with self.subTest(path=value):
                with self.assertRaises(ValueError):
                    self.payload(self.make_queue("bad-path-" + str(index), video_file=value))
        self.validator.assert_not_called()

    def test_source_symlink_outside_video_tree_rejected(self):
        outside = self.root / "outside.mp4"
        outside.write_bytes(MP4)
        link = self.video_dir / "outside-link.mp4"
        link.symlink_to(outside)
        with self.assertRaises(ValueError):
            self.payload(self.make_queue("outside-link", video_file=str(link.relative_to(self.root))))
        self.validator.assert_not_called()

    def test_inside_tree_symlink_is_normalized_to_its_safe_source(self):
        # The contract permits aliases only when their resolved target is still in video/.
        link = self.video_dir / "inside-link.mp4"
        link.symlink_to(self.video)
        payload = self.payload(self.make_queue("inside-link", video_file=str(link.relative_to(self.root))))
        self.assertEqual(payload["video_path"], str(self.video.relative_to(self.root)))
        self.validator.assert_called_once_with(self.video.resolve())

    def test_oversized_source_fails_validation_without_creating_job(self):
        with self.video.open("r+b") as stream:
            stream.truncate(MAX_VIDEO + 1)
        with self.assertRaises(ValueError):
            self.payload()
        self.assertFalse((self.base / "jobs").exists())
        self.assert_no_media_calls()

    def test_validator_failure_is_not_silently_approved(self):
        self.validator.side_effect = ValueError("Synthetic invalid codec/geometry")
        with self.assertRaises(ValueError):
            publisher.preview_job(self.source, (self.current + timedelta(hours=1)).isoformat(), self.env)
        self.assertFalse((self.base / "jobs").exists())
        self.assert_no_media_calls()

    def test_reel_preview_does_not_render_or_upload_card_image(self):
        with patch.object(publisher, "prepare_image", side_effect=AssertionError("No card renderer")):
            payload = publisher.preview_job(self.source,
                (self.current + timedelta(hours=1)).isoformat(), self.env)
        self.assertEqual(payload["media_type"], "REELS")
        self.assert_no_media_calls()

    def test_enqueue_freezes_readonly_mp4_and_job_with_approval_digest(self):
        payload = self.enqueue()
        target = self.base / "assets" / (payload["video_sha256"] + ".mp4")
        job_path = self.base / "jobs" / (payload["job_id"] + ".json")
        job = jobs.read_json(job_path)
        self.assertEqual(target.read_bytes(), MP4)
        self.assertEqual(target.stat().st_mode & 0o777, 0o444)
        self.assertEqual(job_path.stat().st_mode & 0o777, 0o444)
        self.assertEqual(payload["video_path"], str(target.relative_to(self.root)))
        self.assertEqual(job["approval"], {"confirmed": True, "sha256": jobs.digest(job["payload"])})
        self.assertEqual(jobs.validate_job(job, self.base), payload)
        self.video.write_bytes(MP4 + b"queue source changed after approval")
        self.assertEqual(jobs.validate_job(job, self.base), payload)
        with self.assertRaises(ValueError):
            publisher.enqueue(payload, self.base)

    def test_source_bytes_changed_after_preview_cannot_be_enqueued(self):
        payload = self.payload()
        self.video.write_bytes(MP4 + b"changed")
        with self.assertRaises(ValueError):
            publisher.enqueue(payload, self.base)
        self.assertFalse((self.base / "jobs" / (payload["job_id"] + ".json")).exists())
        self.assertEqual(list((self.base / "assets").glob("*")), [])

    def test_source_mutated_during_full_validator_cannot_be_previewed(self):
        def mutate(path):
            Path(path).write_bytes(MP4 + b"changed while decoding")
            return dict(VIDEO_SPEC)
        self.validator.side_effect = mutate
        with self.assertRaises(ValueError):
            self.payload()
        self.assertFalse((self.base / "jobs").exists())
        self.assert_no_media_calls()

    def test_rehashed_reel_requires_feed_boolean_and_video_spec_mapping(self):
        payload = self.enqueue()
        for key, value in (("share_to_feed", False), ("share_to_feed", "true"),
                           ("share_to_feed", 1), ("video_spec", None), ("video_spec", "validated")):
            with self.subTest(field=key, value=value):
                altered = {**payload, key: value}
                with self.assertRaises(ValueError):
                    jobs.validate_job(self.approved(altered), self.base)

    def test_approval_digest_covers_video_path_hash_spec_and_feed_setting(self):
        payload = self.enqueue()
        for key, value in (("video_path", "marketing/video/synthetic/clip.mp4"),
                           ("video_sha256", "0" * 64), ("media_type", "IMAGE"),
                           ("video_spec", {**VIDEO_SPEC, "fps": 24}), ("share_to_feed", False)):
            with self.subTest(field=key):
                job = self.approved(copy.deepcopy(payload))
                job["payload"][key] = value
                with self.assertRaises(ValueError):
                    jobs.validate_job(job, self.base)

    def test_approved_video_mutated_bytes_or_sha_rejected_even_with_rehashed_approval(self):
        payload = self.enqueue()
        altered = copy.deepcopy(payload)
        altered["video_sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            jobs.validate_job(self.approved(altered), self.base)
        target = self.root / payload["video_path"]
        target.chmod(0o600)
        target.write_bytes(MP4 + b"tampered")
        with self.assertRaises(ValueError):
            jobs.validate_job(self.approved(payload), self.base)

    def test_rehashed_approved_video_cannot_escape_assets_or_use_other_extension(self):
        payload = self.enqueue()
        for index, path in enumerate((self.video, self.root / "outside.mp4",
                                     self.base / "assets/wrong.jpg")):
            with self.subTest(path=path):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(MP4)
                candidate = {**payload, "video_path": str(path.relative_to(self.root)),
                             "video_sha256": jobs.file_digest(path)}
                with self.assertRaises(ValueError):
                    jobs.validate_job(self.approved(candidate), self.base)

    def test_approved_asset_symlink_escape_rejected(self):
        payload = self.enqueue()
        alias = self.base / "assets/escape.mp4"
        alias.symlink_to(self.video)
        candidate = {**payload, "video_path": str(alias.relative_to(self.root))}
        with self.assertRaises(ValueError):
            jobs.validate_job(self.approved(candidate), self.base)

    def test_approved_oversized_video_rejected_despite_matching_sha_and_approval(self):
        payload = self.enqueue()
        target = self.root / payload["video_path"]
        target.chmod(0o600)
        with target.open("r+b") as stream:
            stream.truncate(MAX_VIDEO + 1)
        import hashlib
        with target.open('rb') as stream:
            payload['video_sha256'] = hashlib.file_digest(stream, 'sha256').hexdigest()
        with patch.object(jobs, 'file_digest', side_effect=AssertionError('Oversized asset must reject before reading')) as hash_file:
            with self.assertRaises(ValueError):
                jobs.validate_job(self.approved(payload), self.base)
        hash_file.assert_not_called()

    def test_legacy_image_and_threads_approvals_still_validate(self):
        for kind in ("instagram_card", "threads"):
            with self.subTest(kind=kind):
                source = self.make_queue("legacy-" + kind, kind=kind)
                account = self.env["THREADS_USER_ID"] if kind == "threads" else self.env["IG_USER_ID"]
                payload = jobs.payload_from_queue(source, (self.current + timedelta(hours=1)).isoformat(),
                                                  account, "mu_sic_letter")
                if kind == "instagram_card":
                    image = self.root / "synthetic.jpg"
                    image.write_bytes(b"synthetic legacy image fixture")
                    payload.update(image_path=str(image.relative_to(self.root)), image_sha256=jobs.file_digest(image))
                self.assertNotIn("media_type", payload)
                self.enqueue(payload)
                self.assertEqual(jobs.validate_job(self.approved(payload), self.base), payload)
        self.validator.assert_not_called()

    def test_worker_uploads_video_creates_reel_polls_same_container_and_publishes_once(self):
        payload = self.due()
        self.api.container_status.side_effect = ["IN_PROGRESS", "IN_PROGRESS", "FINISHED"]
        self.assertEqual(self.run_due()[0]["phase"], "published")
        self.assertEqual(self.api.mock_calls, [call.verify_accounts(),
            call.upload_video(self.root / payload["video_path"], payload["video_sha256"] + ".mp4"),
            call.create_reel(payload["text"], self.api.upload_video.return_value),
            call.container_status("instagram", "007"), call.container_status("instagram", "007"),
            call.container_status("instagram", "007"), call.publish("instagram", "007"),
            call.permalink("instagram", "008")])
        self.assertEqual(self.sleep.call_args_list, [call(60), call(60)])
        self.assertEqual(self.state(payload)["attempts"], 1)
        self.assertEqual(self.state(payload)["container_id"], "007")
        self.assertEqual(self.run_due(), [])
        self.api.upload_video.assert_called_once()
        self.api.create_reel.assert_called_once()
        self.api.publish.assert_called_once_with("instagram", "007")
        self.api.upload_image.assert_not_called()
        self.api.create_container.assert_not_called()

    def test_slow_reel_resumes_existing_container_without_reupload_or_recreate(self):
        payload = self.due()
        self.api.container_status.return_value = "IN_PROGRESS"
        self.assertEqual(self.run_due()[0]["phase"], "container_ready")
        self.assertEqual(self.sleep.call_count, 4)
        self.api.container_status.return_value = "FINISHED"
        self.assertEqual(self.run_due()[0]["phase"], "published")
        self.api.upload_video.assert_called_once()
        self.api.create_reel.assert_called_once()
        self.api.publish.assert_called_once_with("instagram", "007")
        self.assertTrue(all(c == call("instagram", "007") for c in self.api.container_status.call_args_list))
        self.assertEqual(self.state(payload)["attempts"], 1)

    def timeout_blocks_channel(self, method):
        payload = self.due()
        getattr(self.api, method).side_effect = TimeoutError("synthetic timeout")
        self.assertEqual(self.run_due()[0]["phase"], "uncertain")
        self.assertEqual(self.state(payload)["phase"], "uncertain")
        self.assertEqual(self.run_due(), [])
        getattr(self.api, method).assert_called_once()
        self.current += timedelta(days=1)
        other = self.make_queue("next-day-card", kind="instagram_card")
        next_payload = self.payload(other)
        image = self.root / "next-day.jpg"
        image.write_bytes(b"synthetic next-day image")
        next_payload.update(image_path=str(image.relative_to(self.root)), image_sha256=jobs.file_digest(image))
        self.enqueue(next_payload)
        self.current += timedelta(minutes=11)
        previous_calls = list(self.api.mock_calls)
        self.assertEqual(self.run_due(), [])
        self.assertEqual(self.api.mock_calls, previous_calls)
        self.assertIsNone(self.state(next_payload))
        self.assertEqual(self.state(payload)["phase"], "uncertain")
        self.api.upload_image.assert_not_called()
        self.api.create_container.assert_not_called()

    def test_create_reel_timeout_is_uncertain_no_retry_and_blocks_instagram_next_day(self):
        self.timeout_blocks_channel("create_reel")
        self.api.publish.assert_not_called()

    def test_publish_timeout_is_uncertain_no_retry_and_blocks_instagram_next_day(self):
        self.timeout_blocks_channel("publish")
        self.api.publish.assert_called_once_with("instagram", "007")

    def shared_daily_cap(self, first_kind):
        second_kind = "instagram_card" if first_kind == "instagram_reel" else "instagram_reel"
        payloads = []
        for index, kind in enumerate((first_kind, second_kind)):
            source = self.make_queue("daily-" + str(index), kind=kind)
            payload = self.payload(source, minutes=10 + index)
            if kind == "instagram_card":
                image = self.root / "daily.jpg"
                image.write_bytes(b"synthetic daily card")
                payload.update(image_path=str(image.relative_to(self.root)), image_sha256=jobs.file_digest(image))
            payloads.append(self.enqueue(payload))
        self.current += timedelta(minutes=12)
        self.assertEqual(self.run_due(), [{"job_id": payloads[0]["job_id"], "phase": "published",
                                         "permalink": self.api.permalink.return_value}])
        self.assertEqual(self.run_due(), [])
        self.api.publish.assert_called_once_with("instagram", "007" if first_kind == "instagram_reel" else "009")
        self.assertIsNone(self.state(payloads[1]))

    def test_reel_publication_uses_same_instagram_daily_cap_as_card(self):
        self.shared_daily_cap("instagram_reel")
        self.api.upload_image.assert_not_called()

    def test_card_publication_uses_same_instagram_daily_cap_as_reel(self):
        self.shared_daily_cap("instagram_card")
        self.api.upload_video.assert_not_called()

    def test_dry_run_has_zero_api_sleep_or_state_mutation(self):
        payload = self.due()
        job_path = self.base / "jobs" / (payload["job_id"] + ".json")
        before = job_path.read_bytes()
        result = self.run_due(live=False)
        self.assertEqual(result[0]["mode"], "dry-run")
        self.api_class.assert_not_called()
        self.assertEqual(self.api.mock_calls, [])
        self.sleep.assert_not_called()
        self.assertIsNone(self.state(payload))
        self.assertEqual(job_path.read_bytes(), before)

    def test_disabled_worker_has_zero_api_or_state_mutation(self):
        payload = self.due()
        (self.base / "PUBLISH_DISABLED").touch()
        self.assertEqual(self.run_due(), [{"mode": "disabled"}])
        self.api_class.assert_not_called()
        self.assertEqual(self.api.mock_calls, [])
        self.sleep.assert_not_called()
        self.assertIsNone(self.state(payload))

    def cli(self, *arguments):
        output, error = io.StringIO(), io.StringIO()
        original_enqueue = publisher.enqueue
        with patch.object(sys, "argv", ["social_publish.py", *arguments]), \
             patch.object(publisher, "load_env", return_value=self.env), \
             patch.object(publisher, "lock", side_effect=lambda: contextlib.nullcontext()), \
             patch.object(publisher, "enqueue", side_effect=lambda payload: original_enqueue(payload, self.base)), \
             contextlib.redirect_stdout(output), contextlib.redirect_stderr(error):
            code = publisher.main()
        return code, output.getvalue(), error.getvalue()

    def cli_preview(self):
        at = (self.current + timedelta(hours=1)).isoformat()
        code, output, error = self.cli("preview", str(self.source), "--at", at)
        self.assertEqual(code, 0, error)
        return at, json.loads(output)

    def cli_approve(self, at, preview):
        return self.cli("approve", str(self.source), "--at", at, "--confirmed",
                        "--preview-sha", preview["preview_sha256"])

    def test_cli_approves_reviewed_reel_and_fixes_asset_without_any_api(self):
        at, preview = self.cli_preview()
        code, _, error = self.cli_approve(at, preview)
        self.assertEqual(code, 0, error)
        job = jobs.read_json(self.base / "jobs/test-reel-instagram.json")
        self.assertEqual(jobs.validate_job(job, self.base)["media_type"], "REELS")
        self.assertIn("status: scheduled", self.source.read_text())
        self.assertEqual(self.api.mock_calls, [])

    def test_cli_rejects_source_video_byte_change_after_preview(self):
        at, preview = self.cli_preview()
        self.video.write_bytes(MP4 + b"changed after preview")
        self.assertEqual(self.cli_approve(at, preview)[0], 2)
        self.assertFalse((self.base / "jobs").exists())

    def test_cli_rejects_changed_video_path_even_with_identical_bytes(self):
        at, preview = self.cli_preview()
        other = self.video_dir / "other.mp4"
        other.write_bytes(MP4)
        self.source.write_text(self.source.read_text().replace("synthetic/clip.mp4", "synthetic/other.mp4"))
        self.assertEqual(self.cli_approve(at, preview)[0], 2)
        self.assertFalse((self.base / "jobs").exists())

    def test_cli_rejects_reel_spec_changed_after_preview(self):
        at, preview = self.cli_preview()
        self.validator.side_effect = None
        self.validator.return_value = {**VIDEO_SPEC, "fps": 24}
        self.assertEqual(self.cli_approve(at, preview)[0], 2)
        self.assertFalse((self.base / "jobs").exists())

    def test_cli_rejects_caption_changed_after_preview(self):
        at, preview = self.cli_preview()
        self.source.write_text(self.source.read_text().replace("음악으로 전하는 마음", "변경한 캡션"))
        self.assertEqual(self.cli_approve(at, preview)[0], 2)
        self.assertFalse((self.base / "jobs").exists())


if __name__ == "__main__":
    unittest.main()
