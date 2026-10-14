"""Tighten the roof recess and give near/far jambs independent depth."""
from pathlib import Path
from copy import deepcopy
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[1];DOC=ROOT/'docs/art/campus-kiosk-west-recess'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 manifest=ROOT/'art/architecture/kiosk_v2/manifest.json';manifest_raw=manifest.read_bytes();catalog=read(manifest)
 base=next(a for a in catalog['assets'] if a['id']=='kiosk_west_recess_v4')
 _,_,w,h=base['region']
 def part(name,dims,foot,patches):
  a=deepcopy(base);a.update(id='kiosk_recess_'+name+'_v4',name='小卖铺 · '+name,world_size=dims,render_size=dims,footprint_world_size=foot,ground_rect=[0,h-foot[1]/dims[1]*h,w,foot[1]/dims[1]*h],elevation_world=dims[1]-foot[1],assembly_patches=[dict(source=s,destination=d) for s,d in patches]);return a
 north=part('north_return',[112,24],[112,24],[([38,264,1018,235],[0,0,112,24])])
 south=part('south_return',[112,46],[112,30],[([190,1014,866,195],[18.2,16,93.8,30]),([25,932,165,284],[0,0,18.2,46])])
 canopy=deepcopy(next(a for a in catalog['assets'] if a['id']=='kiosk_recess_canopy_v4'));canopy.update(region=[407,435,918,211],world_size=[528,528*211/918],render_size=[528,528*211/918],footprint_world_size=[528,30],ground_rect=[0,211-30/(528*211/918)*211,918,30/(528*211/918)*211],elevation_world=528*211/918-30)
 catalog['assets']=[a for a in catalog['assets'] if a['id'] not in [north['id'],south['id'],canopy['id']]]+[north,south,canopy]
 p=ROOT/'data/rooms/r04.json';raw=p.read_bytes();m=read(p);room=next(r for r in m['visibility_rooms'] if r['id']=='campus-kiosk');x,y,_,_=room['roof_rect']
 entry=next(f for f in m['fixtures'] if f['id']=='kiosk-side-entry');assert entry['asset_id']=='kiosk_west_recess_v4'
 entry.update(asset_id=south['id'],rect=[x,y+300,112,30],render_size=[112,46],draw_depth=y+330);entry.pop('solid_parts',None)
 m['fixtures'].append(dict(id='kiosk-entry-north-return',asset_id=north['id'],rect=[x,y+136,112,24],render_size=[112,24],draw_depth=y+160,blocks_movement=True,blocks_sight=False,exterior_shell=True))
 room['roof_cutouts']=[[0,136/340,112/640,194/340]]
 awning=next(f for f in m['fixtures'] if f['id']=='kiosk-front-canopy');awning.update(rect=[x+112,y+310,528,30],render_size=canopy['render_size'])
 shelf=next(f for f in m['fixtures'] if f['id']=='kiosk-back-shelf');shelf['rect'][0]=x+95
 floor=deepcopy(next(f for f in m['floor_regions'] if f['id']=='kiosk-floor'));floor.update(id='kiosk-entry-shade',rect=[x,y+160,112,140],tile_origin=[x,y],tint='#a0a8a0',edge_feather=16);m['floor_regions']=[f for f in m['floor_regions'] if f['id']!='kiosk-entry-shade']+[floor]
 assert p.read_bytes()==raw and manifest.read_bytes()==manifest_raw,'Concurrent edit; retry latest.'
 if not (DOC/'before-first-pass.json').exists():shutil.copyfile(DOC/'before.json',DOC/'before-first-pass.json')
 (DOC/'before.json').write_bytes(raw);write(manifest,catalog);write(p,m);write(DOC/'after.json',m)
 registration=read(DOC/'registration.json');registration.update(definition_ids=[north['id'],south['id'],canopy['id']],map_before_sha256=hashlib.sha256(raw).hexdigest(),map_after_sha256=sha(p));write(DOC/'registration.json',registration)
 print('Recess 112 wide; independently sorted north/south returns; continuous shaded indoor floor.')
if __name__=='__main__':run()
