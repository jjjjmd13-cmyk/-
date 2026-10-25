"""Package the painted finish of the 3D motion guides, without inventing poses.

The original Blender renders and the painted atlases are separate sources.
Thin weapons are excluded when measuring body scale/ground level, so an
overhead sword does not shrink the character or move their feet off the floor.
Requires Pillow, numpy and scipy.
"""
from pathlib import Path
import json
import shutil
from io import BytesIO
import numpy as np
from PIL import Image
from scipy.ndimage import binary_erosion, label
from pack_generated_sprites import keep_main_parts

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tools/art_sources/knight-3d'
SIZE = 512


def atlas_cells(path, columns, rows):
    image = Image.open(path).convert('RGBA')
    alpha = np.array(image.getchannel('A'))
    assert alpha.min() == 0 and np.mean(alpha == 0) > .2, 'Source needs real transparency'
    occupancy = (alpha > 32).sum(axis=1)
    boundaries = [0]
    for row in range(1, rows):
        center = image.height * row / rows
        margin = round(image.height / rows * .13)
        candidates = range(round(center)-margin, round(center)+margin+1)
        boundaries.append(min(candidates, key=lambda y: (occupancy[y], abs(y-center))))
    boundaries.append(image.height)
    result = []
    for row in range(rows):
        for col in range(columns):
            cell = image.crop((round(col*image.width/columns), boundaries[row],
                               round((col+1)*image.width/columns), boundaries[row+1]))
            result.append(keep_main_parts(cell))
    return result


def body_core(cell):
    alpha = np.array(cell.getchannel('A'))
    mask = alpha > 48
    eroded = binary_erosion(mask, iterations=max(2, round(cell.width*.016)))
    labels, count = label(eroded)
    assert count, 'Empty body core'
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    body = labels == sizes.argmax()
    ys, xs = np.where(body)
    top, bottom = int(ys.min()), int(ys.max())+1
    return body, top, bottom


def prepare(cell, body_height_hint=None):
    body, top, bottom = body_core(cell)
    # A broad blade can survive erosion and join the raised hands. For these
    # reviewed overhead poses, measure the body using the other attack poses.
    if body_height_hint is not None:
        top = bottom-round(body_height_hint)
    band = body[top:top+max(1, round((bottom-top)*.3))]
    anchor_x = float(np.median(np.where(band)[1]))
    body_height = bottom-top
    scale = 250/body_height
    full = cell.getbbox()
    left, right = anchor_x-full[0], full[2]-anchor_x
    # Retain room for the entire blade and cape around the fixed body anchor.
    scale = min(scale, (SIZE/2-8)/max(left,right), (SIZE*15/16-8)/(bottom-full[1]),
                (SIZE/16-4)/max(1,full[3]-bottom))
    image = cell.crop(full)
    resized = image.resize((max(1, round(image.width*scale)), max(1, round(image.height*scale))), Image.Resampling.LANCZOS)
    x = round(SIZE/2-(anchor_x-full[0])*scale)
    y = round(SIZE*15/16-(bottom-full[1])*scale)
    assert x >= 0 and y >= 0 and x+resized.width <= SIZE and y+resized.height <= SIZE
    frame = Image.new('RGBA', (SIZE,SIZE)); frame.alpha_composite(resized,(x,y))
    return frame


def strip(path, frames):
    result = Image.new('RGBA', (SIZE*len(frames),SIZE))
    for i,frame in enumerate(frames):
        result.alpha_composite(frame,(SIZE*i,0))
    path.parent.mkdir(parents=True,exist_ok=True)
    temporary = path.with_suffix('.tmp')
    buffer = BytesIO()
    result.save(buffer,format='PNG',optimize=True)
    temporary.write_bytes(buffer.getvalue())
    with Image.open(temporary) as check:
        check.verify()
    temporary.replace(path)


def main():
    # Raised weapons have dedicated source cells so their tips cannot collide
    # with the previous row's feet. Head-to-sole measurements are reviewed once
    # on that source atlas and retained alongside it.
    anchors = json.loads((SOURCE/'overhead-anchors.json').read_text())
    raised = atlas_cells(SOURCE/'finished-overhead.png',2,1)
    raised_frames = [prepare(cell,anchor['body_height']) for cell,anchor in zip(raised,anchors)]
    for n in [8,10]:
        cells = atlas_cells(SOURCE/f'finished-{n}.png',n//2,4)
        overhead = [2] if n == 8 else [2,3]
        frames = [None if i-n in overhead else prepare(cell) for i,cell in enumerate(cells)]
        for j,index in enumerate(overhead):
            frames[n+index] = raised_frames[j]
        assert len(frames)==n*2
        folder = ROOT / ('assets/sprites/heroes/knight' if n==10 else 'assets/sprites/variants/knight_8')
        for j,anim in enumerate(['run','attack']):
            strip(folder/f'{anim}.png',frames[j*n:(j+1)*n])
    idle = [prepare(cell) for cell in atlas_cells(SOURCE/'finished-idle.png',2,2)]
    strip(ROOT/'assets/sprites/heroes/knight/idle.png',idle)
    shutil.copyfile(ROOT/'assets/sprites/heroes/knight/idle.png',ROOT/'assets/sprites/variants/knight_8/idle.png')
    (SOURCE/'packing.json').write_text(json.dumps({'frame_size':SIZE,'body_height_target':250,
        'foot_baseline':SIZE*15/16,'runtime':10,'alternative':8,'idle':4,
        'overhead_frames':{'8':[2],'10':[2,3]},
        'finish':'AI-assisted painted finish over Blender pose guides; not raw 3D renders'},indent=2)+'\n')
    print('KNIGHT PACK OK: default 10 run/attack, alternative 8, idle 4')


if __name__=='__main__':
    main()
