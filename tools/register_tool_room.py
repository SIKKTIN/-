"""Register unchanged generated sprites, then restyle only the saved tools room."""
from copy import deepcopy
from pathlib import Path
import json, hashlib, shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/tool-room-redesign'
ART=ROOT/'art/architecture/tool_room_v1'
MANIFEST='res://art/architecture/tool_room_v1/manifest.json'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def register():
 originals={};records=[];assets=[]
 for e in read(DOC/'production-assets.json')['assets']:
  dest=ROOT/e['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(e['source'],dest)
  assert sha(dest)==sha(Path(e['source']))
  im=Image.open(dest);a=dict(texture='res://'+e['path'],texture_size=list(im.size),sha256=sha(dest),source_kind='built-in-imagegen-original-png',runtime_size_limit=768)
  if e['transparent']:
   assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
   x,y,r,b=im.getchannel('A').point(lambda v:255 if v>=180 else 0).getbbox();a['region']=[x,y,r-x,b-y]
  else:a['opaque']=True
  originals[e['key']]=a;records.append(dict(key=e['key'],path=e['path'],sha256=sha(dest)))
 wall=deepcopy(originals['wall']);rx,ry,rw,rh=wall['region'];wall['region']=[rx,ry,min(rw,round(rh*320/120)),rh];wall.pop('runtime_size_limit',None);nr=wall['region']
 templates={a['id']:a for a in read(ROOT/'art/architecture/clinic_v1/manifest.json')['assets']};old=templates['clinic_wall_h_00']['region']
 for id,t in templates.items():
  if not t.get('grid_tile') or not id.startswith(('clinic_wall_','clinic_corner_','clinic_lintel_')):continue
  a=deepcopy(t);a.update(deepcopy(wall));a.update(id=id.replace('clinic_','toolroom_',1),name=t['name'].replace('医务室','工具房'),authoring_set='tool-room-v1',connection_tag=t['connection_tag'].replace('clinic/','toolroom/'))
  for part in a['assembly_patches']:
   x,y,w,h=part['source'];part['source']=[nr[0]+(x-old[0])/old[2]*nr[2],nr[1]+(y-old[1])/old[3]*nr[3],w/old[2]*nr[2],h/old[3]*nr[3]]
   if h<=98:part['source'][1]=nr[1]+2;part['source'][3]=max(1,rh*.095)
  assets.append(a)
 def prop(key,name,width,depth,blocking=True,attachment=False):
  a=deepcopy(originals[key]);_,_,w,h=a['region'];scale=width/w;assert 0<depth<=h*scale
  a.update(id='toolroom_'+key+'_v1',name='工具房 · '+name,world_size=[width,h*scale],render_size=[width,h*scale],ground_rect=[0,h-depth/scale,w,depth/scale],footprint_world_size=[width,depth],elevation_world=h*scale-depth,render_mode='wall_attachment' if attachment else 'projected_prop',blocking=blocking,proportion_locked=True,shadow_baked=False,alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',editor_subcategory='attachments' if attachment else 'furnishings',authoring_set='tool-room-v1')
  assets.append(a);return a
 prop('pegboard','工具挂板',160,58,False,True)
 prop('bench','抽屉领用台',160,40)
 prop('locker','T-01 工具高柜',40,32)
 prop('drawers','台钳备件柜',40,32)
 prop('rack_short','T-03 短零件架',44,58)
 prop('rack','T-02 长零件架',44,155)
 prop('return','归还检查台',48,60)
 prop('cable','双卷线架',34,32)
 prop('chest','T-05 专用工具箱',42,30)
 prop('sign','搪瓷标牌',80,25,False,True)
 for key,id,name in [('floor','toolroom_floor_v1','工具房暗灰工业砖'),('roof','toolroom_roof_surface','工具房深灰防水平顶')]:
  a=deepcopy(originals[key]);a.update(id=id,name=name,world_size=[240,240],render_mode='architecture_material',blocking=False,authoring_set='tool-room-v1');assets.append(a)
 for file,oldid,newkey,name,width in [('art/props/duty_room_v1/manifest.json','duty_clock_v1','clock','墙钟',25),('art/props/duty_room_v1/manifest.json','duty_roster_v1','register','领用登记',30),('art/props/reading_room_v1/manifest.json','reading_lamp_v1','lamp','笼罩壁灯',20),('art/props/duty_room_v1/manifest.json','duty_ledger_v1','ledger','领用记录本',26)]:
  a=deepcopy(next(a for a in read(ROOT/file)['assets'] if a['id']==oldid));ratio=width/a['world_size'][0]
  for k in ['world_size','render_size','footprint_world_size']:a[k]=[v*ratio for v in a[k]]
  a['elevation_world']=a.get('elevation_world',0)*ratio
  a.update(id='toolroom_'+newkey+'_v1',name='工具房 · '+name,authoring_set='tool-room-v1',proportion_locked=True,blocking=False,render_mode='wall_attachment' if newkey!='ledger' else 'projected_prop',editor_subcategory='attachments',runtime_size_limit=256);a.pop('editor_icon',None);assets.append(a)
 # Front states use one fixed outer frame, cropped from the closed original.
 for key in ['door_closed','door_open','door_side_open']:
  a=deepcopy(originals[key]);a.update(id='toolroom_'+key+'_sprite',editor_hidden=True);assets.append(a)
 def patch(key,src,dst,rotation=0):return dict(asset='toolroom_'+key+'_sprite',source=src,destination=dst,rotation_quarters=rotation)
 frame=[patch('door_closed',[0,0,1,.11],[0,0,180,13]),patch('door_closed',[0,.11,.075,.89],[0,13,13.5,107]),patch('door_closed',[.925,.11,.075,.89],[166.5,13,13.5,107])]
 opened=[patch('door_open',[0,.11,.24,.89],[0,13,43.2,107]),patch('door_open',[.76,.11,.24,.89],[136.8,13,43.2,107])]+frame
 closed=[patch('door_closed',[.075,.11,.85,.89],[13.5,13,153,107])]+frame
 front=dict(raised_door=True,clear_wall_facade=True,body_depth_limited=True,door_art_size=[180,120],door_art='toolroom_door_open_sprite',door_art_closed='toolroom_door_closed_sprite',door_open_patches=opened,door_closed_patches=closed,visual_solid_parts=[[0,13,38,107],[142,13,38,107]],closed_visual_solid_parts=[[0,13,180,107]],body_profile='human_silhouette')
 # Side leaf rises above its floor hinge. Patch UVs cancel the portal's 90-degree
 # orientation, keeping the side-facing artwork upright in world space.
 caps=[patch('door_closed',[0,.1,.065,.14],[0,0,8,20]),patch('door_closed',[.935,.78,.065,.14],[158.4,0,8,20])]
 side=dict(raised_door=True,clear_wall_facade=True,body_depth_limited=True,door_art_size=[166.4,20],door_art='toolroom_door_side_open_sprite',door_art_closed='toolroom_door_closed_sprite',door_open_patches=[patch('door_side_open',[0,0,1,1],[-90,-50,140,70],3)]+caps,door_closed_patches=[patch('door_closed',[.075,.1,.1,.89],[0,0,166.4,20])]+caps,visual_solid_parts=[[0,0,8,20],[158.4,0,8,20],[-90,-50,140,70]],closed_visual_solid_parts=[[0,0,166.4,20]],body_profile='human_silhouette')
 for orient,presentation in [('front',front),('side',side)]:
  for state in ['open','closed']:
   a=deepcopy(originals['door_side_open' if orient=='side' and state=='open' else 'door_'+state]);a.update(id=f'doorway_toolroom_{orient}_{state}_v1',name='工具房 · '+('侧门' if orient=='side' else '南双门')+('开启' if state=='open' else '关闭'),render_mode='embedded_door',world_size=[180,120] if orient=='front' else [70,140],render_size=[180,120] if orient=='front' else [70,140],footprint_world_size=[180,20] if orient=='front' else [20,160],ground_rect=[0,0,*a['region'][2:]],blocking=False,proportion_locked=False,grid_door={'cell':20},editor_subcategory='doors',authoring_set='tool-room-v1',door_presentation=deepcopy(presentation));assets.append(a)
 write(ART/'manifest.json',dict(schema=2,version='tool-room-v1',assets=assets));defs={a['id']:a for a in assets}
 path=ROOT/'data/rooms/r04.json';before=path.read_bytes();before_hash=sha(path);m=read(path)
 room=next(r for r in m['visibility_rooms'] if r['id']=='tools');x,y,w,h=room['rect'];assert [w,h]==[360,540]
 assert not any(f['id']=='toolroom-bench' for f in m['fixtures']),'Already installed; adjust placements explicitly instead of overwriting edits.'
 selected=[]
 for s in m['architecture']['wall_surfaces']:
  i=int(s['wall_index']);wx,wy,ww,wh=m['walls'][i]
  boundary=(wy==y-120 and x-20<=wx<x+w+20 and wx+ww<=x+w+20) or (wy in [y+h-100,y+h-80] and x-20<=wx<x+w+20 and wx+ww<=x+w+20) or (wx in [x-20,x+w] and y<=wy<y+h-100 and wy+wh<=y+h-100)
  if not boundary:continue
  base=s.get('grid_tile_asset','')
  if base.startswith('prison_h_short'):new='toolroom_wall_h_short'
  elif base.startswith('prison_h_'):new=f'toolroom_wall_h_{int((wx-x+20)%320/20):02d}'
  elif base=='prison_v_long':new='toolroom_wall_v_long'
  elif base=='prison_v_short':new='toolroom_wall_v_short'
  elif base.startswith('prison_lintel_'):new=base.replace('prison_','toolroom_',1)
  else:new={'prison_l_se':'toolroom_corner_nw','prison_l_sw':'toolroom_corner_ne','prison_l_ne':'toolroom_corner_sw','prison_l_nw':'toolroom_corner_se'}[base]
  assert new in defs;selected.append(i);s['grid_tile_asset']=new
 removed=['campus-tools-locker-0','campus-tools-locker-1','campus-tools-parts'];m['fixtures']=[f for f in m['fixtures'] if f['id'] not in removed]
 def place(key,dx,dy,**extra):
  a=defs['toolroom_'+key+'_v1'];f=dict(id='toolroom-'+key,asset_id=a['id'],rect=[x+dx,y+dy,*a['footprint_world_size']],blocks_movement=a['blocking'],blocks_sight=False);f.update(extra);m['fixtures'].append(f);return f
 place('locker',12,62,loot_profile='tools',name='编号工具高柜')
 place('bench',83,55,name='工具领用台')
 place('pegboard',83,-7,draw_depth=y+96)
 place('drawers',253,63,loot_profile='industrial',name='台钳备件柜')
 place('rack_short',304,95,loot_profile='industrial',name='短零件架')
 place('rack',304,210,loot_profile='industrial',name='长零件架')
 place('return',12,390,name='归还检查台')
 place('cable',266,425)
 place('chest',308,425,loot_profile='tools',name='专用工具箱')
 place('sign',123,-78,draw_depth=y+96)
 place('lamp',64,-74,draw_depth=y+96)
 place('clock',314,-73,draw_depth=y+96)
 place('register',259,-56,draw_depth=y+96)
 place('ledger',202,41,draw_depth=y+97)
 for id,orient in [('tools-entry','side'),('tools-rear','front')]:
  gate=next(g for g in m['access_doors'] if g['id']==id);gate['asset_id']=f'doorway_toolroom_{orient}_closed_v1'
  if orient=='side':gate['rotation_quarters']=1
  for f in m['fixtures']:
   if f.get('access_id')==id:
    f.update(asset_id=gate['asset_id'],closed_asset_id=gate['asset_id'],open_asset_id=f'doorway_toolroom_{orient}_open_v1')
 floor=next(f for f in m['floor_regions'] if f['id']=='campus-tools');floor.update(asset_id='toolroom_floor_v1',manifest=MANIFEST,tile_size=[240,240])
 room['roof_style']='tool_room';next(r for r in m['zones'] if r['id']=='tools')['hide_label']=True
 for n,(start,end) in enumerate([((65,102),(286,102)),((291,160),(291,365)),((65,385),(65,450))]):
  m['ground_details'].append(dict(id='toolroom-line-'+str(n),kind='line',color='#c5a34e',opacity=.48,width=2,**{'from':[x+start[0],y+start[1]],'to':[x+end[0],y+end[1]]}))
 m['lamps'].append(dict(id='toolroom-light',position=[x+170,y+210],radius=350,color='#ffe2ad',energy=.60,draw_fixture=False))
 assert sha(path)==before_hash,'Saved map changed during registration; retry on latest file.'
 (DOC/'registration-input.json').write_bytes(before);write(path,m);write(DOC/'registration-output.json',m)
 write(DOC/'asset-registration.json',dict(assets=records,definition_ids=list(defs),wall_indices=selected,removed_fixture_ids=removed,room_rect=room['rect'],map_before_sha256=before_hash,map_after_sha256=sha(path)))
 print('Registered',len(assets),'definitions;',len(selected),'wall sections; saved only tools room changes.')
if __name__=='__main__':register()