"""Render supplied copy to a deterministic Korean music-letter card (Pillow only)."""
from __future__ import annotations

import argparse
from bisect import bisect_left, bisect_right
from pathlib import Path
import struct
import unicodedata

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_FONT = ROOT / "marketing/assets/fonts/NotoSerifCJKkr-Regular.otf"
CARD_SIZE = (1080, 1350)
HEADER = "Mutter 음악 편지"
FOOTER = "프로필 링크에서 뮤터를 만나보세요"
IVORY = "#F8F4EA"
GOLD = "#AD9260"
INK = "#51483B"
MAX_TITLE_LENGTH = 500
MAX_BODY_LENGTH = 2000
MAX_FONT_BYTES = 64 * 1024 * 1024
TITLE_BOX = (120, 280, 960, 580)
BODY_BOX = (120, 640, 960, 1080)
_CLOSING = set("、。，．！？：；)]}〉》」』】’”.,!?:;")
_OPENING = set("([{〈《「『【‘“")


def _validate_text(value: str, label: str, limit: int) -> str:
    if not isinstance(value, str):
        raise ValueError(f"{label} must be a string")
    if not value.strip():
        raise ValueError(f"{label} must not be empty")
    if len(value) > limit:
        raise ValueError(f"{label} exceeds the {limit}-character limit")
    if any(unicodedata.category(char).startswith("C") and char != "\n" for char in value):
        raise ValueError(f"{label} contains unsupported control or format characters")
    return value


def _supported_codepoints(font_path: Path, required: set[int]) -> set[int]:
    """Read Unicode cmap entries: missing glyphs can otherwise render as silent tofu."""
    if not font_path.is_file():
        raise ValueError(f"Font file does not exist: {font_path}")
    if font_path.stat().st_size > MAX_FONT_BYTES:
        raise ValueError("Font exceeds the 64 MiB size limit")
    data = font_path.read_bytes()
    try:
        sfnt = 0
        if data[:4] == b"ttcf":
            sfnt = struct.unpack_from(">I", data, 12)[0]  # Pillow uses collection face 0.
        if data[sfnt:sfnt + 4] not in (b"\x00\x01\x00\x00", b"OTTO", b"true"):
            raise ValueError("Font must be an OpenType/TrueType font with a Unicode cmap")
        table_count = struct.unpack_from(">H", data, sfnt + 4)[0]
        cmap = None
        for index in range(table_count):
            tag, _, offset, length = struct.unpack_from(">4sIII", data, sfnt + 12 + index * 16)
            if tag == b"cmap":
                if offset + length > len(data):
                    raise ValueError("Font cmap is truncated")
                cmap = data[offset:offset + length]
                break
        if cmap is None:
            raise ValueError("Font has no Unicode cmap")
        count = struct.unpack_from(">H", cmap, 2)[0]
        supported: set[int] = set()
        for index in range(count):
            platform, encoding, offset = struct.unpack_from(">HHI", cmap, 4 + index * 8)
            if platform != 0 and not (platform == 3 and encoding in (1, 10)):
                continue
            fmt = struct.unpack_from(">H", cmap, offset)[0]
            if fmt == 4:
                length, _, segment_bytes = struct.unpack_from(">HHH", cmap, offset + 2)
                sub = cmap[offset:offset + length]
                if len(sub) != length:
                    raise ValueError("Font cmap is truncated")
                segments = segment_bytes // 2
                ends = struct.unpack_from(f">{segments}H", sub, 14)
                starts = struct.unpack_from(f">{segments}H", sub, 16 + segment_bytes)
                deltas = struct.unpack_from(f">{segments}h", sub, 16 + 2 * segment_bytes)
                range_base = 16 + 3 * segment_bytes
                ranges = struct.unpack_from(f">{segments}H", sub, range_base)
                for point in required - supported:
                    if point > 0xFFFF:
                        continue
                    segment = bisect_left(ends, point)
                    if segment == segments or point < starts[segment]:
                        continue
                    if ranges[segment] == 0:
                        glyph = (point + deltas[segment]) & 0xFFFF
                    else:
                        address = range_base + segment * 2 + ranges[segment] + 2 * (point - starts[segment])
                        glyph = struct.unpack_from(">H", sub, address)[0]
                        if glyph:
                            glyph = (glyph + deltas[segment]) & 0xFFFF
                    if glyph:
                        supported.add(point)
            elif fmt in (12, 13):
                length = struct.unpack_from(">I", cmap, offset + 4)[0]
                sub = cmap[offset:offset + length]
                if len(sub) != length:
                    raise ValueError("Font cmap is truncated")
                groups = struct.unpack_from(">I", sub, 12)[0]
                entries = [struct.unpack_from(">III", sub, 16 + group * 12) for group in range(groups)]
                starts = [entry[0] for entry in entries]
                for point in required - supported:
                    group = bisect_right(starts, point) - 1
                    if group >= 0:
                        start, end, glyph = entries[group]
                        if point <= end and (glyph if fmt == 13 else glyph + point - start):
                            supported.add(point)
        return supported
    except (struct.error, IndexError, OverflowError) as error:
        raise ValueError("Font has an invalid or truncated Unicode cmap") from error


def _validate_font(font_path: Path, text: str) -> None:
    required = {ord(char) for char in text if not char.isspace()}
    missing = required - _supported_codepoints(font_path, required)
    if missing:
        sample = ", ".join(f"U+{point:04X}" for point in sorted(missing)[:8])
        raise ValueError(f"Font does not support all supplied text (including Korean): {sample}")


def _load_font(font_path: Path, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(str(font_path), size, layout_engine=ImageFont.Layout.BASIC)
    except (OSError, ValueError) as error:
        raise ValueError(f"Cannot load font: {font_path}") from error


def _tokens(paragraph: str) -> list[str]:
    """Keep Latin words intact; Korean/CJK may break between syllables, not punctuation."""
    tokens: list[str] = []
    pending = ""
    for char in paragraph:
        if char.isspace():
            if pending:
                tokens.append(pending)
                pending = ""
            if tokens and tokens[-1] != " ":
                tokens.append(" ")
        elif unicodedata.east_asian_width(char) in ("W", "F") or char in _OPENING | _CLOSING:
            if pending:
                tokens.append(pending)
                pending = ""
            if char in _CLOSING and tokens and tokens[-1] != " ":
                tokens[-1] += char
            elif tokens and tokens[-1][-1] in _OPENING:
                tokens[-1] += char
            else:
                tokens.append(char)
        else:
            if tokens and tokens[-1][-1] in _OPENING:
                pending = tokens.pop() + char
            else:
                pending += char
    if pending:
        tokens.append(pending)
    return tokens


def _line_width(font: ImageFont.FreeTypeFont, text: str) -> float:
    left, _, right, _ = font.getbbox(text)
    return max(float(right - left), font.getlength(text))


def _wrap_text(text: str, font: ImageFont.FreeTypeFont, width: int) -> list[str]:
    if width <= 0:
        raise ValueError("Text width must be positive")
    lines: list[str] = []
    for paragraph in text.split("\n"):
        current = ""
        for token in _tokens(paragraph):
            if token == " " and not current:
                continue
            if _line_width(font, current + token) <= width:
                current += token
                continue
            if current.strip():
                lines.append(current.rstrip())
                current = ""
            if token == " ":
                continue
            if _line_width(font, token) > width:
                # Never silently clip an unbreakable word or a glyph.
                raise ValueError("A word or glyph is wider than the text area")
            current = token
        lines.append(current.rstrip())
    return lines


def _fit_text(text: str, font_path: Path, box: tuple[int, int, int, int],
              max_lines: int, largest: int, smallest: int, gap: int, label: str):
    width, height = box[2] - box[0], box[3] - box[1]
    for size in range(largest, smallest - 1, -1):
        font = _load_font(font_path, size)
        try:
            lines = _wrap_text(text, font, width)
        except ValueError:
            continue
        ascent, descent = font.getmetrics()
        line_height = max(ascent + descent, *(font.getbbox(line)[3] - font.getbbox(line)[1] for line in lines))
        block_height = len(lines) * line_height + (len(lines) - 1) * gap
        if len(lines) <= max_lines and block_height <= height:
            return font, lines, line_height, block_height
    raise ValueError(f"{label} cannot fit within {max_lines} lines; shorten the supplied text")


def _draw_centered(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont,
                   top: float, color: str, left: int = 120, right: int = 960) -> None:
    x0, y0, x1, y1 = draw.textbbox((0, 0), text, font=font)
    if x1 - x0 > right - left or top < 0 or top + y1 - y0 > CARD_SIZE[1]:
        raise ValueError("Text exceeds card bounds")
    draw.text(((left + right - (x1 - x0)) / 2 - x0, top - y0), text, font=font, fill=color)


def render_card(title: str, body: str, output: Path, font_path: Path) -> Path:
    """Write a 1080x1350 RGB PNG, or fail before writing if copy/font cannot fit."""
    title = _validate_text(title, "Title", MAX_TITLE_LENGTH)
    body = _validate_text(body, "Body", MAX_BODY_LENGTH)
    output, font_path = Path(output), Path(font_path)
    if output.suffix.lower() != ".png":
        raise ValueError("Output must have a .png extension")
    if output.resolve() == font_path.resolve():
        raise ValueError("Output must not overwrite the supplied font")
    _validate_font(font_path, HEADER + FOOTER + title + body)
    title_layout = _fit_text(title, font_path, TITLE_BOX, 4, 68, 40, 12, "Title")
    body_layout = _fit_text(body, font_path, BODY_BOX, 8, 40, 28, 10, "Body")
    image = Image.new("RGB", CARD_SIZE, IVORY)
    draw = ImageDraw.Draw(image)
    draw.rectangle((54, 54, 1025, 1295), outline=GOLD, width=2)
    draw.line((450, 216, 630, 216), fill=GOLD, width=2)
    draw.line((450, 1160, 630, 1160), fill=GOLD, width=2)
    _draw_centered(draw, HEADER, _load_font(font_path, 32), 144, GOLD)
    for box, layout, gap in ((TITLE_BOX, title_layout, 12), (BODY_BOX, body_layout, 10)):
        font, lines, line_height, block_height = layout
        top = box[1] + (box[3] - box[1] - block_height) / 2
        for line in lines:
            _draw_centered(draw, line, font, top, INK, box[0], box[2])
            top += line_height + gap
    _draw_centered(draw, FOOTER, _load_font(font_path, 26), 1220, GOLD)
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output, format="PNG", optimize=False, compress_level=9)
    return output


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--title", required=True, help="Supplied title (max 500 characters)")
    parser.add_argument("--body", required=True, help="Supplied body (max 2000 characters)")
    parser.add_argument("--output", required=True, type=Path, help="Destination .png")
    parser.add_argument("--font", type=Path, default=DEFAULT_FONT, help="Korean-capable OpenType/TrueType font")
    args = parser.parse_args(argv)
    try:
        result = render_card(args.title, args.body, args.output, args.font)
    except (ValueError, OSError) as error:
        parser.exit(2, f"ERROR: {error}\n")
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
