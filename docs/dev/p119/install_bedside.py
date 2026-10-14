"""Register the revised PNG unchanged and calibrate its floor registration."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]

def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

path = ROOT/'art/props/bedside_v51/bedside_cabinet_v2.png'
# Read alpha to register the crop; never crop, resize or repaint the PNG.
with Image.open(path) as image:
    texture_size = list(image.size)
    bounds = image.getchannel('A').point(lambda a: 255 if a >= 16 else 0).getbbox()
    left, top, right, bottom = bounds
    left, top = max(0, left-2), max(0, top-2)
    right, bottom = min(image.width, right+2), min(image.height, bottom+2)
region = [left, top, right-left, bottom-top]
width, height = region[2:]
scale = 64/width
depth = 26/scale
manifest_path = ROOT/'art/props/bedside_v51/manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['version'] = 'bedside-v51-revision-2'
asset = manifest['assets'][0]
asset.update(texture='res://art/props/bedside_v51/bedside_cabinet_v2.png',
             texture_size=texture_size, region=region,
             ground_rect=[0, height-depth, width, depth],
             footprint_world_size=[64, 26], world_size=[64, height*scale],
             render_size=[64, height*scale], elevation_world=height*scale-26,
             sha256=hashlib.sha256(path.read_bytes()).hexdigest())
save(manifest_path, manifest)
icon_path = ROOT/'art/props/bedside_v51/editor_icon.tres'
icon_path.write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                    '[ext_resource type="Texture2D" path="'+asset['texture']+'" id="1"]\n\n'
                    '[resource]\natlas = ExtResource("1")\n'
                    'region = Rect2('+', '.join(map(str, region))+')\nfilter_clip = true\n', encoding='utf-8')
room_path = ROOT/'data/rooms/r04.json'
room = json.loads(room_path.read_text(encoding='utf-8'))
placements = []
for fixture in room['fixtures']:
    if fixture['asset_id'] != 'bedside_cabinet_v44': continue
    name = fixture['id']
    before = fixture['rect'][:]
    i = int(name.rsplit('-', 1)[1])
    if name.startswith('detail44-dorm-personal-'):
        x, feet = 285, 1393+340*i
    else:
        bed = next(f for f in room['fixtures'] if f['id'] == f'campus-dorm-bed-{i}')
        x = bed['rect'][0]+bed['rect'][2]+10
        feet = bed['rect'][1]+bed['rect'][3]-137
    fixture['rect'] = [x, round(feet-26, 4), 64, 26]
    if 'draw_depth' in fixture: fixture['draw_depth'] = feet
    placements.append(dict(id=name, before=before, after=fixture['rect']))
save(room_path, room)
save(ROOT/'docs/dev/p119/registration.json', dict(asset=asset, placements=placements))
print(json.dumps(dict(render_size=asset['render_size'], front_height=asset['elevation_world'],
                      crop=region, footprint=[64,26], instances=len(placements))))
