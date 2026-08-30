#!/usr/bin/env python3
"""Megarocket Steam / SteamGridDB artwork builder (bespoke).

Follows the doom-mod-portable-setup skill's conventions (same output layout
and naming as its build_art.py), but composes from Megarocket's own visual
identity instead of WAD lumps:

  - the launcher's EGA palette, starfield algorithm and embossed big-font
    "MEGAROCKET" wordmark (parsed straight out of launcher/launcher_font_big.h)
  - the EGA rocket pixel art from android/make-icon.py (the app icon)
  - the seven ENGINE-RENDERED title screens (title_art*.ppm, produced from the
    user's own game data -- personal-library artwork, not for redistribution)

Outputs (into the folder above this one):
  grids/    600x900 660x930 342x482 (portrait)  920x430 460x215 (landscape)
  heroes/   3840x1240 1920x620 1600x650 (+ jpg alternates, no text)
  logos/    transparent wordmark lock-up
  icons/    512/256/128/64/32 png + multi-size icon.ico

Usage:  python art_build.py [section]      section in: grids heroes logos icons
"""

import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)                       # ...\Steam Artwork
ROOT = os.path.dirname(OUT)                       # F:\KeenLauncher

# ----------------------------------------------------------------- palette

EGA = [
    (0x00, 0x00, 0x00), (0x00, 0x00, 0xAA), (0x00, 0xAA, 0x00), (0x00, 0xAA, 0xAA),
    (0xAA, 0x00, 0x00), (0xAA, 0x00, 0xAA), (0xAA, 0x55, 0x00), (0xAA, 0xAA, 0xAA),
    (0x55, 0x55, 0x55), (0x55, 0x55, 0xFF), (0x55, 0xFF, 0x55), (0x55, 0xFF, 0xFF),
    (0xFF, 0x55, 0x55), (0xFF, 0x55, 0xFF), (0xFF, 0xFF, 0x55), (0xFF, 0xFF, 0xFF),
]


def ega(i, a=255):
    r, g, b = EGA[i & 15]
    return (r, g, b, a)


# ----------------------------------------------------- the launcher's font

def load_big_font():
    """Parse launcher_font_big.h: 95 glyphs, 12x16, bit (15 - x) per row."""
    path = os.path.join(ROOT, "launcher", "launcher_font_big.h")
    with open(path) as f:
        text = f.read()
    rows = re.findall(r"\{((?:0x[0-9A-Fa-f]{4},?){16})\}", text)
    glyphs = []
    for r in rows:
        vals = [int(v, 16) for v in re.findall(r"0x[0-9A-Fa-f]{4}", r)]
        glyphs.append(vals)
    assert len(glyphs) == 95, len(glyphs)
    return glyphs


LBFONT = load_big_font()
LBW, LBH = 12, 16


def text_pass(im, x, y, s, colour):
    px = im.load()
    for ch in s:
        c = ord(ch)
        if 32 <= c <= 126:
            g = LBFONT[c - 32]
            for row in range(LBH):
                bits = g[row]
                for bit in range(LBW):
                    if bits & (1 << (15 - bit)):
                        xx, yy = x + bit, y + row
                        if 0 <= xx < im.width and 0 <= yy < im.height:
                            px[xx, yy] = colour
        x += LBW


def emboss_text(s, face=14):
    """The launcher's text_big at unit scale, on transparency:
    black outline ring (8 dirs x 2px), shade low, light high, face."""
    w = len(s) * LBW + 4
    h = LBH + 4
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hi = 15 if (face | 8) == face else (face | 8)
    lo = face & 7
    for dx, dy in [(-1, -1), (0, -1), (1, -1), (-1, 0),
                   (1, 0), (-1, 1), (0, 1), (1, 1)]:
        text_pass(im, 2 + 2 * dx, 2 + 2 * dy, s, ega(0))
    text_pass(im, 3, 3, s, ega(lo))
    text_pass(im, 1, 1, s, ega(hi))
    text_pass(im, 2, 2, s, ega(face))
    return im.crop(im.getbbox())


# ------------------------------------------------------------- the rocket

ROCKET_PAL = {
    "K": (0, 0, 0, 255), "W": (255, 255, 255, 255), "G": (170, 170, 170, 255),
    "g": (85, 85, 85, 255), "R": (255, 85, 85, 255), "D": (170, 0, 0, 255),
    "C": (85, 255, 255, 255), "B": (0, 0, 170, 255), "Y": (255, 255, 85, 255),
    ".": (0, 0, 0, 0),
}

ROCKET_ROWS = [
    "........K........", ".......KRK.......", ".......KRK.......",
    "......KRRDK......", "......KRRDK......", ".....KRRRDDK.....",
    ".....KWWWWWK.....", ".....KWWWWGK.....", "....KWWWWWWGK....",
    "....KWKKKKKGK....", "....KWKCCBKGK....", "....KWKCBBKGK....",
    "....KWKKKKKGK....", "....KWWWWWWGK....", "....KWWWWWWGK....",
    "...KDWWWWWWGDK...", "..KDDWWWWWWGDDK..", ".KDRDWWWWWWGDRDK.",
    ".KDRDWWWWWWGDRDK.", ".KDRKWWWWWWGKRDK.", ".KDKKGGGGGGGKKDK.",
    ".KKK.KKKKKKK.KKK.", ".....KYYYYYK.....", "......KYRYK......",
    "......KYRYK......", ".......KYK.......", "........K........",
]


def rocket_im():
    im = Image.new("RGBA", (17, 27), (0, 0, 0, 0))
    for y, row in enumerate(ROCKET_ROWS):
        for x, ch in enumerate(row):
            im.putpixel((x, y), ROCKET_PAL[ch])
    return im


ROCKET = rocket_im()


def scaled(im, f):
    return im.resize((im.width * f, im.height * f), Image.NEAREST)


# ------------------------------------------------- the launcher starfield

def starfield(w, h):
    """launcher.c starfield(): fixed LCG scatter, white every 8th star,
    grey otherwise, a dark-grey plus halo on every 4th."""
    im = Image.new("RGBA", (w, h), ega(0))
    px = im.load()

    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = ega(c)

    seed = 0x1234
    for i in range(int((w * h) / 850)):
        seed = (seed * 1103515245 + 12345) & 0xFFFFFFFF
        x = (seed >> 16) % w
        seed = (seed * 1103515245 + 12345) & 0xFFFFFFFF
        y = (seed >> 16) % h
        put(x, y, 15 if (i & 7) == 0 else 7)
        if (i & 3) == 0:
            put(x - 1, y, 8)
            put(x + 1, y, 8)
            put(x, y - 1, 8)
            put(x, y + 1, 8)
    return im


# ------------------------------------------------------ the title screens

# (path, launcher accent colour) in launcher slot order
TITLES = [
    (os.path.join(ROOT, "keen13", "gamedata", "title_art.ppm"), 9),
    (os.path.join(ROOT, "keen13", "gamedata2", "title_art.ppm"), 11),
    (os.path.join(ROOT, "keen13", "gamedata3", "title_art.ppm"), 13),
    (os.path.join(ROOT, "rt", "title_art_4.ppm"), 10),
    (os.path.join(ROOT, "rt", "title_art_5.ppm"), 14),
    (os.path.join(ROOT, "rt", "title_art_6.ppm"), 12),
    (os.path.join(ROOT, "keendreams", "game", "title_art.ppm"), 3),
]


def load_titles():
    out = []
    for path, accent in TITLES:
        out.append((Image.open(path).convert("RGB"), accent))
    return out


def framed_tile(title, accent, w, h, border=3):
    """A title screen in the launcher's accent-coloured tile frame:
    1px black outline, accent border, 1px black seam, then the art."""
    tile = Image.new("RGB", (w, h), EGA[0])
    d = tile.load()
    for x in range(w):
        for y in range(h):
            edge = min(x, y, w - 1 - x, h - 1 - y)
            if edge == 0:
                d[x, y] = EGA[0]
            elif edge < border:
                d[x, y] = EGA[accent]
            elif edge == border:
                d[x, y] = EGA[0]
    inner_w, inner_h = w - 2 * (border + 1), h - 2 * (border + 1)
    art = title.resize((inner_w, inner_h), Image.LANCZOS)
    tile.paste(art, (border + 1, border + 1))
    return tile


def strip_of_titles(titles, total_w, h, border):
    """All seven titles side by side, launcher-carousel style."""
    strip = Image.new("RGB", (total_w, h), EGA[0])
    xs = [round(i * total_w / 7) for i in range(8)]
    for i, (title, accent) in enumerate(titles):
        w = xs[i + 1] - xs[i]
        strip.paste(framed_tile(title, accent, w, h, border), (xs[i], 0))
    return strip


# ------------------------------------------------------------ compositions

def ensure_dirs():
    for d in ("grids", "heroes", "logos", "icons"):
        os.makedirs(os.path.join(OUT, d), exist_ok=True)


def build_logo():
    """Rocket + embossed MEGAROCKET, transparent, inside 1280x720."""
    word = scaled(emboss_text("MEGAROCKET"), 9)      # ~1116 x ...
    rock = scaled(ROCKET, 6)                          # 102 x 162
    gap = 26
    w = rock.width + gap + word.width
    h = max(rock.height, word.height)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    im.alpha_composite(rock, (0, (h - rock.height) // 2))
    im.alpha_composite(word, (rock.width + gap, (h - word.height) // 2))
    im.save(os.path.join(OUT, "logos", "logo_%dx%d.png" % (w, h)))
    return im


def build_icons():
    """The Android launcher icon, replicated at 512 for Steam."""
    # make-icon.py starfield: navy, fixed star list on a 27-cell field
    stars = [
        (2, 3, 1), (7, 1, 0), (12, 4, 0), (18, 2, 1), (24, 5, 0),
        (1, 10, 0), (5, 14, 1), (3, 20, 0), (8, 24, 0), (13, 22, 1),
        (20, 25, 0), (24, 19, 1), (25, 12, 0), (21, 9, 0), (16, 6, 0),
        (10, 8, 1), (23, 23, 0), (6, 6, 0), (15, 25, 0), (2, 25, 1),
    ]
    size, cell = 512, 19
    im = Image.new("RGBA", (size, size), (5, 5, 24, 255))
    for sx, sy, bright in stars:
        c = (170, 255, 255, 255) if bright else (85, 170, 170, 255)
        for dx in range(cell // 3):
            for dy in range(cell // 3):
                x, y = sx * cell + dx, sy * cell + dy
                if x < size and y < size:
                    im.putpixel((x, y), c)
    r = scaled(ROCKET, 16)                            # 272 x 432
    im.alpha_composite(r, ((size - r.width) // 2, (size - r.height) // 2))

    icons = os.path.join(OUT, "icons")
    im.save(os.path.join(icons, "icon_512.png"))
    for s in (256, 128, 64, 32):
        im.resize((s, s), Image.LANCZOS).save(
            os.path.join(icons, "icon_%d.png" % s))
    im.resize((256, 256), Image.LANCZOS).save(
        os.path.join(icons, "icon.ico"),
        sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])


def build_landscape(titles):
    """920x430 capsule: starfield, twin rockets, wordmark, title strip."""
    im = scaled(starfield(460, 215), 2).convert("RGB")
    strip_h = 84
    strip = strip_of_titles(titles, 920, strip_h, border=3)
    im.paste(strip, (0, 430 - strip_h - 8))

    im_rgba = im.convert("RGBA")
    word = scaled(emboss_text("MEGAROCKET"), 5)
    wx = (920 - word.width) // 2
    wy = (430 - strip_h - 8 - word.height) // 2
    im_rgba.alpha_composite(word, (wx, wy))
    rock = scaled(ROCKET, 5)
    ry = wy + (word.height - rock.height) // 2
    im_rgba.alpha_composite(rock, ((wx - rock.width) // 2, ry))
    im_rgba.alpha_composite(rock, (920 - (wx - rock.width) // 2 - rock.width, ry))

    out = im_rgba.convert("RGB")
    out.save(os.path.join(OUT, "grids", "grid_920x430.png"))
    out.resize((460, 215), Image.LANCZOS).save(
        os.path.join(OUT, "grids", "grid_460x215.png"))


def build_portrait(titles):
    """600x900 capsule: header lock-up, then a 2x4 launcher-tile wall
    (seven games + a rocket emblem cell)."""
    im = scaled(starfield(300, 450), 2).convert("RGBA")

    rock = scaled(ROCKET, 5)                          # 85 x 135
    im.alpha_composite(rock, ((600 - rock.width) // 2, 16))
    word = scaled(emboss_text("MEGAROCKET"), 4)       # ~496 wide
    im.alpha_composite(word, ((600 - word.width) // 2, 168))

    grid_y = 244
    cell_h = (900 - grid_y) // 4                      # 164
    cell_w = 300
    for i, (title, accent) in enumerate(titles):
        col, row = i % 2, i // 2
        # crop the source slightly to the taller-than-1.6 cell aspect
        aspect = cell_w / cell_h
        src_h = min(200, round(320 / aspect))
        top = (200 - src_h) // 2
        art = title.crop((0, top, 320, top + src_h))
        tile = framed_tile(art, accent, cell_w, cell_h, border=3)
        im.paste(tile, (col * cell_w, grid_y + row * cell_h))
    # emblem cell: starfield + rocket, framed in the launcher's brown
    emblem_art = scaled(starfield(150, 82), 2).convert("RGB")
    er = scaled(ROCKET, 4)
    emblem_art.paste(er, ((emblem_art.width - er.width) // 2,
                          (emblem_art.height - er.height) // 2), er)
    emblem = framed_tile(emblem_art, 6, cell_w, cell_h, border=3)
    im.paste(emblem, (cell_w, grid_y + 3 * cell_h))

    out = im.convert("RGB")
    out.save(os.path.join(OUT, "grids", "grid_600x900.png"))
    out.resize((660, 930), Image.LANCZOS).save(
        os.path.join(OUT, "grids", "grid_660x930.png"))
    out.resize((342, 482), Image.LANCZOS).save(
        os.path.join(OUT, "grids", "grid_342x482.png"))


def hero_compose(titles, w, h, pixel_scale, strip_h, border, rocket_scale,
                 rocket_margin):
    """Text-free hero: starfield, title-strip skyline, flanking rockets
    kept clear of Steam's centre logo overlay."""
    im = scaled(starfield(w // pixel_scale, h // pixel_scale),
                pixel_scale).convert("RGBA")
    strip = strip_of_titles(titles, w, strip_h, border)
    pad = pixel_scale * 4
    im.paste(strip, (0, h - strip_h - pad))
    rock = scaled(ROCKET, rocket_scale)
    ry = (h - strip_h - pad - rock.height) // 2
    im.alpha_composite(rock, (rocket_margin, ry))
    im.alpha_composite(rock, (w - rocket_margin - rock.width, ry))
    return im.convert("RGB")


def build_heroes(titles):
    heroes = os.path.join(OUT, "heroes")
    big = hero_compose(titles, 3840, 1240, 4, 344, 6, 12, 380)
    big.save(os.path.join(heroes, "hero_3840x1240.png"))
    big.save(os.path.join(heroes, "hero_3840x1240.jpg"), quality=90)
    mid = big.resize((1920, 620), Image.LANCZOS)
    mid.save(os.path.join(heroes, "hero_1920x620.png"))
    mid.save(os.path.join(heroes, "hero_1920x620.jpg"), quality=90)
    sq = hero_compose(titles, 1600, 650, 2, 180, 3, 6, 150)
    sq.save(os.path.join(heroes, "hero_1600x650.png"))


def main():
    section = sys.argv[1] if len(sys.argv) > 1 else "all"
    ensure_dirs()
    titles = load_titles()
    if section in ("all", "logos"):
        build_logo()
    if section in ("all", "icons"):
        build_icons()
    if section in ("all", "grids"):
        build_landscape(titles)
        build_portrait(titles)
    if section in ("all", "heroes"):
        build_heroes(titles)
    print("done ->", OUT)


if __name__ == "__main__":
    main()
