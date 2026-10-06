"""Read original RGBA atlas; output region/foot metadata and QA. Never edit PNG pixels."""
import json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/characters/thug_v17'
P=OUT/'thug_idle_walk8_v17.png'
SOURCE=Path('C:/Users/gst20/.codex/generated_images/01a10ab4-5cf7-7c70-8247-13b529a3f2da/exec-912a4aca-5c4c-4982-9c58-567427a61503.png')
im=Image.open(P); a=np.asarray(im); assert im.mode=='RGBA'
mask=a[:,:,3]>32
frames=[];checks=[]
for i in range(9):
 c=i%3;r=i//3
 x0=round(c*im.width/3);x1=round((c+1)*im.width/3)
 y0=round(r*im.height/3);y1=round((r+1)*im.height/3)
 cell=mask[y0:y1,x0:x1];yy,xx=np.where(cell)
 assert len(xx)>1000
 bx=int(xx.min())+x0; br=int(xx.max())+1+x0
 by=int(yy.min())+y0; bb=int(yy.max())+1+y0
 rx=max(x0,bx-6);ry=max(y0,by-6);rr=min(x1,br+6);rb=min(y1,bb+6)
 head=mask[by:by+round((bb-by)*.23),bx:br]
 hy,hx=np.where(head)
 head_center=(int(hx.min())+int(hx.max())+1)/2+bx
 anchor=[round(head_center-rx,3),bb-ry]
 region=[rx,ry,rr-rx,rb-ry]
 frame={'id':'idle' if i==0 else 'walk_%d'%(i-1),'region':region,'anchor':anchor}
 frames.append(frame)
 excluded=int(cell.sum()-mask[ry:rb,rx:rr].sum())
 checks.append({'id':frame['id'],'cell':[x0,y0,x1-x0,y1-y0],'core_bounds':[bx,by,br-bx,bb-by],'region':region,'anchor':anchor,'core_pixels_omitted':excluded,'clear_of_cell_edges':bx>x0 and br<x1 and by>y0 and bb<y1,'local_anchor_valid':0<=anchor[0]<=region[2] and 0<=anchor[1]<=region[3],'pose_sha256':hashlib.sha256(a[by:bb,bx:br].tobytes()).hexdigest(),'passed':excluded==0 and bx>x0 and br<x1 and by>y0 and bb<y1})
scale_height=frames[0]['region'][3]
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
manifest={'schema':1,'version':'thug-art-v17-20261006','base_style':'art-v03 / FINAL-WARM-01','actor_id':'guard','texture':'res://art/characters/thug_v17/thug_idle_walk8_v17.png','texture_size':list(im.size),'world_height':60,'initial_walk_frame_seconds':1/12,'frames':{'idle':frames[0]['region'],'walk_a':frames[1]['region'],'walk_b':frames[5]['region']},'anchor':{'idle':frames[0]['anchor'],'walk_a':frames[1]['anchor'],'walk_b':frames[5]['anchor']},'shadow_baked':False,'direction':'right','sha256':sha(P),'walk_animation':{'texture':'res://art/characters/thug_v17/thug_idle_walk8_v17.png','texture_size':list(im.size),'fps':12,'scale_height':scale_height,'frames':frames[1:],'shadow_baked':False,'direction':'right','cycle_seconds':8/12,'region_policy':'Independent clean atlas regions; every walk frame uses world_height / scale_height, never region height','registration_origin':'Head-center axis over lowest opaque shoe sole; per-frame source anchor maps to shared world foot origin'}}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'schema':1,'passed':all(c['passed']for c in checks) and sha(P)==sha(SOURCE),'rgba':True,'source_png':str(SOURCE),'delivered_png':str(P),'source_size':list(im.size),'source_sha256':sha(SOURCE),'delivered_sha256':sha(P),'copy_matches_source':sha(P)==sha(SOURCE),'alpha0_fraction':float((a[:,:,3]==0).mean()),'unique_pose_hashes':len(set(c['pose_sha256']for c in checks)),'world_height':60,'walk_scale_height':scale_height,'uniform_scale':60/scale_height,'frames':checks,'scope':'RGBA/source hash/crops/independent pixel pose checks; native contact and visual identity reviewed separately; production controller/map QA by producer'}
(ROOT/'docs/art/a17-resource-qa.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'passed':report['passed'],'size':im.size,'scale_height':scale_height,'poses':frames},ensure_ascii=False))
