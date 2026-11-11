"""Offline worker safety tests. No real secrets, sleeps, or network calls."""
import copy
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import social_api
import social_jobs as jobs
import social_publish as publisher


class SimulatedCrash(BaseException):
    """Models process termination, which normal Exception handlers cannot absorb."""


class SocialPublishTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.base = self.root / "marketing/publishing"
        self.queue = self.root / "marketing/queue"
        self.queue.mkdir(parents=True)
        self.current = datetime(2026, 10, 10, 12, tzinfo=timezone.utc)
        self.env = {"THREADS_USER_ID": "00123", "IG_USER_ID": "00456",
                    "THREADS_ACCESS_TOKEN": "synthetic-threads-token",
                    "IG_ACCESS_TOKEN": "synthetic-instagram-token",
                    "MARKETING_EXPECTED_USERNAME": "test_account"}
        for module in (jobs, publisher):
            self.patch(module, "ROOT", self.root)
            self.patch(module, "PUBLISHING", self.base)
            self.patch(module, "now", lambda: self.current)
            self.patch(module, "load_env", side_effect=AssertionError("No environment file reads"))
            self.patch(module, "update_env", side_effect=AssertionError("No environment file writes"))
        self.patch(social_api, "urlopen", side_effect=AssertionError("No network"))
        self.sleep = Mock()
        self.api = Mock(spec=social_api.SocialAPI)
        self.api.create_container.return_value = "007"
        self.api.container_status.return_value = "FINISHED"
        self.api.publish.return_value = "008"
        self.api.permalink.return_value = "https://www.threads.net/@test_account/post/synthetic"
        self.api_class = Mock(return_value=self.api)
        # run_due intentionally uses its production execute_job; only its sleep dependency is injected.
        execute = publisher.execute_job
        self.patch(publisher, "execute_job", side_effect=lambda payload, api, base:
                   execute(payload, api, base, sleep=self.sleep))
        current = int(self.current.timestamp())
        jobs.atomic_json(self.base / "token_state.json", {
            channel: {"kind": "long_lived_dashboard", "issued_at": current - 2 * 86400,
                      "expires_at": current + 30 * 86400,
                      "fingerprint": publisher.token_fingerprint(self.env[prefix + "_ACCESS_TOKEN"])}
            for channel, prefix in publisher.TOKEN_KEYS.items()
        })
        self.source = self.queue / "test-note.md"
        self.source.write_text("---\nid: test-note\ntype: threads\nchannel: threads\nstatus: draft\n---\n"
                               "## 추천안\n마음을 담은 음악 편지\n", encoding="utf-8")

    def patch(self, target, attribute, *args, **kwargs):
        context = patch.object(target, attribute, *args, **kwargs)
        result = context.start()
        self.addCleanup(context.stop)
        return result

    def payload(self):
        payload = jobs.payload_from_queue(self.source, (self.current + timedelta(minutes=10)).isoformat(),
                                          self.env["THREADS_USER_ID"], self.env["MARKETING_EXPECTED_USERNAME"])
        return payload

    def enqueue_due(self):
        payload = self.payload()
        publisher.enqueue(payload, self.base)
        self.current += timedelta(minutes=11)
        return payload

    def run_due(self, live=True):
        return publisher.run_due(self.env, live=live, base=self.base, api_class=self.api_class)

    def state(self, payload):
        return jobs.read_json(self.base / "state" / (payload["job_id"] + ".json"))

    def assert_no_posts(self):
        self.api.create_container.assert_not_called()
        self.api.publish.assert_not_called()
        self.api.upload_image.assert_not_called()

    def test_draft_and_preview_without_approval_run_empty_zero_posts(self):
        preview = publisher.preview_job(self.source, (self.current + timedelta(hours=1)).isoformat(), self.env)
        self.assertEqual(preview["text"], "마음을 담은 음악 편지")
        self.current += timedelta(hours=2)
        self.assertEqual(self.run_due(), [])
        self.assertFalse((self.base / "jobs").exists())
        self.api.verify_accounts.assert_not_called()
        self.assert_no_posts()

    def test_dry_run_never_constructs_api_or_mutates_execution_state(self):
        payload = self.enqueue_due()
        job_path = self.base / "jobs" / (payload["job_id"] + ".json")
        original = job_path.read_bytes()
        result = self.run_due(live=False)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["mode"], "dry-run")
        self.api_class.assert_not_called()
        self.assert_no_posts()
        self.assertIsNone(self.state(payload))
        self.assertEqual(job_path.read_bytes(), original)
        self.sleep.assert_not_called()

    def test_pending_publishes_exactly_once_and_durable_rerun_does_not_duplicate(self):
        payload = self.enqueue_due()
        self.assertEqual(self.run_due()[0]["phase"], "published")
        state = self.state(payload)
        self.assertEqual(state["phase"], "published")
        self.assertEqual(state["media_id"], "008")
        self.assertEqual(state["container_id"], "007")
        self.assertEqual(state["attempts"], 1)
        self.assertEqual(state["permalink"], self.api.permalink.return_value)
        self.assertEqual(self.run_due(), [])
        self.api.create_container.assert_called_once_with("threads", payload["text"], None)
        self.api.publish.assert_called_once_with("threads", "007")
        self.api.verify_accounts.assert_called_once()
        self.assertEqual(self.state(payload), state)

    def test_publish_timeout_and_5xx_become_uncertain_and_never_republish(self):
        for failure in (TimeoutError("synthetic timeout"),
                        social_api.ApiError("Synthetic HTTP 503", ambiguous=True, transient=True, http_status=503)):
            with self.subTest(failure=type(failure).__name__):
                # Each case has a fresh job ID and execution ledger.
                self.source = self.queue / ("failure-" + str(len(list((self.base / "jobs").glob("*.json")))) + ".md")
                self.source.write_text("---\nid: " + self.source.stem +
                                       "\ntype: threads\nchannel: threads\nstatus: draft\n---\n## 추천안\n본문\n")
                self.api.reset_mock()
                self.api.publish.side_effect = failure
                payload = self.enqueue_due()
                self.assertEqual(self.run_due()[0]["phase"], "uncertain")
                self.assertEqual(self.state(payload)["phase"], "uncertain")
                self.assertEqual(self.run_due(), [])
                self.api.publish.assert_called_once_with("threads", "007")
                self.api.create_container.assert_called_once()
                # 두 오류 유형은 독립 시나리오. 미확정 원장이 다음 시나리오 채널을 막지 않게 fixture 정리.
                (self.base / 'state' / (payload['job_id'] + '.json')).unlink()
                (self.base / 'jobs' / (payload['job_id'] + '.json')).unlink()

    def test_crash_during_create_or_publish_persists_intent_then_holds_uncertain(self):
        for phase, method in (("creating", "create_container"), ("publishing", "publish")):
            with self.subTest(phase=phase):
                self.source = self.queue / ("crash-" + phase + ".md")
                self.source.write_text("---\nid: " + self.source.stem +
                                       "\ntype: threads\nchannel: threads\nstatus: draft\n---\n## 추천안\n본문\n")
                payload = self.enqueue_due()
                self.api.reset_mock()
                def crash(*args):
                    self.assertEqual(self.state(payload)["phase"], phase)
                    raise SimulatedCrash()
                getattr(self.api, method).side_effect = crash
                with self.assertRaises(SimulatedCrash):
                    self.run_due()
                self.assertEqual(self.state(payload)["phase"], phase)
                getattr(self.api, method).side_effect = None
                self.api.reset_mock()
                self.assertEqual(self.run_due()[0]["phase"], "uncertain")
                self.assertEqual(self.state(payload)["phase"], "uncertain")
                self.assertEqual(self.run_due(), [])
                self.assert_no_posts()
                (self.base / 'state' / (payload['job_id'] + '.json')).unlink()
                (self.base / 'jobs' / (payload['job_id'] + '.json')).unlink()

    def test_uncertain_job_blocks_other_jobs_even_next_kst_day(self):
        first = self.enqueue_due()
        self.api.publish.side_effect = TimeoutError('synthetic lost response')
        self.assertEqual(self.run_due()[0]['phase'], 'uncertain')
        self.source = self.queue / 'second-note.md'
        self.source.write_text('---\nid: second-note\ntype: threads\nchannel: threads\nstatus: draft\n---\n## 추천안\n다음 본문\n')
        self.enqueue_due()
        self.api.publish.side_effect = None
        self.assertEqual(self.run_due(), [])
        self.current += timedelta(days=1)
        self.assertEqual(self.run_due(), [])
        self.api.publish.assert_called_once()
        self.assertEqual(self.state(first)['phase'], 'uncertain')

    def test_pause_after_durable_publish_intent_never_sends_post(self):
        payload = self.enqueue_due()
        original = publisher.save_state
        def save_and_pause(base, content, state):
            original(base, content, state)
            if state['phase'] == 'publishing':
                (base / 'PUBLISH_DISABLED').touch()
        with patch.object(publisher, 'save_state', side_effect=save_and_pause):
            self.assertEqual(self.run_due()[0]['phase'], 'container_ready')
        self.api.publish.assert_not_called()
        self.assertEqual(self.state(payload)['phase'], 'container_ready')

    def test_permalink_failure_keeps_success_published_and_never_republishes(self):
        payload = self.enqueue_due()
        def fail_permalink(*args):
            # Success must already be durable before the optional GET starts.
            self.assertEqual(self.state(payload)["phase"], "published")
            self.assertEqual(self.state(payload)["media_id"], "008")
            raise TimeoutError("synthetic permalink failure")
        self.api.permalink.side_effect = fail_permalink
        self.assertEqual(self.run_due()[0]["phase"], "published")
        self.assertTrue(self.state(payload)["permalink_pending"])
        self.assertEqual(self.run_due(), [])
        self.api.publish.assert_called_once()
        self.api.create_container.assert_called_once()

    def test_in_progress_polling_is_bounded_and_resumes_same_container(self):
        payload = self.enqueue_due()
        self.api.container_status.return_value = "IN_PROGRESS"
        self.assertEqual(self.run_due()[0]["phase"], "container_ready")
        self.assertEqual(self.api.container_status.call_count, 5)
        self.assertEqual(self.sleep.call_count, 5)  # Threads wait plus four polling intervals.
        self.assertLessEqual(sum(call.args[0] for call in self.sleep.call_args_list), 270)
        self.api.publish.assert_not_called()
        self.api.container_status.return_value = "FINISHED"
        self.assertEqual(self.run_due()[0]["phase"], "published")
        self.api.create_container.assert_called_once()
        self.api.publish.assert_called_once_with("threads", "007")
        self.assertEqual(self.state(payload)["container_id"], "007")

    def test_disabled_switch_prevents_api_construction_and_all_posts(self):
        self.enqueue_due()
        (self.base / "PUBLISH_DISABLED").touch()
        self.assertEqual(self.run_due(), [{"mode": "disabled"}])
        self.api_class.assert_not_called()
        self.assert_no_posts()

    def test_disabled_switch_set_during_polling_prevents_publish(self):
        payload = self.enqueue_due()
        def disable(*args):
            (self.base / "PUBLISH_DISABLED").touch()
            return "FINISHED"
        self.api.container_status.side_effect = disable
        self.assertEqual(self.run_due()[0]["phase"], "container_ready")
        self.api.publish.assert_not_called()
        self.assertEqual(self.state(payload)["phase"], "container_ready")

    def test_account_id_or_username_mismatch_prevents_api_and_posts(self):
        self.enqueue_due()
        for key, mismatch in (("THREADS_USER_ID", "00999"), ("MARKETING_EXPECTED_USERNAME", "wrong_account")):
            with self.subTest(field=key):
                original = self.env[key]
                self.env[key] = mismatch
                with self.assertRaises(ValueError):
                    self.run_due()
                self.env[key] = original
                self.api_class.assert_not_called()
                self.assert_no_posts()

    def test_approval_tampering_is_rejected_before_any_api_construction(self):
        payload = self.enqueue_due()
        path = self.base / "jobs" / (payload["job_id"] + ".json")
        job = jobs.read_json(path)
        job["payload"]["text"] = "unapproved replacement"
        jobs.atomic_json(path, job)
        with self.assertRaises(ValueError):
            self.run_due()
        self.api_class.assert_not_called()
        self.assert_no_posts()

    def test_mutated_instagram_asset_rejected_before_any_api_or_upload(self):
        payload = self.payload()
        preview = self.base / "previews/card.jpg"
        preview.parent.mkdir(parents=True)
        preview.write_bytes(b"synthetic original jpeg")
        payload.update(channel="instagram", job_id="test-note-instagram", account_id="00456",
                       image_path=str(preview.relative_to(self.root)), image_sha256=jobs.file_digest(preview))
        publisher.enqueue(payload, self.base)
        asset = self.root / payload["image_path"]
        asset.chmod(0o600)
        asset.write_bytes(b"mutated jpeg")
        self.current += timedelta(minutes=11)
        with self.assertRaises(ValueError):
            self.run_due()
        self.api_class.assert_not_called()
        self.assert_no_posts()

    def test_more_than_24_hours_late_is_durable_hold_without_posts(self):
        payload = self.enqueue_due()
        self.current = jobs.parse_time(payload["scheduled_at"]) + timedelta(hours=24, seconds=1)
        self.assertEqual(self.run_due()[0]["phase"], "expired_hold")
        self.assertEqual(self.state(payload)["phase"], "expired_hold")
        self.assertEqual(self.run_due(), [])
        self.assert_no_posts()

    def test_repeated_timer_runs_publish_only_one_per_channel_per_kst_day(self):
        first = self.enqueue_due()
        self.source = self.queue / "second-note.md"
        self.source.write_text("---\nid: second-note\ntype: threads\nchannel: threads\nstatus: draft\n---\n"
                               "## 추천안\n두 번째 음악 편지\n", encoding="utf-8")
        second = self.enqueue_due()
        result = self.run_due()
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["job_id"], first["job_id"])
        self.assertEqual(result[0]["phase"], "published")
        for _ in range(3):
            self.current += timedelta(minutes=5)
            self.assertEqual(self.run_due(), [])
        self.api.create_container.assert_called_once()
        self.api.publish.assert_called_once()
        self.assertIsNone(self.state(second))
        # 15:00 UTC is midnight KST, not midnight UTC; backlog is still under 24h old.
        self.current = datetime(2026, 10, 10, 15, tzinfo=timezone.utc)
        result = self.run_due()
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["job_id"], second["job_id"])
        self.assertEqual(result[0]["phase"], "published")
        self.assertEqual(self.api.create_container.call_count, 2)
        self.assertEqual(self.api.publish.call_count, 2)
        self.assertEqual(self.run_due(), [])

    def test_duplicate_enqueue_rejected_without_changing_approval(self):
        payload = self.payload()
        path = publisher.enqueue(copy.deepcopy(payload), self.base)
        original = path.read_bytes()
        replacement = copy.deepcopy(payload)
        replacement["text"] = "different duplicate text"
        with self.assertRaises(ValueError):
            publisher.enqueue(replacement, self.base)
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(len(list((self.base / "jobs").glob("*.json"))), 1)
        self.assertIsNone(self.state(payload))
        self.assert_no_posts()


if __name__ == "__main__":
    unittest.main()
