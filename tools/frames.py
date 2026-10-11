# Copyright (C) 2026 the Megarocket contributors; adapted from the Sidescroller Recomps
# project (Copyright (C) 2026 its contributors), GPL v2 or later. See LICENSE.md.
"""A frame sequence store shared by the oracle side and the port side.

A sequence is the list of DISTINCT consecutive 320x200 RGB frames, each with
the number of display refreshes it stayed on screen. On disk it is a folder
holding `frames.bin` (zlib-compressed RGB frames back to back) and
`frames.json` (offset, size, repeat count and SHA-1 of each frame).
"""

import hashlib
import json
import subprocess
import zlib
from pathlib import Path

import numpy as np

WIDTH = 320
HEIGHT = 200
FRAME_BYTES = WIDTH * HEIGHT * 3


class Writer:
    def __init__(self, folder, width=WIDTH, height=HEIGHT):
        self.folder = Path(folder)
        self.folder.mkdir(parents=True, exist_ok=True)
        self.bin = open(self.folder / "frames.bin", "wb")
        self.index = []
        self.offset = 0
        self.last = None
        self.raw_count = 0
        self.width, self.height = width, height     # (another size: a text-mode capture, HARN-06)

    def add(self, rgb_bytes):
        """Add one displayed frame; consecutive identical frames are merged."""
        self.raw_count += 1
        digest = hashlib.sha1(rgb_bytes).hexdigest()
        if digest == self.last:
            self.index[-1][2] += 1
            return
        blob = zlib.compress(rgb_bytes, 1)
        self.bin.write(blob)
        self.index.append([self.offset, len(blob), 1, digest])
        self.offset += len(blob)
        self.last = digest

    def close(self, meta=None):
        self.bin.close()
        doc = {"width": self.width, "height": self.height, "raw_frames": self.raw_count,
               "frames": self.index, "meta": meta or {}}
        (self.folder / "frames.json").write_text(json.dumps(doc), encoding="ascii")
        return len(self.index)


def as_rgb565(picture):
    """The picture as it comes out of a 16-bit recording: five bits of red and
    blue, six of green, widened back to eight by repeating the top bits.

    DOSBox records the 256-colour mode in that format, so a picture of the
    port's can only be compared with such a recording after the same loss.
    """
    out = picture.copy()
    for channel, bits in ((0, 5), (1, 6), (2, 5)):
        value = out[:, :, channel] >> (8 - bits)
        out[:, :, channel] = (value << (8 - bits)) | (value >> (2 * bits - 8))
    return out


class Sequence:
    def __init__(self, folder, rgb565=False):
        self.folder = Path(folder)
        self.rgb565 = rgb565
        doc = json.loads((self.folder / "frames.json").read_text(encoding="ascii"))
        self.index = doc["frames"]
        self.raw_frames = doc["raw_frames"]
        # "indexed": each stored picture is 64000 palette indices followed by
        # the palette as RGB triples. The port writes these.
        self.indexed = doc.get("format", "rgb") == "indexed"
        self.width, self.height = doc.get("width", WIDTH), doc.get("height", HEIGHT)
        self._rgb_digests = {}
        self.meta = doc.get("meta", {})
        self._bin = open(self.folder / "frames.bin", "rb")

    def __len__(self):
        return len(self.index)

    def digest(self, i):
        """SHA-1 of the picture's RGB bytes, whichever way it is stored."""
        if not self.indexed and not self.rgb565:
            return self.index[i][3]
        if i not in self._rgb_digests:
            self._rgb_digests[i] = hashlib.sha1(self.frame(i).tobytes()).hexdigest()
        return self._rgb_digests[i]

    def repeats(self, i):
        return self.index[i][2]

    def frame(self, i):
        offset, size, _, _ = self.index[i]
        self._bin.seek(offset)
        raw = zlib.decompress(self._bin.read(size))
        # an indexed store can hold whole RGB pictures too (a palette changed while the frame was
        # scanned, so no one palette describes it): told apart by their size
        if self.indexed and len(raw) != WIDTH * HEIGHT * 3:
            pixels = WIDTH * HEIGHT
            indices = np.frombuffer(raw[:pixels], dtype=np.uint8)
            palette = np.frombuffer(raw[pixels:], dtype=np.uint8).reshape(-1, 3)
            picture = np.ascontiguousarray(palette[indices].reshape(HEIGHT, WIDTH, 3))
        else:
            picture = np.frombuffer(raw, dtype=np.uint8).reshape(self.height, self.width, 3)
        return as_rgb565(picture) if self.rgb565 else picture

    def digests(self):
        return [self.digest(i) for i in range(len(self.index))]


def damaged(folder):
    """Check a frame store written by the port against its own index: every
    picture must unpack, and (for a store of full-colour pictures) hash to the
    value noted when it was written. Returns a description of the first thing
    wrong, or "" if the store is sound.

    Twice on 2026-10-01 a store written seconds earlier had one picture whose
    bytes no longer unpacked. The cause was not found (the disks report
    healthy); callers run the port again when this says so, and note it.
    """
    folder = Path(folder)
    try:
        doc = json.loads((folder / "frames.json").read_text(encoding="ascii"))
        data = (folder / "frames.bin").read_bytes()
    except (OSError, ValueError) as error:
        return f"the store cannot be read ({error})"
    for i, (offset, size, _, digest) in enumerate(doc["frames"]):
        try:
            raw = zlib.decompress(data[offset:offset + size])
        except zlib.error as error:
            return f"picture {i} of {len(doc['frames'])} does not unpack ({error})"
        if hashlib.sha1(raw).hexdigest() != digest:
            return f"picture {i} of {len(doc['frames'])} is not the picture that was written"
    return ""


def from_video(video, folder, meta=None):
    """Decode a DOSBox capture into a sequence. Returns the number of distinct frames."""
    return from_videos([video], folder, meta)


def from_videos(videos, folder, meta=None, skip_other_sizes=False, text_folder=None):
    """Decode several captures, in order, into one sequence. With `skip_other_sizes` a capture of another
    size is left out (DOSBox 0.83 starts a new file at a mode change: the text-mode start-up's, HARN-22);
    with `text_folder` too, those (text mode's 720x400 or 640x400) go there, in order, as a sequence of
    their own size (HARN-06: the text screens a game shows on starting or quitting)."""
    writer = Writer(folder)
    text_writer = None
    text_parts = []
    for video in videos:
        probe = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
             "stream=width,height", "-of", "csv=p=0", str(video)],
            capture_output=True, text=True, check=True)
        width, height = (int(x) for x in probe.stdout.strip().split(",")[:2])
        # an older capture at twice the size (DOSBox's normal2x): every 2x2 block must be one
        # colour, which is checked, so halving it loses nothing
        double = (width, height) == (2 * WIDTH, 2 * HEIGHT)
        if (width, height) != (WIDTH, HEIGHT) and not double and skip_other_sizes:
            if text_folder is not None and height == 400 and width in (640, 720):
                if text_writer is None:
                    text_writer = Writer(text_folder, width, height)
                if (width, height) == (text_writer.width, text_writer.height):
                    # each capture's pictures apart from the last one's (the EGA ones lie between), and
                    # [file, its first refresh, refreshes, the EGA refreshes recorded before it]
                    text_writer.last = None
                    before = text_writer.raw_count
                    _decode_into(video, text_writer, width * height * 3)
                    text_parts.append([video.name, before, text_writer.raw_count - before, writer.raw_count])
            continue
        if (width, height) != (WIDTH, HEIGHT) and not double:
            raise ValueError(f"{video}: expected {WIDTH}x{HEIGHT}, got {width}x{height}")
        proc = subprocess.Popen(
            ["ffmpeg", "-v", "error", "-i", str(video), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
            stdout=subprocess.PIPE)
        size = FRAME_BYTES * (4 if double else 1)
        while True:
            raw = proc.stdout.read(size)
            if len(raw) < size:
                break
            if double:
                import numpy as np
                a = np.frombuffer(raw, np.uint8).reshape(2 * HEIGHT, 2 * WIDTH, 3)
                h = a[::2, ::2]
                if not (np.array_equal(h, a[1::2, ::2]) and np.array_equal(h, a[::2, 1::2]) and np.array_equal(h, a[1::2, 1::2])):
                    raise ValueError(f"{video}: a doubled picture whose 2x2 blocks are not one colour")
                raw = np.ascontiguousarray(h).tobytes()
            writer.add(raw)
        proc.wait()
        if proc.returncode != 0:
            raise RuntimeError(f"ffmpeg failed on {video}")
    if text_writer is not None:
        text_writer.close(dict(meta or {}, parts=text_parts))
    return writer.close(meta)


def _decode_into(video, writer, size):
    """Every picture of one capture into `writer`, as recorded."""
    proc = subprocess.Popen(["ffmpeg", "-v", "error", "-i", str(video), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                            stdout=subprocess.PIPE)
    while True:
        raw = proc.stdout.read(size)
        if len(raw) < size:
            break
        writer.add(raw)
    proc.wait()
    if proc.returncode != 0:
        raise RuntimeError(f"ffmpeg failed on {video}")
