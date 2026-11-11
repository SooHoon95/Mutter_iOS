"""Small, explicit social API client. Never loads files containing credentials.

The caller owns approval, durable IDs, scheduling and token persistence. POSTs
are never retried here. No redirects are followed (including authenticated GETs).
Sources: Meta Threads posts/debug/refresh docs; Instagram Login get-started,
refresh_access_token and content-publishing docs. Instagram debug_token is not
implemented: the Facebook Login contract does not establish an IG Login one.
"""
from __future__ import annotations

import hashlib
import json
import re
import socket
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


class ApiError(Exception):
    """Only controlled messages and numeric codes; never response text or URLs."""

    def __init__(self, message: str, *, ambiguous: bool = False,
                 transient: bool = False, code: int | None = None,
                 http_status: int | None = None):
        super().__init__(message)
        self.ambiguous = ambiguous
        self.transient = transient
        self.code = code
        self.http_status = http_status


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


# A patchable urlopen with redirects disabled, not the process-global opener.
urlopen = build_opener(_NoRedirect()).open
_MAX_IMAGE = 8 * 1024 * 1024
# Conservative headroom below Supabase's default 50 MB object limit.
_MAX_VIDEO = 45 * 1024 * 1024
_MAX_RESPONSE = 1024 * 1024
_BASE = {"threads": "https://graph.threads.net/v1.0",
         "instagram": "https://graph.instagram.com/v25.0"}
_PREFIX = {"threads": "THREADS", "instagram": "IG"}
_REQUIRED_SCOPES = {"threads_basic", "threads_content_publish"}


class SocialAPI:
    def __init__(self, env: dict):
        self.env = dict(env)

    def _required(self, key: str) -> str:
        value = self.env.get(key)
        if not isinstance(value, str) or not value.strip():
            raise ApiError("Required configuration is missing")
        return value.strip()

    def _channel(self, channel: str) -> str:
        if channel not in _PREFIX:
            raise ApiError("Unsupported channel")
        return _PREFIX[channel]

    def _id(self, value) -> str:
        if isinstance(value, bool) or not isinstance(value, (str, int)):
            raise ApiError("Invalid account or media ID")
        value = str(value)
        if not re.fullmatch(r"[0-9]{1,100}", value):
            raise ApiError("Invalid account or media ID")
        return value

    def _safe_code(self, value) -> int | None:
        if type(value) is not int or not 0 <= value <= 99999:
            return None
        if str(value) in {str(v) for k, v in self.env.items()
                          if "TOKEN" in k or "SECRET" in k or "KEY" in k}:
            return None
        return value

    def _request(self, method: str, url: str, *, params: dict | None = None,
                 body: bytes | None = None, headers: dict | None = None,
                 raw: bool = False, retry_get: bool = True,
                 byte_limit: int | None = None):
        limit = _MAX_IMAGE if raw else _MAX_RESPONSE
        if byte_limit is not None:
            if not raw or type(byte_limit) is not int or not 0 < byte_limit <= _MAX_VIDEO:
                raise ApiError("Invalid raw response limit")
            limit = byte_limit
        if params:
            if method == "GET":
                url += "?" + urlencode(params)
            else:
                body = urlencode(params).encode("utf-8")
                headers = {**(headers or {}),
                           "Content-Type": "application/x-www-form-urlencoded"}
        request = Request(url, data=body, headers=headers or {}, method=method)
        attempts = 2 if method == "GET" and retry_get else 1
        for attempt in range(attempts):
            error = None
            try:
                with urlopen(request, timeout=20) as response:
                    payload = response.read(limit + 1)
                if len(payload) > limit:
                    raise ApiError("API response exceeds limit", ambiguous=method == "POST")
                if raw:
                    return payload
                try:
                    data = json.loads(payload)
                except (ValueError, UnicodeError):
                    raise ApiError("Invalid API response", ambiguous=method == "POST") from None
                if not isinstance(data, dict):
                    raise ApiError("Invalid API response", ambiguous=method == "POST")
                # A valid returned ID is durable evidence, even with extra fields.
                if "error" in data and "id" not in data:
                    detail = data["error"] if isinstance(data["error"], dict) else {}
                    raise ApiError("API rejected request", code=self._safe_code(detail.get("code")))
                return data
            except HTTPError as exc:
                status = exc.code if type(exc.code) is int and 100 <= exc.code <= 599 else None
                code = None
                try:
                    data = json.loads(exc.read(_MAX_RESPONSE))
                    detail = data.get("error", {}) if isinstance(data, dict) else {}
                    if isinstance(detail, dict):
                        code = self._safe_code(detail.get("code"))
                except (ValueError, UnicodeError, OSError):
                    pass
                finally:
                    exc.close()
                error = ApiError("API HTTP failure", http_status=status, code=code,
                                 ambiguous=status is not None and status >= 500,
                                 transient=status == 429 or (status is not None and status >= 500))
            except (URLError, TimeoutError, OSError) as exc:
                reason = exc.reason if isinstance(exc, URLError) else exc
                timeout = isinstance(reason, (TimeoutError, socket.timeout))
                error = ApiError("API transport failure", ambiguous=True, transient=timeout)
            if error is not None:
                if not error.transient or attempt + 1 >= attempts:
                    raise error from None
                time.sleep(0.25)
        raise ApiError("API request failed")

    def _graph(self, channel: str, method: str, endpoint: str, params: dict):
        prefix = self._channel(channel)
        return self._request(method, _BASE[channel] + "/" + endpoint,
                             params={**params, "access_token": self._required(prefix + "_ACCESS_TOKEN")})

    def _account(self, channel: str) -> str:
        return self._id(self._required(self._channel(channel) + "_USER_ID"))

    def verify_accounts(self) -> dict:
        result = {}
        expected = self.env.get("MARKETING_EXPECTED_USERNAME", "mu_sic_letter")
        if not isinstance(expected, str) or not re.fullmatch(r"[A-Za-z0-9_.]+", expected):
            raise ApiError("Invalid expected username")
        for channel, field in (("threads", "id"), ("instagram", "user_id")):
            data = self._graph(channel, "GET", "me", {"fields": field + ",username"})
            # Instagram's documented get-started example wraps the user in data.
            if isinstance(data.get("data"), list) and len(data["data"]) == 1:
                data = data["data"][0]
            if not isinstance(data, dict):
                raise ApiError("Invalid account response")
            identity = self._id(data.get(field))
            if identity != self._account(channel):
                raise ApiError("Account ID does not match configuration")
            username = data.get("username")
            if not isinstance(username, str) or username.casefold() != expected.casefold():
                raise ApiError("Account username does not match configuration")
            result[channel] = {field: identity, "username": username}
        return result

    def _origin(self) -> str:
        value = self._required("SUPABASE_URL")
        try:
            parts = urlsplit(value)
            valid = (parts.scheme == "https" and parts.hostname and not parts.username
                     and not parts.password and parts.port in (None, 443)
                     and not parts.query and not parts.fragment and parts.path in ("", "/"))
        except ValueError:
            valid = False
        if not valid:
            raise ApiError("Invalid Supabase HTTPS origin") from None
        if not re.fullmatch(r"[a-z0-9.-]+", parts.hostname):
            raise ApiError("Invalid Supabase HTTPS origin")
        return "https://" + parts.hostname

    def _image_url(self, value: str, *, jpeg: bool = False) -> str:
        try:
            parts = urlsplit(value)
            origin = self._origin()
            valid = (parts.scheme == "https" and parts.netloc == urlsplit(origin).netloc
                     and not parts.query and not parts.fragment
                     and parts.path.startswith("/storage/v1/object/public/marketing-media/")
                     and re.fullmatch(r"/storage/v1/object/public/marketing-media/[A-Za-z0-9_./-]+", parts.path)
                     and not any(p in (".", "..", "") for p in parts.path.split("/")[1:]))
        except (ValueError, TypeError):
            valid = False
        if not valid or (jpeg and not parts.path.endswith((".jpg", ".jpeg"))):
            raise ApiError("Image must be an approved Supabase public JPEG URL" if jpeg
                           else "Invalid Supabase public image URL")
        return value

    def upload_image(self, path: Path, object_name: str) -> str:
        """Create immutable content-addressed object; compare bytes on conflict."""
        if (not isinstance(object_name, str)
                or not re.fullmatch(r"[A-Za-z0-9_./-]{1,180}", object_name)
                or any(p in ("", ".", "..") for p in object_name.split("/"))):
            raise ApiError("Invalid object name")
        try:
            with Path(path).open("rb") as source:
                content = source.read(_MAX_IMAGE + 1)
        except (OSError, TypeError, ValueError):
            raise ApiError("Cannot read local image") from None
        if not content or len(content) > _MAX_IMAGE:
            raise ApiError("Image must be at most 8 MB")
        if content.startswith(b"\xff\xd8\xff") and content.endswith(b"\xff\xd9"):
            extension, mime = "jpg", "image/jpeg"
        elif content.startswith(b"\x89PNG\r\n\x1a\n"):
            extension, mime = "png", "image/png"
        else:
            raise ApiError("Image must be JPEG or PNG")
        return self._upload_object(content, object_name, extension, mime)

    def _video_url(self, value: str) -> str:
        if not isinstance(value, str):
            raise ApiError("Video must be an approved Supabase public MP4 URL")
        try:
            self._image_url(value)
            parts = urlsplit(value)
            valid = (isinstance(value, str) and value == self._origin() + parts.path
                     and parts.path.endswith(".mp4"))
        except (ApiError, ValueError, TypeError):
            valid = False
        if not valid:
            raise ApiError("Video must be an approved Supabase public MP4 URL") from None
        return value

    def upload_video(self, path: Path, object_name: str) -> str:
        """Upload a bounded MP4 to an immutable marketing-media hash path.

        Header validation is not a codec/duration probe; the caller owns that.
        """
        if (not isinstance(object_name, str)
                or not re.fullmatch(r"[A-Za-z0-9_./-]{1,180}", object_name)
                or any(p in ("", ".", "..") for p in object_name.split("/"))):
            raise ApiError("Invalid object name")
        try:
            with Path(path).open("rb") as source:
                content = source.read(_MAX_VIDEO + 1)
        except (OSError, TypeError, ValueError):
            raise ApiError("Cannot read local video") from None
        if not content or len(content) > _MAX_VIDEO:
            raise ApiError("Video must be at most 45 MiB")
        box_size = int.from_bytes(content[:4], "big")
        # ISO BMFF ftyp: size, type, major brand, minor version, compatible brands.
        # MP4 brands deliberately exclude QuickTime and HEIF containers.
        brands = {b"isom", b"iso2", b"iso3", b"iso4", b"iso5", b"iso6",
                  b"mp41", b"mp42", b"avc1", b"M4V ", b"dash"}
        if (len(content) < 16 or content[4:8] != b"ftyp"
                or not 16 <= box_size <= len(content) or box_size % 4
                or not (content[8:12] in brands
                        or any(content[i:i + 4] in brands for i in range(16, box_size, 4)))):
            raise ApiError("Video must have an MP4 ftyp header")
        return self._upload_object(content, object_name, "mp4", "video/mp4",
                                   byte_limit=_MAX_VIDEO)

    def _upload_object(self, content: bytes, object_name: str, extension: str,
                       mime: str, *, byte_limit: int = _MAX_IMAGE) -> str:
        """POST once; a duplicate succeeds only after a bounded byte comparison."""
        digest = hashlib.sha256(content).hexdigest()
        stem = object_name.rsplit(".", 1)[0] if "." in object_name.split("/")[-1] else object_name
        object_path = f"{stem}-{digest}.{extension}"
        origin = self._origin()
        suffix = "/marketing-media/" + object_path
        public_url = origin + "/storage/v1/object/public" + suffix
        headers = {"Authorization": "Bearer " + self._required("SUPABASE_SERVICE_ROLE_KEY"),
                   "Content-Type": mime, "x-upsert": "false"}
        try:
            self._request("POST", origin + "/storage/v1/object" + suffix,
                          body=content, headers=headers)
        except ApiError as exc:
            if exc.http_status not in (400, 409):
                raise
            # Supabase may use 400 for Duplicate. Do not trust its error text.
            # Only identical publicly retrievable bytes establish success.
            existing = self._request("GET", public_url, raw=True, byte_limit=byte_limit)
            if hashlib.sha256(existing).hexdigest() != digest:
                raise ApiError("Existing storage object content does not match") from None
        return public_url

    def _returned_id(self, data: dict) -> str:
        try:
            return self._id(data.get("id"))
        except ApiError:
            raise ApiError("API did not return a valid media ID", ambiguous=True) from None

    def create_container(self, channel: str, text: str, image_url: str | None = None) -> str:
        self._channel(channel)
        if not isinstance(text, str):
            raise ApiError("Invalid post text")
        account = self._account(channel)
        if channel == "threads":
            if image_url is not None:
                raise ApiError("Threads client supports text only")
            data = self._graph(channel, "POST", account + "/threads",
                               {"media_type": "TEXT", "text": text})
        else:
            if image_url is None:
                raise ApiError("Instagram requires a JPEG image")
            data = self._graph(channel, "POST", account + "/media",
                               {"image_url": self._image_url(image_url, jpeg=True), "caption": text})
        return self._returned_id(data)

    def create_reel(self, text: str, video_url: str) -> str:
        """Create an Instagram Login REELS container; never publish or retry.

        Contract: https://developers.facebook.com/documentation/instagram-platform/content-publishing
        """
        if not isinstance(text, str):
            raise ApiError("Invalid post text")
        data = self._graph("instagram", "POST", self._account("instagram") + "/media",
                           {"media_type": "REELS", "video_url": self._video_url(video_url),
                            "caption": text, "share_to_feed": "true"})
        return self._returned_id(data)

    def container_status(self, channel: str, id: str) -> str:
        field = "status" if channel == "threads" else "status_code"
        data = self._graph(channel, "GET", self._id(id), {"fields": field})
        value = data.get(field)
        if not isinstance(value, str) or value not in {"FINISHED", "IN_PROGRESS", "PUBLISHED", "ERROR", "EXPIRED"}:
            raise ApiError("Unknown container status")
        return value

    def publish(self, channel: str, container_id: str) -> str:
        endpoint = "threads_publish" if channel == "threads" else "media_publish"
        data = self._graph(channel, "POST", self._account(channel) + "/" + endpoint,
                           {"creation_id": self._id(container_id)})
        return self._returned_id(data)

    def permalink(self, channel: str, media_id: str) -> str:
        data = self._graph(channel, "GET", self._id(media_id), {"fields": "permalink"})
        value = data.get("permalink")
        try:
            parts = urlsplit(value)
            hosts = {"threads.net", "www.threads.net", "threads.com", "www.threads.com"} if channel == "threads" else {"instagram.com", "www.instagram.com"}
            valid = (parts.scheme == "https" and parts.hostname in hosts and not parts.username
                     and not parts.password and parts.port in (None, 443) and not parts.query
                     and not parts.fragment)
        except (ValueError, TypeError):
            valid = False
        if not valid:
            raise ApiError("Invalid media permalink")
        return value

    def token_info(self, channel: str) -> dict:
        """Threads debug metadata with required identity/scopes; IG fails closed."""
        self._channel(channel)
        if channel == "instagram":
            return {"supported": False, "reason": "Instagram Login debug contract is not verified"}
        app_token = self._required("THREADS_APP_ID") + "|" + self._required("THREADS_APP_SECRET")
        response = self._request("GET", _BASE[channel] + "/debug_token",
                                 params={"input_token": self._required("THREADS_ACCESS_TOKEN"),
                                         "access_token": app_token})
        data = response.get("data")
        if not isinstance(data, dict) or data.get("is_valid") is not True:
            raise ApiError("Token is not valid")
        if self._id(data.get("user_id")) != self._account(channel):
            raise ApiError("Token account does not match configuration")
        scopes = data.get("scopes")
        if not isinstance(scopes, list) or not all(isinstance(s, str) for s in scopes) or not _REQUIRED_SCOPES.issubset(scopes):
            raise ApiError("Required publishing scopes are missing")
        if "app_id" in data and str(data["app_id"]) != self._required("THREADS_APP_ID"):
            raise ApiError("Token app does not match configuration")
        return {key: data[key] for key in ("is_valid", "user_id", "app_id", "type", "issued_at",
                                          "expires_at", "data_access_expires_at", "scopes") if key in data}

    def refresh_token(self, channel: str) -> dict:
        """Explicit refresh only. Caller records dashboard provenance and times.

        *_TOKEN_KIND must be long_lived_dashboard; *_TOKEN_ISSUED_AT and
        *_TOKEN_EXPIRES_AT are epoch seconds. No short-to-long exchange exists.
        Does not retry even though Meta uses GET, or mutate caller credentials.
        """
        prefix = self._channel(channel)
        if self.env.get(prefix + "_TOKEN_KIND") != "long_lived_dashboard":
            raise ApiError("Refresh requires known long-lived dashboard token")
        try:
            issued = float(self.env[prefix + "_TOKEN_ISSUED_AT"])
            expires = float(self.env[prefix + "_TOKEN_EXPIRES_AT"])
        except (KeyError, ValueError, TypeError, OverflowError):
            raise ApiError("Refresh requires known token timestamps") from None
        now = time.time()
        if not (0 < issued <= now - 86400 and now < expires and issued < expires):
            raise ApiError("Token is expired or not yet eligible for refresh")
        origin = "https://graph.threads.net" if channel == "threads" else "https://graph.instagram.com"
        grant = "th_refresh_token" if channel == "threads" else "ig_refresh_token"
        data = self._request("GET", origin + "/refresh_access_token",
                             params={"grant_type": grant, "access_token": self._required(prefix + "_ACCESS_TOKEN")},
                             retry_get=False)
        if (not isinstance(data.get("access_token"), str) or not data["access_token"]
                or type(data.get("expires_in")) is not int or data["expires_in"] <= 0):
            raise ApiError("Invalid refresh response", ambiguous=True)
        return {key: data[key] for key in ("access_token", "token_type", "expires_in") if key in data}
