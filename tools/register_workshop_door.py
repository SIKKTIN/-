"""Register original door atlas with shared frame and two leaf states.

Existing door IDs are compatible overrides, so saved and unsaved maps retain
their geometry, associations, schedule and inventory data without rewriting.
"""
from copy import deepcopy
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art/architecture/workshop_door_v2'
DOC = ROOT / 'docs/art/workshop-one-restoration/door-v2'

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')

def register():
    path = ART / 'components.png'
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    with Image.open(path) as image:
        assert image.mode == 'RGBA' and image.size == (2172,724)
        assert image.getchannel('A').getextrema() == (0,255)
    assets = []
    for key, region in [
        ('frame',[55,91,755,516]),
        ('closed_leaves',[923,164,498,432]),
        ('open_left',[1578,117,75,476]),
        ('open_right',[1992,117,71,476]),
    ]:
        assets.append(dict(id='workshop_door_v2_'+key, texture='res://art/architecture/workshop_door_v2/components.png',
            texture_size=[2172,724],region=region,sha256=sha,source_kind='built-in-imagegen-original-png',
            editor_hidden=True,runtime_size_limit=768))
    def patch(key, rect):
        return dict(asset='workshop_door_v2_'+key,source=[0,0,1,1],destination=rect)
    frame = patch('frame',[0,0,180,120])
    opened = [patch('open_left',[23,19,18,101]),patch('open_right',[139,19,18,101]),frame]
    closed = [patch('closed_leaves',[23,19,134,101]),frame]
    presentation = dict(raised_door=True,clear_wall_facade=True,body_depth_limited=True,door_art_size=[180,120],
        door_art='doorway_workshop_open_v2',door_art_closed='doorway_workshop_closed_v2',
        door_open_patches=opened,door_closed_patches=closed,
        visual_solid_parts=[[0,18,41,102],[139,18,41,102]],
        closed_visual_solid_parts=[[0,18,180,102]],body_profile='human_silhouette',
        states=['closed','fully-open'])
    for state, key in [('open','frame'),('closed','closed_leaves')]:
        asset = deepcopy(next(a for a in assets if a['id']=='workshop_door_v2_'+key))
        asset.update(id='doorway_workshop_'+state+'_v2',name='一号车间统一钢门 · '+('全开' if state=='open' else '关闭'),
            render_mode='embedded_door',world_size=[180,120],render_size=[180,120],footprint_world_size=[160,20],
            ground_rect=[0,0,*asset['region'][2:]],blocking=False,grid_door={'cell':20},editor_subcategory='doors',
            door_presentation=deepcopy(presentation),editor_hidden=False)
        assets.append(asset)
        alias = deepcopy(asset)
        alias.update(id='doorway_workshop_'+state+'_v1',replacement_asset=asset['id'],editor_hidden=True)
        assets.append(alias)
    write(ART/'manifest.json',dict(schema=2,version='workshop-door-v2',assets=assets))
    write(DOC/'asset-registration.json',dict(original_png=str(path),sha256=sha,regions=assets[:4],
        shared_frame=frame,closed=closed,fully_open=opened,map_modified=False,
        legacy_ids=['doorway_workshop_open_v1','doorway_workshop_closed_v1']))
    print('Registered shared door frame and two leaf states; no map file modified.')

if __name__ == '__main__': register()
