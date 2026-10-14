"""Replace the closed kiosk body with an enterable, modular west-door shop."""
from pathlib import Path
from copy import deepcopy
import json,hashlib,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/campus-kiosk-v2'
ART=ROOT/'art/architecture/kiosk_v2'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 originals={};records=[];assets=[]
 for e in read(DOC/'production-assets.json')['assets']:
  dest=ROOT/e['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(e['source'],dest)
  im=Image.open(dest);assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
  x,y,r,b=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
  a=dict(texture='res://'+e['path'],texture_size=list(im.size),region=[x,y,r-x,b-y],sha256=sha(dest),source_kind='built-in-imagegen-original-png',runtime_size_limit=1024,authoring_set='kiosk-v2',alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader')
  originals[e['key']]=a;records.append(dict(key=e['key'],path=e['path'],sha256=sha(dest)))
 def plane(key,name,width,height,foot=None,region=None):
  a=deepcopy(originals[key]);a.update(id='kiosk_'+name+'_v2',name='小卖铺 · '+name,world_size=[width,height],render_size=[width,height],footprint_world_size=foot or [width,height],render_mode='projected_prop',blocking=True,proportion_locked=False,shadow_baked=True,editor_subcategory='furnishings')
  if region:a['region']=region
  _,_,w,h=a['region'];depth=(foot or [width,height])[1];a['ground_rect']=[0,h-depth/height*h,w,depth/height*h];a['elevation_world']=height-depth;assets.append(a);return a
 shell=plane('shell','shell',640,340);shell['name']='小卖铺 · 西侧开口外墙';shell['editor_subcategory']='buildings'
 shell['assembly_patches']=[dict(source=s,destination=d) for s,d in [([56,95,1621,291],[0,0,640,116]),([1560,386,117,437],[600,116,40,224]),([56,386,120,172],[0,116,40,44]),([56,650,90,173],[0,300,40,40])]]
 door=plane('door','side_entry',110,162);door.update(name='小卖铺 · 开放侧门与壁灯',blocking=False,editor_subcategory='doors')
 shelf=plane('shelf','goods_shelf',350,350*originals['shelf']['region'][3]/originals['shelf']['region'][2],[350,42]);shelf['name']='小卖铺 · 后墙生活用品架'
 base=deepcopy(next(a for a in read(ROOT/'art/architecture/kiosk_v1/manifest.json')['assets'] if a['id']=='kiosk_building_v1'))
 base['authoring_set']='kiosk-v2';base['blocking']=True;base['proportion_locked']=False;base['runtime_size_limit']=1024
 def legacy(name,region,width,depth,elevation=0):
  a=deepcopy(base);w,h=region[2:];height=width*h/w
  a.update(id='kiosk_'+name+'_v2',name='小卖铺 · '+name,region=region,world_size=[width,height],render_size=[width,height],footprint_world_size=[width,depth],ground_rect=[0,h-depth/height*h,w,depth/height*h],elevation_world=height-depth,editor_subcategory='furnishings');assets.append(a);return a
 front=legacy('front_counter',[212,646,1113,308],640,640*308/1113);front['name']='小卖铺 · 唯一正面售货台'
 canopy=legacy('front_canopy',[212,435,1113,211],640,30);canopy.update(name='小卖铺 · 雨棚与招牌',blocking=False,editor_subcategory='attachments')
 locker=legacy('supply_locker',[1073,228,128,197],55,26);locker['name']='小卖铺 · 备货柜'
 write(ART/'manifest.json',dict(schema=2,version='kiosk-v2',assets=assets))
 p=ROOT/'data/rooms/r04.json';raw=p.read_bytes();stamp=sha(p);m=read(p)
 old=next(f for f in m['fixtures'] if f['id']=='kiosk-building');assert old['asset_id']=='kiosk_building_v1','Do not overwrite an already updated/edited shop.'
 room=next(r for r in m['visibility_rooms'] if r['id']=='campus-kiosk');x,y,width,_=room['roof_rect'];assert width==640
 m['fixtures']=[f for f in m['fixtures'] if f['id']!='kiosk-building']
 def place(name,asset,dx,dy,**extra):
  f=dict(id='kiosk-'+name,asset_id=asset['id'],rect=[x+dx,y+dy,*asset['footprint_world_size']],render_size=asset['render_size'],blocks_movement=asset['blocking'],blocks_sight=False);f.update(extra);m['fixtures'].append(f)
 place('shell',shell,0,0,exterior_shell=True,draw_depth=y+100,solid_parts=[[0,0,1,116/340],[0,116/340,40/640,44/340],[0,300/340,40/640,40/340],[600/640,116/340,40/640,224/340]])
 place('side-entry',door,-70,158,exterior_shell=True,draw_depth=y+523)
 place('back-shelf',shelf,115,160)
 place('supply-locker',locker,540,220)
 place('front-counter',front,0,340,exterior_shell=True)
 place('front-canopy',canopy,0,310,exterior_shell=True,hide_in_room='campus-kiosk',draw_depth=y+522)
 room.update(name='小卖铺',rect=[x+40,y+116,560,224],roof_rect=[x,y,640,340],roof_cutouts=[[0,160/340,40/640,140/340]],roof_depth_offset=182,roof_style='kiosk',retained_wall_edges=True)
 zone=next(z for z in m['zones'] if z['id']=='campus-kiosk');zone['rect']=[x,y,640,340+front['footprint_world_size'][1]]
 # Existing cashier and outdoor purchase point are kept: no interior duplicate.
 merchant=next(r for r in m['merchants'] if r['id']=='campus_kiosk');assert merchant['position']==[x+320,y+420]
 assert sha(p)==stamp,'Map changed during preparation; retry on latest map.'
 (DOC/'before.json').write_bytes(raw);write(p,m);write(DOC/'after.json',m)
 write(DOC/'registration.json',dict(assets=records,definition_ids=[a['id'] for a in assets],origin=[x,y],removed_fixture_ids=['kiosk-building'],added_fixture_ids=[f['id'] for f in m['fixtures'] if f['id'].startswith('kiosk-')],map_before_sha256=stamp,map_after_sha256=sha(p)))
 print('Installed west entry and walkable interior; one original cashier/front counter retained.')
if __name__=='__main__':run()
