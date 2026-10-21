#!/usr/bin/env python3
"""Generate the app icon: a cartoon cockroach on the game's paper background,
with the tricolour stripe used on the game's menu card. Draws at 4x and
downsamples for smooth edges. Output: Assets.xcassets/AppIcon.appiconset/icon1024.png
"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 4                    # supersample factor
W = 1024 * S             # canvas

INK = (35, 24, 15)       # game outline colour rgba(35,24,15)
PAPER = (246, 238, 221)  # #f6eedd
PAPER_DARK = (228, 216, 190)
SAFFRON = (255, 153, 51)
GREEN = (19, 136, 8)
WHITE = (255, 255, 255)
BODY_DARK = (58, 34, 16)   # head/legs
BODY_MID = (109, 63, 26)   # pronotum
BODY = (141, 90, 43)       # wings
BODY_LIGHT = (169, 113, 61)

img = Image.new("RGBA", (W, W), PAPER + (255,))
d = ImageDraw.Draw(img)

# subtle radial vignette on the paper
vig = Image.new("L", (W, W), 0)
vd = ImageDraw.Draw(vig)
vd.ellipse([-W * 0.35, -W * 0.35, W * 1.35, W * 1.35], fill=70)
vig = vig.filter(ImageFilter.GaussianBlur(W // 8))
img = Image.composite(Image.new("RGBA", (W, W), PAPER_DARK + (255,)), img, vig)
d = ImageDraw.Draw(img)

# tricolour stripe across the top (matches the menu card)
stripe_h = int(74 * S)
third = W / 3
for i, col in enumerate((SAFFRON, WHITE, GREEN)):
    d.rectangle([i * third, 0, (i + 1) * third, stripe_h], fill=col + (255,))
d.rectangle([0, stripe_h, W, stripe_h + 6 * S], fill=INK + (40,))

CX = W // 2
OL_W = int(7 * S)


def bez(p0, p1, p2, n=40):
    """quadratic bezier points"""
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        pts.append((x, y))
    return pts


def taper(pts, w0, w1, col):
    """draw a polyline with tapering width + round joints"""
    n = len(pts) - 1
    for i in range(n):
        w = w0 + (w1 - w0) * (i / max(1, n))
        d.line([pts[i], pts[i + 1]], fill=col, width=max(1, int(w)))
        r = w / 2
        d.ellipse([pts[i][0] - r, pts[i][1] - r, pts[i][0] + r, pts[i][1] + r], fill=col)


# ---- soft drop shadow
sh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
sd = ImageDraw.Draw(sh)
sd.ellipse([CX - 280 * S, 760 * S, CX + 280 * S, 862 * S], fill=(20, 12, 5, 90))
sh = sh.filter(ImageFilter.GaussianBlur(18 * S))
img.alpha_composite(sh)
d = ImageDraw.Draw(img)

# ---- legs (3 per side, behind body), angular like the game sprites
legs = [
    ((455, 405), (330, 320), (238, 285)),
    ((450, 490), (296, 480), (192, 532)),
    ((455, 580), (318, 655), (228, 745)),
]
for hx, ky, fy in legs:
    for sgn in (-1, 1):
        pts = [(CX + (p[0] - 512) * sgn * S, p[1] * S) for p in (hx, ky, fy)]
        # outline pass then colour pass
        taper(pts, 34 * S, 12 * S, INK + (255,))
        taper(pts, 22 * S, 6 * S, BODY_DARK + (255,))

# ---- cerci (two little tail spikes)
for sgn in (-1, 1):
    pts = [(CX + sgn * 55 * S, 745 * S), (CX + sgn * 95 * S, 815 * S)]
    taper(pts, 16 * S, 5 * S, INK + (255,))
    taper(pts, 9 * S, 3 * S, BODY_MID + (255,))

# ---- antennae
for sgn in (-1, 1):
    pts = bez((CX + sgn * 28 * S, 300 * S), (CX + sgn * 200 * S, 170 * S), (CX + sgn * 330 * S, 215 * S))
    taper(pts, 20 * S, 6 * S, INK + (255,))
    taper(pts, 12 * S, 3 * S, BODY_MID + (255,))

# ---- abdomen / wings (big oval)
abd = [CX - 205 * S, 385 * S, CX + 205 * S, 775 * S]
d.ellipse(abd, fill=BODY + (255,), outline=INK + (255,), width=OL_W)
# gradient-ish shading: darker toward the bottom, clipped to the abdomen
grad = Image.new("RGBA", (W, W), BODY_DARK + (0,))
grad_alpha = Image.linear_gradient("L").crop((0, 0, 1, 256)).resize((W, W))
grad_alpha = grad_alpha.point(lambda v: int(v * 0.55))
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).ellipse(abd, fill=255)
grad.putalpha(Image.composite(grad_alpha, Image.new("L", (W, W), 0), mask))
img.alpha_composite(grad)
d = ImageDraw.Draw(img)

# wing centre seam + fold lines
d.line([(CX, 425 * S), (CX, 745 * S)], fill=INK + (150,), width=int(5 * S))
for sgn in (-1, 1):
    fold = bez((CX + sgn * 70 * S, 430 * S), (CX + sgn * 190 * S, 560 * S), (CX + sgn * 95 * S, 735 * S))
    taper(fold, 5 * S, 4 * S, INK + (120,))

# glossy highlight on the wings
hl = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(hl).ellipse([CX - 165 * S, 430 * S, CX - 35 * S, 620 * S], fill=(255, 255, 255, 55))
hl = hl.filter(ImageFilter.GaussianBlur(10 * S))
img.alpha_composite(hl)
d = ImageDraw.Draw(img)

# ---- pronotum shield
d.ellipse([CX - 150 * S, 320 * S, CX + 150 * S, 460 * S], fill=BODY_MID + (255,),
          outline=INK + (255,), width=OL_W)
d.ellipse([CX - 105 * S, 340 * S, CX + 105 * S, 405 * S], fill=BODY_LIGHT + (255,))

# ---- head
d.ellipse([CX - 82 * S, 245 * S, CX + 82 * S, 355 * S], fill=BODY_DARK + (255,),
          outline=INK + (255,), width=OL_W)

# ---- eyes (cartoon-friendly) + highlights
for sgn in (-1, 1):
    ex = CX + sgn * 44 * S
    ey = 292 * S
    r = 22 * S
    d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=(18, 12, 8, 255))
    hr = 7 * S
    d.ellipse([ex - hr - 4 * S, ey - hr - 5 * S, ex + hr - 4 * S, ey + hr - 5 * S], fill=WHITE + (255,))

# ---- tiny smile
d.arc([CX - 26 * S, 315 * S, CX + 26 * S, 345 * S], 20, 160, fill=(200, 170, 140, 255), width=int(5 * S))

out = img.convert("RGB").resize((1024, 1024), Image.LANCZOS)
here = os.path.dirname(os.path.abspath(__file__))
dest = os.path.join(here, "..", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(dest, exist_ok=True)
path = os.path.join(dest, "icon1024.png")
out.save(path, "PNG")
print("wrote", os.path.normpath(path), out.size, out.mode)
