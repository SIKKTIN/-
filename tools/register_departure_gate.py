"""Install approved departure-checkpoint sprites without changing escape rules."""
from pathlib import Path
from copy import deepcopy
import json, hashlib, shutil, tempfile, os
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/departure-gate-v1'
ART=ROOT/'art/architecture/departure_gate_v1'
GEN=Path('C:/Users/gst20/.codex/generated_images/01a12de1-9940-7ee0-a361-bbf0f88d4681')
SOURCES={
 'frame':'exec-9ef8f1b6-09e7-432f-871c-5a2d9a15e918.png',
 'closed':'exec-ee12af75-46a4-44dd-9892-f74ca569868a.png',
 'open':'exec-c9842792-5fd0-4586-95d2-20d3618de474.png',
 'desk':'exec-b4c2eae3-ae8b-4f4f-adc7-47ec2f9d0f18.png',
 'barrier':'exec-c8ffa59c-4355-4a7e-9b13-56db24882653.png'}
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=p.parent,delete=False) as f:
  f.write(json.dumps(v,ensure_ascii=False,indent='\t')+'\n');temp=f.name
 os.replace(temp,p)
def read(p):return json.loads(p.read_bytes())
def build():
 ART.mkdir(parents=True,exist_ok=True)
 records=[];bounds={};sizes={}
 for key,file in SOURCES.items():
  src=GEN/file;dest=ART/(key+'.png')
  if dest.exists():assert digest(src)==digest(dest)
  else:shutil.copyfile(src,dest)
  with Image.open(dest) as im:
   assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
   box=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
   x,y,r,b=box;bounds[key]=[max(0,x-3),max(0,y-3),min(im.width,r+3)-max(0,x-3),min(im.height,b+3)-max(0,y-3)];sizes[key]=list(im.size)
  records.append(dict(key=key,path=dest.relative_to(ROOT).as_posix(),source=str(src),sha256=digest(dest),region=bounds[key]))
 assets=[]
 def asset(identifier,name,key,region,width,depth,mode='projected_prop',height=None):
  h=height or region[3]*width/region[2];scale=width/region[2]
  a=dict(id=identifier,name='外出大门 · '+name,texture='res://art/architecture/departure_gate_v1/'+key+'.png',
   texture_size=sizes[key],region=region,world_size=[width,h],render_size=[width,h],
   ground_rect=[0,(h-depth)/scale,region[2],depth/scale],footprint_world_size=[width,depth],
   render_mode=mode,elevation_world=max(0,h-depth),proportion_locked=True,blocking=depth>1,interactive=False,
   shadow_baked=False,runtime_size_limit=512,alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
   editor_subcategory='attachments' if mode=='wall_attachment' else 'furnishings')
  assets.append(a);return a
 # Crop coordinates are metadata, generated PNGs remain byte-for-byte intact.
 asset('departure_left_booth_v1','西侧门岗与摄像头','frame',[263,18,396,718],120,60,height=220)
 asset('departure_right_booth_v1','东侧门岗与广播','frame',[1358,18,400,718],120,60,height=220)
 asset('departure_header_v1','出入口门楣','frame',[655,89,706,140],320,1,'wall_attachment')
 for state in ['open','closed']:
  a=asset('doorway_departure_'+state+'_v1','铁门'+('开启' if state=='open' else '关闭'),state,bounds[state],320,20)
  a['editor_subcategory']='doors'
  a['door_presentation']=dict(raised_door=True,clear_wall_facade=True,body_depth_limited=True,
    door_art_size=[320,180],
    door_art='doorway_departure_open_v1',door_art_closed='doorway_departure_closed_v1',
    door_closed_patches=[dict(asset='doorway_departure_closed_v1',source=[0,0,1,1],destination=[0,0,320,135])],
    door_open_patches=[dict(asset='doorway_departure_open_v1',source=[0,0,1,1],destination=[0,0,320,145])])
 asset('departure_check_desk_v1','外出检查台','desk',bounds['desk'],110,64)
 asset('departure_barrier_v1','移动护栏','barrier',bounds['barrier'],74,12)
 all_old={}
 for file in ['art/props/factory_v44/manifest.json','art/props/workshop_one_v1/manifest.json']:
  all_old.update({a['id']:a for a in read(ROOT/file)['assets']})
 for old_id,new_id,name,width,depth in [
  ('weed_planter_v44','departure_planter_v1','门岗花箱',65,34),
  ('workshop_electrical_cabinet_v1','departure_electric_v1','配电箱',28,22)]:
  a=deepcopy(all_old[old_id]);region=a['region'];h=region[3]*width/region[2];scale=width/region[2]
  a.update(id=new_id,name='外出大门 · '+name,world_size=[width,h],render_size=[width,h],
    ground_rect=[0,region[3]-depth/scale,region[2],depth/scale],footprint_world_size=[width,depth],
    elevation_world=h-depth,proportion_locked=True,runtime_size_limit=256,reused_from=old_id)
  a.pop('editor_icon',None);assets.append(a)
 write(ART/'manifest.json',dict(schema=2,version='departure-gate-v1',assets=assets))
 write(DOC/'asset-registration.json',dict(mode='built-in imagegen',assets=records))
 return {a['id']:a for a in assets}
def restore(assets):
 p=ROOT/'data/rooms/r04.json';raw=p.read_bytes();sha=hashlib.sha256(raw).hexdigest();data=json.loads(raw);before=deepcopy(data)
 assert data['door']==[3300,200,320,20] and data['exit']==[3300,80,320,100]
 data['fixtures']=[f for f in data['fixtures'] if not f.get('departure_generated')]
 gate=next(f for f in data['fixtures'] if f.get('primary_gate'))
 gate.update(asset_id='doorway_departure_closed_v1',render_size=[320,180],rotation_door_visual_rect=[3300,100,320,180])
 def place(identifier,key,x,y):
  a=assets[key];w,d=a['footprint_world_size']
  data['fixtures'].append(dict(id=identifier,asset_id=key,rect=[x,y,w,d],
   render_size=a['render_size'],blocks_movement=d>1,blocks_sight=key.endswith('booth_v1'),
   exterior_shell=True,departure_generated=True))
 place('departure-west-booth','departure_left_booth_v1',3180,190)
 place('departure-east-booth','departure_right_booth_v1',3620,190)
 place('departure-gate-header','departure_header_v1',3300,114)
 data['fixtures'][-1].update(blocks_movement=False,blocks_sight=False,in_front_of_wall_trim=True)
 place('departure-check-desk','departure_check_desk_v1',3650,400)
 place('departure-right-barrier','departure_barrier_v1',3680,487)
 place('departure-left-planter','departure_planter_v1',3198,292)
 place('departure-east-electric','departure_electric_v1',3745,270)
 data['ground_details']=[d for d in data.get('ground_details',[]) if not d.get('departure_generated')]
 data['ground_details'].extend([
  dict(id='departure-check-line',kind='dash',**{'from':[3312,302],'to':[3608,302]},
   segment=32,gap=12,width=12,color='#c2a052',opacity=.62,departure_generated=True),
  dict(id='departure-yard-drain',kind='drain',rect=[3695,685,34,30],departure_generated=True),
  dict(id='departure-yard-cover',kind='surface',rect=[3230,830,40,36],color='#59635e',opacity=.28,departure_generated=True)])
 for k in before:
  if k not in ['fixtures','ground_details']:assert data[k]==before[k],k
 assert [f for f in before['fixtures'] if not f.get('primary_gate') and not f.get('departure_generated')]==[f for f in data['fixtures'] if not f.get('primary_gate') and not f.get('departure_generated')]
 assert len({f['id'] for f in data['fixtures']})==len(data['fixtures'])
 if not (DOC/'before-map.json').exists():(DOC/'before-map.json').write_bytes(raw)
 (DOC/'last-input-map.json').write_bytes(raw)
 assert digest(p)==sha,'Map changed during preparation; retry using latest.'
 write(DOC/'map-registration.json',dict(input_sha256=sha,fixture_ids=[f['id']for f in data['fixtures']if f.get('departure_generated')],logical_gate_preserved=True))
 # Atomic replacement guarded again immediately before writing.
 text=json.dumps(data,ensure_ascii=False,indent='\t')+'\n'
 with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=p.parent,delete=False) as f:f.write(text);temp=f.name
 assert digest(p)==sha,'Map changed before atomic write.'
 os.replace(temp,p)
 print(json.dumps(dict(map_sha256=digest(p),assets=len(assets),fixtures=len(data['fixtures']),added=len(data['fixtures'])-len(before['fixtures'])),ensure_ascii=False))
if __name__=='__main__':restore(build())
