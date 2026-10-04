"""Copy the original merchant PNG unchanged; measure alpha and create registrations.
Reads source pixels, never edits or resamples generated image data.
"""
import hashlib,json,shutil
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[2]
doc=root/'docs/art'
source=Path(r'C:\Users\gst20\.codex\generated_images\01a10697-9228-7c00-906b-43051bade1e0\exec-46939d32-9602-43a0-b140-14f313048dc9.png')
target=root/'art/characters/merchant/merchant_idle_v07.png'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
target.parent.mkdir(parents=True,exist_ok=True)
if target.exists():
    if sha(source)!=sha(target):raise RuntimeError('Refuse to overwrite merchant asset')
else:shutil.copyfile(source,target)
im=Image.open(target);a=np.asarray(im)
assert im.mode=='RGBA'
m=a[:,:,3]>32;y,x=np.where(m)
box=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]
padding=6
region=[box[0]-padding,box[1]-padding,box[2]-box[0]+padding*2,box[3]-box[1]+padding*2]
# Anchor is centered between planted shoes, at the last opaque bottom edge.
foot_y=int(box[3]-(box[3]-box[1])*0.18)
foot_mask=(a[:,:,3]>128)&(np.indices(a.shape[:2])[0]>=foot_y)
_,foot_x=np.where(foot_mask)
anchor=[(int(foot_x.min())+int(foot_x.max())+1)/2-region[0],box[3]-region[1]]
merchant={'texture':'res://art/characters/merchant/merchant_idle_v07.png','region':region,'anchor':anchor,'world_height':64,'opaque_bounds':[padding,padding,box[2]-box[0],box[3]-box[1]],'shadow_baked':False,'npc_role':'merchant','animation':'idle','actor_id':None}
records=json.loads((doc/'a05-icon-sources-v07.json').read_text())['records']
items={r['id']:{'texture':'res://'+r['texture'],'world_size':[26,26],'hud_size':[28,28]}for r in records if '/items/' in r['texture']}
icons={r['id']:{'texture':'res://'+r['texture'],'display_sizes':[24,28,32]}for r in records if '/ui/' in r['texture']}
manifest={'schema':1,'version':'inventory-art-v07-20261005','base_style':'art-v03 / FINAL-WARM-01','merchant':merchant,'items':items,'icons':icons,'slot_size':[47,48],'shadow_policy':'Merchant ground shadows drawn once by producer; no item/icon cast shadows','source_license':'docs/art/a05-source-license-v07.json'}
(doc/'inventory-assets-v07.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
provenance={'schema':1,'mode':'built-in imagegen for merchant; original SVG for icons','merchant':{'source':str(source),'texture':str(target.relative_to(root)).replace('\\','/'),'sha256':sha(target),'source_sha256':sha(source),'original_copy_matches':sha(source)==sha(target),'prompt':'docs/art/a05-merchant-v07.prompt.txt','references':['art/characters/inmate_02_handpaint_v03.png','art/characters/guard_01_handpaint_v03.png'],'license':'Project-owned generated original artwork; project-owned style references; no copied third-party game assets'},'icons':records,'icon_license':'Project-owned original vector artwork; existing project UI line system; no third-party artwork'}
(doc/'a05-source-license-v07.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
rows=[]
for p in [target]+[root/r['texture']for r in records]:
    z=Image.open(p);q=np.asarray(z);mask=q[:,:,3]>32;yy,xx=np.where(mask)
    rows.append({'path':str(p.relative_to(root)).replace('\\','/'),'size':list(z.size),'mode':z.mode,'opaque_bounds':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],'transparent_border':bool(np.all(q[0,:,3]==0)and np.all(q[-1,:,3]==0)and np.all(q[:,0,3]==0)and np.all(q[:,-1,3]==0)),'alpha_min':int(q[:,:,3].min()),'alpha_max':int(q[:,:,3].max()),'sha256':sha(p)})
old_checks=[]
for v in ['v01','v02','v03']:
    old=json.loads((doc/f'delivery-{v}.json').read_text(encoding='utf-8-sig'))
    for f in old['files']:old_checks.append({'path':f['path'],'unchanged':sha(root/f['path'])==f['sha256']})
passed=all(r['transparent_border']and r['mode']=='RGBA'and r['alpha_min']==0 and r['alpha_max']==255 for r in rows)and all(r['unchanged']for r in old_checks)
qa={'merchant_registration':merchant,'merchant_visible_height':(box[3]-box[1])*64/region[3],'merchant_foot_padding_world':padding*64/region[3],'resources':rows,'old_files_unchanged':all(r['unchanged']for r in old_checks),'old_file_count':len(old_checks),'original_merchant_copy_matches':sha(source)==sha(target),'passed':passed}
(doc/'a05-qa-resources-v07.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'passed':passed,'merchant':merchant,'textures':len(rows),'failed_borders':[r['path']for r in rows if not r['transparent_border']]}))
