"""Install approved D doorway without modifying the rest of the saved map."""
from pathlib import Path
from copy import deepcopy
import hashlib,json,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/campus-kiosk-open-entry-d'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 record=read(DOC/'generation.json')
 png=ROOT/record['output'];png.parent.mkdir(parents=True,exist_ok=True)
 shutil.copyfile(record['source'],png)
 im=Image.open(png);assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
 x,y,r,b=im.getchannel('A').point(lambda a:255 if a>=180 else 0).getbbox()
 manifest=ROOT/'art/architecture/kiosk_v2/manifest.json';manifest_raw=manifest.read_bytes();m=read(manifest)
 original=next(a for a in m['assets'] if a['id']=='kiosk_side_entry_v2')
 a=deepcopy(original)
 a.update(id='kiosk_open_entry_d_v3',name='小卖铺 · D敞开式门洞',texture='res://'+record['output'],texture_size=list(im.size),region=[x,y,r-x,b-y],sha256=sha(png),authoring_set='kiosk-open-entry-d',world_size=[80,162],render_size=[80,162],footprint_world_size=[80,162],ground_rect=[0,0,r-x,b-y],blocking=False,elevation_world=0)
 m['assets']=[e for e in m['assets'] if e['id']!=a['id']]+[a]
 p=ROOT/'data/rooms/r04.json';raw=p.read_bytes();map_data=read(p)
 entry=next(f for f in map_data['fixtures'] if f['id']=='kiosk-side-entry')
 assert entry['asset_id']=='kiosk_side_entry_v2','Unexpected current doorway; preserve user changes.'
 assert int(entry.get('rotation_quarters',0))==0,'Doorway moved/rotated; inspect latest geometry.'
 left,top,width,height=entry['rect']
 canopy=next(f for f in map_data['fixtures'] if f['id']=='kiosk-front-canopy')
 entry.update(asset_id=a['id'],rect=[left+width-80,top,80,height],render_size=[80,height],blocks_movement=False,draw_depth=float(canopy['draw_depth'])+16)
 assert p.read_bytes()==raw and manifest.read_bytes()==manifest_raw,'Concurrent edit; retry latest files.'
 (DOC/'before.json').write_bytes(raw);(DOC/'manifest-before.json').write_bytes(manifest_raw)
 write(manifest,m);write(p,map_data);write(DOC/'after.json',map_data)
 write(DOC/'registration.json',dict(assets=[dict(key='open-entry-d',path=record['output'],sha256=sha(png))],definition_ids=[a['id']],map_before_sha256=hashlib.sha256(raw).hexdigest(),map_after_sha256=sha(p)))
 print(json.dumps(dict(asset=a['id'],size=im.size,region=a['region'],fixture=entry),ensure_ascii=True))
if __name__=='__main__':run()
