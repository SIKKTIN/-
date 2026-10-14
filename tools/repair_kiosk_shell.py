"""Replace stretched old side-door fragments with one continuous shell."""
from pathlib import Path
from copy import deepcopy
import json,hashlib,shutil,os,tempfile
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];DOC=ROOT/'docs/art/campus-kiosk-shell-repair'
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def write(p,v):
 p.parent.mkdir(parents=True,exist_ok=True)
 fd,tmp=tempfile.mkstemp(prefix=p.name+'.',suffix='.tmp',dir=p.parent)
 try:
  with os.fdopen(fd,'w',encoding='utf-8') as f:f.write(json.dumps(v,ensure_ascii=False,indent='\t')+'\n')
  os.replace(tmp,p)
 finally:
  if os.path.exists(tmp):os.unlink(tmp)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 rec=read(DOC/'generation.json');png=ROOT/rec['output']
 p=ROOT/'data/rooms/r04.json';raw=p.read_bytes();m=read(p)
 shell=next(f for f in m['fixtures'] if f['id']=='kiosk-shell')
 manifest=ROOT/'art/architecture/kiosk_v2/manifest.json';manifest_raw=manifest.read_bytes();c=read(manifest)
 if shell['asset_id']=='kiosk_continuous_shell_v6':
  current=next(a for a in c['assets'] if a['id']==shell['asset_id'])
  assert sha(png)==sha(Path(rec['source']))==current['sha256'],'Installed shell PNG differs from its original.'
  assert current['render_size']==shell['render_size']==[640,340]
  print('Continuous shell v6 is already installed; latest map and original repair snapshots preserved.')
  return
 assert shell['asset_id']=='kiosk_closed_side_shell_v5','Unexpected current kiosk shell; inspect latest map before replacement.'
 if not png.exists() or sha(png)!=sha(Path(rec['source'])):shutil.copyfile(rec['source'],png)
 im=Image.open(png);assert im.mode=='RGBA';alpha=im.getchannel('A');x,y,r,b=alpha.point(lambda a:255 if a>=180 else 0).getbbox()
 a=deepcopy(next(a for a in c['assets'] if a['id']=='kiosk_closed_side_shell_v5'))
 a.update(id='kiosk_continuous_shell_v6',name='小卖铺 · 连续墙壳修正版',texture='res://'+rec['output'],texture_size=list(im.size),region=[x,y,r-x,b-y],sha256=sha(png),authoring_set='kiosk-shell-repair',ground_rect=[0,0,r-x,b-y])
 # Register whole horizontal bands of the NEW continuous original. Both
 # sides remain contiguous; no old doorway or end-cap fragment is stretched.
 a['assembly_patches']=[dict(source=[x,y,r-x,280-y],destination=[0,0,640,116]),dict(source=[x,280,r-x,b-280],destination=[0,116,640,224])]
 c['assets']=[e for e in c['assets'] if e['id']!=a['id']]+[a]
 shell['asset_id']=a['id']
 assert p.read_bytes()==raw and manifest.read_bytes()==manifest_raw,'Concurrent edit; retry latest.'
 (DOC/'before.json').write_bytes(raw);(DOC/'manifest-before.json').write_bytes(manifest_raw)
 write(manifest,c);write(p,m);write(DOC/'after.json',m)
 registration=read(ROOT/'docs/art/campus-kiosk-front-entry/registration.json');registration.update(assets=[dict(key='continuous-wall-shell',path=rec['output'],sha256=sha(png))],definition_ids=[a['id']],map_before_sha256=hashlib.sha256(raw).hexdigest(),map_after_sha256=sha(p));write(DOC/'registration.json',registration)
 print(json.dumps(dict(size=im.size,region=a['region'],patches=a['assembly_patches']),ensure_ascii=True))
if __name__=='__main__':run()
