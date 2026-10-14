"""Fill the saved R04 north-west alcove, preserving other authored rooms."""
import copy, hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/north-dorm-addition'
path=ROOT/'data/rooms/r04.json'
original=path.read_bytes(); data=json.loads(original)
assert not any(v['id']=='dorm-north' for v in data['visibility_rooms']), 'North dorm already exists.'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'before.json').write_bytes(original)
surfaces={int(v['wall_index']):v for v in data['architecture']['wall_surfaces']}
# Preserve the long north perimeter, replacing two pieces with a fitted T joint.
assert data['walls'][234]==[660,100,40,120] and data['walls'][235]==[700,100,40,120]
data['walls'][234]=[660,100,60,120]
surfaces[234].update(grid_tile_asset='prison_t_s',collision_parts=[[0,100,60,20]])
data['walls'][235]=[720,100,20,120]
surfaces[235].update(grid_tile_asset='prison_h_short_a',collision_parts=[[0,100,20,20]])
for y,h,asset in [(220,120,'prison_v_long'),(340,20,'prison_v_short'),(360,20,'prison_v_short')]:
 i=len(data['walls']); data['walls'].append([680,y,20,h])
 data['architecture']['wall_surfaces'].append(dict(wall_index=i,height=20,grid_tile_asset=asset,collision_parts=[[0,0,20,h]]))
data['fixtures'].append(dict(id='dorm-north-entry',asset_id='doorway_free_v48',rect=[680,380,20,140],render_size=[24,140],rotation_quarters=1,blocks_movement=False,blocks_sight=False))
for name,asset,rect in [
 ('bed','dorm_bunk_h_v1',[140,290,200,95]),
 ('locker','dorm_personal_locker_v1',[405,344,58,36]),
 ('toilet','dorm_toilet_v1',[510,320,40,48]),
 ('counter','dorm_wash_counter_ns_v1',[608,285,50,110]),
 ('stool','dorm_cushion_stool_v1',[140,402,55,30])]:
 f=dict(id='dorm-north-'+name,asset_id=asset,rect=rect,blocks_movement=True,blocks_sight=False)
 if name=='locker': f.update(loot_profile='personal',loot_name='私人储物柜',loot_location='北侧宿舍')
 data['fixtures'].append(f)
data['visibility_rooms'].append(dict(id='dorm-north',name='北侧宿舍',kind='room',rect=[120,220,560,300],door_ids=[],roof_style='concrete'))
data['zones'].append(dict(id='dorm-north',name='北侧宿舍',rect=[120,220,560,300],color='#9ca099',hide_label=True))
data['lamps'].append(dict(dorm_decor_room_id='dorm-north',draw_fixture=False,position=[633,248],radius=280))
# The existing alcove floor already matches the adjoining dorms exactly.
assert any(f['id']=='north-life-alcove' and f['rect']==[100,220,600,300] for f in data['floor_regions'])
assert path.read_bytes()==original, 'Map changed during preparation.'
text=json.dumps(data,ensure_ascii=False,indent='\t')+'\n'
path.write_text(text,encoding='utf-8',newline='\n')
(OUT/'after.json').write_bytes(path.read_bytes())
print('Added north dorm: 3 wall pieces, 1 doorway, 5 furnishings, room visibility and lamp; 2 north wall pieces fitted at T joint.')