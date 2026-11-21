"""Draws the Dahaby logo and writes every icon size the app needs.

Run from the repo root:  python3 docs/brand/make_icons.py
Needs Pillow. The same geometry is drawn in app/lib/ui/logo.dart and
docs/brand/logo.svg; change all three together.
"""

import json
import os
import sys

from PIL import Image, ImageDraw

BOX = 512  # the design grid
GOLD_TOP = (246, 220, 140)  # F6DC8C
GOLD_MID = (233, 190, 76)  # E9BE4C
GOLD_END = (201, 148, 22)  # C99416
INK = (43, 31, 0)  # 2B1F00

# Three gold bars in a pyramid, then a four-point sparkle.
# Each bar: (centre x, top y). Bars are trapezoids with rounded corners.
BARS = [(256, 206), (170, 312), (342, 312)]
BAR_BOTTOM = 152  # width at the base
BAR_TOP = 100  # width at the top
BAR_HEIGHT = 88
BAR_ROUND = 12  # corner radius
SPARKLE_CENTER = (388, 150)
SPARKLE_RADIUS = 52


def bar_points(cx, top):
    """Corners of one bar, inset by the corner radius (the stroke adds it back)."""
    r = BAR_ROUND
    b, t, h = BAR_BOTTOM / 2 - r, BAR_TOP / 2 - r, BAR_HEIGHT
    return [(cx - b, top + h - r), (cx + b, top + h - r), (cx + t, top + r), (cx - t, top + r)]


def gradient(size):
    """Diagonal gold gradient, light at the top right."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = ((size - 1 - x) + y) / (2 * (size - 1))
            if t < 0.5:
                a, b, k = GOLD_TOP, GOLD_MID, t * 2
            else:
                a, b, k = GOLD_MID, GOLD_END, (t - 0.5) * 2
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * k) for i in range(3))
    return img


def logo(size, *, full_bleed=False, mark_scale=1.0):
    """The logo at [size] px. full_bleed fills the square (no rounded corners)."""
    ss = 4 if size < 512 else 2
    n = size * ss
    k = n / BOX

    base = gradient(min(n, 512)).resize((n, n), Image.BICUBIC).convert("RGBA")
    mark = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    draw = ImageDraw.Draw(mark)

    def pt(p):
        c = BOX / 2
        return ((c + (p[0] - c) * mark_scale) * k, (c + (p[1] - c) * mark_scale) * k)

    r = BAR_ROUND * mark_scale * k
    for cx, top in BARS:
        pts = [pt(p) for p in bar_points(cx, top)]
        draw.polygon(pts, fill=INK + (255,))
        draw.line(pts + [pts[0]], fill=INK + (255,), width=round(2 * r))
        for x, y in pts:
            draw.ellipse((x - r, y - r, x + r, y + r), fill=INK + (255,))

    cx, cy = SPARKLE_CENTER
    s = SPARKLE_RADIUS
    w = s * 0.22
    star = [
        (cx, cy - s), (cx + w, cy - w), (cx + s, cy), (cx + w, cy + w),
        (cx, cy + s), (cx - w, cy + w), (cx - s, cy), (cx - w, cy - w),
    ]
    draw.polygon([pt(p) for p in star], fill=(255, 255, 255, 255))

    base.alpha_composite(mark)
    if not full_bleed:
        mask = Image.new("L", (n, n), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, n - 1, n - 1), radius=round(116 * k), fill=255)
        base.putalpha(mask)
    return base.resize((size, size), Image.LANCZOS)


def save(img, path, opaque=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    (img.convert("RGB") if opaque else img).save(path)
    print("wrote", path)


def main():
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    app = os.path.join(root, "app")

    save(logo(1024), os.path.join(root, "docs/brand/logo.png"))

    res = os.path.join(app, "android/app/src/main/res")
    for name, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        save(logo(size), os.path.join(res, f"mipmap-{name}/ic_launcher.png"))

    web = os.path.join(app, "web")
    save(logo(32), os.path.join(web, "favicon.png"))
    for size in (192, 512):
        save(logo(size), os.path.join(web, f"icons/Icon-{size}.png"))
        # Maskable icons get cropped to a circle, so the mark stays smaller.
        save(logo(size, full_bleed=True, mark_scale=0.78), os.path.join(web, f"icons/Icon-maskable-{size}.png"), opaque=True)

    ios = os.path.join(app, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    with open(os.path.join(ios, "Contents.json")) as f:
        for entry in json.load(f)["images"]:
            if "filename" not in entry:
                continue
            px = round(float(entry["size"].split("x")[0]) * int(entry["scale"][0]))
            # iOS rounds the corners itself and rejects transparency.
            save(logo(px, full_bleed=True, mark_scale=0.9), os.path.join(ios, entry["filename"]), opaque=True)


if __name__ == "__main__":
    if len(sys.argv) > 1:  # preview only
        logo(512).save(sys.argv[1])
    else:
        main()
