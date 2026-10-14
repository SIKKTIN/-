"""Register the unmodified generated painting using native UV patches."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ART = ROOT / 'art/architecture/v53'
EDITOR = ROOT / 'art/editor/v25'
ART.mkdir(parents=True, exist_ok=True)
(EDITOR / 'icons').mkdir(parents=True, exist_ok=True)
ASSET_ID = 'prison_t_w_round_v53'
TEXTURE = 'res://art/architecture/v53/three_way_west.png'
master = json.loads((ROOT / 'art/architecture/v36/manifest.json').read_text('utf-8'))
asset = copy.deepcopy(next(a for a in master['assets'] if a['id'] == 'prison_t_w'))
asset.update(
    id=ASSET_ID, name='T形弧接 · 上 / 下 / 左 · 2×7格',
    texture=TEXTURE, texture_size=[1073, 1466], region=[488, 420, 200, 508],
    world_size=[40, 140], render_size=[40, 140],
    authoring_set='universal-v53', connection_tag='north,south,west/40x140',
    junction_shape='continuous-rounded-three-port',
    alpha_core_shader='res://art/architecture/v53/junction-ports.gdshader',
    collision_parts=[[0, 120, 40, 20], [20, 0, 20, 140]],
    editor_subcategory='tiles_junction',
    editor_icon=f'res://art/editor/v25/icons/{ASSET_ID}.tres',
    sha256=hashlib.sha256((ROOT / TEXTURE.removeprefix('res://')).read_bytes()).hexdigest(),
)
asset['grid_tile'].update(rows=7, horizontal_offset=20, horizontal_extent=120,
    port_reference_texture='res://art/architecture/v33/full_wall_master_v33.png')
asset['assembly_patches'] = []
def patch(source, destination):
    asset['assembly_patches'].append(dict(source=source, destination=destination,
        modulate=[1, 1, 1, 1], mirror_x=False, role='complete_wall_body'))
patch([588, 420, 96, 54], [20, 0, 20, 20])
for sy, sh, dy, dh in [(474, 88, 20, 30.5), (562, 273, 50.5, 57.5), (835, 90, 108, 32)]:
    patch([492, sy, 96, sh], [0, dy, 20, dh])
    patch([588, sy, 96, sh], [20, dy, 20, dh])

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', 'utf-8')
write(ART / 'manifest.json', dict(schema=2, version='three-way-junction-v53', assets=[asset]))
write(EDITOR / 'manifest.json', dict(schema=1, assets=[dict(id=ASSET_ID,
    name=asset['name'], editor_icon=asset['editor_icon'], category='furniture')], tools=[]))
map_path = ROOT / 'data/rooms/r04.json'
data = json.loads(map_path.read_text('utf-8'))
before = ROOT / 'docs/dev/p133/r04-before.json'
if not before.exists():
    before.write_bytes(map_path.read_bytes())
index = next(i for i, w in enumerate(data['walls']) if w == [660, 3220, 40, 140])
surface = next(s for s in data['architecture']['wall_surfaces'] if s['wall_index'] == index)
assert surface['collision_parts'] == asset['collision_parts']
previous = next(s['grid_tile_asset'] for s in json.loads(before.read_text('utf-8'))['architecture']['wall_surfaces'] if s['wall_index'] == index)
surface['grid_tile_asset'] = ASSET_ID
write(map_path, data)
write(ROOT / 'docs/dev/p133/integration.json', dict(asset=ASSET_ID,
    wall_index=index, rect=data['walls'][index], previous_asset=previous,
    collision_unchanged=True, image_sha256=asset['sha256']))
print('Registered one three-way junction and updated R04 wall', index)
