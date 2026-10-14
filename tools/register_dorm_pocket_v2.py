"""Register original generated RGBA using native regions and shared frame pieces."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r'C:\Users\gst20\.codex\generated_images\01a12f0d-4fc4-7dd2-b6a0-d189a674ef6e\exec-f94a8506-f6c9-4b40-b3c7-d9d122fd77a4.png')
folder = ROOT / 'art/architecture/dorm_door_v1'
target = folder / 'pocket-components-v2.png'
shutil.copyfile(SOURCE, target)
sha = hashlib.sha256(target.read_bytes()).hexdigest()
path = folder / 'manifest.json'
manifest = json.loads(path.read_text(encoding='utf-8'))
common = dict(texture='res://art/architecture/dorm_door_v1/pocket-components-v2.png', texture_size=[1536,1024], sha256=sha, source_kind='built-in-imagegen-original-png', runtime_size_limit=1024)
regions = {'dorm_pocket_open_frame_v2':[428,21,104,982], 'dorm_pocket_closed_frame_v2':[1005,21,104,982]}
manifest['assets'] = [a for a in manifest['assets'] if a['id'] not in regions]
for asset_id, region in regions.items():
    manifest['assets'].append(dict(common,id=asset_id,region=region,editor_hidden=True))

def patch(asset, source, destination):
    return dict(asset=asset,source=source,destination=destination,rotation_quarters=3)

top = patch('dorm_pocket_open_frame_v2',[0,0,1,0.15],[0,0,14,28])
bottom = patch('dorm_pocket_open_frame_v2',[0,0.85,1,0.15],[186,0,14,28])
middle = patch('dorm_pocket_open_frame_v2',[0,0.15,1,0.7],[14,0,172,28])
middle['ground_level'] = True
closed_middle = patch('dorm_pocket_closed_frame_v2',[0,0.15,1,0.7],[14,0,172,28])
presentation = dict(raised_door=True,piece_depth=True,clear_wall_facade=True,
    side_aperture_span=200,door_art_size=[200,20],door_art='doorway_dorm_side_open_v1',door_art_closed='doorway_dorm_side_closed_v1',
    door_open_patches=[top,bottom,middle],door_closed_patches=[closed_middle,top,bottom],
    visual_solid_parts=[[0,0,14,28],[186,0,14,28]],
    closed_visual_solid_parts=[[0,0,14,28],[186,0,14,28],[14,0,172,28]],
    body_profile='full_body',states=['closed','fully-open'],manual_door=True,
    closure_padding=[16,0,4,0],expose_closed_frame=True,roof_occludes_door=True,
    passage_body_center=[100,10],design='in-wall-pocket-v2')
for asset in manifest['assets']:
    if asset['id'] not in ('doorway_dorm_side_open_v1','doorway_dorm_side_closed_v1'): continue
    asset.update(common)
    asset.update(region=regions['dorm_pocket_open_frame_v2' if 'open' in asset['id'] else 'dorm_pocket_closed_frame_v2'],
        name='宿舍宽口移门 · '+('全开' if 'open' in asset['id'] else '关闭'),world_size=[20,200],render_size=[20,200],ground_rect=[0,0,104,982],door_presentation=presentation)
manifest['version']='dorm-pocket-v2'
path.write_bytes((json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
record = dict(generator='built-in imagegen',source=str(SOURCE),asset=str(target),sha256=sha,regions=regions,aperture=200,clear_span=172,body_height=100)
(ROOT/'docs/art/dorm-pocket-v2/registration.json').write_bytes((json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
print(json.dumps(record,ensure_ascii=False))
