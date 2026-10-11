"""Full-body L corners and tightly framed 20-unit gate definitions."""
from pathlib import Path
import copy, hashlib, json

root = Path(__file__).resolve().parents[3]
art = root / 'art/architecture/v37'
icons = root / 'art/editor/v16/icons'
art.mkdir(parents=True, exist_ok=True)
icons.mkdir(parents=True, exist_ok=True)
old = json.loads((root / 'art/architecture/v36/manifest.json').read_text('utf-8'))
assets = []

def patch(source, destination):
    return dict(source=source, destination=destination, modulate=[1,1,1,1], mirror_x=False, role='complete_wall_body')

for code, label in [('se','左上 · 向右 / 下'), ('sw','右上 · 向左 / 下'), ('ne','左下 · 向右 / 上'), ('nw','右下 · 向左 / 上')]:
    a = copy.deepcopy(next(a for a in old['assets'] if a['id'] == 'prison_corner_' + code))
    a.update(id='prison_l_' + code, name='L型弧角 · ' + label, authoring_set='universal-v37')
    east, south = code.endswith('e'), code.startswith('s')
    stem = 0 if east else 20
    # Keep the T junction's inner curve on the open side. The closed side
    # uses a continuous upright face, so there is no third arm or orphan arc.
    # All pieces form one full-body grid tile, not a coping overlay.
    bend_height = 106 * 120 / 370
    open_half = patch([770 if east else 710,130,60,106], [stem+(10 if east else 0),0,10,bend_height])
    closed_half = patch([710 if east else 770,250,60,106], [stem+(0 if east else 10),0,10,bend_height])
    if south:
        body = [patch([710,236,120,264], [stem,bend_height,20,120-bend_height])]
    else:
        body = [patch([710,754,120,128], [stem,bend_height,20,88-bend_height]), patch([710,882,120,88], [stem,88,20,32])]
    wing = patch([830 if east else 590,130,120,370], [20 if east else 0,0,20,120])
    a['assembly_patches'] = [closed_half,open_half] + body + [wing]
    a['corner_shape'] = 'rounded-two-port'
    a['editor_icon'] = f"res://art/editor/v16/icons/{a['id']}.tres"
    assets.append(a)

gate_texture = 'res://art/architecture/v23/cafeteria_gate_pair_v23.png'
sha = hashlib.sha256((root / gate_texture.removeprefix('res://')).read_bytes()).hexdigest()
for state, x in [('closed',59), ('open',1087)]:
    ident = 'prison_gate_' + state + '_v37'
    assets.append(dict(id=ident, name='栅栏门 · ' + ('关闭' if state=='closed' else '开启') + ' · 9×5格',
        texture=gate_texture, texture_size=[2095,751], region=[x,91,946,550],
        world_size=[180,100], render_size=[180,100], footprint_world_size=[180,20],
        render_mode='embedded_door', blocking=state=='closed', interactive=False,
        state=state, state_driven=True, pair='prison_gate_v37', authoring_set='universal-v37',
        alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
        grid_door=dict(cell=20, columns=9, rows=5), sha256=sha,
        editor_icon=f'res://art/editor/v16/icons/{ident}.tres'))

manifest = dict(schema=2, version='prison-l-gate-v37', assets=assets)
(art / 'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n','utf-8')
paired = dict(schema=1, assets=[dict(id=a['id'], name=a['name'], editor_icon=a['editor_icon'], category='furniture') for a in assets], tools=[])
(root / 'art/editor/v16/manifest.json').write_text(json.dumps(paired,ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps(dict(assets=len(assets), gate_frame=[180,100], gate_footprint=[180,20])))
