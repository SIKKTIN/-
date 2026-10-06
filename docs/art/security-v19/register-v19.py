"""Byte-identical PNG copy, read-only alpha analysis, world metadata and Atlas icons."""
from pathlib import Path
from PIL import Image
import numpy as np
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[3];DOC=Path(__file__).resolve().parent;OUT=ROOT/'art/props/security_v19';ICONS=ROOT/'art/editor/v02/icons'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
inputs=json.loads((DOC/'image-inputs-v19.json').read_text(encoding='utf-8'))['assets'];assets=[];reports=[];sources=[]
names={'access_reader':'门禁控制盒','solitary_door_closed':'禁闭室铁门·关闭','solitary_door_open':'禁闭室铁门·打开','solitary_bed':'禁闭室薄单人床'}
for e in inputs:
 source=Path(e['source']);target=OUT/e['filename']
 if target.exists():assert sha(target)==sha(source),'Refuse overwrite PNG'
 else:shutil.copyfile(source,target)
 image=Image.open(target);a=np.asarray(image);assert image.mode=='RGBA';n=2 if e['kind']=='gate'else 1;bounds=[]
 for i in range(n):
  x0=image.width*i//n;x1=image.width*(i+1)//n;yy,xx=np.where(a[:,x0:x1,3]>32)
  bounds.append([x0+int(xx.min()),int(yy.min()),int(xx.max()-xx.min()+1),int(yy.max()-yy.min()+1)])
 if n==2:
  assert bounds[0][0]==bounds[1][0]-image.width//2 and bounds[0][1]==bounds[1][1] and bounds[0][3]==bounds[1][3]
  assert abs(bounds[0][2]-bounds[1][2])<=1,'Fixed door-frame mismatch'
 for i,b in enumerate(bounds):
  bx,by,bw,bh=b;registered_w=max(v[2]for v in bounds)if n==2 else bw
  x=max(image.width*i//n,bx-6);y=max(0,by-6);w=registered_w+12;h=bh+12
  assert x+w<=image.width*(i+1)//n and y+h<=image.height
  width=e.get('width',80);scale=width/registered_w
  depth=14 if e['kind']=='gate'else 112 if e['kind']=='floor'else 1
  ground=[bx-x,by+bh-y-depth/scale,registered_w,depth/scale];assert ground[1]>=0
  id=e['id']if n==1 else 'solitary_door_closed'if i==0 else 'solitary_door_open'
  region=[x,y,w,h];asset={'id':id,'name':names[id],'texture':'res://'+target.relative_to(ROOT).as_posix(),'texture_size':list(image.size),'region':region,'ground_rect':[round(v,6)for v in ground],'footprint_world_size':[width,depth],'world_size':[round(w*scale,6),round(h*scale,6)],'scale':scale,'anchor':[ground[0]+ground[2]/2,by+bh-y],'elevation_world':round(ground[1]*scale,6),'shadow_baked':False,'blocking':e['kind']=='floor'or(n==2 and i==0),'interactive':False,'render_mode':'wall_attachment'if e['kind']=='wall'else 'ground_prop','editor_icon':'res://art/editor/v02/icons/'+id+'.tres','sha256':sha(target)}
  if e['kind']=='wall':asset.update({'mount_anchor':asset['anchor'],'recommended_mount_height_world':38,'registration_note':'1-unit virtual registration strip; wall-mounted reader has no floor collision. Red/green lenses are neutral and state overlays are separate.'})
  if n==2:asset.update({'pair':'solitary_door','state':'closed'if i==0 else 'open','plane':'east-west horizontal threshold','state_driven':True,'registration_note':'Shared frame, scale, ground_rect and anchor; fixed source frame alignment identical, 1px handle extent difference retained without image edits.'})
  assets.append(asset)
  cropped=a[y:y+h,x:x+w,3];cell=a[:,image.width*i//n:image.width*(i+1)//n,3]
  complete=int((cropped>32).sum())==int((cell>32).sum())
  holes=[{'xy':[bx+int(bw*u),by+int(bh*v)],'alpha':int(a[by+int(bh*v),bx+int(bw*u),3])}for u,v in[(.4,.4),(.6,.6),(.7,.8)]]if id=='solitary_door_open'else []
  reports.append({'id':id,'region':region,'source_bounds':b,'complete_own_core_pixels':complete,'transparent_fraction':float((a[:,:,3]==0).mean()),'source_copy_matches':sha(source)==sha(target),'uniform_scale':scale,'ground_valid':ground[1]>=0,'open_passage_samples':holes,'passed':complete and sha(source)==sha(target)and ground[1]>=0 and all(p['alpha']<=1 for p in holes)})
 sources.append({'id':e['id'],'source_png':str(source),'project_png':target.relative_to(ROOT).as_posix(),'sha256':sha(target)})
write(OUT/'manifest.json',{'schema':1,'version':'security-art-v19-20261006','style':'FINAL-WARM-01','assets':assets})
old=json.loads((ROOT/'art/props/prison_v17/manifest.json').read_text(encoding='utf-8'))['assets'];editor=[];icon_qa=[]
for asset in old+assets:
 id=asset['id'];id='prison_notice_board'if id=='notice_board'else id
 category='props'if 'door'in id or 'gate'in id or id=='access_reader'else 'furniture'
 region=asset['region'];w,h=region[2:];square=max(w,h)*1.12;mx=(square-w)/2;my=(square-h)/2
 resource='[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="'+asset['texture']+'" id="1_atlas"]\n\n[resource]\natlas = ExtResource("1_atlas")\nregion = Rect2('+', '.join(str(v)for v in region)+')\nmargin = Rect2('+', '.join(str(round(v,6))for v in [mx,my,square-w,square-h])+')\nfilter_clip = true\n'
 p=ICONS/(id+'.tres');p.write_text(resource,encoding='utf-8',newline='\n')
 editor.append({'id':id,'name':asset.get('name',asset.get('label',id)),'category':category,'editor_icon':'res://'+p.relative_to(ROOT).as_posix()})
 icon_qa.append({'id':id,'world_source_id':asset['id'],'texture':asset['texture'],'region':region,'margin':[round(v,6)for v in [mx,my,square-w,square-h]],'square_canvas':square,'editor_icon':editor[-1]['editor_icon'],'target_sizes':[48,64]})
write(ROOT/'art/editor/v02/manifest.json',{'schema':1,'assets':editor,'tools':[]})
write(DOC/'editor-icon-regions-v19.json',{'schema':1,'icons':icon_qa,'alias':{'prison_notice_board':'A17 notice_board (legacy prison_v08 notice_board remains unchanged)'},'note':'v02 is additive: merge its 13 assets with existing v01; tools remain from v01. AtlasTexture square margins preserve proportions at TextureRect 48/64.'})
baseline=json.loads((DOC/'old-assets-v19.json').read_text(encoding='utf-8'))['files'];changed=[b['path']for b in baseline if sha(ROOT/b['path'])!=b['sha256']]
closed=next(a for a in assets if a['id']=='solitary_door_closed');opened=next(a for a in assets if a['id']=='solitary_door_open');shared=all(closed[k]==opened[k]for k in ['ground_rect','world_size','scale','anchor'])
report={'passed':all(r['passed']for r in reports)and shared and not changed,'assets':reports,'shared_door_registration':shared,'door_source_extent_delta_px':1,'editor_icon_count':len(editor),'old_files_checked':len(baseline),'changed_old_files':changed,'scope':'PNG alpha, complete region, uniform scale, ground anchors, door registration and old assets; native Atlas/icon rendering checked separately'}
write(DOC/'qa-resources-v19.json',report)
write(DOC/'source-license-v19.json',{'schema':1,'mode':'built-in imagegen','reference':'art/props/prison_v17/prison_gate_pair_v17.png','reference_role':'project-owned style reference; original A17 art unmodified','prompts':'docs/art/security-v19/imagegen-prompts-v19.json','pixel_policy':'generated PNGs copied byte-identically; Atlas resource metadata only; no source resampling/background edits','sources':sources})
print(json.dumps({'passed':report['passed'],'assets':len(assets),'icons':len(editor),'shared_registration':shared,'changed_old_files':changed}))
