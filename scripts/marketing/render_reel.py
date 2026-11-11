"""Offline, fixed-copy 15-second muted music-letter reel. No app UI or music assets."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import random
import re
import struct
import subprocess
import tempfile
import threading

from PIL import Image, ImageDraw, ImageFilter

try:
    from .render_card import DEFAULT_FONT, _fit_text, _load_font, _validate_font
except ImportError:  # Direct CLI execution.
    from render_card import DEFAULT_FONT, _fit_text, _load_font, _validate_font

SIZE = (1080, 1920)
DURATION = 15
FPS = 30
MAX_BYTES = 45 * 1024 * 1024
PROCESS_TIMEOUT = 480
IVORY = "#FFFDF2"
INK = "#221D14"
MAUVE = "#C77BAE"
HEADER = "@mu_sic_letter"
SAFE_BOX = (100, 270, 980, 1570)
# Fixed preview copy. The bus/bakery lines are invented examples, not user testimony.
SCENES = (
    (0, 3, "첫 줄은\n오늘 있었던 일로"),
    (3, 7, "오늘 버스를 기다리다가\n네가 알려 준 빵집을 봤어."),
    (7, 10, "다음엔 같이 가고 싶어."),
    (10, 13, "짧은 편지에\n노래 한 곡을 담아요."),
    (13, 15, "뮤터 · 음악 편지\n프로필 링크에서"),
)
FADE = 0.36  # Half-width of a smooth crossfade at each boundary.


def _ffmpeg() -> str:
    # Optional locally staged wheel binary supports a Pillow-only production venv.
    import os
    local = DEFAULT_FONT.parents[0].parent / "bin/ffmpeg"
    if local.is_file() and os.access(local, os.X_OK):
        return str(local.resolve())
    # The platform-specific wheel bundles one binary. Locate it without invoking
    # imageio's unbounded `ffmpeg -version` discovery or leaving a helper child.
    try:
        import imageio_ffmpeg
        folder = Path(imageio_ffmpeg.__file__).resolve().parent / "binaries"
        candidates = [file for file in folder.glob("ffmpeg-*") if file.is_file() and os.access(file, os.X_OK)]
    except ImportError:
        candidates = []
    if len(candidates) != 1:
        raise ValueError("Install imageio-ffmpeg==0.6.0 or stage an executable at marketing/assets/bin/ffmpeg; local FFmpeg is required")
    return str(candidates[0].resolve())


def _ease(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def _weights(t: float) -> list[float]:
    weights = []
    for start, end, _ in SCENES:
        incoming = 1.0 if start == 0 else _ease((t - start + FADE) / (2 * FADE))
        outgoing = 1.0 if end == DURATION else 1 - _ease((t - end + FADE) / (2 * FADE))
        weights.append(min(incoming, outgoing))
    return weights


def _paper() -> Image.Image:
    """Stable seeded fiber grain and soft window light, with extra dolly margins."""
    rng = random.Random(20261011)
    size = (1120, 1960)
    grain = Image.frombytes("L", (280, 490), bytes(rng.randrange(228, 256) for _ in range(280 * 490)))
    grain = grain.resize(size, Image.Resampling.BICUBIC)
    base = Image.new("RGB", size, IVORY)
    tint = Image.new("RGB", size, "#E7DFD2")
    base = Image.composite(base, tint, grain)
    light = Image.new("L", (280, 490), 0)
    draw = ImageDraw.Draw(light)
    draw.polygon([(-50, 20), (210, -20), (340, 330), (90, 390)], fill=36)
    light = light.filter(ImageFilter.GaussianBlur(38)).resize(size, Image.Resampling.BICUBIC)
    return Image.composite(Image.new("RGB", size, "#F0E7DA"), base, light)


def _text_sprite(text: str, font_path: Path, largest: int, width: int = 850):
    font, lines, line_height, height = _fit_text(
        text, font_path, (0, 0, width, 450), 2, largest, 40, 26, "Reel copy")
    # Preserve the approved line breaks, rather than inserting an unexpected third line.
    if lines != text.split("\n"):
        raise ValueError("Reel copy must fit its approved line breaks; use the bundled Korean serif font")
    sprite = Image.new("RGBA", (width + 16, height + 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(sprite)
    top = 8
    for line in lines:
        x0, y0, x1, y1 = draw.textbbox((0, 0), line, font=font)
        draw.text(((sprite.width - x1 + x0) / 2 - x0, top - y0), line, font=font, fill=INK)
        top += line_height + 26
    bounds = sprite.getbbox()
    if bounds is None or bounds[0] < 8 or bounds[2] > sprite.width - 8:
        raise ValueError("Reel text would clip horizontally")
    return sprite


def _prepare(font_path: Path):
    _validate_font(font_path, HEADER + "".join(scene[2] for scene in SCENES))
    sprites = [_text_sprite(text, font_path, size) for (_, _, text), size in zip(SCENES, (74, 58, 62, 68, 68))]
    header = Image.new("RGBA", (600, 70))
    draw = ImageDraw.Draw(header)
    font = _load_font(font_path, 26)
    draw.text((300, 6), HEADER, font=font, fill=INK, anchor="mt")
    return _paper(), sprites, header


def _paste(image: Image.Image, sprite: Image.Image, xy: tuple[int, int], opacity: float = 1):
    if opacity <= 0:
        return
    alpha = sprite.getchannel("A")
    if opacity < 1:
        alpha = alpha.point([round(value * opacity) for value in range(256)])
    image.paste(sprite, xy, alpha)


def _frame(t: float, prepared) -> Image.Image:
    paper, sprites, header = prepared
    # A 10px dolly drift across 15s, not simulated screenshots or fast camera motion.
    x = round(20 + 7 * math.sin(t / 15 * math.pi))
    y = round(20 + 9 * _ease(t / 15))
    frame = paper.crop((x, y, x + SIZE[0], y + SIZE[1]))
    _paste(frame, header, (240, 330))
    draw = ImageDraw.Draw(frame)
    draw.line((496, 492, 584, 492), fill=MAUVE, width=2)
    weights = _weights(t)
    for index, ((start, end, _), sprite, weight) in enumerate(zip(SCENES, sprites, weights)):
        if weight <= 0:
            continue
        progress = _ease((t - start) / (end - start))
        top = round(905 - sprite.height / 2 + 10 * (1 - progress))
        left = (SIZE[0] - sprite.width) // 2
        bounds = sprite.getbbox()
        if not (SAFE_BOX[0] <= left + bounds[0] and left + bounds[2] <= SAFE_BOX[2]
                and SAFE_BOX[1] <= top + bounds[1] and top + bounds[3] <= SAFE_BOX[3]):
            raise ValueError("Animated text exceeds reel safe zones")
        _paste(frame, sprite, (left, top), weight)
    # Abstract score lines, not player controls, buttons, app chrome, or real UI.
    waves = Image.new("RGBA", (640, 150))
    wave_draw = ImageDraw.Draw(waves)
    for line in range(3):
        points = [(px, round(48 + line * 26 + 6 * math.sin(px / 85 + t / 3 + line))) for px in range(10, 631, 4)]
        wave_draw.line(points, fill=MAUVE, width=2)
    _paste(frame, waves, (220, 1190), 0.28 + 0.4 * weights[3])
    return frame


def _run(args: list[str], timeout: int) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, timeout=timeout, check=False)
    except (subprocess.TimeoutExpired, OSError) as error:
        raise ValueError("Local media inspection failed or timed out") from error


def _parse_metadata(stderr: str) -> dict:
    """Parse only known FFmpeg header fields; never echo arbitrary file metadata."""
    duration = re.search(r"Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)", stderr)
    videos = re.findall(r"^\s*Stream #[^\n]*: Video: ([^\n]+)", stderr, re.M)
    audios = re.findall(r"^\s*Stream #[^\n]*: Audio: ([^\n]+)", stderr, re.M)
    if not duration or len(videos) != 1 or len(audios) != 1:
        raise ValueError("Media must contain exactly one video stream and one audio stream with a known duration")
    video, audio = videos[0], audios[0]
    dimensions = re.search(r"(?:^|[, ])(\d+)x(\d+)(?:[, \[])" , video)
    fps = re.search(r"(?:^|,\s*)(\d+(?:\.\d+)?)\s+fps\b", video)
    sample_rate = re.search(r"\b(\d+) Hz\b", audio)
    if not dimensions or not fps or not sample_rate:
        raise ValueError("Media stream dimensions, frame rate, or sample rate could not be verified")
    return {"duration": int(duration[1]) * 3600 + int(duration[2]) * 60 + float(duration[3]),
            "width": int(dimensions[1]), "height": int(dimensions[2]), "fps": float(fps[1]),
            "video_codec": video.split()[0], "pixel_format": "yuv420p" if re.search(r"\byuv420p\b", video) else "unknown",
            "progressive": bool(re.search(r"\bprogressive\b", video)),
            "audio_codec": audio.split()[0], "sample_rate": int(sample_rate[1]),
            "channels": 2 if re.search(r"\bstereo\b", audio) else 0}


def _faststart(path: Path) -> bool:
    """Inspect real top-level MP4 atoms, not a filename or encoder assertion."""
    moov = mdat = None
    with path.open("rb") as source:
        end = path.stat().st_size
        while source.tell() + 8 <= end:
            offset = source.tell()
            length, kind = struct.unpack(">I4s", source.read(8))
            header = 8
            if length == 1:
                data = source.read(8)
                if len(data) != 8:
                    return False
                length = struct.unpack(">Q", data)[0]
                header = 16
            elif length == 0:
                length = end - offset
            if length < header or offset + length > end:
                return False
            if kind == b"moov":
                moov = offset
            if kind == b"mdat":
                mdat = offset
            source.seek(offset + length)
    return moov is not None and mdat is not None and moov < mdat


def metadata_probe(path: Path) -> dict:
    path = Path(path).resolve()
    if path.with_suffix('.validation.json').is_file():
        from reel_validation import validate_browser_reel
        return validate_browser_reel(path)
    if not path.is_file() or not 0 < path.stat().st_size <= MAX_BYTES:
        raise ValueError("Media must be a nonempty local file no larger than 45 MiB")
    result = _run([_ffmpeg(), "-hide_banner", "-nostdin", "-protocol_whitelist", "file,pipe", "-f", "mov", "-i", str(path)], 20)
    metadata = _parse_metadata(result.stderr.decode("utf-8", errors="replace"))
    metadata.update(size_bytes=path.stat().st_size, faststart=_faststart(path))
    return metadata


def validate_reel(path: Path) -> dict:
    if Path(path).with_suffix('.validation.json').is_file():
        from reel_validation import validate_browser_reel
        return validate_browser_reel(path)
    metadata = metadata_probe(path)
    expected = {"width": 1080, "height": 1920, "fps": 30, "video_codec": "h264",
                "pixel_format": "yuv420p", "progressive": True, "audio_codec": "aac",
                "sample_rate": 48000, "channels": 2, "faststart": True}
    if any(metadata[key] != value for key, value in expected.items()) or abs(metadata["duration"] - 15) > .2:
        raise ValueError("Reel must be 1080x1920, 30fps, 15s progressive H.264/yuv420p with faststart and stereo AAC 48kHz")
    # Decode real frames. Duration * fps is not evidence of an actual 450-frame file.
    result = _run([_ffmpeg(), "-v", "error", "-nostdin", "-threads", "2", "-protocol_whitelist", "file,pipe", "-f", "mov", "-i", str(Path(path).resolve()),
                   "-map", "0:v:0", "-an", "-fps_mode", "passthrough", "-progress", "pipe:1", "-f", "null", "-"], 120)
    frames = re.findall(rb"(?m)^frame=(\d+)\s*$", result.stdout)
    if result.returncode != 0 or result.stderr.strip() or not frames or int(frames[-1]) != 450:
        raise ValueError("Reel must decode cleanly to exactly 450 frames")
    metadata["frames"] = int(frames[-1])
    return metadata


def render_reel(output: Path, font_path: Path = DEFAULT_FONT, duration=15, fps=30) -> Path:
    """Write the approved deterministic preview atomically; refuses existing outputs."""
    if duration != DURATION or fps != FPS:
        raise ValueError("This fixed approved preview requires duration=15 and fps=30")
    output, font_path = Path(output), Path(font_path)
    if output.suffix.lower() != ".mp4":
        raise ValueError("Output must have a .mp4 extension")
    if output.exists():
        raise ValueError("Output already exists; select a new filename")
    if not font_path.is_file():
        raise ValueError(f"Missing Korean serif font: {font_path}. Supply --font pointing to local NotoSerifCJKkr-Regular.otf")
    prepared = _prepare(font_path)
    binary = _ffmpeg()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".reel-", dir=output.parent) as directory:
        staged = Path(directory) / "preview.mp4"
        args = [binary, "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
                "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "1080x1920", "-r", "30", "-i", "pipe:0",
                "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-map", "0:v:0", "-map", "1:a:0",
                "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-threads", "2",
                "-maxrate", "25M", "-bufsize", "50M", "-g", "60", "-flags", "+cgop",
                "-pix_fmt", "yuv420p", "-field_order", "progressive", "-r", "30",
                "-frames:v", "450", "-t", "15", "-c:a", "aac", "-b:a", "128k", "-ar", "48000", "-ac", "2",
                "-map_metadata", "-1", "-movflags", "+faststart", "-use_editlist", "0", str(staged)]
        with (Path(directory) / "encoder.log").open("wb") as log:
            try:
                process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=log)
            except OSError as error:
                raise ValueError("Cannot start local FFmpeg encoder") from error
            expired = threading.Event()
            def stop():
                expired.set()
                process.kill()
            timer = threading.Timer(PROCESS_TIMEOUT, stop)
            timer.daemon = True
            timer.start()
            try:
                for index in range(450):
                    if expired.is_set():
                        raise ValueError("Reel rendering exceeded the 480-second timeout")
                    process.stdin.write(_frame(index / FPS, prepared).tobytes())
                process.stdin.close()
                process.wait(timeout=PROCESS_TIMEOUT)
                if expired.is_set() or process.returncode:
                    raise ValueError("Local FFmpeg encoding failed or timed out")
            except (OSError, subprocess.TimeoutExpired) as error:
                raise ValueError("Local FFmpeg encoding failed or timed out") from error
            finally:
                timer.cancel()
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=10)
                if not process.stdin.closed:
                    process.stdin.close()
        validate_reel(staged)
        # Exclusive creation protects against a concurrent job taking this name.
        import os
        os.link(staged, output)
    return output


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--output", type=Path, help="New destination .mp4 (muted preview)")
    mode.add_argument("--probe", type=Path, help="Validate an existing local reel and print metadata")
    parser.add_argument("--font", type=Path, default=DEFAULT_FONT)
    args = parser.parse_args(argv)
    try:
        if args.probe:
            print(json.dumps(validate_reel(args.probe), sort_keys=True))
        else:
            print(render_reel(args.output, args.font))
    except (ValueError, OSError) as error:
        parser.exit(2, f"ERROR: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
