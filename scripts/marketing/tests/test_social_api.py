"""Offline protocol and safety tests. All credentials and responses are synthetic."""
import hashlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlsplit

SPEC = importlib.util.spec_from_file_location("social_api", Path(__file__).parents[1] / "social_api.py")
api = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(api)


def response(value):
    result = io.BytesIO(value if isinstance(value, bytes) else json.dumps(value).encode())
    return result


def http_error(status, code=190):
    return HTTPError("https://private.invalid/token=secret-token", status,
                     "secret-token secret-key", {}, io.BytesIO(json.dumps({"error": {
                         "code": code, "message": "secret-token secret-key https://private.invalid"}}).encode()))


class SocialAPITests(unittest.TestCase):
    def setUp(self):
        self.env = {"THREADS_USER_ID": "00123", "IG_USER_ID": "00456",
                    "THREADS_ACCESS_TOKEN": "secret-token", "IG_ACCESS_TOKEN": "secret-ig",
                    "THREADS_APP_ID": "999", "THREADS_APP_SECRET": "secret-app",
                    "SUPABASE_URL": "https://example.supabase.co",
                    "SUPABASE_SERVICE_ROLE_KEY": "secret-key"}
        self.client = api.SocialAPI(self.env)
        self.network = patch.object(api, "urlopen")
        self.urlopen = self.network.start()
        self.addCleanup(self.network.stop)
        self.sleep = patch.object(api.time, "sleep").start()
        self.addCleanup(patch.stopall)

    def request(self, index=-1):
        return self.urlopen.call_args_list[index].args[0]

    def params(self, index=-1):
        req = self.request(index)
        return parse_qs(req.data.decode() if req.data else urlsplit(req.full_url).query)

    def test_verify_accounts_preserves_ids_and_protocol(self):
        self.urlopen.side_effect = [response({"id": "00123", "username": "mu_sic_letter"}),
                                   response({"id": "wrong-app-scoped", "user_id": "00456", "username": "mu_sic_letter"})]
        result = self.client.verify_accounts()
        self.assertEqual(result["instagram"]["user_id"], "00456")
        self.assertEqual(result["threads"]["id"], "00123")
        self.assertEqual(urlsplit(self.request(0).full_url).netloc, "graph.threads.net")
        self.assertEqual(urlsplit(self.request(1).full_url).path, "/v25.0/me")
        self.assertEqual(self.params(1)["fields"], ["user_id,username"])

    def test_wrong_identity_and_configurable_username(self):
        self.urlopen.return_value = response({"id": "999", "username": "mu_sic_letter"})
        with self.assertRaises(api.ApiError):
            self.client.verify_accounts()
        self.env["MARKETING_EXPECTED_USERNAME"] = "another"
        self.client = api.SocialAPI(self.env)
        self.urlopen.side_effect = [response({"id": "00123", "username": "another"}),
                                   response({"data": [{"user_id": "00456", "username": "another"}]})]
        self.assertEqual(self.client.verify_accounts()["threads"]["username"], "another")

    def test_create_status_publish_permalink(self):
        self.urlopen.side_effect = [response({"id": "007"}), response({"id": "008"}),
                                   response({"status": "FINISHED"}), response({"status_code": "IN_PROGRESS"}),
                                   response({"id": "009", "config_issue": "secret-token"}),
                                   response({"id": "010"}), response({"permalink": "https://www.instagram.com/p/abc/"})]
        self.assertEqual(self.client.create_container("threads", "hello 한글"), "007")
        image = "https://example.supabase.co/storage/v1/object/public/marketing-media/a.jpg"
        self.assertEqual(self.client.create_container("instagram", "caption", image), "008")
        self.assertEqual(self.params(0)["media_type"], ["TEXT"])
        self.assertNotIn("image_url", self.params(0))
        self.assertEqual(self.params(1)["caption"], ["caption"])
        self.assertEqual(self.client.container_status("threads", "007"), "FINISHED")
        self.assertEqual(self.client.container_status("instagram", "008"), "IN_PROGRESS")
        self.assertEqual(self.client.publish("threads", "007"), "009")
        self.assertTrue(self.request().full_url.endswith("/00123/threads_publish"))
        self.assertEqual(self.params()["creation_id"], ["007"])
        self.assertEqual(self.client.publish("instagram", "008"), "010")
        self.assertTrue(self.request().full_url.endswith("/00456/media_publish"))
        self.assertEqual(self.client.permalink("instagram", "010"), "https://www.instagram.com/p/abc/")

    def test_post_never_retried_and_errors_sanitized(self):
        for failure, ambiguous, transient in [(http_error(503), True, True),
                                               (http_error(429), False, True),
                                               (URLError("secret-token https://private.invalid"), True, False),
                                               (TimeoutError("secret-key"), True, True)]:
            self.urlopen.reset_mock()
            self.urlopen.side_effect = failure
            with self.assertRaises(api.ApiError) as captured:
                self.client.publish("threads", "007")
            self.assertEqual(self.urlopen.call_count, 1)
            exc = captured.exception
            self.assertEqual((exc.ambiguous, exc.transient), (ambiguous, transient))
            for secret in ("secret-token", "secret-key", "https:"):
                self.assertNotIn(secret, str(exc))
                self.assertNotIn(secret, repr(exc))
            self.assertTrue(exc.__suppress_context__)

    def test_get_bounded_retry(self):
        self.urlopen.side_effect = [http_error(503), response({"status": "FINISHED"})]
        self.assertEqual(self.client.container_status("threads", "7"), "FINISHED")
        self.assertEqual(self.urlopen.call_count, 2)
        self.urlopen.reset_mock()
        self.urlopen.side_effect = http_error(503)
        with self.assertRaises(api.ApiError):
            self.client.container_status("threads", "7")
        self.assertEqual(self.urlopen.call_count, 2)

    def test_no_redirect_following(self):
        self.assertIsNone(api._NoRedirect().redirect_request(None, None, 302, "", {}, "https://evil.invalid"))
        self.urlopen.side_effect = http_error(302)
        with self.assertRaises(api.ApiError):
            self.client.publish("instagram", "7")
        self.assertEqual(self.urlopen.call_count, 1)

    def test_upload_hash_and_conflict_comparison(self):
        content = b"\xff\xd8\xffsample\xff\xd9"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "image.jpg"
            path.write_bytes(content)
            self.urlopen.return_value = response({"Key": "irrelevant"})
            url = self.client.upload_image(path, "cards/post.jpg")
            self.assertIn(hashlib.sha256(content).hexdigest(), url)
            req = self.request()
            self.assertEqual(req.get_method(), "POST")
            headers = {k.lower(): v for k, v in req.header_items()}
            self.assertEqual(headers["authorization"], "Bearer secret-key")
            self.assertEqual(headers["x-upsert"], "false")
            self.assertNotIn("apikey", headers)
            self.assertNotIn("secret-key", req.full_url)
            self.urlopen.side_effect = [http_error(409), response(content)]
            self.assertEqual(self.client.upload_image(path, "cards/post.jpg"), url)
            self.assertEqual(self.request().get_method(), "GET")
            self.assertFalse(self.request().has_header("Authorization"))
            self.urlopen.side_effect = [http_error(400), response(b"different")]
            with self.assertRaises(api.ApiError):
                self.client.upload_image(path, "cards/post.jpg")

    def test_upload_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "image"
            for content in (b"invalid", b"\xff\xd8\xff" + b"a" * (8 * 1024 * 1024) + b"\xff\xd9"):
                path.write_bytes(content)
                with self.assertRaises(api.ApiError):
                    self.client.upload_image(path, "safe")
            path.write_bytes(b"\x89PNG\r\n\x1a\nsynthetic")
            self.urlopen.return_value = response({})
            self.assertTrue(self.client.upload_image(path, "safe").endswith(".png"))
            for name in ("../bad", "https://evil.invalid", "a//b"):
                with self.assertRaises(api.ApiError):
                    self.client.upload_image(path, name)

    def test_image_urls_reject_ssrf_and_png_instagram(self):
        for url in ("http://example.supabase.co/image.jpg", "https://evil.invalid/image.jpg",
                    "https://example.supabase.co.evil.invalid/storage/v1/object/public/marketing-media/a.jpg",
                    "https://example.supabase.co/storage/v1/object/public/marketing-media/../a.jpg",
                    "https://example.supabase.co/storage/v1/object/public/marketing-media/a.png",
                    "https://example.supabase.co/storage/v1/object/public/marketing-media/a.jpg?token=secret"):
            with self.assertRaises(api.ApiError):
                self.client.create_container("instagram", "x", url)
        self.urlopen.assert_not_called()

    def test_token_scopes_identity_and_app_credentials(self):
        info = {"is_valid": True, "user_id": "00123", "scopes": ["threads_basic", "threads_content_publish"], "app_id": "999"}
        self.urlopen.return_value = response({"data": info})
        self.assertEqual(self.client.token_info("threads"), info)
        self.assertEqual(self.params()["access_token"], ["999|secret-app"])
        self.assertEqual(self.params()["input_token"], ["secret-token"])
        for invalid in ({**info, "scopes": ["threads_basic"]}, {**info, "user_id": "123"},
                        {**info, "is_valid": False}, {**info, "app_id": "111"}):
            self.urlopen.return_value = response({"data": invalid})
            with self.assertRaises(api.ApiError):
                self.client.token_info("threads")
        self.urlopen.reset_mock()
        self.assertFalse(self.client.token_info("instagram")["supported"])
        self.urlopen.assert_not_called()

    def test_refresh_known_long_lived_only_and_no_retry(self):
        with self.assertRaises(api.ApiError):
            self.client.refresh_token("threads")
        now = api.time.time()
        for channel, prefix, grant in (("threads", "THREADS", "th_refresh_token"), ("instagram", "IG", "ig_refresh_token")):
            self.env.update({prefix + "_TOKEN_KIND": "long_lived_dashboard", prefix + "_TOKEN_ISSUED_AT": str(now - 172800),
                             prefix + "_TOKEN_EXPIRES_AT": str(now + 86400)})
            self.client = api.SocialAPI(self.env)
            self.urlopen.side_effect = None
            self.urlopen.return_value = response({"access_token": "new-secret", "expires_in": 5184000})
            self.assertEqual(self.client.refresh_token(channel)["access_token"], "new-secret")
            self.assertEqual(self.params()["grant_type"], [grant])
            self.assertNotIn("client_secret", self.params())
            self.assertEqual(self.client.env[prefix + "_ACCESS_TOKEN"], self.env[prefix + "_ACCESS_TOKEN"])
            self.urlopen.reset_mock()
            self.urlopen.side_effect = http_error(503)
            with self.assertRaises(api.ApiError):
                self.client.refresh_token(channel)
            self.assertEqual(self.urlopen.call_count, 1)

    def test_refresh_rejects_young_expired_unknown_tokens(self):
        now = api.time.time()
        for kind, issued, expires in (("short_lived", now - 172800, now + 86400),
                                      ("long_lived_dashboard", now - 3600, now + 86400),
                                      ("long_lived_dashboard", now - 172800, now - 1),
                                      ("long_lived_dashboard", float("nan"), now + 86400)):
            self.env.update({"IG_TOKEN_KIND": kind, "IG_TOKEN_ISSUED_AT": issued,
                             "IG_TOKEN_EXPIRES_AT": expires})
            with self.assertRaises(api.ApiError):
                api.SocialAPI(self.env).refresh_token("instagram")
        self.urlopen.assert_not_called()

    def test_malformed_inputs_and_response_types_are_safe(self):
        for origin in ("https://example.supabase.co:secret-key", "https://[secret-key",
                       "http://example.supabase.co", "https://secret-key@example.supabase.co"):
            self.env["SUPABASE_URL"] = origin
            client = api.SocialAPI(self.env)
            with self.assertRaises(api.ApiError) as captured:
                client._origin()
            self.assertNotIn("secret-key", str(captured.exception))
        self.urlopen.return_value = response({"status": ["secret-token"]})
        with self.assertRaises(api.ApiError):
            self.client.container_status("threads", "7")
        self.urlopen.reset_mock()
        for invalid_id in ("7/../publish", "https://secret-token", True):
            with self.assertRaises(api.ApiError):
                self.client.publish("threads", invalid_id)
        self.urlopen.assert_not_called()

    def test_constructor_does_not_read_files_or_mutate_environment(self):
        with patch.object(Path, "open", side_effect=AssertionError("No env file reads")):
            client = api.SocialAPI(self.env)
            client.env["THREADS_ACCESS_TOKEN"] = "different"
        self.assertEqual(self.env["THREADS_ACCESS_TOKEN"], "secret-token")
        self.urlopen.assert_not_called()

    def test_invalid_post_response_ambiguous(self):
        for value in (b"secret-token not json", {"unexpected": "secret-key"}, {"id": "bad/secret-token"}):
            self.urlopen.return_value = response(value)
            with self.assertRaises(api.ApiError) as captured:
                self.client.publish("threads", "7")
            self.assertTrue(captured.exception.ambiguous)
            self.assertNotIn("secret", str(captured.exception))


if __name__ == "__main__":
    unittest.main()
