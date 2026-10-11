"""Register unchanged generated PNGs; inspect alpha for frame metadata only."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ART = ROOT / 'art/characters/factory_occupations_v48'
SRC = Path('C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0')
ROLES = [
    ('canteen_cook', '食堂师傅', '7bb53d06-d8c2-4bb9-809b-8cec3a6e7aa3', 62),
    ('clinic_medic', '医务人员', '28710ebc-2ce4-40f5-a10a-3baa00002662', 60),
    ('maintenance_technician', '维修师傅', 'e6aa325c-15af-4a55-a700-387a488a951e', 60),
    ('warehouse_clerk', '仓库管理员', '25dc67b5-b496-460c-aa0b-99ddbcf423d5', 61),
    ('truck_driver', '货车司机', 'd9e10843-465e-486e-80a2-798705ed6b16', 62),
    ('cleaner', '清洁人员', '3fb13271-f758-4d9a-a4dd-7485347203cf', 58),
]

def separators(mask, axis, identity):
    length = mask.height if axis == 'row' else mask.width
    gaps, start = [], None
    for n in range(length):
        band = (0, n, mask.width, n+1) if axis == 'row' else (n, 0, n+1, mask.height)
        empty = mask.crop(band).getbbox() is None
        if empty and start is None:
            start = n
        if not empty and start is not None:
            if n-start >= 3:
                gaps.append((start, n))
            start = None
    cuts = [0]
    for j in (1, 2):
        goal = length*j/3
        candidates = [g for g in gaps if abs(sum(g)/2-goal) < length*.14]
        assert candidates, (identity, axis, goal)
        gap = min(candidates, key=lambda g: abs(sum(g)/2-goal))
        cuts.append(round(sum(gap)/2))
    return cuts+[length]

ART.mkdir(parents=True, exist_ok=True)
characters, originals = [], []
for identity, name, source_id, height in ROLES:
    source = SRC / ('exec-'+source_id+'.png')
    target = ART / (identity+'_idle_walk8.png')
    shutil.copy2(source, target)
    im = Image.open(source)
    assert im.mode == 'RGBA' and im.getchannel('A').getextrema()[0] == 0
    mask = im.getchannel('A').point(lambda a: 255 if a >= 24 else 0)
    rows, cols = separators(mask, 'row', identity), separators(mask, 'col', identity)
    frames, stats = [], []
    for i in range(9):
        col, row = i % 3, i // 3
        cell = (cols[col], rows[row], cols[col+1], rows[row+1])
        box = mask.crop(cell).getbbox()
        assert box, (identity, i)
        x0, y0, x1, y1 = box
        head = mask.crop((cell[0]+x0, cell[1]+y0+round((y1-y0)*.08), cell[0]+x1, cell[1]+y0+round((y1-y0)*.30))).getbbox()
        axis = cell[0]+x0+(head[0]+head[2])/2
        x, y = max(cell[0], cell[0]+x0-3), max(cell[1], cell[1]+y0-3)
        right, bottom = min(cell[2], cell[0]+x1+3), min(cell[3], cell[1]+y1+3)
        frames.append(dict(id='idle' if i == 0 else 'walk_'+str(i-1), region=[x, y, right-x, bottom-y], anchor=[round(axis-x, 3), cell[1]+y1-y]))
        stats.append(dict(body_height=y1-y0, body_width=x1-x0, cell=list(cell), head_axis=axis))
    idle, walk = frames[0], frames[1:]
    scale_height = idle['region'][3]
    texture = 'res://art/characters/factory_occupations_v48/'+target.name
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    assert hashlib.sha256(target.read_bytes()).hexdigest() == digest
    asset = dict(id=identity, name=name, texture=texture, texture_size=list(im.size), world_height=height, scale_height=scale_height,
        frames={'idle': idle['region'], 'walk_a': walk[0]['region'], 'walk_b': walk[4]['region']},
        anchor={'idle': idle['anchor'], 'walk_a': walk[0]['anchor'], 'walk_b': walk[4]['anchor']},
        portrait_region=[idle['region'][0], idle['region'][1], idle['region'][2], round(idle['region'][3]*.55)],
        initial_walk_frame_seconds=.15, shadow_baked=False,
        walk_animation=dict(texture=texture, fps=12, scale_height=scale_height, frames=walk),
        source_kind='built-in-imagegen-original-png', sha256=digest)
    characters.append(asset)
    originals.append(dict(id=identity, name=name, original=str(source), project=str(target), sha256=digest, size=list(im.size), frames=stats))

def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

save(ART/'manifest.json', dict(schema=1, version='factory-occupations-v48', characters=characters))
save(OUT/'registration.json', dict(originals=originals, characters=characters, policy='Original PNG bytes unchanged. Only alpha regions, head axes, foot anchors and shared pose scale registered.'))
print(json.dumps(dict(characters=len(characters), idle_frames=len(characters), walk_frames=8*len(characters))))
