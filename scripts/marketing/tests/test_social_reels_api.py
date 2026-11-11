"""Offline Instagram Login REELS/storage safety tests, using synthetic data only."""
import hashlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs

SPEC = importlib.util.spec_from_file_location("social_reels_api", Path(__file__).parents[1] / "social_api.py")
api = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(api)

PUBLIC = "https://example.supabase.co/storage/v1/object/public/marketing-media/"
MP4 = (24).to_bytes(4, "big") + b"ftypisom\x00\x00\x00\x00isommp42" + (8).to_bytes(4, "big") + b"mdat"


def response(value):
    return io.BytesIO(value if isinstance(value, bytes) else json.dumps(value).encode())


def http_error(status):
    return HTTPError("https://secret.invalid/secret-token", status, "secret-key", {},
                     response({"error": {"code": 190, "message": "secret-token secret-key"}}))


class SocialReelsAPITests(unittest.TestCase):
    def setUp(self):
        self.env = {"IG_USER_ID": "00456", "IG_ACCESS_TOKEN": "secret-token",
                    "THREADS_USER_ID": "00123", "THREADS_ACCESS_TOKEN": "secret-threads",
                    "SUPABASE_URL": "https://example.supabase.co",
                    "SUPABASE_SERVICE_ROLE_KEY": "secret-key"}
        self.client = api.SocialAPI(self.env)
        self.network = patch.object(api, "urlopen")
        self.urlopen = self.network.start()
        self.addCleanup(self.network.stop)
        self.sleep = patch.object(api.time, "sleep")
        self.sleep_mock = self.sleep.start()
        self.addCleanup(self.sleep.stop)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "clip.mp4"
        self.path.write_bytes(MP4)

    def request(self, index=-1):
        return self.urlopen.call_args_list[index].args[0]

    def params(self, index=-1):
        return parse_qs(self.request(index).data.decode(), keep_blank_values=True)

    def test_reel_exact_instagram_login_contract_and_durable_id(self):
        self.urlopen.return_value = response({"id": "000789", "extra": "secret-token"})
        self.assertEqual(self.client.create_reel("음악 편지", PUBLIC + "reels/clip.mp4"), "000789")
        self.assertEqual(self.request().get_method(), "POST")
        self.assertEqual(self.request().full_url, "https://graph.instagram.com/v25.0/00456/media")
        self.assertEqual(self.params(), {"media_type": ["REELS"], "video_url": [PUBLIC + "reels/clip.mp4"],
                                         "caption": ["음악 편지"], "share_to_feed": ["true"],
                                         "access_token": ["secret-token"]})
        self.assertEqual(self.urlopen.call_count, 1)

    def test_existing_image_and_threads_creation_unchanged(self):
        self.urlopen.side_effect = [response({"id": "0007"}), response({"id": "0008"})]
        self.assertEqual(self.client.create_container("instagram", "photo", PUBLIC + "photo.jpg"), "0007")
        self.assertEqual(self.params(0), {"caption": ["photo"], "image_url": [PUBLIC + "photo.jpg"],
                                          "access_token": ["secret-token"]})
        self.assertEqual(self.client.create_container("threads", "text"), "0008")
        self.assertEqual(self.request().full_url, "https://graph.threads.net/v1.0/00123/threads")
        self.assertEqual(self.params()["media_type"], ["TEXT"])
        with self.assertRaises(api.ApiError):
            self.client.create_container("instagram", "not a photo", PUBLIC + "clip.mp4")

    def test_reel_uses_existing_media_publish_endpoint(self):
        self.urlopen.side_effect = [response({"id": "0007"}), response({"id": "0008"})]
        container = self.client.create_reel("caption", PUBLIC + "clip.mp4")
        self.assertEqual(self.client.publish("instagram", container), "0008")
        self.assertEqual(self.request().full_url, "https://graph.instagram.com/v25.0/00456/media_publish")
        self.assertEqual(self.request().get_method(), "POST")
        self.assertEqual(self.params(), {"creation_id": ["0007"], "access_token": ["secret-token"]})

    def test_reel_post_timeout_and_http_failures_never_retry(self):
        for failure in (TimeoutError("secret-token"), URLError("secret-key"), http_error(503), http_error(429)):
            with self.subTest(failure=type(failure).__name__):
                self.urlopen.reset_mock()
                self.urlopen.side_effect = failure
                with self.assertRaises(api.ApiError) as caught:
                    self.client.create_reel("caption", PUBLIC + "clip.mp4")
                self.assertEqual(self.urlopen.call_count, 1)
                self.assertNotIn("secret", str(caught.exception))
                self.assertNotIn("https:", repr(caught.exception))
                self.assertTrue(caught.exception.__suppress_context__)
        self.sleep_mock.assert_not_called()

    def test_reel_invalid_returned_id_is_ambiguous(self):
        for value in ({}, {"id": True}, {"id": "secret-token"}, b"secret-key", {"id": []}):
            self.urlopen.return_value = response(value)
            with self.assertRaises(api.ApiError) as caught:
                self.client.create_reel("caption", PUBLIC + "clip.mp4")
            self.assertTrue(caught.exception.ambiguous)
            self.assertNotIn("secret", str(caught.exception))

    def test_reel_invalid_text_or_account_rejected_before_network(self):
        for text in (None, b"caption", 12):
            with self.assertRaises(api.ApiError):
                self.client.create_reel(text, PUBLIC + "clip.mp4")
        for identity in ("secret-token", "7/../media", True):
            with self.assertRaises(api.ApiError):
                api.SocialAPI({**self.env, "IG_USER_ID": identity}).create_reel("caption", PUBLIC + "clip.mp4")
        self.urlopen.assert_not_called()

    def test_video_url_exact_origin_bucket_extension_and_safe_path(self):
        invalid = [None, 42, b"https://secret.invalid", "http://example.supabase.co/clip.mp4",
                   PUBLIC.replace("example.supabase.co", "evil.invalid") + "clip.mp4",
                   PUBLIC.replace("example.supabase.co", "example.supabase.co.evil.invalid") + "clip.mp4",
                   PUBLIC.replace("marketing-media", "other-bucket") + "clip.mp4",
                   PUBLIC.replace("/public/", "/sign/") + "clip.mp4",
                   PUBLIC.replace("example.supabase.co", "secret-token@example.supabase.co") + "clip.mp4",
                   PUBLIC.replace("example.supabase.co", "example.supabase.co:443") + "clip.mp4",
                   PUBLIC + "clip.jpg", PUBLIC + "clip.MP4", PUBLIC + "../clip.mp4", PUBLIC + "./clip.mp4",
                   PUBLIC + "reels//clip.mp4", PUBLIC + "%2e%2e/clip.mp4", PUBLIC + "reels%2fclip.mp4",
                   PUBLIC + "reels\\clip.mp4", PUBLIC + "clip.mp4?secret-token", PUBLIC + "clip.mp4#secret-key",
                   PUBLIC + "clip.mp4?", PUBLIC + "clip.mp4#", "\n" + PUBLIC + "clip.mp4",
                   PUBLIC + "cli\np.mp4", PUBLIC + "clip.mp4 "]
        for value in invalid:
            with self.subTest(url=repr(value)):
                with self.assertRaises(api.ApiError) as caught:
                    self.client.create_reel("caption", value)
                self.assertNotIn("secret", str(caught.exception))
        self.urlopen.assert_not_called()

    def test_upload_mp4_hash_path_headers_and_bytes(self):
        self.urlopen.return_value = response({"Key": "ignored"})
        url = self.client.upload_video(self.path, "reels/clip.mp4")
        digest = hashlib.sha256(MP4).hexdigest()
        self.assertEqual(url, PUBLIC + "reels/clip-" + digest + ".mp4")
        req = self.request()
        self.assertEqual(req.full_url, url.replace("/object/public/", "/object/"))
        self.assertEqual(req.get_method(), "POST")
        self.assertEqual(req.data, MP4)
        headers = {key.lower(): value for key, value in req.header_items()}
        self.assertEqual(headers["content-type"], "video/mp4")
        self.assertEqual(headers["x-upsert"], "false")
        self.assertEqual(headers["authorization"], "Bearer secret-key")
        self.assertNotIn("apikey", headers)
        self.assertNotIn("secret", req.full_url)
        self.assertEqual(self.client._video_url(url), url)

    def test_video_conflict_identical_bytes_succeeds(self):
        digest = hashlib.sha256(MP4).hexdigest()
        for status in (400, 409):
            self.urlopen.reset_mock()
            self.urlopen.side_effect = [http_error(status), response(MP4)]
            self.assertEqual(self.client.upload_video(self.path, "clip"), PUBLIC + "clip-" + digest + ".mp4")
            self.assertEqual(self.urlopen.call_count, 2)
            self.assertEqual(self.request(0).get_method(), "POST")
            self.assertEqual(self.request().get_method(), "GET")
            self.assertFalse(self.request().has_header("Authorization"))
            self.assertFalse(self.request().has_header("apikey"))

    def test_video_conflict_hash_mismatch_fails_closed(self):
        self.urlopen.side_effect = [http_error(409), response(MP4 + b"different")]
        with self.assertRaises(api.ApiError) as caught:
            self.client.upload_video(self.path, "clip")
        self.assertEqual(str(caught.exception), "Existing storage object content does not match")
        self.assertEqual(self.urlopen.call_count, 2)

    def test_video_conflict_can_compare_more_than_eight_mib(self):
        content = MP4 + b"\x00" * (9 * 1024 * 1024)
        self.path.write_bytes(content)
        self.urlopen.side_effect = [http_error(409), response(content)]
        self.assertIn(hashlib.sha256(content).hexdigest(), self.client.upload_video(self.path, "clip"))
        self.assertEqual(self.urlopen.call_count, 2)

    def test_upload_post_timeout_or_server_failure_never_retried(self):
        for failure in (TimeoutError("secret-key"), http_error(503), http_error(302)):
            self.urlopen.reset_mock()
            self.urlopen.side_effect = failure
            with self.assertRaises(api.ApiError) as caught:
                self.client.upload_video(self.path, "clip")
            self.assertEqual(self.urlopen.call_count, 1)
            self.assertNotIn("secret", str(caught.exception))
            self.assertTrue(caught.exception.__suppress_context__)
        self.sleep_mock.assert_not_called()

    def test_mp4_type_header_and_box_size_validation(self):
        invalid = (b"", b"not an mp4", b"\xff\xd8\xffimage\xff\xd9", b"\x89PNG\r\n\x1a\n",
                   b"\x1aE\xdf\xa3webm", b"ftyp" + MP4, MP4[:12],
                   (12).to_bytes(4, "big") + MP4[4:], (999).to_bytes(4, "big") + MP4[4:],
                   (25).to_bytes(4, "big") + MP4[4:],
                   (16).to_bytes(4, "big") + b"ftypqt  \x00\x00\x00\x00",
                   (16).to_bytes(4, "big") + b"ftypheic\x00\x00\x00\x00")
        for content in invalid:
            self.path.write_bytes(content)
            with self.assertRaises(api.ApiError):
                self.client.upload_video(self.path, "clip")
        self.urlopen.assert_not_called()

    def test_compatible_mp4_brand_and_filename_independent_detection(self):
        self.path.write_bytes((20).to_bytes(4, "big") + b"ftypiso9\x00\x00\x00\x00mp42")
        self.urlopen.return_value = response({})
        self.assertTrue(self.client.upload_video(self.path, "clip.jpg").endswith(".mp4"))

    def test_video_45_mib_boundary_and_bounded_read(self):
        with self.path.open("wb") as source:
            source.write(MP4)
            source.truncate(api._MAX_VIDEO)
        self.urlopen.return_value = response({})
        self.assertTrue(self.client.upload_video(self.path, "clip").endswith(".mp4"))
        self.assertEqual(len(self.request().data), 45 * 1024 * 1024)
        self.urlopen.reset_mock()
        with self.path.open("ab") as source:
            source.write(b"x")
        with self.assertRaises(api.ApiError):
            self.client.upload_video(self.path, "clip")
        self.urlopen.assert_not_called()
        source = response(MP4)
        with patch.object(Path, "open", return_value=source), patch.object(source, "read", wraps=source.read) as read:
            self.urlopen.return_value = response({})
            self.client.upload_video(self.path, "bounded")
            read.assert_called_once_with(api._MAX_VIDEO + 1)

    def test_video_object_traversal_and_local_read_errors_safe(self):
        for name in ("../clip", "a/../clip", "/clip", "a//clip", "a/./clip", "clip/", "a%2fclip", "a\\clip", None):
            with self.assertRaises(api.ApiError):
                self.client.upload_video(self.path, name)
        for path in (Path(self.directory.name) / "secret-token.mp4", None, self.directory.name):
            with self.assertRaises(api.ApiError) as caught:
                self.client.upload_video(path, "clip")
            self.assertNotIn("secret", str(caught.exception))
            self.assertTrue(caught.exception.__suppress_context__)
        self.urlopen.assert_not_called()

    def test_request_limits_keep_json_and_default_raw_bounded(self):
        self.urlopen.return_value = response(b"x" * (api._MAX_RESPONSE + 1))
        with self.assertRaises(api.ApiError):
            self.client._request("POST", "https://example.invalid")
        self.urlopen.return_value = response(b"x" * (api._MAX_IMAGE + 1))
        with self.assertRaises(api.ApiError):
            self.client._request("GET", PUBLIC + "clip.mp4", raw=True)
        self.urlopen.reset_mock()
        for limit in (-1, 0, True, "large", api._MAX_VIDEO + 1):
            with self.assertRaises(api.ApiError):
                self.client._request("GET", PUBLIC + "clip.mp4", raw=True, byte_limit=limit)
        with self.assertRaises(api.ApiError):
            self.client._request("GET", PUBLIC + "clip.mp4", byte_limit=api._MAX_VIDEO)
        self.urlopen.assert_not_called()
        raw = response(b"x" * 65)
        self.urlopen.return_value = raw
        with patch.object(raw, "read", wraps=raw.read) as read:
            with self.assertRaises(api.ApiError):
                self.client._request("GET", PUBLIC + "clip.mp4", raw=True, byte_limit=64)
            read.assert_called_once_with(65)

    def test_conflict_response_over_video_limit_is_rejected(self):
        self.urlopen.side_effect = [http_error(409), response(b"x" * (api._MAX_VIDEO + 1))]
        with self.assertRaises(api.ApiError) as caught:
            self.client.upload_video(self.path, "clip")
        self.assertEqual(str(caught.exception), "API response exceeds limit")
        self.assertEqual(self.urlopen.call_count, 2)

    def test_conflict_redirect_not_followed(self):
        self.assertIsNone(api._NoRedirect().redirect_request(None, None, 302, "", {}, "https://secret.invalid"))
        self.urlopen.side_effect = [http_error(409), http_error(302)]
        with self.assertRaises(api.ApiError):
            self.client.upload_video(self.path, "clip")
        self.assertEqual(self.urlopen.call_count, 2)
        self.assertFalse(self.request().has_header("Authorization"))

    def test_constructor_never_reads_environment_files(self):
        with patch.object(Path, "open", side_effect=AssertionError("No file reads")):
            client = api.SocialAPI(self.env)
            client.env["IG_ACCESS_TOKEN"] = "changed"
        self.assertEqual(self.env["IG_ACCESS_TOKEN"], "secret-token")
        self.urlopen.assert_not_called()


if __name__ == "__main__":
    unittest.main()
