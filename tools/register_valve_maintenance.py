"""Restore the valve compound with original PNGs and editable native props."""
from pathlib import Path
from copy import deepcopy
from PIL import Image
import json, hashlib, shutil, tempfile, os
from tools.register_equipment_pipes import patches as pipe_patches

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/valve-maintenance-v1'
ART=ROOT/'art/props/valve_maintenance_v1'
GEN=Path('C:/Users/gst20/.codex/generated_images/01a12b69-115b-7641-b7d4-9ca1e651c449')
SOURCES={'base':'exec-652b6b66-3a0f-4f83-9cde-f259065ab6af.png',
 'machine':'exec-9b97046b-d87e-4939-bcb0-4b27d696625e.png',
 'fences':'exec-d5a5b0f6-4a22-499a-a752-83beaa30989c.png',
 'accessories':'exec-b3d06dbb-c6af-4df6-9533-d29a4252c582.png'}
MANIFEST='res://art/props/valve_maintenance_v1/manifest.json'
SHADER='res://art/props/exercise_yard_v54/clean_cutout.gdshader'
def read(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):
 p.parent.mkdir(parents=True,exist_ok=True);fd,tmp=tempfile.mkstemp(dir=p.parent,prefix=p.name+'.',suffix='.writing')
 try:
  with os.fdopen(fd,'w',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent='\t')+'\n')
  os.replace(tmp,p)
 finally:
  if os.path.exists(tmp):os.unlink(tmp)
def crop(key,box=None):
 im=Image.open(ART/(key+'.png'));box=box or(0,0,im.width,im.height)
 bounds=im.getchannel('A').crop(box).point(lambda v:255 if v>=205 else 0).getbbox()
 assert bounds,(key,box)
 x,y,r,b=bounds;x=max(box[0],box[0]+x-2);y=max(box[1],box[1]+y-2)
 r=min(box[2],box[0]+r+2);b=min(box[3],box[1]+b+2)
 return[x,y,r-x,b-y]

def register():
 ART.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
 records=[]
 for key,n in SOURCES.items():
  p=ART/(key+'.png')
  if not p.exists() or sha(p)!=sha(GEN/n):shutil.copyfile(GEN/n,p)
  records.append(dict(key=key,path=p.relative_to(ROOT).as_posix(),source=str(GEN/n),sha256=sha(p),size=list(Image.open(p).size)))
 shutil.copyfile(GEN/'exec-9cceb9db-05c4-42bd-af90-d1bb12e1d22d.png',DOC/'approved-concept.png')
 assets=[]
 def prop(id,name,key,width,depth,height=None,box=None,blocking=False,hidden=False):
  region=crop(key,box);sw,sh=region[2:];height=height or sh*width/sw
  assert height>=depth,(id,height,depth)
  a=dict(id=id,name='主阀门检修区 · '+name,texture='res://art/props/valve_maintenance_v1/'+key+'.png',
   texture_size=list(Image.open(ART/(key+'.png')).size),region=region,world_size=[width,height],render_size=[width,height],
   footprint_world_size=[width,depth],ground_rect=[0,sh*(1-depth/height),sw,sh*depth/height],
   elevation_world=height-depth,render_mode='projected_prop',proportion_locked=False,blocking=blocking,
   interactive=False,shadow_baked=True,alpha_core_shader=SHADER,runtime_size_limit=768,
   sha256=sha(ART/(key+'.png')),source_kind='built-in-imagegen-original-png',editor_hidden=hidden,
   editor_subcategory='doors' if 'gate' in id else 'furnishings')
  assets.append(a);return a
 prop('valve_base_v1','八角水泥底座与台阶','base',500,440)
 machine=prop('valve_machine_v1','低矮主阀与红色手轮','machine',230,140,blocking=True)
 machine['solid_parts']=[[.23,.1,.64,.9]]
 prop('valve_rail_north_v1','后侧直护栏','fences',140,12,52,(20,190,430,405),True)
 prop('valve_rail_south_v1','前侧直护栏','fences',80,12,45,(20,640,430,865),True)
 side=prop('valve_rail_side_v1','侧向薄护栏','fences',18,200,243,(545,60,655,500),True)
 side['assembly_patches']=[
  dict(source=[563,85,65,108],destination=[0,0,18,35],role='north_post'),
  dict(source=[578,181,27,172],destination=[6,30,6,185],role='side_rail'),
  dict(source=[559,353,73,124],destination=[0,208,18,35],role='south_post')]
 for key,box in [('rising',(800,90,1105,480)),('falling',(1180,90,1490,480))]:
  a=prop('valve_rail_'+key+'_v1','八角斜向护栏'+key,'fences',105,90,137,box,True)
  # A diagonal fence only blocks a narrow line at the real ground feet.
  a['solid_parts']=[[i/6,(1-(i+1)/6) if key=='rising' else i/6,1/6+.06,1/6+.06] for i in range(6)]
 closed=prop('valve_gate_closed_sprite','检修门关闭原图','fences',120,12,75,(450,600,840,870),hidden=True)
 prop('valve_gate_left_jamb','检修门固定左柱','fences',20,12,59,(478,647,546,848),hidden=True)
 prop('valve_gate_right_jamb','检修门固定右柱','fences',20,12,59,(762,647,834,848),hidden=True)
 prop('valve_gate_open_leaf','检修门内开门扇','fences',31,12,85,(932,575,1008,810),hidden=True)
 presentation=dict(raised_door=True,body_depth_limited=True,piece_depth=True,door_art_size=[120,12],
  door_art='valve_gate_closed_sprite',door_art_closed='valve_gate_closed_sprite',
  door_closed_patches=[dict(asset='valve_gate_closed_sprite',source=[0,0,1,1],destination=[0,-63,120,75])],
  door_open_patches=[dict(asset='valve_gate_left_jamb',source=[0,0,1,1],destination=[0,-47,20,59]),
   dict(asset='valve_gate_right_jamb',source=[0,0,1,1],destination=[100,-47,20,59]),
   dict(asset='valve_gate_open_leaf',source=[0,0,1,1],destination=[10,-84,31,85])])
 for state in ['closed','open']:
  a=deepcopy(closed);a.update(id='doorway_valve_maintenance_'+state+'_v1',name='主阀门检修区 · 检修门'+('关闭' if state=='closed' else'全开'),editor_hidden=False,door_presentation=deepcopy(presentation),open_state=state=='open');assets.append(a)
 for id,name,cell,w,d,block in [('control','双表控制箱',0,56,34,True),('grate','方形检修格栅',1,65,65,False),
  ('hatch','封闭检修盖',2,38,38,False),('warning','双层禁入标牌',3,80,12,True),
  ('gauge','蓝管压力表',4,58,17,False),('cabinet','上锁备件柜',5,42,27,True)]:
  col,row=cell%3,cell//3;box=(col*512,row*512,(col+1)*512,(row+1)*512)
  a=prop('valve_'+id+'_v1',name,'accessories',w,d,height=w if id in ['grate','hatch'] else None,box=box,blocking=block)
  if id in ['grate','hatch']:a.update(world_size=[w,w],render_size=[w,w],footprint_world_size=[w,w],ground_rect=[0,0,a['region'][2],a['region'][3]],elevation_world=0)
 # Native pipe assembly reuses the existing unchanged red/blue fitting PNG.
 for key,color,points in [('feed','red',[(3930,2938),(3930,3340)]),
                         ('bypass','blue',[(3820,3480),(3820,3296),(4040,3296),(4040,3350)])]:
  parts=pipe_patches(color,points)
  x=min(p['destination'][0] for p in parts);y=min(p['destination'][1] for p in parts)
  r=max(p['destination'][0]+p['destination'][2] for p in parts);b=max(p['destination'][1]+p['destination'][3] for p in parts)
  for p in parts:p['destination'][0]-=x;p['destination'][1]-=y
  a=deepcopy(next(a for a in read(ROOT/'art/props/equipment_pipes_v2/manifest.json')['assets'] if a['id']=='equipment_pipe_west_riser_v2'))
  a.update(id='valve_pipe_'+key+'_v1',name='主阀门检修区 · '+('红管连续进水' if key=='feed' else'蓝管回水旁路'),world_size=[r-x,b-y],render_size=[r-x,b-y],footprint_world_size=[r-x,b-y],assembly_patches=parts)
  assets.append(a)
 a=deepcopy(next(a for a in read(ROOT/'art/props/pipe_energy_court_v1/manifest.json')['assets'] if a['id']=='energy_pipe_blue_v1'))
 a.update(id='valve_return_flange_v1',name='主阀门检修区 · 回水落地法兰',region=[715,868,109,81],
  world_size=[24,18],render_size=[24,18],footprint_world_size=[24,18],ground_rect=[0,0,109,81],
  proportion_locked=False,elevation_world=0,editor_subcategory='furnishings')
 assets.append(a)
 write(ART/'manifest.json',dict(schema=2,version='valve-maintenance-v1',assets=assets))
 write(DOC/'production-assets.json',dict(pngs=records,definition_ids=[a['id'] for a in assets]))
 catalog=ROOT/'scripts/presentation/prop_catalog.gd';text=catalog.read_text(encoding='utf-8');entry='\t"'+MANIFEST+'",\n'
 if entry.strip() not in text:catalog.write_text(text.replace('\n]\n','\n'+entry+']\n',1),encoding='utf-8')
 return{a['id']:a for a in assets}

def restore(defs):
 path=ROOT/'data/rooms/r04.json';disk=sha(path);before=read(path);after=deepcopy(before)
 assert not after.get('valve_maintenance_version'),'Already installed; update owned objects individually.'
 owned={'energy-court-valve-platform'}|{'energy-court-platform-red-feed-'+str(i) for i in range(4)}
 after['fixtures']=[f for f in after['fixtures'] if f['id'] not in owned]
 added=[]
 def place(key,asset,x,y,w=None,d=None,height=None,**extra):
  a=defs.get(asset,{})
  dims=a.get('footprint_world_size',[24,18]);w=w or dims[0];d=d or dims[1]
  f=dict(id='valve-maintenance-'+key,asset_id=asset,rect=[x,y,w,d],blocks_movement=a.get('blocking',False),
   blocks_sight=False,exterior_shell=True,valve_maintenance_generated=True)
  if a:f['render_size']=[w,height or a['render_size'][1]]
  elif height:f['render_size']=[w,height]
  f.update(extra)
  if a.get('solid_parts'):f['solid_parts']=deepcopy(a['solid_parts'])
  after['fixtures'].append(f);added.append(f['id']);return f
 place('base','valve_base_v1',3680,3240,draw_depth=0)
 place('machine','valve_machine_v1',3794,3434)
 place('north-left','valve_rail_north_v1',3790,3230)
 place('north-right','valve_rail_north_v1',3930,3230)
 place('east','valve_rail_side_v1',4151,3320)
 place('west','valve_rail_side_v1',3691,3320)
 place('northwest','valve_rail_rising_v1',3695,3230)
 place('northeast','valve_rail_falling_v1',4065,3230)
 place('southwest','valve_rail_falling_v1',3695,3520)
 place('southeast','valve_rail_rising_v1',4065,3520)
 place('south-left','valve_rail_south_v1',3790,3610)
 place('south-right','valve_rail_south_v1',3990,3610)
 place('gate','doorway_valve_maintenance_closed_v1',3870,3610,120,12,
  blocks_movement=False,access_id='valve-maintenance-entry',closed_asset='doorway_valve_maintenance_closed_v1',open_asset='doorway_valve_maintenance_open_v1')
 after['access_doors'].append(dict(id='valve-maintenance-entry',name='主阀门检修门',kind='locked',rect=[3870,3610,120,12],
  asset_id='doorway_valve_maintenance_closed_v1',initial_closed=True,blocks_sight=False,interaction_point=[3930,3705]))
 place('control','valve_control_v1',3740,3400)
 place('grate-west','valve_grate_v1',3750,3480,draw_depth=1)
 place('grate-east','valve_grate_v1',4050,3410,draw_depth=1)
 place('hatch','valve_hatch_v1',4080,3500,draw_depth=1)
 place('cabinet','valve_cabinet_v1',4090,3325)
 place('warning','valve_warning_v1',4090,3680)
 place('bollard-west','equipment_secure_bollard_v1',3840,3690,blocks_movement=True)
 place('bollard-east','equipment_secure_bollard_v1',4000,3690,blocks_movement=True)
 for key,x,y in [('feed',3922.44,2938),('bypass',3808.84,3282.32)]:
  a=defs['valve_pipe_'+key+'_v1'];parts=a['assembly_patches']
  # Store the same route bounds used to build native patch coordinates.
  points=[(3930,2938),(3930,3340)] if key=='feed' else[(3820,3480),(3820,3296),(4040,3296),(4040,3350)]
  actual=pipe_patches('red' if key=='feed' else'blue',points)
  x=min(p['destination'][0] for p in actual);y=min(p['destination'][1] for p in actual)
  place('pipe-'+key,a['id'],x,y,render_size=a['render_size'],draw_depth=3380 if key=='feed' else 3350)
 place('pressure','valve_gauge_v1',3990,3287,draw_depth=3351)
 place('return-flange','valve_return_flange_v1',4028,3348,draw_depth=3367)
 changed_floor=[]
 for f in after['floor_regions']:
  if f['id']=='energy-court-platform-green-edge':
   changed_floor.append(f['id']);f.update(asset_id='energy_concrete_v1',manifest='res://art/environment/pipe_energy_court_v1/manifest.json',natural_ground=False,tile_size=[240,240])
   for key in ['outline_asset_id','outline_manifest','outline_width','edge_feather']:f.pop(key,None)
 after['valve_maintenance_version']='editable-v1'
 assert sha(path)==disk,'Map changed concurrently; retry with latest save.'
 write(DOC/'before-map.json',before)
 write(DOC/'registration.json',dict(removed_fixture_ids=sorted(owned),added_fixture_ids=added,changed_floor_ids=changed_floor,
  added_access_id='valve-maintenance-entry',platform_rect=[3680,3240,500,440],unchanged_pipe_tee='energy-court-platform-tee'))
 write(path,after);write(DOC/'after-map.json',after)
 print(json.dumps(dict(assets=len(defs),fixtures=len(added),map_sha256=sha(path))))

if __name__=='__main__':restore(register())
