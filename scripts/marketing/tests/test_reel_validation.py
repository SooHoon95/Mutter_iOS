"""Offline tests, including the actual 450-frame browser-produced reel.

Run: python3 -m unittest discover -s scripts/marketing/tests -p test_reel_validation.py
No FFmpeg, browser, subprocess, network, or secret inputs are used by this suite.
Actual fixture tests skip when neither original nor project fixture is present.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts/marketing"))
import reel_validation as validation

ACTUAL = Path("/Users/choesuhun/.aside/u/0/sessions/2026-10-10_rgqweBsiHyLoqg9i/tmp/browser-reel/result.mp4")
SHA = "d22352031129d39b9ef8d46ad92ce83737db6d607c41f408f5762bd1561a0458"


def atom(kind, payload=b""):
    return struct.pack(">I4s", len(payload) + 8, kind) + payload


def ue(n):
    value = bin(n + 1)[2:]
    return "0" * (len(value) - 1) + value


def sps(progressive=True, chroma=1, depth=8, width_mbs=68, crop_right=4):
    """Independent small SPS encoder for physical-format rejection cases."""
    bits = f"{100:08b}" + "00000000" + f"{40:08b}" + ue(0)
    bits += ue(chroma)
    if chroma == 3:
        bits += "0"
    bits += ue(depth - 8) * 2 + "00"  # depths, bypass, no scaling matrix
    bits += ue(0) + ue(0) + ue(0)  # frame num, POC type, POC size
    bits += ue(1) + "0" + ue(width_mbs - 1) + ue(119 if progressive else 59)
    bits += "1" if progressive else "00"
    bits += "1" + "1" + ue(0) + ue(crop_right) + ue(0) + ue(0)
    bits += "01"  # no VUI, RBSP stop bit
    bits += "0" * (-len(bits) % 8)
    return b"\x67" + bytes(int(bits[i:i + 8], 2) for i in range(0, len(bits), 8))


class BoundedParserTests(unittest.TestCase):
    def test_malformed_box_bounds(self):
        fixtures = [b"", b"abc", struct.pack(">I4s", 7, b"moov"),
                    struct.pack(">I4s", 100, b"moov"),
                    struct.pack(">I4s", 1, b"moov"),
                    struct.pack(">I4sQ", 1, b"moov", 15),
                    struct.pack(">I4sQ", 1, b"moov", 2**64 - 1),
                    atom(b"moov") + b"trailing"]
        for data in fixtures:
            with self.subTest(data=data), self.assertRaises(ValueError):
                validation._probe(data)

    def test_extended_and_zero_size_boxes_are_bounded(self):
        data = struct.pack(">I4sQ", 1, b"free", 16) + struct.pack(">I4s", 0, b"mdat") + b"123"
        boxes = validation._MP4(data).boxes(0, len(data))
        self.assertEqual([(b[0], b[2] - b[1]) for b in boxes], [(b"free", 0), (b"mdat", 3)])

    def test_box_count_limit(self):
        data = atom(b"free") * 3
        with patch.object(validation, "MAX_BOXES", 2), self.assertRaises(ValueError):
            validation._MP4(data).boxes(0, len(data))

    def test_sps_derives_cropped_dimensions_and_format(self):
        self.assertEqual(validation._sps(sps()), (1080, 1920))
        for nal in (sps(progressive=False), sps(chroma=3), sps(depth=10),
                    sps(crop_right=0), sps(width_mbs=67), b"\x67", b"\x68" + sps()[1:]):
            with self.subTest(nal=nal.hex()), self.assertRaises(ValueError):
                validation._sps(nal)

    def test_descriptor_bounds_and_bitstream_limits(self):
        for data in (b"\x05", b"\x05\x80", b"\x05\x80\x80\x80\x80", b"\x05\x04\0"):
            with self.subTest(data=data), self.assertRaises(ValueError):
                validation._descriptors(data)
        with self.assertRaises(ValueError):
            validation._Bits(b"\0" * 5).ue()
        with self.assertRaises(ValueError):
            validation._Bits(b"").get(1)

    def test_reads_are_bounded_before_allocation(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "oversize.mp4"
            with file.open("wb") as out:
                out.truncate(validation.MAX_BYTES + 1)
            with self.assertRaises(ValueError):
                validation._read(file, validation.MAX_BYTES)
            file.write_bytes(b"")
            with self.assertRaises(ValueError):
                validation._read(file, validation.MAX_BYTES)


class ActualBrowserReelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # A fixture may be copied here by the parent production task for later runs.
        project = ROOT / "marketing/video/2026-10-11-motion-first-line/preview-browser.mp4"
        cls.source = ACTUAL if ACTUAL.is_file() else project
        if not cls.source.is_file():
            raise unittest.SkipTest("Actual browser MP4 fixture is not available")
        cls.data = validation._read(cls.source, validation.MAX_BYTES)
        record = cls.source.with_suffix(".metadata.json")
        if not record.is_file():
            record = cls.source.with_suffix(".validation.json")
        cls.record = json.loads(validation._read(record, validation.MAX_RECORD_BYTES))

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "reel.mp4"
        self.cache = self.path.with_suffix(".validation.json")
        self.path.write_bytes(self.data)
        self.cache.write_text(json.dumps(self.record))

    def run_validation(self):
        return validation.validate_browser_reel(self.path)

    def mutate(self, offset, value, refresh_sha=True):
        data = bytearray(self.path.read_bytes())
        data[offset:offset + len(value)] = value
        self.path.write_bytes(data)
        if refresh_sha:
            record = json.loads(self.cache.read_text())
            record["sha256"] = hashlib.sha256(data).hexdigest()
            self.cache.write_text(json.dumps(record))

    def find(self, kind, last=False):
        # avc1 also occurs as an ftyp compatible brand, before its sample entry.
        offset = self.data.rfind(kind) if last else self.data.find(kind, 40 if kind == b"avc1" else 0)
        self.assertGreaterEqual(offset, 4)
        return offset - 4

    def test_actual_good_file_exact_normalized_probe(self):
        self.assertEqual(hashlib.sha256(self.data).hexdigest(), SHA)
        self.assertEqual(self.run_validation(), {
            "duration": 15.082673611111112, "width": 1080, "height": 1920,
            "fps": 30.0, "video_codec": "h264", "pixel_format": "yuv420p",
            "progressive": True, "audio_codec": "aac", "sample_rate": 48000,
            "channels": 2, "faststart": True, "size_bytes": 4457200, "frames": 450})
        self.assertEqual(validation.validate_browser_reel(self.path, self.cache), self.run_validation())

    def test_cached_flags_counts_and_expected_metadata_must_match(self):
        changes = {"backend": "ffmpeg", "decode_verified": False, "sha256": "0" * 64,
                   "frames": 449, "duration": 14.99, "decoded_audio_samples": 0,
                   "progressive": False, "pixel_format": "yuv444p", "width": 720,
                   "height": 1080, "fps": 29.97, "sample_rate": 44100,
                   "channels": 1, "audio_codec": "mp3", "video_codec": "hevc",
                   "faststart": False, "size_bytes": 1, "file_duration": 15}
        for key, value in changes.items():
            with self.subTest(key=key):
                self.cache.write_text(json.dumps(self.record | {key: value}))
                with self.assertRaises(ValueError):
                    self.run_validation()

    def test_no_boolean_or_string_decode_evidence(self):
        for change in ({"decode_verified": "true"}, {"decode_verified": 1},
                       {"decoded_audio_samples": True}, {"frames": "450"},
                       {"progressive": 1}, {"duration": True}, {"size_bytes": True}):
            with self.subTest(change=change):
                self.cache.write_text(json.dumps(self.record | change))
                with self.assertRaises(ValueError):
                    self.run_validation()

    def test_missing_malformed_duplicate_and_oversized_cache(self):
        self.cache.unlink()
        with self.assertRaises(ValueError):
            self.run_validation()
        for data in (b"not-json", b"[]", b"{\"backend\":1,\"backend\":2}",
                     b"x" * (validation.MAX_RECORD_BYTES + 1)):
            self.cache.write_bytes(data)
            with self.assertRaises(ValueError):
                self.run_validation()

    def test_tampered_actual_media_cannot_reuse_decode_cache(self):
        self.mutate(len(self.data) - 1, b"\xff", refresh_sha=False)
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            self.run_validation()

    def test_fake_progressive_cache_cannot_override_sps(self):
        marker = self.data.find(b"avcC") + 4
        sps_start = marker + 8
        sps_length = int.from_bytes(self.data[marker + 6:marker + 8], "big")
        for nal in (sps(progressive=False), sps(chroma=3), sps(depth=10), sps(crop_right=0)):
            with self.subTest(nal=nal.hex()):
                self.path.write_bytes(self.data)
                self.assertLessEqual(len(nal), sps_length)
                self.mutate(sps_start, nal + b"\0" * (sps_length - len(nal)))
                with self.assertRaises(ValueError):
                    self.run_validation()

    def test_physical_video_tables_dimensions_and_audio_config_rechecked(self):
        mutations = [
            (self.find(b"stsz") + 16, struct.pack(">I", 449)),
            (self.find(b"stts") + 20, struct.pack(">I", 2)),
            (self.find(b"mdhd") + 20, struct.pack(">I", 29)),
            (self.find(b"avc1") + 32, struct.pack(">H", 720)),
            (self.find(b"mp4a") + 24, struct.pack(">H", 1)),
            (self.find(b"mp4a") + 32, struct.pack(">I", 44100 * 65536)),
            (self.find(b"stco") + 16, struct.pack(">I", len(self.data) + 1)),
            (self.find(b"esds") + 8, b"\x04"),
            (self.find(b"hdlr", last=True) + 16, b"vide"),
        ]
        for offset, value in mutations:
            with self.subTest(offset=offset):
                self.path.write_bytes(self.data)
                self.mutate(offset, value)
                with self.assertRaises(ValueError):
                    self.run_validation()

    def test_wrong_aac_object_type_and_audio_specific_config(self):
        for pattern, value in ((b"\x04\x11\x40\x15", b"\x04\x11\x6b\x15"),
                               (b"\x05\x02\x11\x90", b"\x05\x02\x12\x10")):
            offset = self.data.find(pattern)
            self.assertGreater(offset, 0)
            self.path.write_bytes(self.data)
            self.mutate(offset, value)
            with self.assertRaises(ValueError):
                self.run_validation()

    def test_box_length_brand_faststart_and_moov_limit(self):
        cases = [(self.find(b"moov"), struct.pack(">I", len(self.data) + 1)),
                 (self.find(b"avcC"), struct.pack(">I", 2**32 - 1))]
        for offset, value in cases:
            self.path.write_bytes(self.data)
            self.mutate(offset, value)
            with self.assertRaises(ValueError):
                self.run_validation()
        # Moving mdat before moov is structurally non-faststart even if cache says true.
        moov_start, mdat_start = self.find(b"moov"), self.find(b"mdat")
        moved = self.data[:moov_start] + self.data[mdat_start:] + self.data[moov_start:mdat_start]
        self.path.write_bytes(moved)
        self.cache.write_text(json.dumps(self.record | {"sha256": hashlib.sha256(moved).hexdigest()}))
        with self.assertRaisesRegex(ValueError, "moov before mdat"):
            self.run_validation()
        self.path.write_bytes(self.data)
        self.cache.write_text(json.dumps(self.record))
        with patch.object(validation, "MAX_MOOV_BYTES", 1), self.assertRaises(ValueError):
            self.run_validation()


if __name__ == "__main__":
    unittest.main()
