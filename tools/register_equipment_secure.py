"""Restore the approved classified equipment room with editable native assets.

PNG sources remain byte-identical; atlas regions and architecture patches are
metadata. Re-read the saved map immediately before changing this room only.
"""
from copy import deepcopy
from pathlib import Path
from PIL import Image
import hashlib, json, os, shutil, tempfile

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art/architecture/equipment_secure_v1'
DOC = ROOT / 'docs/art/equipment-secure-v1'
GEN = Path('C:/Users/gst20/.codex/generated_images/01a12b69-115b-7641-b7d4-9ca1e651c449')
MANIFEST = 'res://art/architecture/equipment_secure_v1/manifest.json'
PREFIX = 'equipment-secure-'
SOURCES = {
 'wall': 'exec-d5223adf-10fe-43ed-9b50-e4cd708f4124.png',
 'door': 'exec-c24eb9dc-e559-4a57-8546-1666004aa8b3.png',
 'security': 'exec-d315e167-a8e1-4a58-949d-f93cf2d45a4c.png',
 'mesh': 'exec-be8e35b8-d878-4d35-b2eb-3a41995a8702.png',
 'surfaces': 'exec-a608bba0-18cd-4f0d-b335-57e31f331831.png',
 'console': 'exec-aaa9b5af-bcc2-404a-832a-02b5be7937d1.png',
}
SHADER = 'res://art/props/exercise_yard_v54/clean_cutout.gdshader'

def read(p): return json.loads(p.read_bytes())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p, value):
 p.parent.mkdir(parents=True, exist_ok=True)
 fd, tmp = tempfile.mkstemp(prefix=p.name+'.', suffix='.writing', dir=p.parent)
 try:
  with os.fdopen(fd, 'w', encoding='utf-8') as f: f.write(json.dumps(value, ensure_ascii=False, indent='\t')+'\n')
  os.replace(tmp, p)
 finally:
  if os.path.exists(tmp): os.unlink(tmp)

def region(key, cell=None):
 im=Image.open(ART/(key+'.png')); a=im.getchannel('A')
 box=cell or (0,0,im.width,im.height); a=a.crop(box)
 bounds=a.point(lambda v:255 if v>=205 else 0).getbbox()
 assert bounds, (key,box)
 x,y,r,b=bounds; x=max(box[0],box[0]+x-2);y=max(box[1],box[1]+y-2)
 r=min(box[2],box[0]+r+2);b=min(box[3],box[1]+b+2)
 return [x,y,r-x,b-y]

def register():
 ART.mkdir(parents=True,exist_ok=True);DOC.mkdir(parents=True,exist_ok=True)
 records=[]
 for key,src in SOURCES.items():
  path=ART/(key+'.png')
  if not path.exists() or sha(path)!=sha(GEN/src):shutil.copyfile(GEN/src,path)
  assert sha(path)==sha(GEN/src)
  im=Image.open(path)
  if key!='surfaces': assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
  records.append(dict(key=key,source=str(GEN/src),path=path.relative_to(ROOT).as_posix(),sha256=sha(path),size=list(im.size)))
 shutil.copyfile(GEN/'exec-6898f3fe-aa2d-49b5-9c93-1bd7493edd0c.png',DOC/'approved-concept.png')
 assets=[]
 def original(key,crop=None):
  im=Image.open(ART/(key+'.png'))
  return dict(texture='res://art/architecture/equipment_secure_v1/'+key+'.png',texture_size=list(im.size),
    region=crop or region(key),sha256=sha(ART/(key+'.png')),source_kind='built-in-imagegen-original-png',runtime_size_limit=768)
 wall=original('wall');nr=wall['region'];nr[2]=min(nr[2],round(nr[3]*320/120))
 templates={a['id']:a for a in read(ROOT/'art/architecture/clinic_v1/manifest.json')['assets']}
 old=templates['clinic_wall_h_00']['region']
 for id,t in templates.items():
  if not t.get('grid_tile') or not id.startswith(('clinic_wall_','clinic_corner_','clinic_lintel_')):continue
  a=deepcopy(t);a.update(deepcopy(wall));a.update(id=id.replace('clinic_','equipment_secure_',1),name=t['name'].replace('医务室','机密设备室'),authoring_set='equipment-secure-v1',connection_tag=t['connection_tag'].replace('clinic/','equipment_secure/'))
  a.pop('runtime_size_limit',None)
  for p in a['assembly_patches']:
   x,y,w,h=p['source'];p['source']=[nr[0]+(x-old[0])/old[2]*nr[2],nr[1]+(y-old[1])/old[3]*nr[3],w/old[2]*nr[2],h/old[3]*nr[3]]
   if h<=98:p['source'][1]=nr[1]+2;p['source'][3]=max(1,nr[3]*.145)
  assets.append(a)
 base=next(a for a in assets if a['id']=='equipment_secure_wall_h_00')
 a=deepcopy(base);a.update(id='equipment_secure_wall_h_80',name='机密设备室封闭墙 80',world_size=[80,120],render_size=[80,120],collision_parts=[[0,100,80,20]])
 a['assembly_patches'][0]['destination']=[0,0,80,120];a['grid_tile']['columns']=4;a['connection_tag']='equipment_secure/east,west/80x120';assets.append(a)
 def prop(key,name,file,width,depth,blocking=False,attachment=False,crop=None,**extra):
  a=original(file,crop);w,h=a['region'][2:];height=h*width/w
  assert height>=depth>0,(key,height,depth)
  a.update(id='equipment_secure_'+key+'_v1',name='机密设备室 · '+name,world_size=[width,height],render_size=[width,height],
   ground_rect=[0,h-depth*w/width,w,depth*w/width],footprint_world_size=[width,depth],elevation_world=height-depth,
   render_mode='wall_attachment' if attachment else 'projected_prop',blocking=blocking,proportion_locked=True,
   alpha_core_shader=SHADER,shadow_baked=True,editor_subcategory='attachments' if attachment else 'furnishings',authoring_set='equipment-secure-v1')
  a.update(extra);assets.append(a);return a
 im=Image.open(ART/'security.png')
 for i,(key,name,width,depth,block) in enumerate([
   ('sign','设备室搪瓷标牌',140,1,False),('warning','机密重地禁入标牌',150,1,False),
   ('camera','门禁监视摄像头',44,1,False),('reader','红灯门禁读卡器',16,1,False),
   ('beacon','红色警戒灯',20,1,False),('bollard','入口防撞柱',24,18,True),
   ('grille','防护网通风口',68,1,False),('vent','屋顶封闭排风罩',100,1,False),('hatch','封闭检修盖',100,1,False)]):
  col,row=i%3,i//3;box=(col*im.width//3,row*im.height//3,(col+1)*im.width//3,(row+1)*im.height//3)
  prop(key,name,'security',width,depth,block,key!='bollard',region('security',box))
 im=Image.open(ART/'mesh.png')
 # Unequal atlas widths are intentionally measured, not scaled to equal cells.
 prop('mesh','设备防护网片','mesh',150,10,True,crop=region('mesh',(0,0,1200,im.height)))
 mesh_gate=prop('mesh_gate','上锁检修网门','mesh',150,10,True,crop=region('mesh',(1200,0,im.width,im.height)))
 mesh_gate.update(world_size=[150,65],render_size=[150,65],footprint_world_size=[150,10],elevation_world=55,proportion_locked=False)
 sw,sh=mesh_gate['region'][2:];mesh_gate['ground_rect']=[0,sh*(1-10/65),sw,sh*10/65]
 side=original('mesh',[140,181,920,43])
 side.update(id='equipment_secure_mesh_side_v1',name='机密设备室 · 侧向护网顶栏',world_size=[135,12],render_size=[135,12],
  footprint_world_size=[135,12],ground_rect=[0,0,920,43],elevation_world=0,render_mode='projected_prop',blocking=True,
  proportion_locked=False,alpha_core_shader=SHADER,shadow_baked=True,editor_subcategory='furnishings',authoring_set='equipment-secure-v1')
 assets.append(side)
 im=Image.open(ART/'console.png')
 prop('console','受控动力操作台','console',130,40,True,crop=region('console',(0,0,1100,im.height)))
 prop('documents','上锁机密资料柜','console',45,32,True,crop=region('console',(1100,0,im.width,im.height)))
 im=Image.open(ART/'door.png')
 for key,box in [('door_closed',(0,0,im.width//2,im.height)),('door_open',(im.width//2,0,im.width,im.height))]:
  a=original('door',region('door',box));a.update(id='equipment_secure_'+key+'_sprite',editor_hidden=True);assets.append(a)
 def patch(key,src,dst):return dict(asset='equipment_secure_'+key+'_sprite',source=src,destination=dst)
 frame=[patch('door_closed',[0,0,1,.16],[0,0,180,19.2]),patch('door_closed',[0,.16,.13,.84],[0,19.2,23.4,100.8]),patch('door_closed',[.87,.16,.13,.84],[156.6,19.2,23.4,100.8])]
 presentation=dict(raised_door=True,clear_wall_facade=True,body_depth_limited=True,door_art_size=[180,120],
  door_art='equipment_secure_door_open_sprite',door_art_closed='equipment_secure_door_closed_sprite',
  door_open_patches=[patch('door_open',[.13,.16,.13,.84],[23.4,19.2,23.4,100.8]),patch('door_open',[.74,.16,.13,.84],[133.2,19.2,23.4,100.8])]+frame,
  door_closed_patches=[patch('door_closed',[.13,.16,.74,.84],[23.4,19.2,133.2,100.8])]+frame,
  visual_solid_parts=[[0,19.2,46.8,100.8],[133.2,19.2,46.8,100.8]],closed_visual_solid_parts=[[0,19.2,180,100.8]],body_profile='human_silhouette')
 for state in ['open','closed']:
  a=original('door',region('door',(0,0,im.width//2,im.height) if state=='closed' else (im.width//2,0,im.width,im.height)))
  a.update(id='doorway_equipment_secure_'+state+'_v1',name='机密设备室 · 门禁钢门 · '+('全开' if state=='open' else '关闭'),
   render_mode='embedded_door',world_size=[180,120],render_size=[180,120],footprint_world_size=[180,20],ground_rect=[0,0,*a['region'][2:]],
   blocking=False,proportion_locked=False,grid_door={'cell':20},editor_subcategory='doors',authoring_set='equipment-secure-v1',door_presentation=deepcopy(presentation));assets.append(a)
 im=Image.open(ART/'surfaces.png')
 for i,(key,name) in enumerate([('roof_metal','深灰金属设备屋顶'),('roof_concrete','密闭混凝土设备屋顶'),('floor','机密设备室深灰工业地面')]):
  a=original('surfaces',[i*im.width//3,0,im.width//3,im.height]);a.update(id='equipment_secure_'+key+'_v1',name=name,world_size=[240,240],render_mode='architecture_material',blocking=False,authoring_set='equipment-secure-v1');assets.append(a)
 # Preserve the established machine artwork while restoring the approved layout.
 energy={a['id']:a for a in read(ROOT/'art/props/pipe_energy_court_v1/manifest.json')['assets']}
 for old,key,name,width in [('energy_control_bank_v1','control_bank','上锁仪表配电柜组',420),('energy_pump_v1','pump','蓝钢动力循环泵',240)]:
  a=deepcopy(energy[old]);factor=width/a['world_size'][0]
  for field in ['world_size','render_size','footprint_world_size']:a[field]=[v*factor for v in a[field]]
  a['elevation_world']=a.get('elevation_world',0)*factor
  a.update(id='equipment_secure_'+key+'_v1',name='机密设备室 · '+name,authoring_set='equipment-secure-v1',reused_from=old);assets.append(a)
 write(ART/'manifest.json',dict(schema=2,version='equipment-secure-v1',assets=assets))
 write(DOC/'production-assets.json',dict(mode='built-in-imagegen',pngs=records,definition_ids=[a['id'] for a in assets],manifest=MANIFEST))
 catalog=ROOT/'scripts/presentation/prop_catalog.gd';text=catalog.read_text(encoding='utf-8');line='\t"'+MANIFEST+'",\n'
 if line not in text:
  anchor='\t"res://art/architecture/dorm_door_v1/manifest.json",\n';assert text.count(anchor)==1
  catalog.write_text(text.replace(anchor,anchor+line),encoding='utf-8')
 return {a['id']:a for a in assets}

def restore(defs):
 path=ROOT/'data/rooms/r04.json';digest=sha(path);before=read(path);d=deepcopy(before)
 assert not d.get('equipment_secure_version'),'Already restored; do not overwrite later editor edits.'
 room=next(r for r in d['visibility_rooms'] if r['id']=='equipment')
 assert room['rect']==[2320,2740,1220,1200] and room['roof_rect']==[2300,2620,1260,1220]
 changed_walls=[]
 for s in d['architecture']['wall_surfaces']:
  if not s.get('energy_court_generated'):continue
  i=int(s['wall_index']);r=d['walls'][i];old=s.get('grid_tile_asset','')
  new=old.replace('workshop_','equipment_secure_',1)
  assert new in defs,(old,new)
  if r[1]==3400 and 'lintel' in old:
   r[3]=120;s['collision_parts']=[[0,100,r[2],20]]
   new='equipment_secure_wall_h_80' if r[2]==80 else 'equipment_secure_wall_h_short'
  s.update(grid_tile_asset=new,equipment_secure_generated=True);changed_walls.append(i)
 removed=['energy-court-energy-court-entry','energy-court-nameplate','energy-court-gray-control-bank',
          'energy-court-pump','energy-court-south-worktable','energy-court-indoor-drums','energy-court-wall-table-drums']
 d['fixtures']=[f for f in d['fixtures'] if f['id'] not in removed]
 d['access_doors']=[g for g in d['access_doors'] if g['id']!='energy-court-entry']
 gate=next(g for g in d['access_doors'] if g['id']=='energy-entry')
 gate.update(asset_id='doorway_equipment_secure_closed_v1',kind='locked',name='机密设备室门禁',initial_closed=True,
             interaction_point=[2990,4015],equipment_secure_generated=True)
 door=next(f for f in d['fixtures'] if f.get('access_id')=='energy-entry')
 door.update(asset_id=gate['asset_id'],closed_asset=gate['asset_id'],open_asset='doorway_equipment_secure_open_v1',
             closed_asset_id=gate['asset_id'],open_asset_id='doorway_equipment_secure_open_v1',equipment_secure_generated=True)
 fixture_ids=[]
 def place(key,x,y,tag=None,**extra):
  a=defs['equipment_secure_'+key+'_v1'];f=dict(id=PREFIX+(tag or key),asset_id=a['id'],rect=[x,y,*a['footprint_world_size']],
    blocks_movement=a['blocking'],blocks_sight=False,equipment_secure_generated=True)
  f.update(extra);d['fixtures'].append(f);fixture_ids.append(f['id']);return f
 shell=dict(exterior_shell=True,in_front_of_wall_trim=True,draw_depth=3990)
 place('sign',2920,3862,**shell)
 place('warning',3130,3890,**shell)
 place('camera',2810,3870,**shell)
 place('reader',2854,3905,**shell)
 place('beacon',3080,3860,**shell)
 for i,x in enumerate([2660,3360]):place('grille',x,3905,tag='grille-'+str(i),**shell)
 for i,x in enumerate([2860,3098]):place('bollard',x,3990,tag='bollard-'+str(i),exterior_shell=True)
 place('pump',2470,3725)
 place('control_bank',3040,3600)
 # Mesh ends deliberately leave the east service aisle and entry landing clear.
 for i,x in enumerate([2325,2475]):place('mesh',x,3530,tag='tank-mesh-'+str(i))
 for i,x in enumerate([3025,3175]):place('mesh',x,3770,tag='control-mesh-'+str(i))
 place('mesh_gate',3325,3770,tag='control-mesh-gate')
 for i in range(6):place('mesh_side',2625,2780+i*125,tag='tank-side-'+str(i),rect=[2625,2780+i*125,12,125],rotation_quarters=1,render_size=[125,12])
 for side,x in [('left',3025),('right',3463)]:
  for i in range(2):place('mesh_side',x,3500+i*135,tag='control-side-'+side+'-'+str(i),rect=[x,3500+i*135,12,135],rotation_quarters=1)
 place('console',3270,3790,tag='control-desk',name='受控动力操作台')
 place('documents',3480,3800)
 room.update(name='机密动力设备室',door_ids=['energy-entry'],roof_sections=[
  dict(rect=[0,0,500/1260,1],asset_id='equipment_secure_roof_metal_v1',tile_size=[300,300]),
  dict(rect=[500/1260,780/1220,760/1260,440/1220],asset_id='equipment_secure_roof_concrete_v1',tile_size=[300,300])],
  roof_details=[dict(asset_id='roof_fan',position=[.20,.23]),dict(asset_id='equipment_secure_vent_v1',position=[.20,.70]),
                dict(asset_id='equipment_secure_hatch_v1',position=[.68,.85]),dict(asset_id='equipment_secure_vent_v1',position=[.88,.87])],equipment_secure_generated=True)
 for floor in d['floor_regions']:
  if floor['id'] in ['energy-court-equipment-west-floor','energy-court-equipment-south-floor']:
   floor.update(asset_id='equipment_secure_floor_v1',manifest=MANIFEST,tile_size=[240,240],room_id='equipment',equipment_secure_generated=True)
 # Remove only existing interior equipment-room service markings; keep outside roads.
 d['ground_details']=[g for g in d.get('ground_details',[]) if not (g.get('energy_court_generated') and g.get('kind')=='line' and all(2320<=p[0]<3540 and p[1]>=3500 for p in [g['from'],g['to']]))]
 def detail(kind,rect,**extra):
  v=dict(id=PREFIX+'ground-'+str(len(d['ground_details'])),kind=kind,rect=rect,equipment_secure_generated=True);v.update(extra);d['ground_details'].append(v)
 for x,y,w,h in [[2440,3680,300,170],[3025,3570,460,210]]:
  points=[[x,y],[x+w,y],[x+w,y+h],[x,y+h]]
  for i in range(4):d['ground_details'].append(dict(id=PREFIX+'line-'+str(len(d['ground_details'])),kind='line',**{'from':points[i],'to':points[(i+1)%4]},color='#bf9c3e',opacity=.7,width=3,equipment_secure_generated=True))
 detail('hatch',[2900,3980,180,70],color='#c8a148',opacity=.85,width=3)
 d.setdefault('gate_guards',[]).append(dict(id='equipment-secure-watch',name='机密区看守',position=[2770,4040],blocks_primary=False,post_activity='设备室警戒'))
 d['equipment_secure_version']=1
 assert sha(path)==digest,'Map changed while restoring; retry on latest saved file.'
 write(DOC/'before-map.json',before);write(path,d);write(DOC/'after-map.json',d)
 write(DOC/'registration.json',dict(before_sha256=digest,after_sha256=sha(path),changed_wall_indices=changed_walls,
   removed_fixture_ids=removed,removed_access_id='energy-court-entry',added_fixture_ids=fixture_ids,
   room_id='equipment',room_rect=room['rect'],external_pipeline_preserved=True,manifest=MANIFEST))
 write(DOC/'art-requirements.json',dict(approved_concept='approved-concept.png',goal='封闭机密动力控制区',
   scope=['原L形房间','密闭双材质屋顶','统一混凝土与暗色石基墙','南侧门禁与警戒附件','内部设备防护网','机密区看守'],
   gameplay='南门沿用现有锁门与撬锁规则；院侧门封成实体墙；主路、架空管线、阀门平台保持。',
   editability='墙、门、附件、护网、地面均为原生独立对象，屋顶通过同一房间显隐。'))
 print('Restored equipment room:',len(changed_walls),'walls,',len(fixture_ids),'new independent fixtures.')

if __name__=='__main__': restore(register())
