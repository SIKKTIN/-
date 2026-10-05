"""Read-only PNG analysis; byte-identical source copy and region metadata only."""
from pathlib import Path
from PIL import Image
import numpy as np
import json,hashlib,shutil

ROOT=Path(__file__).resolve().parents[3]
DOC=Path(__file__).resolve().parent
SOURCE=Path(r'C:\Users\gst20\.codex\generated_images\01a10697-9228-7c00-906b-43051bade1e0\exec-83fbd5d3-1697-49b7-ac5b-01f7a2f6736a.png')
TARGET=ROOT/'art/characters/dog/police-dog-atlas-v01.png'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,obj):p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
if TARGET.exists():assert sha(TARGET)==sha(SOURCE),'Do not overwrite generated PNG'
else:shutil.copyfile(SOURCE,TARGET)
im=Image.open(TARGET);array=np.asarray(im);assert im.mode=='RGBA'
frames=[];reports=[];head_roots=[]
for i in range(5):
 row,col=divmod(i,3);x0=int(col*im.width/3);x1=int((col+1)*im.width/3);y0=int(row*im.height/2);y1=int((row+1)*im.height/2)
 cell=array[y0:y1,x0:x1,3];yy,xx=np.where(cell>32)
 bx=x0+int(xx.min());by=y0+int(yy.min());bw=int(xx.max()-xx.min()+1);bh=int(yy.max()-yy.min()+1)
 x=max(x0,bx-6);y=max(y0,by-6);w=min(x1,bx+bw+6)-x;h=min(y1,by+bh+6)-y
 hy,hx=np.where(array[by:by+int(bh*.35),bx:bx+bw,3]>128)
 head_center=bx+(int(hx.min())+int(hx.max())+1)/2
 head_roots.append(head_center)
 frames.append({'id':'idle' if i==0 else 'walk_'+str(i-1),'region':[x,y,w,h],'anchor':[0,by+bh-y]})
 crop=array[y:y+h,x:x+w,3];complete=int((crop>32).sum())==int((cell>32).sum())
 reports.append({'id':frames[-1]['id'],'body_bounds':[bx,by,bw,bh],'head_center_x':head_center,'head_width':int(hx.max()-hx.min()+1),'cell':[x0,y0,x1-x0,y1-y0],'region_inside_cell':x>=x0 and y>=y0 and x+w<=x1 and y+h<=y1,'complete_core_pixels':complete,'core_pixel_count':int((crop>32).sum()),'region':frames[-1]['region']})
scale_height=float(np.median([r['body_bounds'][3]for r in reports[1:]]));world=44
lower_hashes=[];heights=[];head_widths=[]
for i,(frame,r)in enumerate(zip(frames,reports)):
 x,y,w,h=frame['region'];frame['anchor'][0]=round(head_roots[i]-scale_height*.25-x,1)
 r.update({'anchor':frame['anchor'],'visible_world_height':r['body_bounds'][3]*world/scale_height,'foot_world_error':0,'scale':world/scale_height})
 if i:
  crop=array[y+int(h*.58):y+h,x:x+w,3]>32
  lower_hashes.append(hashlib.sha256(crop.tobytes()).hexdigest());heights.append(r['visible_world_height']);head_widths.append(r['head_width'])
spread=(max(heights)-min(heights))/float(np.median(heights));head_spread=(max(head_widths)-min(head_widths))/float(np.median(head_widths))
texture='res://'+TARGET.relative_to(ROOT).as_posix()
idle={'texture':texture,**frames[0],'scale_height':scale_height}
manifest={'schema':1,'version':'police-dog-art-v01-20261005','actor_id':'police_dog','identity':'German Shepherd police dog','world_height':world,'scale_height':scale_height,'idle':idle,'walk_animation':{'texture':texture,'texture_size':list(im.size),'frames':frames[1:],'fps':10,'scale_height':scale_height,'direction':'right','shadow_baked':False},'render_contract':'ALL idle/walk frames: scale=world_height/scale_height, destination_pos=world_foot-anchor*scale, size=region.size*scale; mirror whole draw at world_foot for left','sha256':sha(TARGET)}
write(ROOT/'art/characters/dog/manifest-v01.json',manifest)
write(ROOT/'art/characters/dog/manifest.json',manifest)
baseline_file=DOC/'old-assets-v01.json'
if not baseline_file.exists():
 files=[]
 for folder in ['art/characters','scripts','data','scenes']:
  for p in sorted((ROOT/folder).rglob('*')):
   if p.is_file() and '/dog/'not in p.as_posix() and p.suffix in ['.json','.png','.svg','.gd','.tscn']:
    files.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)})
 for p in [ROOT/'project.godot']:
  files.append({'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)})
 write(baseline_file,{'files':files,'note':'Read-only baseline; producer may independently edit gameplay during A08'})
baseline=json.loads(baseline_file.read_text(encoding='utf-8'))['files']
changed=[b['path']for b in baseline if sha(ROOT/b['path'])!=b['sha256']]
qa={'passed':sha(SOURCE)==sha(TARGET)and spread<=.06 and head_spread<=.08 and len(set(lower_hashes))==4 and all(r['region_inside_cell']and r['complete_core_pixels']for r in reports),'mode':im.mode,'source_size':list(im.size),'transparent_pixel_fraction':float((array[:,:,3]==0).mean()),'background_empty_cell_core_pixels':int((array[im.height//2:,im.width*2//3:,3]>32).sum()),'background_empty_cell_alpha_max':int(array[im.height//2:,im.width*2//3:,3].max()),'copy_matches_original':sha(SOURCE)==sha(TARGET),'walk_body_height_spread_fraction':spread,'walk_head_width_spread_fraction':head_spread,'distinct_lower_leg_masks':len(set(lower_hashes)),'frames':reports,'baseline_file_count':len(baseline),'changed_baseline_files':changed,'scope':'source alpha, complete own-core crops, empty cell, distinct leg masks, shared scale and foot registration; source poses also visually reviewed'}
write(DOC/'qa-resources-v01.json',qa)
write(DOC/'source-license-v01.json',{'schema':1,'mode':'built-in imagegen','source_png':str(SOURCE),'project_png':TARGET.relative_to(ROOT).as_posix(),'sha256':sha(TARGET),'reference':'art/characters/guard_01_handpaint_v03.png','reference_sha256':sha(ROOT/'art/characters/guard_01_handpaint_v03.png'),'prompt':'docs/art/police-dog/prompt-v01.json','license':'Generated project artwork using only project-owned reference','pixel_policy':'byte-identical original generated PNG; no code edits, interpolation, background removal or silhouette modifications'})
print(json.dumps({k:qa[k]for k in ['passed','source_size','copy_matches_original','walk_body_height_spread_fraction','walk_head_width_spread_fraction','distinct_lower_leg_masks','background_empty_cell_core_pixels','changed_baseline_files']}))
