from pathlib import Path
import json,hashlib,shutil,re
from PIL import Image
import numpy as np
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v30';qa=doc/'godot-qa'
target=root/'art/editor/v10/icons';target.mkdir(parents=True,exist_ok=True)
for p in (qa/'art/editor/v10/icons').glob('*.tres'):
    (target/p.name).write_text(re.sub(r' uid="uid://[^\"]+"','',p.read_text(encoding='utf-8-sig')),encoding='utf-8')
for name in ['native-preview.png','native-detail.png','native-preview.json','icons-qa.json']:shutil.copy2(qa/name,doc/name)
a=np.asarray(Image.open(doc/'native-preview.png').convert('RGB'));checks=[]
for i in range(2):
    x=200+i*620+66;y=545
    b=a[y:y+128,x:x+128].astype(int);bg=a[513,203+i*620].astype(int)
    n=int((abs(b-bg).max(2)>12).sum());checks.append(dict(icon=i+1,nonbackground_pixels=n,visible=n>1500))
assert all(c['visible'] for c in checks)
assert not (doc/'native-preview.stderr.log').read_text(encoding='utf-8-sig').strip()
(doc/'native-icons-visible.json').write_text(json.dumps(dict(checked=2,all_visible=True,checks=checks,basis='actual native GPU pixels; not resource-load-only',stderr_empty=True),indent=2)+'\n',encoding='utf-8')
png=root/'art/architecture/v30/cafeteria_t_master_v30.png';source=Path(r'C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-94afff07-4727-4cb5-8311-5408720e6fd6.png')
im=Image.open(png);alpha=np.asarray(im)[:,:,3]
old={};differences={}
for v in ['v24','v25','v26','v27','v28','v29']:
    d=json.loads((root/('docs/art/architecture-'+v+'/delivery.json')).read_text(encoding='utf-8-sig'))
    delta=[f['path'] for f in d['files'] if hashlib.sha256((root/f['path']).read_bytes()).hexdigest()!=f['sha256']]
    old[v]=not delta
    if delta:differences[v]=delta
assert png.read_bytes()==source.read_bytes()
review=dict(mode='built-in imagegen approved natural masonry source, raw unchanged copy',source_copy_matches=True,sha256=hashlib.sha256(png.read_bytes()).hexdigest(),size=list(im.size),image_mode=im.mode,alpha_range=[int(alpha.min()),int(alpha.max())],lower_left_notch_alpha=int(alpha[650,300]),lower_right_notch_alpha=int(alpha[650,1300]),old_deliveries_unchanged=old,old_package_differences=differences,assets=2,single_new_T_source=True,source_L_used_as_parts=False,native_trial='ordinary masonry header and two upright stem blocks, no T plaque; actual kitchen review pending')
assert review['lower_left_notch_alpha']==0 and review['lower_right_notch_alpha']==0
(doc/'source-review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(icons=2,all_visible=True,source_copy_matches=True,old_unchanged=old,differences=differences)))

