from pathlib import Path
import shutil,json,re,hashlib
from PIL import Image
import numpy as np
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v28';qa=doc/'godot-qa'
target=root/'art/editor/v08/icons';target.mkdir(parents=True,exist_ok=True)
for p in (qa/'art/editor/v08/icons').glob('*.tres'):
    (target/p.name).write_text(re.sub(r' uid="uid://[^\"]+"','',p.read_text(encoding='utf-8-sig')),encoding='utf-8')
for name in ['native-preview.png','native-detail.png','native-preview.json','icons-qa.json']:
    shutil.copy2(qa/name,doc/name)
a=np.asarray(Image.open(doc/'native-preview.png').convert('RGB'));checks=[]
for i in range(4):
    x=32+i*312+68;y=590;b=a[y:y+128,x:x+128].astype(int);bg=a[563,35+i*312].astype(int)
    n=int((abs(b-bg).max(2)>12).sum());checks.append({'icon':i+1,'nonbackground_pixels':n,'visible':n>2000})
assert all(c['visible'] for c in checks)
assert not (doc/'native-preview.stderr.log').read_text(encoding='utf-8-sig').strip()
(doc/'native-icons-visible.json').write_text(json.dumps({'checked':4,'all_visible':True,'checks':checks,'basis':'actual native GPU viewport; no resource-only approval','stderr_empty':True},indent=2)+'\n',encoding='utf-8')
png=root/'art/architecture/v28/cafeteria_turn_master_v28.png'
source=Path(r'C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-5d6a9638-38b3-47f3-9e1d-4132b85f1a07.png')
im=Image.open(png);alpha=np.asarray(im)[:,:,3]
old={}
for version in ['v24','v25','v26','v27']:
    d=json.loads((root/('docs/art/architecture-'+version+'/delivery.json')).read_text(encoding='utf-8-sig'))
    old[version]=all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in d['files'])
assert all(old.values()) and png.read_bytes()==source.read_bytes()
review={'mode':'built-in imagegen targeted edit, unchanged output bytes','source_copy_matches':True,'sha256':hashlib.sha256(png.read_bytes()).hexdigest(),'size':list(im.size),'image_mode':im.mode,'alpha_range':[int(alpha.min()),int(alpha.max())],'inner_notch_alpha':int(alpha[800,800]),'old_deliveries_unchanged':old,'assets':4,'single_new_corner_source':True,'native_trial':'continuous L top and inside chamfer; old facade/columns/lintel retained; actual game connection review pending'}
assert review['inner_notch_alpha']==0
(doc/'source-review.json').write_text(json.dumps(review,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'icons':4,'all_visible':True,'source_copy_matches':True,'old_unchanged':old}))
