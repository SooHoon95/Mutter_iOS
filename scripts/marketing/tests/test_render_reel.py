"""Offline focused tests: python3 -m unittest discover -s scripts/marketing/tests -p test_render_reel.py."""
import importlib.util
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts/marketing"))
spec = importlib.util.spec_from_file_location("render_reel", ROOT / "scripts/marketing/render_reel.py")
reel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reel)

# Independent recorded-header fixtures, not generated from the parser's output.
HEADER = """Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'local.mp4':
  Metadata:
    title           : arbitrary metadata must not be echoed
  Duration: 00:00:15.00, start: 0.000000, bitrate: 1400 kb/s
  Stream #0:0[0x1](und): Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 1080x1920, 1280 kb/s, 30 fps, 30 tbr, 15360 tbn (default)
  Stream #0:1[0x2](und): Audio: aac (LC) (mp4a / 0x6134706D), 48000 Hz, stereo, fltp, 128 kb/s (default)
At least one output file must be specified
"""


def atom(kind, payload=b""):
    return struct.pack(">I4s", 8 + len(payload), kind) + payload


class MetadataTests(unittest.TestCase):
    def test_header_parses_actual_fields(self):
        data = reel._parse_metadata(HEADER)
        self.assertEqual(data, dict(duration=15.0, width=1080, height=1920, fps=30.0,
                                   video_codec="h264", pixel_format="yuv420p", progressive=True,
                                   audio_codec="aac", sample_rate=48000, channels=2))

    def test_header_color_range_and_fractional_duration(self):
        text = HEADER.replace("yuv420p(progressive)", "yuv420p(tv, bt709, progressive)").replace("15.00", "15.07")
        self.assertEqual(reel._parse_metadata(text)["duration"], 15.07)

    def test_malformed_or_multiple_streams_rejected_without_echo(self):
        for text in ("private-token-untrusted", HEADER.replace("Duration:", "Unknown:"),
                     HEADER + HEADER, HEADER.replace("30 fps", "unknown fps"),
                     HEADER.replace("48000 Hz", "unknown Hz")):
            with self.subTest(text=text[:20]), self.assertRaises(ValueError) as raised:
                reel._parse_metadata(text)
            self.assertNotIn("private-token", str(raised.exception))

    def test_wrong_codec_format_audio_order_fps_duration_rejected(self):
        baseline = reel._parse_metadata(HEADER) | {"size_bytes": 100, "faststart": True}
        changes = {"width": 720, "height": 1080, "fps": 29.97, "duration": 14.7,
                   "video_codec": "hevc", "pixel_format": "yuv444p", "progressive": False,
                   "audio_codec": "mp3", "sample_rate": 44100, "channels": 1, "faststart": False}
        for key, value in changes.items():
            with self.subTest(key=key), patch.object(reel, "metadata_probe", return_value=baseline | {key: value}), self.assertRaises(ValueError):
                reel.validate_reel(Path("preview.mp4"))

    def test_counts_decoded_frames_and_rejects_corruption(self):
        data = reel._parse_metadata(HEADER) | {"size_bytes": 100, "faststart": True}
        with patch.object(reel, "metadata_probe", return_value=data), patch.object(reel, "_ffmpeg", return_value="local-ffmpeg"):
            for frames, status, stderr in ((450, 0, b""), (449, 0, b""), (450, 1, b""), (450, 0, b"bad decode")):
                with patch.object(reel, "_run", return_value=subprocess.CompletedProcess([], status, f"frame={frames}\nprogress=end\n".encode(), stderr)):
                    if frames == 450 and status == 0 and not stderr:
                        self.assertEqual(reel.validate_reel(Path("local.mp4"))["frames"], 450)
                    else:
                        with self.assertRaises(ValueError):
                            reel.validate_reel(Path("local.mp4"))

    def test_probe_checks_local_file_size_and_bounded_timeout(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.mp4"
            with self.assertRaises(ValueError):
                reel.metadata_probe(path)
            path.write_bytes(atom(b"moov") + atom(b"mdat"))
            with patch.object(reel, "_ffmpeg", return_value="local-ffmpeg"), patch.object(reel, "_run", return_value=subprocess.CompletedProcess([], 1, b"", HEADER.encode())) as run:
                data = reel.metadata_probe(path)
                self.assertTrue(data["faststart"])
                self.assertEqual(run.call_args.args[1], 20)
            with patch.object(reel, "MAX_BYTES", 1), self.assertRaises(ValueError):
                reel.metadata_probe(path)

    def test_timeout_is_sanitized(self):
        with patch.object(reel.subprocess, "run", side_effect=subprocess.TimeoutExpired("private-token", 1)), self.assertRaises(ValueError) as raised:
            reel._run(["private-token"], 1)
        self.assertNotIn("private-token", str(raised.exception))

    def test_faststart_real_atom_order_and_malformed_atoms(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "atoms.mp4"
            for data, expected in ((atom(b"ftyp") + atom(b"moov") + atom(b"mdat"), True),
                                   (atom(b"mdat") + atom(b"moov"), False),
                                   (struct.pack(">I4s", 100, b"moov"), False),
                                   (struct.pack(">I4sQ", 1, b"moov", 16) + atom(b"mdat"), True)):
                path.write_bytes(data)
                self.assertEqual(reel._faststart(path), expected)


class LayoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not reel.DEFAULT_FONT.is_file():
            raise unittest.SkipTest("Bundled Korean font not present")
        cls.prepared = reel._prepare(reel.DEFAULT_FONT)

    def test_all_fixed_copy_glyphs_and_explicit_line_breaks_fit(self):
        for start, end, text in reel.SCENES:
            reel._validate_font(reel.DEFAULT_FONT, text)
            sprite = reel._text_sprite(text, reel.DEFAULT_FONT, 74)
            self.assertIsNotNone(sprite.getbbox())
            self.assertLessEqual(sprite.height, 466)

    def test_frames_are_full_rgb_and_deterministic(self):
        for t in (0, 3, 5, 7, 10, 13, 14.9666667):
            first = reel._frame(t, self.prepared)
            self.assertEqual(first.size, (1080, 1920))
            self.assertEqual(first.mode, "RGB")
            self.assertEqual(first.tobytes(), reel._frame(t, self.prepared).tobytes())
        self.assertNotEqual(reel._frame(4, self.prepared).tobytes(), reel._frame(5, self.prepared).tobytes())

    def test_crossfade_weights_smooth_and_normalized(self):
        for index in range(450):
            weights = reel._weights(index / 30)
            self.assertAlmostEqual(sum(weights), 1, places=7)
            self.assertTrue(all(0 <= weight <= 1 for weight in weights))
        self.assertEqual(reel._weights(3)[:2], [.5, .5])
        self.assertEqual(reel._weights(14.9666667)[-1], 1)

    def test_missing_font_and_missing_glyph_fail_before_encoder(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(reel, "_ffmpeg") as binary, self.assertRaisesRegex(ValueError, "Missing Korean serif"):
                reel.render_reel(Path(directory) / "new.mp4", Path(directory) / "missing.otf")
            binary.assert_not_called()
        with self.assertRaises(ValueError):
            reel._validate_font(reel.DEFAULT_FONT, "\U0010FFFF")

    def test_fixed_parameters_and_existing_output_rejected(self):
        with self.assertRaisesRegex(ValueError, "duration=15"):
            reel.render_reel(Path("unused.mp4"), duration=1)
        with self.assertRaises(ValueError):
            reel.render_reel(Path("unused.png"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "existing.mp4"
            path.write_bytes(b"do not overwrite")
            with self.assertRaisesRegex(ValueError, "already exists"):
                reel.render_reel(path)
            self.assertEqual(path.read_bytes(), b"do not overwrite")


class TinyEncoderTests(unittest.TestCase):
    @unittest.skipUnless(os.environ.get('RUN_REEL_ENCODER_TEST') == '1', 'Native encoder smoke is explicit opt-in; offline tests do not prove rendering')
    def test_real_two_frame_rgb_pipe_header_when_binary_available(self):
        try:
            binary = reel._ffmpeg()
        except ValueError:
            self.skipTest("Local FFmpeg unavailable or executable discovery blocked in this runtime")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tiny.mp4"
            args = [binary, "-hide_banner", "-loglevel", "error", "-nostdin", "-y", "-f", "rawvideo",
                    "-pix_fmt", "rgb24", "-s", "16x16", "-r", "30", "-i", "pipe:0", "-f", "lavfi",
                    "-i", "anullsrc=r=48000:cl=stereo", "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-frames:v", "2", "-t", "0.066667", "-c:a", "aac", "-b:a", "128k", "-ar", "48000", "-ac", "2",
                    "-movflags", "+faststart", str(path)]
            result = subprocess.run(args, input=bytes([255, 253, 242]) * 16 * 16 * 2,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
            self.assertEqual(result.returncode, 0, "Local two-frame encoding failed")
            data = reel.metadata_probe(path)
            self.assertEqual((data["width"], data["height"], data["fps"]), (16, 16, 30))
            self.assertEqual((data["audio_codec"], data["sample_rate"], data["channels"]), ("aac", 48000, 2))
            self.assertTrue(data["progressive"])
            self.assertTrue(data["faststart"])
            with self.assertRaises(ValueError):
                reel.validate_reel(path)


if __name__ == "__main__":
    unittest.main()
