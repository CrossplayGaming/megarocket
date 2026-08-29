#!/usr/bin/env python3
"""Generate Megarocket's Android launcher icon set.

Original pixel art (no game data): a chunky EGA-palette rocket over the
launcher's starfield, nearest-neighbour scaled so the pixels stay hard.
Outputs adaptive-icon layers plus legacy square icons for every density.

    python android/make-icon.py
"""

import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "megarocket", "src", "main", "res")

# EGA palette entries used
EGA = {
    "K": (0, 0, 0, 255),         # black outline
    "W": (255, 255, 255, 255),   # white
    "G": (170, 170, 170, 255),   # light grey
    "g": (85, 85, 85, 255),      # dark grey
    "R": (255, 85, 85, 255),     # light red
    "D": (170, 0, 0, 255),       # red
    "C": (85, 255, 255, 255),    # light cyan
    "B": (0, 0, 170, 255),       # blue
    "Y": (255, 255, 85, 255),    # yellow
    ".": (0, 0, 0, 0),           # transparent
}

# 17 x 26 rocket, straight up, black-outlined so it reads on anything
ROCKET = [
    "........K........",
    ".......KRK.......",
    ".......KRK.......",
    "......KRRDK......",
    "......KRRDK......",
    ".....KRRRDDK.....",
    ".....KWWWWWK.....",
    ".....KWWWWGK.....",
    "....KWWWWWWGK....",
    "....KWKKKKKGK....",
    "....KWKCCBKGK....",
    "....KWKCBBKGK....",
    "....KWKKKKKGK....",
    "....KWWWWWWGK....",
    "....KWWWWWWGK....",
    "...KDWWWWWWGDK...",
    "..KDDWWWWWWGDDK..",
    ".KDRDWWWWWWGDRDK.",
    ".KDRDWWWWWWGDRDK.",
    ".KDRKWWWWWWGKRDK.",
    ".KDKKGGGGGGGKKDK.",
    ".KKK.KKKKKKK.KKK.",
    ".....KYYYYYK.....",
    "......KYRYK......",
    "......KYRYK......",
    ".......KYK.......",
    "........K........",
]

# star positions (x, y, bright) on a 27x27 field, echoing the launcher
STARS = [
    (2, 3, 1), (7, 1, 0), (12, 4, 0), (18, 2, 1), (24, 5, 0),
    (1, 10, 0), (5, 14, 1), (3, 20, 0), (8, 24, 0), (13, 22, 1),
    (20, 25, 0), (24, 19, 1), (25, 12, 0), (21, 9, 0), (16, 6, 0),
    (10, 8, 1), (23, 23, 0), (6, 6, 0), (15, 25, 0), (2, 25, 1),
]

BG_TOP = (5, 5, 24, 255)      # near-black navy, like the shell
STAR_DIM = (85, 170, 170, 255)
STAR_BRIGHT = (170, 255, 255, 255)


def draw_grid(rows):
    h = len(rows)
    w = len(rows[0])
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            im.putpixel((x, y), EGA[ch])
    return im


def starfield(size_px, cell):
    im = Image.new("RGBA", (size_px, size_px), BG_TOP)
    for (sx, sy, bright) in STARS:
        px, py = sx * cell // 1, sy * cell // 1
        c = STAR_BRIGHT if bright else STAR_DIM
        for dx in range(cell // 3):
            for dy in range(cell // 3):
                if px + dx < size_px and py + dy < size_px:
                    im.putpixel((px + dx, py + dy), c)
    return im


def scaled(im, factor):
    return im.resize((im.width * factor, im.height * factor), Image.NEAREST)


def main():
    rocket = draw_grid(ROCKET)

    # ---- adaptive layers: 432x432, content within the centre ~66% ----
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    r = scaled(rocket, 9)  # 153 x 234
    fg.alpha_composite(r, ((432 - r.width) // 2, (432 - r.height) // 2))
    bg = starfield(432, 16)

    v26 = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(v26, exist_ok=True)
    for dens, size in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216),
                       ("xxhdpi", 324), ("xxxhdpi", 432)]:
        d = os.path.join(RES, "mipmap-" + dens)
        os.makedirs(d, exist_ok=True)
        fg.resize((size, size), Image.NEAREST).save(
            os.path.join(d, "ic_launcher_foreground.png"))
        bg.resize((size, size), Image.NEAREST).save(
            os.path.join(d, "ic_launcher_background.png"))

    with open(os.path.join(v26, "ic_launcher.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android='
                '"http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable='
                '"@mipmap/ic_launcher_background" />\n'
                '    <foreground android:drawable='
                '"@mipmap/ic_launcher_foreground" />\n'
                '</adaptive-icon>\n')

    # ---- legacy square icons: composited, rocket a bit larger ----
    for dens, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                       ("xxhdpi", 144), ("xxxhdpi", 192)]:
        base = starfield(432, 16)
        r2 = scaled(rocket, 14)  # 238 x 364 on 432
        base.alpha_composite(r2, ((432 - r2.width) // 2,
                                  (432 - r2.height) // 2))
        base.resize((size, size), Image.LANCZOS).save(
            os.path.join(RES, "mipmap-" + dens, "ic_launcher.png"))

    # preview for humans
    prev = starfield(432, 16)
    prev.alpha_composite(scaled(rocket, 14), ((432 - 238) // 2,
                                              (432 - 364) // 2))
    prev.save(os.path.join(HERE, "icon-preview.png"))
    print("icon set written under", RES)


if __name__ == "__main__":
    main()
