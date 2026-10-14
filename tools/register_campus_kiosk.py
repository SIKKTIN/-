"""Install approved original kiosk sprites and replace only the repair copy."""
from pathlib import Path
from copy import deepcopy
import json, hashlib, shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/campus-kiosk-v1'
ART=ROOT/'art/architecture/kiosk_v1'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 assets=[];records=[]
 for e in read(DOC/'production-assets.json')['assets']:
  dest=ROOT/e['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(e['source'],dest)
  im=Image.open(dest);assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
  x,y,r,b=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox();w,h=r-x,b-y
  a=dict(id='kiosk_'+e['key']+'_v1',name={'building':'小卖铺 · 完整售货亭','roof':'小卖铺 · 独立铁皮屋顶','vendor':'小卖铺 · 售货员'}[e['key']],texture='res://'+e['path'],texture_size=list(im.size),region=[x,y,w,h],source_kind='built-in-imagegen-original-png',sha256=sha(dest),runtime_size_limit=1024,authoring_set='kiosk-v1',alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader')
  if e['key']=='building':
   scale=640/w;depth=h*scale-100
   a.update(world_size=[640,h*scale],render_size=[640,h*scale],ground_rect=[0,100/scale,w,depth/scale],footprint_world_size=[640,depth],elevation_world=100,render_mode='projected_prop',proportion_locked=True,blocking=True,shadow_baked=True,editor_subcategory='buildings')
  elif e['key']=='roof':a.update(world_size=[640,238],render_mode='architecture_material',fit_roof=True,blocking=False)
  else:a.update(world_size=[48,48*h/w],render_size=[48,48*h/w],editor_hidden=True,blocking=False)
  assets.append(a);records.append(dict(key=e['key'],path=e['path'],sha256=sha(dest)))
 write(ART/'manifest.json',dict(schema=2,version='kiosk-v1',assets=assets))
 path=ROOT/'data/rooms/r04.json';raw=path.read_bytes();stamp=sha(path);m=read(path)
 assert not any(f['id']=='kiosk-building' for f in m['fixtures']),'Already installed; do not overwrite saved adjustments.'
 remove=set()
 for i,w in enumerate(m['walls']):
  x,y,a,b=w
  if 2280<=x and x+a<=3000 and 1920<=y and y+b<=2440:remove.add(i)
 assert len(remove)==44,('Unexpected placeholder footprint',len(remove))
 remap={old:new for new,old in enumerate(i for i in range(len(m['walls'])) if i not in remove)}
 m['walls']=[w for i,w in enumerate(m['walls']) if i not in remove]
 m['architecture']['wall_surfaces']=[dict(s,wall_index=remap[int(s['wall_index'])]) for s in m['architecture']['wall_surfaces'] if int(s['wall_index']) not in remove]
 removed=[f['id'] for f in m['fixtures'] if f['id'].startswith('campus-repair-') and f['id'].endswith('_1')]
 assert len(removed)==6
 m['fixtures']=[f for f in m['fixtures'] if f['id'] not in removed]
 building=next(a for a in assets if a['id']=='kiosk_building_v1');depth=building['footprint_world_size'][1]
 m['fixtures'].append(dict(id='kiosk-building',asset_id=building['id'],name='园区小卖铺',rect=[2320,2020,640,depth],blocks_movement=True,blocks_sight=False))
 room=next(r for r in m['visibility_rooms'] if r['id']=='repair_2')
 room.update(id='campus-kiosk',name='小卖铺库房',rect=[2340,2020,600,160],roof_rect=[2320,1920,640,238],roof_style='kiosk',retained_wall_edges=True,roof_depth_offset=260,door_ids=[])
 floor=next(f for f in m['floor_regions'] if f['id']=='campus-repair_copy1');floor.update(id='kiosk-floor',room_id='campus-kiosk',rect=[2320,1920,640,depth+100])
 m['zones']=[z for z in m['zones'] if z.get('id')!='repair_1']
 m['zones'].append(dict(id='campus-kiosk',name='小卖铺',rect=[2320,2020,640,depth],color='#787d65',hide_label=True))
 pos=[2640,2340]
 m['merchants'].append(dict(id='campus_kiosk',name='小卖铺售货员',position=pos,service_offset=[0,130],service_side='south',sprite_asset_id='kiosk_vendor_v1',draw_depth_offset=100,routine=[dict(kind='rest',minute=0,position=pos),dict(kind='shop',minute=480,position=pos),dict(kind='rest',minute=1200,position=pos)],stock=[dict(definition_id=k,count=n) for k,n in [('biscuits',12),('canned_meat',6),('instant_coffee',6),('cigarettes',6),('antiseptic',4),('duct_tape',6),('work_gloves',3),('canvas_pouch',2)]]))
 m['lamps'].append(dict(id='kiosk-lamp',position=[2640,2370],radius=240,color='#ffe1a5',energy=.5,draw_fixture=False))
 assert sha(path)==stamp,'Map changed during installation; retry on latest file.'
 (DOC/'installation-before.json').write_bytes(raw);write(path,m);write(DOC/'installation-after.json',m)
 write(DOC/'installation.json',dict(assets=records,removed_wall_indices=sorted(remove),removed_fixture_ids=removed,before_sha256=stamp,after_sha256=sha(path)))
 print('Installed kiosk, removed',len(remove),'old walls and',len(removed),'old fixtures; other map contents preserved.')
if __name__=='__main__':run()
