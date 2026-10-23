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


def keep_main_parts(cell):
    """Drops small islands, such as a sword tip spilling over from the neighbouring cell."""
    alpha = np.asarray(cell.getchannel("A"))
    mask = alpha > 32
    labels = np.zeros(mask.shape, dtype=np.int32)
    sizes, touches_edge, boxes = [0], [False], [None]
    h, w = mask.shape
    for sy, sx in zip(*np.nonzero(mask)):
        if labels[sy, sx]:
            continue
        label = len(sizes)
        labels[sy, sx] = label
        stack, count, edge = [(sy, sx)], 0, False
        box = [sx, sy, sx, sy]
        while stack:
            y, x = stack.pop()
            count += 1
            box = [min(box[0], x), min(box[1], y), max(box[2], x), max(box[3], y)]
            edge = edge or x == 0 or x == w - 1
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = label
                    stack.append((ny, nx))
        sizes.append(count)
        touches_edge.append(edge)
        boxes.append(box)
    biggest = max(sizes)
    main = boxes[sizes.index(biggest)]
    keep = np.zeros(len(sizes), dtype=bool)
    for i in range(1, len(sizes)):
        b = boxes[i]
        # Small bits are kept only when they sit on the body (hair strands, tassels).
        touching_body = b[0] <= main[2] + 6 and b[2] >= main[0] - 6 and b[1] <= main[3] + 6 and b[3] >= main[1] - 6
        keep[i] = sizes[i] >= biggest * 0.15 or (not touches_edge[i] and touching_body and sizes[i] >= biggest * 0.004)
    kept = keep[labels]
    # Keep the soft anti-aliased fringe (alpha <= 32) only around the kept parts.
    near = kept.copy()
    for _ in range(3):
        grown = near.copy()
        grown[1:] |= near[:-1]
        grown[:-1] |= near[1:]
        grown[:, 1:] |= near[:, :-1]
        grown[:, :-1] |= near[:, 1:]
        near = grown
    out = np.asarray(cell).copy()
    out[..., 3] = np.where(kept | (near & (labels == 0)), out[..., 3], 0)
    return Image.fromarray(out)


def cells(image, top, bottom):
    """Imagegen may return a canvas a few pixels off the requested dimensions."""
    result = []
    for col in range(4):
        cell = keep_main_parts(image.crop((round(col * image.width / 4), top,
                                           round((col + 1) * image.width / 4), bottom)))
        alpha = np.asarray(cell.getchannel("A"))
        ys, xs = np.where(alpha > 32)
        assert len(xs), "Empty generated frame"
        box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        # Anchor on the head and shoulders, not the feet: a running stride or a
        # flying cape moves the feet a lot, and anchoring there made the whole
        # body jump sideways from frame to frame.
        height = box[3] - box[1]
        band = alpha[box[1] + int(height * 0.05): box[1] + int(height * 0.4)] > 96
        band_x = np.where(band)[1]
        anchor = float(np.median(band_x)) if len(band_x) else (box[0] + box[2]) / 2
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
