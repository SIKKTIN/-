"""Register imagegen's three original RGBA atlases using metadata only."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from statistics import median
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art/characters/player_overhead_v50'
DOC = ROOT / 'docs/art/player-overhead-v50'


def inspect(source):
    image = Image.open(source)
    assert image.mode == 'RGBA' and image.getchannel('A').getextrema()[0] == 0
    mask = image.getchannel('A').point(lambda value: 255 if value >= 24 else 0)

    def cuts(axis):
        length = image.width if axis == 'x' else image.height
        gaps, begin = [], None
        for position in range(length):
            line = (position, 0, position+1, image.height) if axis == 'x' else (0, position, image.width, position+1)
            empty = mask.crop(line).getbbox() is None
            if empty and begin is None:
                begin = position
            elif not empty and begin is not None:
                if position-begin >= 4:
                    gaps.append((begin, position))
                begin = None
        result = [0]
        for division in [1, 2]:
            target = length*division/3
            choices = [gap for gap in gaps if abs(sum(gap)/2-target) < length/3*.35]
            assert choices, (source, axis, division, 'Missing transparent separator')
            result.append(round(sum(min(choices, key=lambda gap: abs(sum(gap)/2-target)))/2))
        return result+[length]

    xs, ys = cuts('x'), cuts('y')
    frames, statistics = [], []
    for index in range(9):
        col, row = index % 3, index // 3
        cell = (xs[col], ys[row], xs[col+1], ys[row+1])
        bounds = mask.crop(cell).getbbox()
        assert bounds, (source, index, 'Empty frame')
        x0, y0, x1, y1 = bounds
        height = y1-y0
        crown = mask.crop((cell[0]+x0, cell[1]+y0+round(height*.08), cell[0]+x1, cell[1]+y0+round(height*.30))).getbbox()
        axis = cell[0]+x0+(crown[0]+crown[2])/2
        x, y = max(cell[0], cell[0]+x0-3), max(cell[1], cell[1]+y0-3)
        end_x, end_y = min(cell[2], cell[0]+x1+3), min(cell[3], cell[1]+y1+3)
        frames.append(dict(id='idle' if index == 0 else f'walk_{index-1}', region=[x, y, end_x-x, end_y-y], anchor=[axis-x, cell[1]+y1-y]))
        statistics.append(dict(index=index, cell=list(cell), body_height=height, crown_axis=axis))
    return frames, statistics, list(image.size)


def register(sources):
    ART.mkdir(parents=True, exist_ok=True)
    DOC.mkdir(parents=True, exist_ok=True)
    variants, report = {}, {}
    analyses = {direction: inspect(source) for direction, source in sources.items()}
    # One projection scale across all directions, with per-frame foot origins.
    scale_height = median(stat['body_height'] for _, stats, _ in analyses.values() for stat in stats)
    for direction, source in sources.items():
        target = ART / (direction+'_idle_walk8.png')
        shutil.copy2(source, target)
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        assert digest == hashlib.sha256(source.read_bytes()).hexdigest()
        frames, stats, dimensions = analyses[direction]
        path = 'res://'+target.relative_to(ROOT).as_posix()
        idle, walks = frames[0], frames[1:]
        variants[direction] = dict(texture=path, texture_size=dimensions, sha256=digest, scale_height=scale_height,
            frames=dict(idle=idle['region'], walk_a=walks[0]['region'], walk_b=walks[4]['region']),
            anchor=dict(idle=idle['anchor'], walk_a=walks[0]['anchor'], walk_b=walks[4]['anchor']),
            walk_animation=dict(texture=path, fps=10, scale_height=scale_height, frames=walks))
        report[direction] = dict(source=str(source), sha256=digest, dimensions=dimensions, registration=stats, frames=frames)
    asset = dict(id='player_overhead_v50', name='林川 · 俯视试用', world_height=60, initial_walk_frame_seconds=.1,
                 shadow_baked=False, source_kind='built-in-imagegen-original-RGBA', directional_variants=variants)
    asset.update(variants['down'])
    idle_region = asset['frames']['idle']
    asset['portrait_region'] = [idle_region[0], idle_region[1], idle_region[2], round(idle_region[3]*.63)]
    (ART/'manifest.json').write_text(json.dumps(dict(schema=1, characters=[asset]), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    catalog_path = ROOT/'data/presentation/character_libraries.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8-sig'))
    new_path = 'res://art/characters/player_overhead_v50/manifest.json'
    if new_path not in catalog['libraries']:
        catalog['libraries'].append(new_path)
        catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    room_path = ROOT/'data/rooms/r04.json'
    room = json.loads(room_path.read_text(encoding='utf-8-sig'))
    before = room.get('character_appearances', {}).copy()
    room.setdefault('character_appearances', {})['actor:0'] = asset['id']
    room_path.write_text(json.dumps(room, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (DOC/'registration.json').write_text(json.dumps(dict(scale_height=scale_height, atlases=report,
        previous_appearance=before.get('actor:0',''), activated_only='r04.actor:0',
        policy='Original PNG bytes unchanged; atlas regions and registered feet are metadata'), ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(scale_height=scale_height, frames_per_direction=9, directions=list(variants), activated_only='r04.actor:0')))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for direction in ['down', 'up', 'right']:
        parser.add_argument('--'+direction, required=True, type=Path)
    args = parser.parse_args()
    register({direction: getattr(args, direction) for direction in ['down', 'up', 'right']})
