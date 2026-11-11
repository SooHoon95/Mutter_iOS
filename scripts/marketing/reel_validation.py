"""Bounded MP4 inspection plus a SHA-bound cache of an actual browser decode.

This does NOT decode H.264/AAC in Python. The adjacent validation JSON records a
previous full Mediabunny VideoSampleSink/AudioSampleSink decode (all 450 video
frames at i/30, and all audio samples). SHA-256 binds that result to these bytes.
The cache is not a security signature: anyone able to edit both files can forge
it. It assumes a trusted producer running as the same macOS user. Structural
facts are always re-read from MP4 bytes, never inferred from decode_verified.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import struct

MAX_BYTES = 45 * 1024 * 1024
MAX_RECORD_BYTES = 64 * 1024
MAX_MOOV_BYTES = 4 * 1024 * 1024
MAX_BOXES = 10000
MAX_SAMPLES = 10000
BACKEND = "browser-webcodecs-mediabunny"
EXPECTED = {"width": 1080, "height": 1920, "fps": 30, "video_codec": "h264",
            "pixel_format": "yuv420p", "progressive": True, "audio_codec": "aac",
            "sample_rate": 48000, "channels": 2, "faststart": True, "frames": 450}


def _need(condition, message="Invalid or unsupported MP4 structure"):
    if not condition:
        raise ValueError(message)


def _read(path, limit):
    """Check size before allocation; limit the actual read even if file grows."""
    with Path(path).open("rb") as source:
        import os
        size = os.fstat(source.fileno()).st_size
        _need(0 < size <= limit, "Local validation input is empty or exceeds its size limit")
        data = source.read(limit + 1)
        _need(len(data) == size and len(data) <= limit, "Validation input changed or exceeded its size limit")
    return data


class _MP4:
    def __init__(self, data):
        self.data = data
        self.box_count = 0

    def u(self, offset, size, end):
        _need(0 <= offset and offset + size <= end <= len(self.data))
        return int.from_bytes(self.data[offset:offset + size], "big")

    def boxes(self, start, end):
        result = []
        while start < end:
            _need(end - start >= 8, "Truncated MP4 box header")
            size = self.u(start, 4, end)
            kind = self.data[start + 4:start + 8]
            header = 8
            if size == 1:
                size = self.u(start + 8, 8, end)
                header = 16
            elif size == 0:
                size = end - start
            _need(size >= header and size <= end - start, "MP4 box exceeds its parent bounds")
            self.box_count += 1
            _need(self.box_count <= MAX_BOXES, "Too many MP4 boxes")
            result.append((kind, start + header, start + size, start))
            start += size
        return result

    def one(self, boxes, kind):
        found = [box for box in boxes if box[0] == kind]
        _need(len(found) == 1, "Missing or duplicate required MP4 box")
        return found[0]

    def children(self, box, skip=0):
        return self.boxes(box[1] + skip, box[2])

    def clock(self, box):
        _, p, end, _ = box
        version = self.u(p, 1, end)
        _need(version in (0, 1))
        offset = p + (20 if version == 1 else 12)
        scale = self.u(offset, 4, end)
        duration = self.u(offset + 4, 8 if version == 1 else 4, end)
        _need(scale > 0 and duration > 0)
        return scale, duration

    def table(self, box, columns):
        _, p, end, _ = box
        _need(self.u(p, 4, end) == 0, "Unsupported sample table version or flags")
        count = self.u(p + 4, 4, end)
        _need(0 < count <= MAX_SAMPLES and p + 8 + count * columns * 4 == end)
        return [tuple(self.u(p + 8 + (i * columns + j) * 4, 4, end)
                      for j in range(columns)) for i in range(count)]

    def samples(self, stbl, scale, duration, mdats):
        stsz = self.one(stbl, b"stsz")
        _, p, end, _ = stsz
        _need(self.u(p, 4, end) == 0)
        fixed, count = self.u(p + 4, 4, end), self.u(p + 8, 4, end)
        _need(0 < count <= MAX_SAMPLES)
        _need(p + 12 + (0 if fixed else 4 * count) == end)
        sizes = [fixed] * count if fixed else [self.u(p + 12 + 4 * i, 4, end) for i in range(count)]
        _need(all(size > 0 for size in sizes), "Empty MP4 sample")
        timing = self.table(self.one(stbl, b"stts"), 2)
        _need(all(n > 0 and delta > 0 for n, delta in timing))
        _need(sum(n for n, _ in timing) == count and sum(n * delta for n, delta in timing) == duration,
              "Sample timing disagrees with sample count or media duration")
        offsets_boxes = [b for b in stbl if b[0] in (b"stco", b"co64")]
        _need(len(offsets_boxes) == 1)
        box = offsets_boxes[0]
        if box[0] == b"stco":
            offsets = [row[0] for row in self.table(box, 1)]
        else:
            _, p, end, _ = box
            n = self.u(p + 4, 4, end)
            _need(self.u(p, 4, end) == 0 and 0 < n <= MAX_SAMPLES and p + 8 + 8 * n == end)
            offsets = [self.u(p + 8 + 8 * i, 8, end) for i in range(n)]
        mapping = self.table(self.one(stbl, b"stsc"), 3)
        _need(mapping[0][0] == 1 and all(0 < first <= len(offsets) and n > 0 and desc == 1
                                        for first, n, desc in mapping))
        _need(all(mapping[i][0] < mapping[i + 1][0] for i in range(len(mapping) - 1)))
        ranges, sample, row = [], 0, 0
        for chunk, offset in enumerate(offsets, 1):
            if row + 1 < len(mapping) and chunk == mapping[row + 1][0]:
                row += 1
            n = mapping[row][1]
            _need(n <= count - sample, "Chunk sample count exceeds sample table")
            length = sum(sizes[sample:sample + n])
            _need(any(lo <= offset and offset + length <= hi for lo, hi in mdats),
                  "Sample data is outside mdat")
            ranges.append((offset, offset + length))
            sample += n
        _need(sample == count, "Sample chunks do not cover all samples")
        # Nonzero composition offsets would invalidate the recorded i/30 timeline.
        for box in stbl:
            if box[0] == b"ctts":
                rows = self.table(box, 2)
                _need(sum(n for n, _ in rows) == count and all(n > 0 and delta == 0 for n, delta in rows),
                      "Unsupported composition timestamps")
        return count, timing, ranges


class _Bits:
    def __init__(self, data):
        self.data, self.pos = data, 0

    def get(self, n):
        _need(0 <= n <= 64 and self.pos + n <= len(self.data) * 8, "Truncated codec bitstream")
        value = 0
        for _ in range(n):
            value = (value << 1) | ((self.data[self.pos // 8] >> (7 - self.pos % 8)) & 1)
            self.pos += 1
        return value

    def ue(self):
        zeros = 0
        while self.get(1) == 0:
            zeros += 1
            _need(zeros <= 31, "Oversized codec Exp-Golomb value")
        return (1 << zeros) - 1 + self.get(zeros)

    def se(self):
        value = self.ue()
        return (value + 1) // 2 if value & 1 else -(value // 2)


def _sps(nal):
    _need(len(nal) >= 4 and nal[0] & 31 == 7 and nal[0] & 128 == 0, "Invalid H.264 SPS")
    rbsp, zeros = bytearray(), 0
    for i, byte in enumerate(nal[1:]):
        if zeros >= 2 and byte == 3:
            _need(i + 2 < len(nal) and nal[i + 2] <= 3, "Invalid SPS emulation prevention")
            zeros = 0
            continue
        rbsp.append(byte)
        zeros = zeros + 1 if byte == 0 else 0
    bits = _Bits(rbsp)
    profile = bits.get(8)
    bits.get(8)
    bits.get(8)
    _need(bits.ue() <= 31)
    chroma, luma_depth, chroma_depth = 1, 8, 8
    if profile in (100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 139, 134, 135):
        chroma = bits.ue()
        _need(chroma <= 3)
        if chroma == 3:
            _need(bits.get(1) == 0, "Separate colour planes unsupported")
        luma_depth, chroma_depth = 8 + bits.ue(), 8 + bits.ue()
        bits.get(1)
        if bits.get(1):
            for i in range(8 if chroma != 3 else 12):
                if bits.get(1):
                    last = nxt = 8
                    for _ in range(16 if i < 6 else 64):
                        if nxt:
                            nxt = (last + bits.se() + 256) % 256
                        last = nxt or last
    else:
        _need(profile in (66, 77, 88), "Unsupported H.264 profile")
    _need(bits.ue() <= 12)
    poc = bits.ue()
    if poc == 0:
        _need(bits.ue() <= 12)
    elif poc == 1:
        bits.get(1)
        bits.se()
        bits.se()
        n = bits.ue()
        _need(n <= 255)
        for _ in range(n):
            bits.se()
    else:
        _need(poc == 2)
    _need(bits.ue() <= 32)
    bits.get(1)
    width, height = (bits.ue() + 1) * 16, (bits.ue() + 1) * 16
    progressive = bits.get(1) == 1
    if not progressive:
        bits.get(1)
        height *= 2
    bits.get(1)
    crop = [bits.ue() for _ in range(4)] if bits.get(1) else [0] * 4
    _need(chroma == 1 and luma_depth == chroma_depth == 8 and progressive,
          "SPS must prove progressive 8-bit 4:2:0 H.264")
    width -= 2 * (crop[0] + crop[1])
    height -= 2 * (crop[2] + crop[3])
    _need((width, height) == (1080, 1920), "SPS cropped dimensions must be 1080x1920")
    return width, height


def _avcc(data):
    _need(len(data) >= 7 and data[0] == 1 and data[4] & 3 == 3, "Unsupported AVC configuration")
    count, pos, dimensions = data[5] & 31, 6, []
    _need(count > 0)
    for _ in range(count):
        _need(pos + 2 <= len(data))
        n = int.from_bytes(data[pos:pos + 2], "big")
        pos += 2
        _need(n > 0 and pos + n <= len(data))
        dimensions.append(_sps(data[pos:pos + n]))
        pos += n
    _need(pos < len(data))
    npps, pos = data[pos], pos + 1
    _need(npps > 0)
    for _ in range(npps):
        _need(pos + 2 <= len(data))
        n = int.from_bytes(data[pos:pos + 2], "big")
        pos += 2
        _need(n > 0 and pos + n <= len(data) and data[pos] & 31 == 8)
        pos += n
    _need(all(d == dimensions[0] for d in dimensions))
    return dimensions[0]


def _descriptors(data):
    pos, result = 0, []
    while pos < len(data):
        tag, pos = data[pos], pos + 1
        length = 0
        for i in range(4):
            _need(pos < len(data), "Truncated AAC descriptor")
            byte, pos = data[pos], pos + 1
            length = (length << 7) | (byte & 127)
            if byte < 128:
                break
        else:
            raise ValueError("Oversized AAC descriptor length")
        _need(pos + length <= len(data), "AAC descriptor exceeds parent bounds")
        result.append((tag, data[pos:pos + length]))
        pos += length
    return result


def _descriptor_one(rows, tag):
    values = [data for kind, data in rows if kind == tag]
    _need(len(values) == 1, "Missing or duplicate AAC descriptor")
    return values[0]


def _aac(data):
    _need(len(data) >= 4 and data[:4] == b"\0\0\0\0")
    es = _descriptor_one(_descriptors(data[4:]), 3)
    _need(len(es) >= 3 and es[2] == 0, "Unsupported ES descriptor flags")
    config = _descriptor_one(_descriptors(es[3:]), 4)
    _need(len(config) >= 13 and config[0] == 0x40 and config[1] >> 2 == 5,
          "Audio descriptor must identify MPEG-4 AAC")
    asc = _descriptor_one(_descriptors(config[13:]), 5)
    bits = _Bits(asc)
    _need(bits.get(5) == 2, "AudioSpecificConfig must identify AAC-LC")
    frequency = bits.get(4)
    rate = bits.get(24) if frequency == 15 else (
        [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350][frequency]
        if frequency < 13 else 0)
    channels = bits.get(4)
    _need(rate == 48000 and channels == 2, "AAC config must be stereo 48kHz")
    _need(bits.get(1) == 0 and bits.get(1) == 0 and bits.get(1) == 0,
          "Unsupported AAC-LC frame configuration")


def _probe(data):
    mp4 = _MP4(data)
    top = mp4.boxes(0, len(data))
    ftyp, moov = mp4.one(top, b"ftyp"), mp4.one(top, b"moov")
    _need(ftyp[3] == 0 and ftyp[2] - ftyp[1] >= 8 and (ftyp[2] - ftyp[1]) % 4 == 0)
    brands = [data[i:i + 4] for i in [ftyp[1]] + list(range(ftyp[1] + 8, ftyp[2], 4))]
    _need(any(b in (b"isom", b"iso2", b"mp41", b"mp42", b"avc1") for b in brands), "Missing MP4 file type")
    mdats = [(b[1], b[2]) for b in top if b[0] == b"mdat"]
    _need(mdats and all(moov[3] < lo - 8 for lo, _ in mdats), "MP4 must have moov before mdat")
    _need(moov[2] - moov[1] <= MAX_MOOV_BYTES, "MP4 moov exceeds inspection limit")
    _need(not any(b[0] == b"moof" for b in top), "Fragmented MP4 unsupported")
    children = mp4.children(moov)
    movie_scale, movie_ticks = mp4.clock(mp4.one(children, b"mvhd"))
    tracks = [b for b in children if b[0] == b"trak"]
    _need(len(tracks) == 2, "Exactly one video and one audio track required")
    types, all_ranges, audio_count = [], [], 0
    for track in tracks:
        tboxes = mp4.children(track)
        _need(not any(b[0] == b"edts" for b in tboxes), "Edit lists unsupported for cached timestamps")
        tkhd = mp4.one(tboxes, b"tkhd")
        _, p, end, _ = tkhd
        version = mp4.u(p, 1, end)
        _need(version in (0, 1) and end - p == (84 if version == 0 else 96))
        dims = (mp4.u(end - 8, 4, end) / 65536, mp4.u(end - 4, 4, end) / 65536)
        matrix = data[end - 44:end - 8]
        _need(matrix == struct.pack(">9I", 65536, 0, 0, 0, 65536, 0, 0, 0, 1073741824),
              "Track transform must be unrotated identity")
        media = mp4.children(mp4.one(tboxes, b"mdia"))
        scale, ticks = mp4.clock(mp4.one(media, b"mdhd"))
        handler = mp4.one(media, b"hdlr")
        _need(handler[1] + 12 <= handler[2])
        kind = data[handler[1] + 8:handler[1] + 12]
        types.append(kind)
        stbl = mp4.children(mp4.one(mp4.children(mp4.one(media, b"minf")), b"stbl"))
        stsd = mp4.one(stbl, b"stsd")
        _need(mp4.u(stsd[1], 4, stsd[2]) == 0 and mp4.u(stsd[1] + 4, 4, stsd[2]) == 1)
        entries = mp4.children(stsd, 8)
        _need(len(entries) == 1)
        entry = entries[0]
        _, p, end, _ = entry
        count, timing, ranges = mp4.samples(stbl, scale, ticks, mdats)
        all_ranges.extend(ranges)
        if kind == b"vide":
            _need(entry[0] == b"avc1" and p + 78 <= end, "Video must be H.264 avc1")
            dimensions = (mp4.u(p + 24, 2, end), mp4.u(p + 26, 2, end))
            avcc = mp4.one(mp4.children(entry, 78), b"avcC")
            sps_dims = _avcc(data[avcc[1]:avcc[2]])
            _need(dimensions == dims == sps_dims == (1080, 1920), "Video dimensions disagree")
            _need(count == 450 and ticks == 15 * scale and all(delta * 30 == scale for _, delta in timing),
                  "Video sample table must contain 450 constant 30fps frames over 15 seconds")
        elif kind == b"soun":
            _need(entry[0] == b"mp4a" and p + 28 <= end and mp4.u(p + 8, 2, end) == 0)
            _need(mp4.u(p + 16, 2, end) == 2 and mp4.u(p + 24, 4, end) == 48000 * 65536,
                  "Audio sample entry must be stereo 48kHz")
            esds = mp4.one(mp4.children(entry, 28), b"esds")
            _aac(data[esds[1]:esds[2]])
            _need(scale == 48000 and all(delta == 1024 for _, delta in timing))
            _need(abs(ticks / scale - 15) <= .2, "Audio duration must match the reel")
            audio_count = count
        else:
            raise ValueError("Unsupported MP4 track type")
    _need(sorted(types) == [b"soun", b"vide"], "Exactly one video and one audio track required")
    all_ranges.sort()
    _need(all(all_ranges[i][1] <= all_ranges[i + 1][0] for i in range(len(all_ranges) - 1)),
          "Overlapping MP4 sample chunks")
    duration = movie_ticks / movie_scale
    _need(abs(duration - 15) <= .2, "Movie duration must match the reel")
    return {"duration": duration, **EXPECTED, "fps": 30.0, "size_bytes": len(data)}, audio_count


def _number(value):
    return type(value) in (int, float) and math.isfinite(value)


def _json_object(pairs):
    obj = {}
    for key, value in pairs:
        _need(key not in obj, "Duplicate validation record key")
        obj[key] = value
    return obj


def validate_browser_reel(path, record_path=None) -> dict:
    """Recheck physical MP4 facts and reuse a trusted previous full-decode record.

    Return the same normalized keys as render_reel.validate_reel. The record's
    duration is VIDEO duration (15s); returned duration is actual MOVIE duration,
    including the AAC tail, matching the native probe's container semantics.
    """
    path = Path(path)
    record_path = Path(record_path) if record_path is not None else path.with_suffix(".validation.json")
    try:
        data = _read(path, MAX_BYTES)
        raw_record = _read(record_path, MAX_RECORD_BYTES)
        record = json.loads(raw_record, object_pairs_hook=_json_object)
        _need(isinstance(record, dict), "Validation record must be a JSON object")
        _need(record.get("backend") == BACKEND and record.get("decode_verified") is True,
              "Missing trusted full browser-decode record")
        _need(record.get("sha256") == hashlib.sha256(data).hexdigest(), "Browser decode cache SHA-256 mismatch")
        metadata, audio_count = _probe(data)
        for key, expected in EXPECTED.items():
            value = record.get(key)
            _need(type(value) is bool if type(expected) is bool else type(value) is not bool,
                  "Invalid cached metadata type")
            _need(value == expected, "Cached browser metadata does not match physical MP4 facts")
        _need(_number(record.get("duration")) and record["duration"] == 15,
              "Cached video duration must be 15 seconds")
        _need(type(record.get("decoded_audio_samples")) is int and record["decoded_audio_samples"] == audio_count > 0,
              "Cached audio decode count does not match actual AAC samples")
        _need(type(record.get("size_bytes")) is int and record["size_bytes"] == len(data),
              "Cached file size mismatch")
        _need(_number(record.get("file_duration")) and abs(record["file_duration"] - metadata["duration"]) <= .0001,
              "Cached movie duration mismatch")
        return metadata
    except (OSError, UnicodeError, json.JSONDecodeError, RecursionError) as error:
        raise ValueError("Cannot read local media or browser validation record") from error
