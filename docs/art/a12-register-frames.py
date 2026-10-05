"""Register original imagegen poses with metadata only. PNG artwork stays byte-identical.
Pillow/numpy are used ONLY to read alpha and measure masks, not to edit or save artwork.
"""
import json, hashlib, statistics
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
PNG=ROOT/'art/characters/merchant/walk_v12/merchant_walk8_v12.png'
SOURCE=Path(r'C:/Users/gst20/.codex/generated_images/01a10ab4-5cf7-7c70-8247-13b529a3f2da/exec-bf7d0d66-1d65-468b-9a8d-87529aca28b6.png')
IDLE=ROOT/'art/characters/merchant/merchant_idle_v07.png'
OLD_SHA='61e43132d13615bf4c712fb16038f4fee03c9bb7d436163919a3d7826b55f7ed'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def write(path,data):
 path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
im=Image.open(PNG);a=np.asarray(im)
assert im.mode=='RGBA',im.mode
counts=(a[:,:,3]>32).sum(axis=1)
empty=[y for y in range(int(im.height*.4),int(im.height*.6)) if counts[y]==0]
assert empty,'No empty separator'
separator=min(empty,key=lambda y:abs(y-im.height/2))
measurements=[];frames=[]
for i in range(8):
 row,col=divmod(i,4); x0=int(col*im.width/4); x1=int((col+1)*im.width/4)
 y0=0 if row==0 else separator;y1=separator if row==0 else im.height
 mask=a[y0:y1,x0:x1,3]>32
 yy,xx=np.where(mask)
 assert len(xx),i
 bx0=x0+int(xx.min());by0=y0+int(yy.min());bx1=x0+int(xx.max())+1;by1=y0+int(yy.max())+1
 h=by1-by0;w=bx1-bx0
 head=a[by0:by0+int(h*.3),bx0:bx1,3]>128
 _,hx=np.where(head)
 headwidth=int(hx.max()-hx.min()+1)
 root_x=round(bx0+(int(hx.min())+int(hx.max())+1)/2)
 foot_y=by1
 x=max(0,bx0-6);y=max(0,by0-6);right=min(im.width,bx1+6);bottom=min(im.height,by1+6)
 region=[x,y,right-x,bottom-y];anchor=[root_x-x,foot_y-y]
 core=a[y:bottom,x:right,3]>32
 cy,cx=np.indices(core.shape)
 neighbor=int((core&((cx+x<x0)|(cx+x>=x1)|(cy+y<y0)|(cy+y>=y1))).sum())
 own=int(mask.sum());actual=int(core.sum())
 frames.append({'id':f'walk_{i}','region':region,'anchor':anchor})
 measurements.append({'id':f'walk_{i}','cell':[x0,y0,x1-x0,y1-y0],'opaque_canvas_bounds':[bx0,by0,w,h],'body_height_px':h,'head_width_px':headwidth,'head_axis_x':root_x,'foot_y':foot_y,'region':region,'anchor':anchor,'neighbor_core_pixels':neighbor,'own_core_pixels':own,'region_core_pixels':actual,'isolated':neighbor==0 and own==actual})
idle=np.asarray(Image.open(IDLE))
r=[314,149,644,1035]
idle_alpha=idle[r[1]:r[1]+r[3],r[0]:r[0]+r[2],3]>32
yy,xx=np.where(idle_alpha);idle_core_h=int(yy.max()-yy.min()+1)
idle_visible=64*idle_core_h/r[3]
median_h=float(statistics.median(m['body_height_px']for m in measurements))
scale_height=median_h*64/idle_visible
scale=64/scale_height
registered=[]
max_h=max(m['body_height_px']for m in measurements)+24
max_w=max(m['opaque_canvas_bounds'][2]for m in measurements)+128
for m in measurements:
 bx,by,w,h=m['opaque_canvas_bounds']
 mm=np.zeros((max_h,max_w),dtype=bool)
 axis=max_w//2
 left=axis-(m['head_axis_x']-bx)
 top=max_h-8-h
 mm[top:top+h,left:left+w]=a[by:by+h,bx:bx+w,3]>32
 registered.append(mm[int(max_h*.55):])
 m['visible_world_height']=round(m['body_height_px']*scale,4)
 m['head_world_width']=round(m['head_width_px']*scale,4)
 m['foot_world_error']=0
distinct=len(set(hashlib.sha256(m.tobytes()).hexdigest()for m in registered))
changes=[]
for i in range(8):
 j=(i+1)%8
 u=np.logical_or(registered[i],registered[j]).sum()
 d=np.logical_xor(registered[i],registered[j]).sum()
 changes.append({'from':i,'to':j,'lower_silhouette_changed_fraction':round(float(d/max(1,u)),4)})
height_spread=(max(m['body_height_px']for m in measurements)-min(m['body_height_px']for m in measurements))/median_h
head_values=[m['head_width_px']for m in measurements]
head_spread=(max(head_values)-min(head_values))/statistics.median(head_values)
walk={'texture':'res://art/characters/merchant/walk_v12/merchant_walk8_v12.png','texture_size':list(im.size),'fps':12,'scale_height':round(scale_height,8),'region_policy':'individual clean regions; world_height / scale_height for ALL frames, never divide by region height','registration_origin':'head-center axis at lowest opaque shoe sole; source anchor maps to shared world foot','row_separator':separator,'frames':frames,'shadow_baked':False,'direction':'right','cycle_seconds':8/12,'sha256':sha(PNG)}
manifest={'schema':1,'version':'merchant-walk-art-v12-20261005','base_style':'art-v03 / FINAL-WARM-01','npc_role':'merchant','world_height':64,'idle_policy':'keep inventory-assets-v07 merchant idle; this manifest only overrides actual-displacement walk','walk_animation':walk}
write(ROOT/'art/characters/merchant/walk_v12/manifest.json',manifest)
passed=sha(PNG)==sha(SOURCE) and sha(IDLE)==OLD_SHA and distinct==8 and height_spread<=.06 and head_spread<=.08 and all(m['isolated']for m in measurements)
qa={'schema':1,'passed':passed,'rgba':im.mode=='RGBA','source_size':list(im.size),'copy_matches_original':sha(PNG)==sha(SOURCE),'old_idle_unchanged':sha(IDLE)==OLD_SHA,'old_idle_sha256':sha(IDLE),'body_height_spread_fraction':round(height_spread,4),'head_width_spread_fraction':round(head_spread,4),'scale_height':walk['scale_height'],'idle_visible_world_height':round(idle_visible,4),'median_visible_world_height':round(median_h*scale,4),'distinct_lower_silhouettes':distinct,'neighbor_lower_silhouette_changes':changes,'frames':measurements,'scope':'alpha geometry/metadata only; unique masks do not prove correct gait order; pose identity and loop separately reviewed visually'}
write(ROOT/'docs/art/a12-qa-resources.json',qa)
print(json.dumps({k:qa[k]for k in ['passed','rgba','source_size','body_height_spread_fraction','head_width_spread_fraction','scale_height','idle_visible_world_height','median_visible_world_height','distinct_lower_silhouettes','old_idle_unchanged']}))
assert passed
