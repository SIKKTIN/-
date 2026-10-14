"""Register original office sprites and restore only the saved office footprint."""
from copy import deepcopy
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image
from compact_clinic import contains_wall

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'docs/art/office-restoration'
TARGET = [4260, 660, 460, 440]
SHADER = 'res://art/architecture/v25/safe_edges_v25.gdshader'

def read(path):
    return json.loads(path.read_bytes())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')

def definitions():
    # Read alpha bounds without changing generated pixels. World ground and
    # visible height are calibrated independently of the padded source PNG.
    specs = {'archive': (155, 42), 'desk': (180, 70), 'cabinet': (44, 32),
             'sideboard': (44, 155), 'work_chair': (44, 30),
             'visitor_chair': (40, 26), 'sign': (95, 1)}
    names = {'archive': '木质档案柜', 'desk': '行政办公桌', 'cabinet': '铁皮文件柜',
             'sideboard': '窄保管柜', 'work_chair': '办公椅',
             'visitor_chair': '接待椅', 'sign': '办公室门牌'}
    assets = []
    records = []
    for item in read(DOC/'generated-assets.json')['assets']:
        key = item['key']
        path = ROOT/item['path']
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(item['source'], path)
        assert digest(path) == digest(Path(item['source']))
        image = Image.open(path)
        assert image.mode == 'RGBA' and image.getchannel('A').getextrema()[0] == 0, key
        bounds = image.getchannel('A').point(lambda alpha: 255 if alpha >= 180 else 0).getbbox()
        assert bounds, key
        left, top, right, bottom = bounds
        left = max(0, left-3); top = max(0, top-3)
        right = min(image.width, right+3); bottom = min(image.height, bottom+3)
        width, height = right-left, bottom-top
        world_width, ground_height = specs[key]
        scale = world_width/width
        visible_height = height*scale
        asset = dict(id='office_'+key+'_v1', name='办公室 · '+names[key],
                     texture='res://'+item['path'], texture_size=list(image.size),
                     region=[left, top, width, height], ground_rect=[0, height-ground_height/scale, width, ground_height/scale],
                     world_size=[world_width, visible_height], render_size=[world_width, visible_height],
                     footprint_world_size=[world_width, ground_height], elevation_world=visible_height-ground_height,
                     render_mode='projected_prop', blocking=key!='sign', interactive=False,
                     shadow_baked=True, proportion_locked=True, authoring_set='office-v1',
                     editor_subcategory='attachments' if key=='sign' else 'furnishings',
                     alpha_core_shader=SHADER, source_kind='built-in-imagegen-original-png', sha256=digest(path))
        asset['runtime_size_limit'] = 256 if key.endswith('chair') else 512
        if key=='sign':
            # The ground anchor remains inside the room while art is placed on
            # the front lintel, as with the existing duty-room name plaque.
            asset['ground_rect'] = [0, height+30/scale, width, 1/scale]
            asset['elevation_world'] = visible_height+30
            asset['render_mode'] = 'wall_attachment'
        assets.append(asset)
        records.append(dict(key=key, source=item['source'], path=item['path'], sha256=digest(path), region=asset['region']))
    legacy = {a['id']: a for folder in ['art/props/duty_room_v1', 'art/props/prison_v17']
              for a in read(ROOT/folder/'manifest.json')['assets']}
    for key, source, name, width, lift in [('clock','duty_clock_v1','办公室挂钟',25,80),
                                         ('board','notice_board','办公室公告板',80,70)]:
        asset = deepcopy(legacy[source])
        asset.pop('editor_icon', None)
        sw, sh = asset['region'][2:]
        scale = width/sw
        asset.update(id='office_'+key+'_v1', name='办公室 · '+name,
                     world_size=[width, sh*scale], render_size=[width, sh*scale],
                     ground_rect=[0, sh+lift/scale, sw, 1/scale], footprint_world_size=[width,1],
                     elevation_world=sh*scale+lift, render_mode='wall_attachment',
                     blocking=False, shadow_baked=True, proportion_locked=True,
                     editor_subcategory='attachments', authoring_set='office-v1')
        assets.append(asset)
    write(ROOT/'art/props/office_v1/manifest.json', dict(schema=2, version='office-v1', assets=assets))
    write(DOC/'asset-registration.json', dict(mode='built-in imagegen', assets=records))
    return {asset['id']: asset for asset in assets}

def restore_map(assets):
    path = ROOT/'data/rooms/r04.json'
    before = path.read_bytes(); original_digest = digest(path)
    room = json.loads(before)
    previous = next(v['rect'] for v in room['visibility_rooms'] if v['id']=='office')
    selected = {i for i, rect in enumerate(room['walls']) if contains_wall(previous, rect)}
    surfaces = {int(v['wall_index']): v for v in room['architecture']['wall_surfaces']}
    templates = {surfaces[i]['grid_tile_asset']: deepcopy(surfaces[i]) for i in selected}
    # A compact room may use only long stems. Keep repeat registration valid
    # without depending on a short stem being present in the previous layout.
    if 'prison_v_short' not in templates and 'prison_v_long' in templates:
        templates['prison_v_short'] = deepcopy(templates['prison_v_long'])
        templates['prison_v_short']['grid_tile_asset'] = 'prison_v_short'
    assert all(key in templates for key in ['prison_l_se','prison_l_sw','prison_l_ne','prison_l_nw',
                                             'prison_h_c','prison_h_short_c','prison_v_long','prison_v_short',
                                             'prison_lintel_80','prison_lintel_20'])
    walls = []; remap = {}; wall_surfaces = []
    for index, rect in enumerate(room['walls']):
        if index not in selected:
            remap[index] = len(walls); walls.append(deepcopy(rect))
    for index, surface in surfaces.items():
        if index in remap:
            surface = deepcopy(surface); surface['wall_index'] = remap[index]; wall_surfaces.append(surface)
    def tile(asset, x, y, width, height):
        surface = deepcopy(templates[asset]); surface['wall_index'] = len(walls)
        if asset.startswith('prison_v_'): surface['collision_parts'] = [[0,0,width,height]]
        walls.append([x,y,width,height]); wall_surfaces.append(surface)
    x,y,w,h = TARGET
    west,east,north,south = x-20,x+w,y-120,y+h+20
    tile('prison_l_se',west,north,40,120)
    cursor = west+40
    while cursor < east-20:
        length = min(40,east-20-cursor)
        tile('prison_h_c' if length==40 else 'prison_h_short_c',cursor,north,length,120)
        cursor += length
    tile('prison_l_sw',east-20,north,40,120)
    tile('prison_l_ne',west,south-120,40,140)
    tile('prison_l_nw',east-20,south-120,40,140)
    for start,end in [(west+40,4400),(4580,east-20)]:
        cursor=start
        while cursor<end:
            length=min(40,end-cursor)
            tile('prison_h_c' if length==40 else 'prison_h_short_c',cursor,south-100,length,120)
            cursor+=length
    for px,length in [(4400,80),(4480,80),(4560,20)]:
        tile('prison_lintel_'+str(length),px,south-100,length,20)
    for px in [west,east]:
        cursor=y
        while cursor<south-120:
            length=min(120,south-120-cursor)
            tile('prison_v_long' if length>=80 else 'prison_v_short',px,cursor,20,length)
            cursor+=length
    room['walls']=walls; room['architecture']['wall_surfaces']=wall_surfaces
    for group in ['visibility_rooms','zones']:
        entry=next(v for v in room[group] if v['id']=='office'); entry['rect']=TARGET.copy()
        if group=='zones': entry['hide_label']=True
    for line in room['concept_plan']['horizontal']:
        if line['id']=='office-north':line.update(x0=west,x1=east+20,y=y-20)
        if line['id']=='office-south':line.update(x0=west,x1=east+20,y=south)
    for line in room['concept_plan']['vertical']:
        if line['id'].startswith('office-'):line.update(x=west if line['id']=='office-west' else east,y0=y-20,y1=south)
    floor=next(v for v in room['floor_regions'] if v['id']=='campus-office')
    floor.update(asset_id='duty_tiles_v1',manifest='res://art/environment/duty_room_v1/manifest.json',
                 rect=[west,y-20,w+40,h+60],tile_size=[160,160])
    room['floor_regions']=[v for v in room['floor_regions'] if v['id']!='office-north-grass']
    base_north=previous[1]
    if (DOC/'initial-map.json').exists():
        base_north=min(base_north,next(v['rect'][1] for v in read(DOC/'initial-map.json')['visibility_rooms'] if v['id']=='office'))
    if y>base_north:
        room['floor_regions'].insert(room['floor_regions'].index(floor),dict(id='office-north-grass',
             asset_id='grass_base_v46',manifest='res://art/environment/factory_v46/manifest.json',
             natural_ground=True,rect=[west,base_north-120,w+40,y-base_north],tile_size=[930,930]))
    old_ids={'campus-admin-desk-1','campus-admin-cabinet-1','campus-admin-board-1'}
    room['fixtures']=[v for v in room['fixtures'] if v['id'] not in old_ids and not v.get('office_generated',False)]
    def prop(identifier,key,px,py,loot=False,depth=None):
        asset=assets['office_'+key+'_v1']
        fixture=dict(id=identifier,asset_id=asset['id'],rect=[x+px,y+py,*asset['footprint_world_size']],
                     blocks_movement=asset['blocking'],blocks_sight=False,office_generated=True)
        if loot:fixture.update(loot_location='办公室',loot_name=asset['name'].split(' · ')[-1],loot_profile='office')
        if depth is not None:fixture['draw_depth']=y+depth
        room['fixtures'].append(fixture)
    prop('office-archive-west','archive',10,5,True)
    prop('office-archive-east','archive',295,5,True)
    prop('campus-admin-desk-1','desk',20,215,True)
    prop('office-work-chair','work_chair',88,168)
    prop('office-visitor-west','visitor_chair',48,320)
    prop('office-visitor-east','visitor_chair',130,320)
    prop('campus-admin-cabinet-1','cabinet',402,140,True)
    prop('office-records-sideboard','sideboard',402,210,True)
    prop('campus-admin-board-1','board',188,12,False,52)
    prop('office-clock','clock',272,12,False,52)
    prop('office-entry-sign','sign',182.5,395,False,h+60)
    room['office_restoration_version']=1
    room['concept_plan']['office_revision']=dict(version=1,reference='docs/concepts/office-restoration-v01.png',
        room_rect=TARGET.copy(),preserved_south_door=True)
    # Preserve every unrelated object and all user-authored room changes.
    original=json.loads(before)
    for group in ['visibility_rooms','zones']:
        assert [v for v in original[group] if v['id']!='office']==[v for v in room[group] if v['id']!='office']
    assert room['access_doors']==original['access_doors']
    assert [v for v in original['fixtures'] if v['id'] not in old_ids and not v.get('office_generated',False)] == [v for v in room['fixtures'] if not v.get('office_generated',False)]
    assert digest(path)==original_digest, 'Saved map changed during registration; rerun on latest saved map.'
    if not (DOC/'initial-map.json').exists():
        (DOC/'initial-map.json').write_bytes((DOC/'last-input-map.json').read_bytes() if (DOC/'last-input-map.json').exists() else before)
    (DOC/'last-input-map.json').write_bytes(before)
    write(path,room)
    (DOC/'last-output-map.json').write_bytes(path.read_bytes())
    write(DOC/'map-registration.json',dict(before_sha256=original_digest,after_sha256=digest(path),
         before=previous,after=TARGET,removed_office_wall_indices=sorted(selected),wall_remap=remap))
    print(f'Office restored {previous} -> {TARGET}; neighboring rooms and south door preserved.')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--definitions-only',action='store_true');args=parser.parse_args()
    assets=definitions()
    if not args.definitions_only:restore_map(assets)
    print('Registered seven unchanged generated office PNGs and two reused wall details.')
