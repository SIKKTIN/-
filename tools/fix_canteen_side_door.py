"""Enlarge only the canteen west doorway and seal its existing roof."""
from pathlib import Path
from copy import deepcopy
import json,hashlib,os,tempfile
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/canteen-side-door-v3'
def read(p):return json.loads(p.read_bytes())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=p.parent,delete=False) as f:
  f.write(json.dumps(v,ensure_ascii=False,indent='\t')+'\n');temp=f.name
 os.replace(temp,p)
def register():
 original=read(ROOT/'art/architecture/workshop_door_v2/manifest.json')
 assets=[]
 for state in ['open','closed']:
  a=deepcopy(next(v for v in original['assets'] if v['id']=='doorway_workshop_'+state+'_v2'))
  a.update(id='doorway_canteen_side_'+state+'_v3',name='食堂侧门 · 加宽钢门'+('开启' if state=='open' else '关闭'),
   world_size=[260,120],render_size=[260,120],footprint_world_size=[220,20],reused_from='doorway_workshop_'+state+'_v2')
  spec=a['door_presentation'];spec['door_art_size']=[260,120];spec['roof_occludes_door']=True
  for key in ['door_open_patches','door_closed_patches']:
   for patch in spec[key]:
    d=patch['destination'];d[0]*=260/180;d[2]*=260/180
  for key in ['visual_solid_parts','closed_visual_solid_parts']:
   for piece in spec[key]:piece[0]*=260/180;piece[2]*=260/180
  assets.append(a)
 write(ROOT/'art/architecture/canteen_side_v3/manifest.json',dict(schema=2,version='canteen-side-v3',assets=assets))
 p=ROOT/'data/rooms/r04.json';raw=p.read_bytes();digest=sha(p);m=json.loads(raw);before=deepcopy(m)
 gate=next(f for f in m['fixtures'] if f['id']=='campus-life-west-meal')
 assert gate['rect'][0]==880
 gate.update(asset_id='doorway_canteen_side_open_v3',open_asset='doorway_canteen_side_open_v3',closed_asset='doorway_canteen_side_closed_v3',
   rect=[880,1980,20,220],render_size=[260,120],rotation_door_visual_rect=[880,1940,120,260],rotation_quarters=3)
 # Projected headroom extends above the ground opening; the lower jamb
 # finishes exactly at its lower wall shoulder, leaving no unframed gap.
 # Retain array indices for walls, furniture and all room references.
 indices=[]
 for i,r in enumerate(m['walls']):
  if r[0]==880 and r[2]==20 and r[3]==20 and 1980<=r[1]<2200:
   surface=next(s for s in m['architecture']['wall_surfaces'] if s['wall_index']==i)
   surface.update(collision_parts=[],render_enabled=False);indices.append(i)
 room=next(r for r in m['visibility_rooms'] if r['id']=='canteen')
 room['roof_sealed']=True
 for g in m['access_doors']:
  if g['id'] in room['door_ids']:g['roof_occludes_door']=True
 for f in m['fixtures']:
  if f.get('access_id') in room['door_ids']:f['roof_occludes_door']=True
 for k in m:
  if k not in ['fixtures','architecture','visibility_rooms','access_doors']:assert m[k]==before[k],k
 assert m['walls']==before['walls']
 (OUT/'before-map.json').write_bytes(raw)
 write(OUT/'map-registration.json',dict(input_sha256=digest,door_id=gate['id'],disabled_wall_surface_indices=indices,logical_opening_before=before['fixtures'][before['fixtures'].index(next(f for f in before['fixtures'] if f['id']==gate['id']))]['rect'],logical_opening_after=gate['rect']))
 with tempfile.NamedTemporaryFile(mode='w',encoding='utf-8',dir=p.parent,delete=False) as f:
  f.write(json.dumps(m,ensure_ascii=False,indent='\t')+'\n');temp=f.name
 assert sha(p)==digest,'Latest map changed; retry.'
 os.replace(temp,p)
 print(json.dumps(dict(disabled_wall_surface_indices=indices,map_sha256=sha(p))))
if __name__=='__main__':register()
