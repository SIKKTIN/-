from pathlib import Path
import shutil,json,re
from PIL import Image
import numpy as np
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v27';qa=doc/'godot-qa'
target=root/'art/editor/v07/icons';target.mkdir(parents=True,exist_ok=True)
for p in (qa/'art/editor/v07/icons').glob('*.tres'):
    text=p.read_text(encoding='utf-8-sig')
    text=re.sub(r' uid="uid://[^\"]+"','',text)
    (target/p.name).write_text(text,encoding='utf-8')
for name in ['native-preview.png','native-detail.png','native-preview.json','icons-qa.json']:
    shutil.copy2(qa/name,doc/name)
im=np.asarray(Image.open(doc/'native-preview.png').convert('RGB'))
checks=[]
for i in range(10):
    x=24+(i%5)*250+48;y=500+(i//5)*195+14
    a=im[y:y+128,x:x+128].astype(int)
    bg=im[500+(i//5)*195+3,24+(i%5)*250+3].astype(int)
    count=int((abs(a-bg).max(2)>12).sum())
    checks.append({'icon':i+1,'nonbackground_pixels':count,'visible':count>1000})
assert all(c['visible'] for c in checks)
assert (doc/'native-preview.stderr.log').read_text(encoding='utf-8-sig').strip()==''
(doc/'native-icons-visible.json').write_text(json.dumps({'checked':10,'all_visible':True,'checks':checks,'basis':'actual GPU viewport pixels, not only resource load','stderr_empty':True},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'icons':len(checks),'all_visible':True,'min_pixels':min(c['nonbackground_pixels'] for c in checks)}))
