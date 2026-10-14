"""Register the original generated PNG; no pixel edits or anisotropic scaling."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

old_manifest = json.loads((ROOT/'art/props/factory_v44/manifest.json').read_text(encoding='utf-8'))
original = next(a for a in old_manifest['assets'] if a['id'] == 'bedside_cabinet_v44')
asset = original.copy()
width, height = 953, 671
scale = 64 / width
depth = 30 / scale
asset.update(texture='res://art/props/bedside_v51/bedside_cabinet.png',
             texture_size=[1316, 1195], region=[185, 256, width, height],
             ground_rect=[0, height-depth, width, depth],
             footprint_world_size=[64, 30], world_size=[64, height*scale],
             render_size=[64, height*scale], elevation_world=height*scale-30,
             authoring_set='bedside-v51',
             editor_icon='res://art/props/bedside_v51/editor_icon.tres',
             sha256=hashlib.sha256((ROOT/'art/props/bedside_v51/bedside_cabinet.png').read_bytes()).hexdigest())
save(ROOT/'art/props/bedside_v51/manifest.json', dict(schema=2, version='bedside-v51', assets=[asset]))
settings_path = ROOT/'data/presentation/prop_proportions.json'
settings = json.loads(settings_path.read_text(encoding='utf-8'))
settings['widths_at_reference']['bedside_cabinet_v44'] = 64
save(settings_path, settings)
room_path = ROOT/'data/rooms/r04.json'
room = json.loads(room_path.read_text(encoding='utf-8'))
changes = []
for fixture in room['fixtures']:
    if fixture['asset_id'] != 'bedside_cabinet_v44':
        continue
    old = fixture['rect'][:]
    name = fixture['id']
    if name.startswith('detail44-dorm-personal-'):
        i = int(name.rsplit('-', 1)[1])
        feet = 1377 + 340*i
        x = 285
    else:
        i = int(name.rsplit('-', 1)[1])
        bed = next(f for f in room['fixtures'] if f['id'] == f'campus-dorm-bed-{i}')
        # Keep the same relation to the mattress head as the main dorms.
        feet = bed['rect'][1] + bed['rect'][3] - 153
        x = bed['rect'][0] + bed['rect'][2] + 10
    fixture['rect'] = [x, round(feet-30, 4), 64, 30]
    fixture.pop('render_size', None)
    if 'draw_depth' in fixture:
        fixture['draw_depth'] = feet
    changes.append(dict(id=name, before=old, after=fixture['rect']))
save(room_path, room)
save(ROOT/'docs/dev/p118/placement.json', dict(original_source=original, replacement=asset, placements=changes))
print(json.dumps(dict(replaced_instances=len(changes), render_size=asset['render_size'], footprint=asset['footprint_world_size'])))
