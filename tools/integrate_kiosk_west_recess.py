"""Replace the freestanding frontal doorway with a west-facing recess."""
from pathlib import Path
from copy import deepcopy
import json,hashlib,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/campus-kiosk-west-recess'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 rec=read(DOC/'generation.json');png=ROOT/rec['output'];shutil.copyfile(rec['source'],png)
 im=Image.open(png);assert im.mode=='RGBA';bounds=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox();x,y,r,b=bounds
 manifest=ROOT/'art/architecture/kiosk_v2/manifest.json';manifest_raw=manifest.read_bytes();catalog=read(manifest)
 a=deepcopy(next(a for a in catalog['assets'] if a['id']=='kiosk_open_entry_d_v3'))
 a.update(id='kiosk_west_recess_v4',name='小卖铺 · 西向内凹入口',texture='res://'+rec['output'],texture_size=list(im.size),region=[x,y,r-x,b-y],sha256=sha(png),authoring_set='kiosk-west-recess',world_size=[160,194],render_size=[160,194],footprint_world_size=[160,194],ground_rect=[0,0,r-x,b-y],blocking=True)
 # Original pixels only: register two horizontal returns and the squat pier.
 a['assembly_patches']=[dict(source=s,destination=d) for s,d in [([38,260,1018,239],[0,0,160,24]),([190,1014,866,195],[26,164,134,30]),([24,932,166,284],[0,148,26,46])]]
 canopy=deepcopy(next(a for a in catalog['assets'] if a['id']=='kiosk_front_canopy_v2'))
 canopy.update(id='kiosk_recess_canopy_v4',name='小卖铺 · 入口退让雨棚',region=[490,435,835,211],world_size=[480,480*211/835],render_size=[480,480*211/835],footprint_world_size=[480,30],ground_rect=[0,211-30/(480*211/835)*211,835,30/(480*211/835)*211],elevation_world=480*211/835-30,authoring_set='kiosk-west-recess')
 catalog['assets']=[e for e in catalog['assets'] if e['id'] not in [a['id'],canopy['id']]]+[a,canopy]
 p=ROOT/'data/rooms/r04.json';raw=p.read_bytes();m=read(p)
 room=next(r for r in m['visibility_rooms'] if r['id']=='campus-kiosk');ox,oy,w,h=room['roof_rect'];assert [w,h]==[640,340]
 entry=next(f for f in m['fixtures'] if f['id']=='kiosk-side-entry');assert entry['asset_id']=='kiosk_open_entry_d_v3'
 entry.update(asset_id=a['id'],rect=[ox,oy+136,160,194],render_size=[160,194],blocks_movement=True,solid_parts=[[0,0,1,24/194],[0,164/194,1,30/194]])
 room['roof_cutouts']=[[0,136/340,160/640,194/340]]
 awning=next(f for f in m['fixtures'] if f['id']=='kiosk-front-canopy')
 awning.update(asset_id=canopy['id'],rect=[ox+160,oy+310,480,30],render_size=canopy['render_size'])
 shelf=next(f for f in m['fixtures'] if f['id']=='kiosk-back-shelf');shelf['exterior_shell']=True
 assert p.read_bytes()==raw and manifest.read_bytes()==manifest_raw,'Concurrent map edit; retry latest.'
 (DOC/'before.json').write_bytes(raw);(DOC/'manifest-before.json').write_bytes(manifest_raw)
 write(manifest,catalog);write(p,m);write(DOC/'after.json',m)
 write(DOC/'registration.json',dict(assets=[dict(key='west-recess',path=rec['output'],sha256=sha(png))],definition_ids=[a['id'],canopy['id']],map_before_sha256=hashlib.sha256(raw).hexdigest(),map_after_sha256=sha(p)))
 print(json.dumps(dict(region=a['region'],door=entry,roof_cutouts=room['roof_cutouts']),ensure_ascii=True))
if __name__=='__main__':run()
