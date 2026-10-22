"""Cuts the character art out of its light studio background and writes
game-ready portraits to assets/portraits/.

usage: python3 tools/make_portraits.py <dir with rogue/mage/ranger/knight.png>
"""
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

SRC = sys.argv[1]
OUT = "assets/portraits"
HEIGHT = 900


def flood(seed, allowed):
    """Grows `seed` through 4-connected `allowed` pixels."""
    h, w = allowed.shape
    out = seed.copy()
    q = deque(zip(*np.nonzero(seed)))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and allowed[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    return out


def cut(path):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    h, w, _ = a.shape
    sat = a.max(axis=2) - a.min(axis=2)
    lum = a.mean(axis=2)
    cand = (sat < 22) & (lum > 178)
    border = np.zeros((h, w), bool)
    border[0, :] = border[-1, :] = border[:, 0] = border[:, -1] = True
    bg = flood(border & cand, cand)

    # Large bright pockets enclosed by the figure (e.g. inside the bow string).
    rest = cand & ~bg & (lum > 212)
    seen = np.zeros((h, w), bool)
    for y, x in zip(*np.nonzero(rest)):
        if seen[y, x]:
            continue
        comp = flood(np.pad(np.ones((1, 1), bool), ((y, h - y - 1), (x, w - x - 1))), rest)
        seen |= comp
        if comp.sum() > 1500:
            bg |= comp

    # Floor shadow: grey pixels near the feet that touch the background become
    # a translucent dark shadow so they read correctly on dark UI.
    floor_zone = np.zeros((h, w), bool)
    floor_zone[int(h * 0.82):, :] = True
    shadow = flood(bg & floor_zone, floor_zone & (sat < 18) & (lum > 128)) & ~bg

    alpha_arr = np.where(bg, 0, 255).astype(np.float32)
    shade = np.clip((236 - lum) / 236 * 2.4, 0, 0.8) * 255
    alpha_arr[shadow] = shade[shadow]
    rgb = a.copy()
    rgb[shadow] = 0
    im = Image.fromarray(rgb.astype(np.uint8))
    alpha = Image.fromarray(alpha_arr.astype(np.uint8))
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    bbox = out.getbbox()
    out = out.crop(bbox)
    scale = HEIGHT / out.height
    return out.resize((int(out.width * scale), HEIGHT), Image.LANCZOS)


for name in ("rogue", "mage", "ranger", "knight"):
    img = cut(f"{SRC}/{name}.png")
    img.save(f"{OUT}/{name}.png", optimize=True)
    print(name, img.size)
