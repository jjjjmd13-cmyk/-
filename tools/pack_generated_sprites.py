"""Package imagegen atlases as the runtime's anchored, horizontal PNG strips.

Art is retained verbatim in art_sources. This only slices, scales and pads it;
it does not invent in-between frames. Requires Pillow and numpy.
"""
from pathlib import Path
from io import BytesIO
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools/art_sources"
OUT = ROOT / "assets/sprites"
HERO_ROWS = {
    "knight": [0, 365, 700, 1086], "ranger": [0, 382, 718, 1086],
    "mage": [0, 376, 704, 1086], "rogue": [0, 382, 711, 1086],
}
ENEMIES = [
    ("enemies-a", ["ghoul", "bat", "archer", "brute", "cultist"], [0, 277, 535, 768, 1102, 1402]),
    ("enemies-b", ["wraith", "bomber", "shield", "necro", "skeleton"], [0, 285, 537, 800, 1116, 1402]),
]
SIZES = {"brute": (256, 200), "shield": (256, 170), "necro": (256, 190),
         "bat": (192, 105), "wraith": (192, 140), "skeleton": (192, 110)}


def cells(image, top, bottom):
    """Imagegen may return a canvas a few pixels off the requested dimensions."""
    result = []
    for col in range(4):
        cell = image.crop((round(col * image.width / 4), top,
                           round((col + 1) * image.width / 4), bottom))
        alpha = np.asarray(cell.getchannel("A"))
        ys, xs = np.where(alpha > 32)
        assert len(xs), "Empty generated frame"
        box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        # Estimate a foot anchor from opaque pixels in the lowest 8% of the body.
        foot = (alpha > 96) & (np.indices(alpha.shape)[0] >= box[3] - max(4, (box[3]-box[1]) * .08))
        foot_x = np.where(foot)[1]
        anchor = float(np.median(foot_x)) if len(foot_x) else (box[0] + box[2]) / 2
        result.append((cell.crop(box), anchor - box[0]))
    return result


def pack(group, actor, animations, size, height):
    flat = [frame for frames in animations.values() for frame in frames]
    max_h = max(im.height for im, _ in flat)
    # Leave room on BOTH sides of the fixed foot anchor, including long weapons.
    max_extent = max(max(anchor, im.width - anchor) for im, anchor in flat)
    scale = min(height / max_h, (size / 2 - 4) / max_extent)
    folder = OUT / group / actor
    folder.mkdir(parents=True, exist_ok=True)
    for anim, frames in animations.items():
        strip = Image.new("RGBA", (size * len(frames), size))
        for i, (im, anchor) in enumerate(frames):
            resized = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.Resampling.LANCZOS)
            x = round(size / 2 - anchor * scale)
            y = round(size * 15 / 16) - resized.height
            assert x >= 0 and y >= 0 and x + resized.width <= size
            strip.alpha_composite(resized, (i * size + x, y))
        buffer = BytesIO()
        strip.save(buffer, format="PNG", optimize=True)
        (folder / f"{anim}.png").write_bytes(buffer.getvalue())
    print(group, actor, sorted(animations))


def main():
    for actor, boundaries in HERO_ROWS.items():
        image = Image.open(SOURCE / f"{actor}.png").convert("RGBA")
        animations = {anim: cells(image, boundaries[i], boundaries[i+1])
                      for i, anim in enumerate(["idle", "run", "attack"])}
        pack("heroes", actor, animations, 384, 250 if actor == "knight" else 240)
    for source, actors, boundaries in ENEMIES:
        image = Image.open(SOURCE / f"{source}.png").convert("RGBA")
        for i, actor in enumerate(actors):
            pack("enemies", actor, {"run": cells(image, boundaries[i], boundaries[i+1])}, *SIZES.get(actor, (192, 125)))
    image = Image.open(SOURCE / "bosses.png").convert("RGBA")
    for i, actor in enumerate(["dread_knight", "blood_witch", "void_lord"]):
        frames = cells(image, round(i * image.height / 3), round((i+1) * image.height / 3))
        pack("bosses", actor, {"idle": frames, "run": frames}, 640 if actor == "void_lord" else 512,
             500 if actor == "void_lord" else 400)


if __name__ == "__main__":
    main()
