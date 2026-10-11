from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
catalog=root/'scripts/editor/editor_catalog.gd'
source=catalog.read_text('utf-8')
source=source.replace('"res://art/editor/v17/manifest.json"]:', '"res://art/editor/v17/manifest.json","res://art/editor/v18/manifest.json"]:')
catalog.write_text(source,'utf-8')
path=root/'data/rooms/r04.json'
backup=out/'r04-before-cafeteria.json'
if not backup.exists():backup.write_bytes(path.read_bytes())
d=json.loads(path.read_bytes())
f=next(f for f in d['fixtures'] if f['id']=='canteen-counter')
f.update(asset_id='cafeteria_counter_front_v40',name='食堂取餐台',rect=[1300,1540,600,20])
f.pop('render_size',None)
rear=next(f for f in d['fixtures'] if f['id']=='canteen-kitchen-collision')
rear.update(asset_id='cafeteria_backline_v40',name='食堂靠墙设备',rect=[1300,1260,580,60],blocks_movement=True,blocks_sight=True)
rear.pop('hidden',None);rear.pop('render_size',None)
lamp=next(f for f in d['fixtures'] if f['id']=='expansion-7')
lamp['rect']=[1670,1200,36,1.5]
lamp['draw_depth']=1330
for light in d.get('lamps',[]):
    if light['position']==[1670,1330]:light['position']=[1670,1260]
before=json.loads(backup.read_bytes())
assert d['walls']==before['walls'] and d['architecture']==before['architecture']
assert d['access_doors']==before['access_doors'] and d['cafeteria']==before['cafeteria'] and d['routine_points']==before['routine_points']
allowed={'canteen-counter','canteen-kitchen-collision','expansion-7'}
assert [f for f in d['fixtures'] if f['id'] not in allowed]==[f for f in before['fixtures'] if f['id'] not in allowed]
path.write_text(json.dumps(d,ensure_ascii=False,indent='\t')+'\n','utf-8')
(out/'integration.json').write_text(json.dumps(dict(front=f,rear=rear,lamp=lamp,work_aisle=[1300,1320,580,220],front_baseline=1560,front_baseline_offset=20,entry_clearance=60,layout_only=True),ensure_ascii=False,indent=2)+'\n','utf-8')
print('R04: rear backs on wall y1260; front baseline1560 (+20) leaves a60-unit nav-safe entrance.')
