"""Renders the Aegis mark into every icon slot both platforms ask for.

The mark is the same shield drawn in `lib/features/share/share_card.dart`, so
the launcher icon, the launch screen and the shared card are demonstrably one
shape rather than three drawings that resemble each other.

Run from the repo root:  python tool/make_icons.py
"""

from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw

INK = (242, 243, 245, 255)
GROUND = (22, 24, 28, 255)
SUPERSAMPLE = 8

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS_ICONS = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
)


def quadratic(p0, p1, p2, steps=24):
    """Samples a quadratic bezier, since PIL only draws straight segments."""
    points = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
        y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
        points.append((x, y))
    return points


def shield_points(x, y, w, h):
    """The shield outline: a crest, two shoulders, and a curved point."""
    pts = [(x + w / 2, y), (x + w, y + h * 0.22), (x + w, y + h * 0.58)]
    pts += quadratic(
        (x + w, y + h * 0.58), (x + w, y + h * 0.90), (x + w / 2, y + h)
    )
    pts += quadratic(
        (x + w / 2, y + h), (x, y + h * 0.90), (x, y + h * 0.58)
    )
    pts += [(x, y + h * 0.22)]
    return pts


def render(size, *, ground, ink, shield_fraction, stroke_fraction):
    """Draws one icon. Supersampled, because a hairline shield aliases badly."""
    big = size * SUPERSAMPLE
    image = Image.new("RGBA", (big, big), ground)
    draw = ImageDraw.Draw(image)

    shield_w = big * shield_fraction
    shield_h = shield_w * 1.16
    x = (big - shield_w) / 2
    y = (big - shield_h) / 2

    stroke = max(1, round(shield_w * stroke_fraction))
    points = shield_points(x, y, shield_w, shield_h)
    draw.line(points + [points[0]], fill=ink, width=stroke, joint="curve")

    # Round the two hard corners the polyline leaves at the crest and shoulders.
    for point in (points[0], points[1], points[2], points[-1]):
        r = stroke / 2
        draw.ellipse(
            [point[0] - r, point[1] - r, point[0] + r, point[1] + r], fill=ink
        )

    return image.resize((size, size), Image.LANCZOS)


def write(image, *paths):
    for path in paths:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        image.save(path)
        print("  ", os.path.relpath(path, ROOT))


def main():
    transparent = (0, 0, 0, 0)

    print("Android launcher icons")
    # Legacy square icon: the launcher applies its own mask.
    for bucket, size in [
        ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
        ("xxhdpi", 144), ("xxxhdpi", 192),
    ]:
        icon = render(size, ground=GROUND, ink=INK,
                      shield_fraction=0.52, stroke_fraction=0.09)
        write(icon, os.path.join(ANDROID_RES, f"mipmap-{bucket}", "ic_launcher.png"))

    print("Android adaptive foreground")
    # 108dp canvas with a 72dp safe zone, so the shield occupies about a third
    # of the width and survives every mask shape a launcher might apply.
    for bucket, size in [
        ("mdpi", 108), ("hdpi", 162), ("xhdpi", 216),
        ("xxhdpi", 324), ("xxxhdpi", 432),
    ]:
        fg = render(size, ground=transparent, ink=INK,
                    shield_fraction=0.34, stroke_fraction=0.10)
        write(fg, os.path.join(ANDROID_RES, f"mipmap-{bucket}", "ic_launcher_foreground.png"))

        # Themed icons are tinted by the launcher, so the silhouette must be
        # opaque white and carry no colour of its own.
        mono = render(size, ground=transparent, ink=(255, 255, 255, 255),
                      shield_fraction=0.34, stroke_fraction=0.10)
        write(mono, os.path.join(ANDROID_RES, f"mipmap-{bucket}", "ic_launcher_monochrome.png"))

    print("Android launch mark")
    for bucket, size in [
        ("mdpi", 96), ("hdpi", 144), ("xhdpi", 192),
        ("xxhdpi", 288), ("xxxhdpi", 384),
    ]:
        light = render(size, ground=transparent, ink=(22, 24, 28, 255),
                       shield_fraction=0.62, stroke_fraction=0.075)
        write(light, os.path.join(ANDROID_RES, f"drawable-{bucket}", "launch_mark.png"))

    print("iOS app icons")
    # iOS composites no mask and shows no transparency, so every slot is the
    # full opaque tile.
    with open(os.path.join(IOS_ICONS, "Contents.json")) as handle:
        contents = json.load(handle)
    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        scale = int(entry["scale"].rstrip("x"))
        size = round(float(entry["size"].split("x")[0]) * scale)
        icon = render(size, ground=GROUND, ink=INK,
                      shield_fraction=0.52, stroke_fraction=0.09)
        write(icon.convert("RGB"), os.path.join(IOS_ICONS, filename))


if __name__ == "__main__":
    main()
