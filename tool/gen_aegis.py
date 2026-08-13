"""Aegis icon: a phone that is a shield.

The mark is one silhouette read two ways. The top half is a phone -- portrait,
corners rounded at 24.5% of the body width, an earpiece slot knocked out of the
head. The bottom half stops being a phone: the sides run straight past the
midpoint and then turn in to a point. Nothing is added on top of the shape, so
there is no lock, no tick and no keyhole in it. The product is a phone that is
guarded, and the outline says exactly that and nothing else.

The alternative was a heraldic shield with a tick in it, which is what every
other app in the category already is. It was drawn and rejected: it reads as
"security app", not as "Aegis".

Proportions, chosen off the size ladder rather than by eye:

  body      70.0% as wide as it is tall, so it reads phone rather than crest
  corners   24.5% of the body width -- lower and it reads as a luggage tag
  shoulder  the straight sides run to 62% of the height before turning in
  handle    the bezier handle sits at 84%; higher and the tip goes blunt and
            the whole thing turns into a guitar pick
  slot      34% of the body width, one earpiece, centred at 15.5% down
  mark      80% of the tile, so the tip has air under it at every mask

Colours: a flat #0B1220 ground, which is the app's own steel-blue seed
(#3A6EA5) taken down to near-black without losing the blue, and a vertical
ice-to-steel ramp on the mark. Flat, because a vignette behind a single solid
shape only muddies its edge.

Drawn at 4096 and downsampled with LANCZOS; Pillow's primitives are aliased, so
the supersample is what gives clean edges.

Run: python gen_aegis.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

S = 4096
OUT = 1024
C = S // 2

BG = (0x0B, 0x12, 0x20)
ICE_TOP = (0xE4, 0xEE, 0xFB)
ICE_BOT = (0x74, 0x9F, 0xD6)
FLAT = (0xC5, 0xD8, 0xF2)       # single-colour silhouette

MARK_FRAC = 0.80                # mark height / tile, full bleed
BODY_WF = 0.700                 # body width / mark height
CORNER_F = 0.245                # corner radius / body width
SHOULDER = 0.62                 # where the straight sides stop
HANDLE = 0.840                  # bezier handle, down the height
SLOT_W = 0.340                  # earpiece width / body width
SLOT_H = 0.095
SLOT_Y = 0.155                  # slot centre, down from the top
GROW = S * 0.009                # uniform grow; this is what rounds the tip

# Android adaptive icons are a 108dp canvas with only the central 72dp
# guaranteed visible. The furthest points from centre are not the shield tip,
# as it first looks: the tip sits at half the height, but the two rounded head
# corners sit further out still, at 0.545 of the height once the corner radius
# is added back on. 0.60 puts them at 35.3dp against a 36dp safe radius, and
# the tip at 32.4dp. The full-bleed 0.80 would push the corners to 47dp and a
# circular mask would shave both shoulders flat.
SAFE_FRAC = 0.60

DENSITIES = [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2),
             ("xxhdpi", 3), ("xxxhdpi", 4)]

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
AND_DIR = os.path.join(OUT_DIR, "android")


# --------------------------------------------------------------------------- #
# geometry
# --------------------------------------------------------------------------- #

def quad(p0, p1, p2, n=160):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                    u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]))
    return out


def arc(cx, cy, r, a0, a1, step=2.0):
    import math
    n = max(2, int(abs(a1 - a0) / step))
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


def fill_round(draw, pts, r, fill=255):
    """Filled polygon grown outward by r, every corner rounded by r.

    Repeating the first *two* points is what gives the closing corner a joint
    like the others; with only pts[0] it stays a nicked butt end.
    """
    draw.polygon(pts, fill=fill)
    if r > 0:
        draw.line(list(pts) + [pts[0], pts[1]], fill=fill,
                  width=int(2 * r), joint="curve")


def outline(cx, cy, w, h):
    """Phone head, shield foot, as one closed path."""
    top, bot = cy - h / 2, cy + h / 2
    L, R = cx - w / 2, cx + w / 2
    r = w * CORNER_F
    ys = top + h * SHOULDER
    pts = arc(L + r, top + r, r, 180, 270)
    pts += arc(R - r, top + r, r, 270, 360)
    pts.append((R, ys))
    pts += quad((R, ys), (R, top + h * HANDLE), (cx, bot))[1:]
    pts += quad((cx, bot), (L, top + h * HANDLE), (L, ys))[1:]
    return pts


def mark_mask(frac=MARK_FRAC):
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    h = frac * S
    w = h * BODY_WF
    # The path is inset by GROW first, because fill_round expands it back out
    # by exactly that much.
    fill_round(d, outline(C, C, w - 2 * GROW, h - 2 * GROW), GROW)

    hole = Image.new("L", (S, S), 0)
    pw, ph = w * SLOT_W, w * SLOT_H
    y = C - h / 2 + w * SLOT_Y
    ImageDraw.Draw(hole).rounded_rectangle(
        [C - pw / 2, y - ph / 2, C + pw / 2, y + ph / 2],
        radius=ph / 2, fill=255)
    m.paste(0, (0, 0), hole)
    return m


# --------------------------------------------------------------------------- #
# paint
# --------------------------------------------------------------------------- #

def ramp(top, bot):
    """Vertical ramp, built one pixel wide and stretched."""
    n = 256
    strip = Image.new("RGB", (1, n))
    px = strip.load()
    for y in range(n):
        t = y / (n - 1)
        px[0, y] = tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    return strip.resize((S, S), Image.BILINEAR)


def squircle(size, n=5.0):
    """iOS-style superellipse. One row per scanline, so it stays cheap."""
    ss = 2048
    m = Image.new("L", (ss, ss), 0)
    d = ImageDraw.Draw(m)
    a = (ss - 1) / 2
    for y in range(ss):
        v = abs((y - a) / a)
        if v > 1:
            continue
        x = a * (1 - v ** n) ** (1 / n)
        d.line([a - x, y, a + x, y], fill=255)
    return m.resize((size, size), Image.LANCZOS)


def circle(size):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse([0, 0, size - 1, size - 1], fill=255)
    return m


def down(im, size):
    return im.resize((size, size), Image.LANCZOS)


def composite(mask):
    return Image.composite(ramp(ICE_TOP, ICE_BOT),
                           Image.new("RGB", (S, S), BG), mask)


def silhouette(mask, colour=None):
    """Mark alone on transparency. colour=None keeps the ramp."""
    src = ramp(ICE_TOP, ICE_BOT) if colour is None \
        else Image.new("RGB", (S, S), colour)
    out = src.convert("RGBA")
    out.putalpha(mask)
    return out


# --------------------------------------------------------------------------- #
# outputs
# --------------------------------------------------------------------------- #

def write(im, *parts):
    p = os.path.join(*parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p, "PNG", optimize=True)
    print("wrote", os.path.relpath(p, OUT_DIR))


def write_text(text, *parts):
    p = os.path.join(*parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", os.path.relpath(p, OUT_DIR))


def ladder(icon, path):
    sizes = [280, 120, 76, 48]
    pad = 46
    img = Image.new("RGB", (900, 420), (0x1C, 0x1E, 0x22))
    d = ImageDraw.Draw(img)
    try:
        f_big = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 30)
        f_small = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 24)
    except OSError:
        f_big = f_small = ImageFont.load_default()
    d.text((pad, 26), "Aegis - phone/shield - size ladder",
           font=f_big, fill=(0xF2, 0xEF, 0xE6))
    x = pad
    for s in sizes:
        card = Image.new("RGB", (s, s), (0x1C, 0x1E, 0x22))
        card.paste(down(icon, s), (0, 0), squircle(s))
        img.paste(card, (x, 90 + (sizes[0] - s) // 2))
        d.text((x, 90 + (sizes[0] - s) // 2 + s + 8), f"{s}px",
               font=f_small, fill=(0x9B, 0xA3, 0xAE))
        x += s + 44
    img.save(path, "PNG", optimize=True)
    print("wrote", os.path.relpath(path, OUT_DIR))


ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
"""

COLORS_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0B1220</color>
</resources>
"""


def main():
    full = mark_mask()
    safe = mark_mask(SAFE_FRAC)

    icon = down(composite(full), OUT).convert("RGB")

    # --- store masters -------------------------------------------------------
    # Full bleed and no alpha: App Store Connect rejects alpha, and both stores
    # apply their own corner mask.
    write(icon, OUT_DIR, "aegis_master_1024.png")

    rounded = icon.convert("RGBA")
    rounded.putalpha(squircle(OUT))
    write(rounded, OUT_DIR, "aegis_squircle_1024.png")

    write(down(composite(full), 512).convert("RGB"),
          OUT_DIR, "play_store_512.png")

    # --- silhouettes, transparent background ---------------------------------
    write(down(silhouette(full), OUT), OUT_DIR, "aegis_silhouette_1024.png")
    write(down(silhouette(full, FLAT), OUT),
          OUT_DIR, "aegis_silhouette_flat_1024.png")
    write(down(silhouette(full, (255, 255, 255)), OUT),
          OUT_DIR, "aegis_silhouette_white_1024.png")

    # --- Android launcher assets --------------------------------------------
    fg = silhouette(safe)
    mono = silhouette(safe, (255, 255, 255))
    for name, mult in DENSITIES:
        legacy = round(48 * mult)        # pre-API-26 launcher bitmap
        adaptive = round(108 * mult)     # 108dp adaptive layer
        d = os.path.join(AND_DIR, f"mipmap-{name}")
        write(down(icon, legacy), d, "ic_launcher.png")
        rnd = down(icon, legacy).convert("RGBA")
        rnd.putalpha(circle(legacy))
        write(rnd, d, "ic_launcher_round.png")
        write(down(fg, adaptive), d, "ic_launcher_foreground.png")
        write(down(mono, adaptive), d, "ic_launcher_monochrome.png")

    write_text(ADAPTIVE_XML, AND_DIR, "mipmap-anydpi-v26", "ic_launcher.xml")
    write_text(ADAPTIVE_XML, AND_DIR, "mipmap-anydpi-v26",
               "ic_launcher_round.xml")
    write_text(COLORS_XML, AND_DIR, "values", "ic_launcher_background.xml")

    ladder(icon, os.path.join(OUT_DIR, "_aegis_ladder.png"))


if __name__ == "__main__":
    main()
