"""Register the approved replacement walk PNG without changing its pixels or idle."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/dev/older-worker-walk'
MANIFEST = ROOT / 'art/characters/factory_cast_v47/manifest.json'
TARGET = ROOT / 'art/characters/factory_cast_v47/older_worker_walk_v2.png'


def register(source):
    image = Image.open(source)
    assert image.mode == 'RGBA' and image.getchannel('A').getextrema()[0] == 0
    mask = image.getchannel('A').point(lambda value: 255 if value >= 24 else 0)

    def cuts(axis, count):
        length = image.width if axis == 'x' else image.height
        gaps, start = [], None
        for n in range(length):
            line = (n, 0, n+1, image.height) if axis == 'x' else (0, n, image.width, n+1)
            empty = mask.crop(line).getbbox() is None
            if empty and start is None:
                start = n
            elif not empty and start is not None:
                if n-start >= 4:
                    gaps.append((start, n))
                start = None
        result = [0]
        for division in range(1, count):
            target = length * division / count
            candidates = [g for g in gaps if abs(sum(g)/2-target) < length/count*.35]
            assert candidates, (axis, division, 'No clear separator')
            gap = min(candidates, key=lambda g: abs(sum(g)/2-target))
            result.append(round(sum(gap)/2))
        return result + [length]

    xs, ys = cuts('x', 4), cuts('y', 2)
    frames, statistics = [], []
    for index in range(8):
        column, row = index % 4, index // 4
        cell = (xs[column], ys[row], xs[column+1], ys[row+1])
        x0, y0, x1, y1 = mask.crop(cell).getbbox()
        height = y1-y0
        head = mask.crop((cell[0]+x0, cell[1]+y0+round(height*.08),
                          cell[0]+x1, cell[1]+y0+round(height*.30))).getbbox()
        head_axis = cell[0]+x0+(head[0]+head[2])/2
        x, y = max(cell[0], cell[0]+x0-3), max(cell[1], cell[1]+y0-3)
        right, bottom = min(cell[2], cell[0]+x1+3), min(cell[3], cell[1]+y1+3)
        frames.append(dict(id=f'walk_{index}', region=[x, y, right-x, bottom-y],
                           anchor=[round(head_axis-x, 3), cell[1]+y1-y]))
        statistics.append(dict(index=index, cell=cell, body_height=height,
                               head_axis=head_axis, top_to_floor=cell[1]+y1-y))

    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    asset = next(a for a in manifest['characters'] if a['id'] == 'older_worker')
    OUT.mkdir(parents=True, exist_ok=True)
    baseline = OUT / 'previous-walk.json'
    if not baseline.exists():
        baseline.write_text(json.dumps(asset['walk_animation'], indent=2)+'\n', encoding='utf-8')
    shutil.copy2(source, TARGET)
    digest = hashlib.sha256(TARGET.read_bytes()).hexdigest()
    scale = sorted(f['region'][3] for f in frames)[4]
    asset['walk_animation'] = dict(texture='res://'+TARGET.relative_to(ROOT).as_posix(),
                                  texture_size=list(image.size), fps=8, scale_height=scale,
                                  frames=frames, sha256=digest,
                                  source_kind='built-in-imagegen-original-png')
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    report = dict(source=str(source), texture=asset['walk_animation']['texture'], sha256=digest,
                  texture_size=list(image.size), frames=frames, registration=statistics,
                  idle_preserved=True, policy='PNG bytes unchanged; head axis and foot origin registered as metadata')
    (OUT / 'registration.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, ensure_ascii=True, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    register(parser.parse_args().source)
