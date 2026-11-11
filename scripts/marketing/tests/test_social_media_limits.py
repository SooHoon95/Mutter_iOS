"""파일 증가/초과 파일에도 고정 메모리로 해시한다."""
import hashlib
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import social_jobs as jobs


class RecordingStream(io.BytesIO):
    def __init__(self, value):
        super().__init__(value)
        self.requests, self.returned = [], 0

    def read(self, size=-1):
        self.requests.append(size)
        value = super().read(size)
        self.returned += len(value)
        return value


class BoundedDigestTests(unittest.TestCase):
    def test_streaming_digest_uses_at_most_one_mib_per_read(self):
        value = b'x' * (2 * 1024 * 1024 + 3)
        stream = RecordingStream(value)
        with patch.object(Path, 'open', return_value=stream):
            result = jobs.file_digest(Path('synthetic.mp4'), limit=len(value))
        self.assertEqual(result, hashlib.sha256(value).hexdigest())
        self.assertTrue(all(0 < size <= 1024 * 1024 for size in stream.requests))
        self.assertEqual(stream.returned, len(value))

    def test_growing_file_stops_after_limit_plus_one_without_unbounded_read(self):
        limit = 1024 * 1024 + 2
        stream = RecordingStream(b'x' * (limit + 100))
        with patch.object(Path, 'open', return_value=stream), self.assertRaises(ValueError):
            jobs.file_digest(Path('synthetic.mp4'), limit=limit)
        self.assertEqual(stream.returned, limit + 1)
        self.assertTrue(all(0 < size <= 1024 * 1024 for size in stream.requests))

    def test_invalid_limits_fail_before_opening_file(self):
        for value in (0, -1, True, '1', 46 * 1024 * 1024):
            with self.subTest(value=value), patch.object(Path, 'open') as opening, self.assertRaises(ValueError):
                jobs.file_digest(Path('synthetic.mp4'), limit=value)
            opening.assert_not_called()


if __name__ == '__main__':
    unittest.main()
