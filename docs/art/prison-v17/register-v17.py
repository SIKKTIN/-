"""Analyze original generated PNGs and write registration JSON. Never alter PNG pixels."""
from pathlib import Path
from PIL import Image
import numpy as np
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[3];DOC=Path(__file__).resolve().parent;OUT=ROOT/'art/props/prison_v17'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,obj):p.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
inputs=json.loads((DOC/'image-inputs-v17.json').read_text(encoding='utf-8'))['assets']
assets=[];qa=[];sources=[]
mount_heights={'wall_vent':54,'caged_wall_lamp':65,'pipe_valve':10,'fire_extinguisher':16,'notice_board':50}
for e in inputs:
 source=Path(e['source']);target=OUT/e['filename']
 if target.exists():assert sha(target)==sha(source),'Refuse overwrite '+str(target)
 else:shutil.copyfile(source,target)
 im=Image.open(target);arr=np.asarray(im);assert im.mode=='RGBA'
 is_gate=e['kind']=='gate';count=2 if is_gate else 1
 regions=[];bounds=[]
 for i in range(count):
  x0=im.width*i//count;x1=im.width*(i+1)//count;alpha=arr[:,x0:x1,3];yy,xx=np.where(alpha>32)
  bx=x0+int(xx.min());by=int(yy.min());bw=int(xx.max()-xx.min()+1);bh=int(yy.max()-yy.min()+1)
  region=[max(x0,bx-6),max(0,by-6),min(x1,bx+bw+6)-max(x0,bx-6),min(im.height,by+bh+6)-max(0,by-6)]
  regions.append(region);bounds.append([bx,by,bw,bh])
 if is_gate:
  assert bounds[0][2:]==bounds[1][2:],'Gate state frame dimensions differ'
  assert bounds[0][1]==bounds[1][1] and bounds[0][0]==bounds[1][0]-im.width//2,'Gate state frame registration differs'
 for i,(region,b) in enumerate(zip(regions,bounds)):
  x,y,w,h=region;bx,by,bw,bh=b;kind=e['kind']
  width=e['footprint'][0]if kind in ['gate','floor']else e['world_width']
  scale=width/bw;depth=e['footprint'][1]if kind in ['gate','floor']else 1.0
  ground_h=depth/scale;ground=[bx-x,by+bh-y-ground_h,bw,ground_h]
  assert ground[1]>=0 and ground[0]>=0 and ground[0]+ground[2]<=w and ground[1]+ground[3]<=h
  suffix=('_closed'if i==0 else '_open')if is_gate else ''
  id=('prison_gate'+suffix)if is_gate else e['id']
  asset={'id':id,'label':e['label']+('·关闭'if i==0 else '·打开')if is_gate else e['label'],'texture':'res://'+target.relative_to(ROOT).as_posix(),'texture_size':list(im.size),'region':region,'ground_rect':[round(v,6)for v in ground],'footprint_world_size':[width,depth],'world_size':[round(w*scale,6),round(h*scale,6)],'scale':scale,'anchor':[round((bx-x)+bw/2,6),by+bh-y],'elevation_world':round(ground[1]*scale,6),'shadow_baked':False,'render_mode':'wall_attachment'if kind=='wall'else 'ground_prop','blocking':kind=='floor'or(is_gate and i==0),'interactive':False,'source_kind':'built-in-imagegen-original-png','sha256':sha(target)}
  if kind=='wall':asset.update({'mount_anchor':asset['anchor'],'recommended_mount_height_world':mount_heights[e['id']],'registration_note':'ground_rect is only a 1-unit registration strip; wall attachment has no independent floor collision or cast shadow.'})
  if is_gate:asset.update({'pair':'prison_gate','state':'closed'if i==0 else 'open','plane':'east-west threshold','state_driven':True,'registration_note':'Same frame, region size, ground_rect, anchor and scale in both states. Bind blocking/lock indication to existing door logic; outer posts remain fixed.'})
  assets.append(asset)
  crop=arr[y:y+h,x:x+w,3];cell=arr[:,im.width*i//count:im.width*(i+1)//count,3]
  complete=int((crop>32).sum())==int((cell>32).sum());inside=x>=im.width*i//count and x+w<=im.width*(i+1)//count
  extra_core=int((arr[:,:,3]>32).sum())-sum(int((arr[r[1]:r[1]+r[3],r[0]:r[0]+r[2],3]>32).sum())for r in regions)
  sampled_holes=[]
  if is_gate:
   points=[(.25,.4),(.47,.4),(.70,.4)]if i==0 else[(.4,.4),(.6,.6),(.7,.8)]
   for u,v in points:
    px=bx+int(bw*u);py=by+int(bh*v);sampled_holes.append({'source_xy':[px,py],'alpha':int(arr[py,px,3])})
  border=np.concatenate([arr[:4,:,3].flatten(),arr[-4:,:,3].flatten(),arr[:,:4,3].flatten(),arr[:,-4:,3].flatten()])
  qa.append({'id':id,'original_copy_matches':sha(source)==sha(target),'mode':im.mode,'texture_size':list(im.size),'region':region,'opaque_bounds':b,'own_core_pixel_count_equal':complete,'region_within_cell':inside,'missed_core_pixels_whole_sheet':extra_core,'transparent_fraction':float((arr[:,:,3]==0).mean()),'outer_border_max_alpha':int(border.max()),'gate_hole_samples':sampled_holes,'ground_rect_valid':True,'scale_x':scale,'scale_y':scale,'passed':bool(sha(source)==sha(target)and complete and inside and extra_core==0 and (arr[:,:,3]==0).mean()>.1)})
 sources.append({'id':e['id'],'source_png':str(source),'project_png':target.relative_to(ROOT).as_posix(),'sha256':sha(target),'prompt':'docs/art/prison-v17/imagegen-prompts-v17.json#'+e['id']})
write(OUT/'manifest.json',{'schema':1,'version':'prison-expansion-art-v17-20261006','style':'FINAL-WARM-01','assets':assets,'wall_attachment_contract':'draw at wall ground registration minus (0,mount_height), using mount_anchor and uniform scale; no floor collision; prefer rear/cutaway wall; no gameplay added'})
base=json.loads((DOC/'old-assets-v17.json').read_text(encoding='utf-8'))['files'];changed=[b['path']for b in base if sha(ROOT/b['path'])!=b['sha256']]
report={'passed':all(q['passed']for q in qa)and not changed,'assets':qa,'old_assets_checked':len(base),'changed_old_assets':changed,'gate_shared_registration':all(assets[0][k]==assets[1][k]for k in ['ground_rect','world_size','anchor','scale']),'scope':'source alpha, complete crops, uniform scale, shared gate registration and old assets; composites and Godot resource read checked separately'}
report['passed']=report['passed']and report['gate_shared_registration']
write(DOC/'qa-resources-v17.json',report)
write(DOC/'source-license-v17.json',{'schema':1,'mode':'built-in imagegen','reference':'docs/art/prison-v17/user-reference-v17.png','reference_role':'user supplied style/scene reference; no external image search','prompts':'docs/art/prison-v17/imagegen-prompts-v17.json','pixel_policy':'Generated original PNGs copied byte-identically. Metadata and rendered previews only; no image editing by code.','sources':sources})
print(json.dumps({'passed':report['passed'],'assets':len(assets),'old_assets_checked':len(base),'changed_old_assets':changed,'gate_shared_registration':report['gate_shared_registration'],'gate_holes':[q['gate_hole_samples']for q in qa if q['gate_hole_samples']]}))
