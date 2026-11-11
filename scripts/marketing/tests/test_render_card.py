"""Offline unit/integration tests: python3 -m unittest discover -s scripts/marketing/tests."""
from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageFont

SCRIPT = Path(__file__).resolve().parents[1] / "render_card.py"
spec = importlib.util.spec_from_file_location("render_card", SCRIPT)
card = importlib.util.module_from_spec(spec)
spec.loader.exec_module(card)


class FixedFont:
    """Metric-only font lets layout tests run without installed Korean fonts."""
    def __init__(self, size=1):
        self.size = size

    def getbbox(self, text):
        return (0, 0, len(text) * self.size, self.size if text else 0)

    def getlength(self, text):
        return len(text) * self.size

    def getmetrics(self):
        return (self.size, 0)


def unicode_font():
    candidates = [
        card.DEFAULT_FONT,
        card.ROOT / "Projects/UIComponent/Resources/Fonts/Pretendard-Regular.ttf",
    ]
    for candidate in candidates:
        if candidate.is_file():
            try:
                card._validate_font(candidate, card.HEADER + card.FOOTER + "테스트 마음 음악 편지")
                return candidate
            except ValueError:
                continue
    return None


def sfnt_with_cmap(subtable, platform=3, encoding=1):
    cmap = struct.pack(">HHHHI", 0, 1, platform, encoding, 12) + subtable
    header = struct.pack(">IHHHH", 0x10000, 1, 16, 0, 0)
    directory = struct.pack(">4sIII", b"cmap", 0, 28, len(cmap))
    return header + directory + cmap


class WrappingTests(unittest.TestCase):
    def test_latin_words_remain_intact(self):
        self.assertEqual(card._wrap_text("hello world again", FixedFont(), 11), ["hello world", "again"])

    def test_korean_wraps_without_losing_syllables(self):
        text = "마음을전하는음악편지"
        lines = card._wrap_text(text, FixedFont(), 4)
        self.assertEqual("".join(lines), text)
        self.assertTrue(all(len(line) <= 4 for line in lines))

    def test_explicit_newlines_and_blank_lines_preserved(self):
        self.assertEqual(card._wrap_text("첫 줄\n\n둘째 줄", FixedFont(), 20), ["첫 줄", "", "둘째 줄"])

    def test_punctuation_does_not_start_new_line(self):
        lines = card._wrap_text("가나다,라마", FixedFont(), 3)
        self.assertEqual(lines, ["가나", "다,라", "마"])
        self.assertFalse(any(line.startswith(",") for line in lines))

    def test_opening_punctuation_stays_with_following_word(self):
        self.assertEqual(card._wrap_text("hi (word)", FixedFont(), 6), ["hi", "(word)"])

    def test_unbreakable_words_fail_instead_of_clipping(self):
        with self.assertRaisesRegex(ValueError, "wider"):
            card._wrap_text("unbreakable", FixedFont(), 3)

    def test_oversized_glyph_and_invalid_width_fail(self):
        with self.assertRaises(ValueError):
            card._wrap_text("가", FixedFont(5), 4)
        with self.assertRaises(ValueError):
            card._wrap_text("가", FixedFont(), 0)

    def test_fitting_shrinks_font_and_keeps_all_text(self):
        with patch.object(card, "_load_font", side_effect=lambda path, size: FixedFont(size)):
            font, lines, _, height = card._fit_text("abcdef", Path("mock"), (0, 0, 12, 10), 1, 5, 1, 0, "Title")
        self.assertEqual(font.size, 2)
        self.assertEqual(lines, ["abcdef"])
        self.assertLessEqual(height, 10)

    def test_line_limit_is_not_silently_truncated(self):
        with patch.object(card, "_load_font", side_effect=lambda path, size: FixedFont(size)):
            with self.assertRaisesRegex(ValueError, "within 4 lines"):
                card._fit_text("가\n나\n다\n라\n마", Path("mock"), (0, 0, 100, 100), 4, 2, 1, 0, "Title")

    def test_fixed_header_and_footer_cannot_clip_vertically(self):
        image = Image.new("RGB", card.CARD_SIZE)
        draw = card.ImageDraw.Draw(image)
        with patch.object(draw, "textbbox", return_value=(0, 0, 100, 200)):
            with self.assertRaisesRegex(ValueError, "card bounds"):
                card._draw_centered(draw, "footer", FixedFont(), 1220, card.GOLD)

    def test_height_limit_is_enforced(self):
        with patch.object(card, "_load_font", side_effect=lambda path, size: FixedFont(size)):
            with self.assertRaisesRegex(ValueError, "cannot fit"):
                card._fit_text("가\n나", Path("mock"), (0, 0, 100, 1), 8, 2, 1, 0, "Body")


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_empty_long_and_control_character_text_rejected(self):
        for title, body in (("", "body"), (" \n", "body"), ("x" * 501, "body"),
                            ("title", "y" * 2001), ("title", "body\x00"),
                            ("title", "body\u200d"), (None, "body")):
            with self.subTest(title=title, body=body):
                with self.assertRaises(ValueError):
                    card.render_card(title, body, self.root / "out.png", self.root / "font.otf")
        self.assertFalse((self.root / "out.png").exists())

    def test_missing_font_has_actionable_error(self):
        with self.assertRaisesRegex(ValueError, "Font file does not exist"):
            card.render_card("제목", "본문", self.root / "out.png", self.root / "missing.otf")

    def test_non_png_output_is_rejected(self):
        with self.assertRaisesRegex(ValueError, ".png"):
            card.render_card("title", "body", self.root / "out.jpg", self.root / "missing.otf")

    def test_font_cannot_be_overwritten(self):
        with self.assertRaisesRegex(ValueError, "overwrite"):
            card.render_card("title", "body", self.root / "font.png", self.root / "font.png")

    def test_malformed_font_rejected(self):
        font = self.root / "broken.otf"
        font.write_bytes(b"OTTO")
        with self.assertRaisesRegex(ValueError, "invalid or truncated"):
            card._validate_font(font, "음악")

    def test_font_size_cap(self):
        font = self.root / "large.otf"
        font.write_bytes(b"OTTO")
        with patch.object(card, "MAX_FONT_BYTES", 3):
            with self.assertRaisesRegex(ValueError, "size limit"):
                card._validate_font(font, "음악")

    def test_cmap_format4_range_offsets_and_missing_glyphs(self):
        # The first segment maps 가 through glyphIdArray plus idDelta.
        sub = struct.pack(">7H", 4, 34, 0, 4, 4, 1, 0)
        sub += struct.pack(">2H", 0xAC00, 0xFFFF) + struct.pack(">H", 0)
        sub += struct.pack(">2H", 0xAC00, 0xFFFF)
        sub += struct.pack(">2h", 2, 1) + struct.pack(">2H", 4, 0) + struct.pack(">H", 8)
        font = self.root / "synthetic.ttf"
        font.write_bytes(sfnt_with_cmap(sub))
        self.assertEqual(card._supported_codepoints(font, {0xAC00, 0xAC01, 0xFFFF}), {0xAC00})
        card._validate_font(font, "가")
        with self.assertRaisesRegex(ValueError, "U\\+AC01"):
            card._validate_font(font, "각")

    def test_cmap_format12_non_bmp_support_and_zero_glyph(self):
        sub = struct.pack(">HHIII", 12, 0, 40, 0, 2)
        sub += struct.pack(">III", 0xAC00, 0xAC01, 1)
        sub += struct.pack(">III", 0x1F600, 0x1F601, 0)
        font = self.root / "synthetic.otf"
        font.write_bytes(sfnt_with_cmap(sub, encoding=10))
        points = {0xAC00, 0xAC01, 0x1F600, 0x1F601}
        self.assertEqual(card._supported_codepoints(font, points), points - {0x1F600})

    def test_truncated_cmap_does_not_pass_validation(self):
        sub = struct.pack(">HHIII", 12, 0, 28, 0, 1)
        font = self.root / "truncated.ttf"
        font.write_bytes(sfnt_with_cmap(sub, encoding=10))
        with self.assertRaisesRegex(ValueError, "truncated"):
            card._validate_font(font, "가")

    def test_validation_includes_fixed_header_and_footer(self):
        with patch.object(card, "_validate_font", side_effect=ValueError("stop")) as validate:
            with self.assertRaisesRegex(ValueError, "stop"):
                card.render_card("title", "body", self.root / "out.png", self.root / "font.otf")
        checked = validate.call_args.args[1]
        self.assertIn(card.HEADER, checked)
        self.assertIn(card.FOOTER, checked)
        self.assertIn("title", checked)
        self.assertIn("body", checked)

    def test_cli_default_and_explicit_font_selection(self):
        for extra, expected in (([], card.DEFAULT_FONT), (["--font", "custom.otf"], Path("custom.otf"))):
            with patch.object(card, "render_card", return_value=Path("out.png")) as render:
                with redirect_stdout(io.StringIO()):
                    self.assertEqual(card.main(["--title", "title", "--body", "body", "--output", "out.png", *extra]), 0)
            self.assertEqual(render.call_args.args, ("title", "body", Path("out.png"), expected))

    def test_cli_validation_error_exits_two(self):
        stderr = io.StringIO()
        with redirect_stderr(stderr), self.assertRaises(SystemExit) as raised:
            card.main(["--title", "가", "--body", "나", "--output", str(self.root / "out.png"),
                       "--font", str(self.root / "missing.otf")])
        self.assertEqual(raised.exception.code, 2)
        self.assertIn("Font file does not exist", stderr.getvalue())


@unittest.skipUnless(unicode_font(), "No project-local Korean font; metric-only tests still run")
class KoreanIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.font = unicode_font()
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_card_dimensions_palette_and_byte_determinism(self):
        title, body = "테스트 음악 편지", "테스트 마음\n음악 편지"
        first, second = self.root / "nested/one.png", self.root / "two.png"
        self.assertEqual(card.render_card(title, body, first, self.font), first)
        card.render_card(title, body, second, self.font)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        with Image.open(first) as image:
            self.assertEqual(image.size, (1080, 1350))
            self.assertEqual(image.mode, "RGB")
            self.assertEqual(image.format, "PNG")
            self.assertEqual(image.getpixel((0, 0)), (248, 244, 234))
            self.assertEqual(image.getpixel((54, 54)), (173, 146, 96))

    def test_title_and_body_fit_real_font_without_loss(self):
        for text, box, count, largest, smallest, gap, label in (
            ("테스트 음악 편지 " * 6, card.TITLE_BOX, 4, 68, 40, 12, "Title"),
            ("테스트 마음 음악 편지 " * 14, card.BODY_BOX, 8, 40, 28, 10, "Body"),
        ):
            font, lines, line_height, height = card._fit_text(text, self.font, box, count, largest, smallest, gap, label)
            self.assertLessEqual(len(lines), count)
            self.assertLessEqual(height, box[3] - box[1])
            self.assertEqual("".join(lines).replace(" ", ""), text.replace(" ", ""))
            for line in lines:
                self.assertLessEqual(card._line_width(font, line), box[2] - box[0])
                bbox = font.getbbox(line)
                self.assertLessEqual(bbox[3] - bbox[1], line_height)

    def test_overflow_leaves_existing_file_unchanged(self):
        output = self.root / "existing.png"
        output.write_bytes(b"existing")
        for title, body in (("가\n" * 4 + "가", "테스트"), ("테스트", "가\n" * 8 + "가")):
            with self.assertRaisesRegex(ValueError, "cannot fit"):
                card.render_card(title, body, output, self.font)
            self.assertEqual(output.read_bytes(), b"existing")

    def test_unsupported_characters_fail_before_output(self):
        output = self.root / "out.png"
        with self.assertRaisesRegex(ValueError, "does not support"):
            card.render_card("테스트", "\U0001d11e", output, self.font)
        self.assertFalse(output.exists())

    def test_mocked_latin_only_coverage_is_rejected_for_korean(self):
        font_path = Path(ImageFont.truetype(str(self.font), 20).path)
        # The actual supplied font is inspected, not silently replaced with another face.
        self.assertEqual(font_path, self.font)
        with patch.object(card, "_supported_codepoints", return_value={ord("M")}):
            with self.assertRaisesRegex(ValueError, "including Korean"):
                card._validate_font(self.font, card.HEADER)


if __name__ == "__main__":
    unittest.main()
