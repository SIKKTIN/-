"""A14 metadata registration. Read original PNG alpha only; never save modified pixels."""
import json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/props/cafeteria_v14'
entries=[
 ('cafeteria_counter','cafeteria_counter_v14.png',[600,80],.15,'C:/Users/gst20/.codex/generated_images/01a10ab4-5cf7-7c70-8247-13b529a3f2da/exec-b0afe226-5751-4a02-8319-694476a2219e.png'),
 ('cafeteria_return','cafeteria_return_v14.png',[110,70],.10,'C:/Users/gst20/.codex/generated_images/01a10ab4-5cf7-7c70-8247-13b529a3f2da/exec-25c2357d-1e38-4ae6-83ec-f6fdebe6f7db.png'),
 ('cafeteria_tray','cafeteria_tray_v14.png',[36,20],None,'C:/Users/gst20/.codex/generated_images/01a10ab4-5cf7-7c70-8247-13b529a3f2da/exec-f862d6dd-82ec-4064-bc87-0f254cbd9ae8.png'),
 ('cafeteria_queue','cafeteria_queue_v14.png',[180,12],.10,'C:/Users/gst20/.codex/generated_images/01a10ab4-5cf7-7c70-8247-13b529a3f2da/exec-3c4c8edc-030e-443f-b661-b0354f26df7b.png')]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assets=[];qa=[]
for id,name,foot,tail,source in entries:
 path=OUT/name;im=Image.open(path);a=np.asarray(im)
 assert im.mode=='RGBA'
 mask=a[:,:,3]>32;ys,xs=np.where(mask)
 bx,by=int(xs.min()),int(ys.min());br,bb=int(xs.max()+1),int(ys.max()+1)
 if tail is not None:
  low_y=bb-int((bb-by)*tail)
  ly,lx=np.where(mask[low_y:bb])
  gx=int(lx.min());gr=int(lx.max()+1)
 else:
  gx=bx;gr=br
 gw=gr-gx;gh=gw*foot[1]/foot[0]
 rx=max(0,bx-6);ry=max(0,by-6);right=min(im.width,br+6);bottom=min(im.height,bb+6)
 if tail is None:
  # A tabletop decoration occupies a36x20 placement cell. Preserve extra transparent
  # depth in the atlas region to maintain UNIFORM scale; no pixel stretch. Nonblocking.
  gy=by
  bottom=min(im.height,max(bottom,int(np.ceil(gy+gh))+6))
 else:
  gy=bb-gh
 region=[rx,ry,right-rx,bottom-ry]
 ground=[gx-rx,round(gy-ry,6),gw,round(gh,6)]
 s=foot[0]/gw;world=[round(region[2]*s,6),round(region[3]*s,6)]
 elevation=max(0,round((gy-ry)*s,6))
 inbounds=ground[0]>=0 and ground[1]>=0 and ground[0]+ground[2]<=region[2] and ground[1]+ground[3]<=region[3]
 assert inbounds,(id,region,ground)
 cropped=mask[ry:bottom,rx:right]
 outside=int(mask.sum()-cropped.sum())
 uniform=abs(foot[0]/ground[2]-foot[1]/ground[3])<1e-7
 notes={
  'cafeteria_counter':'South counter-base projected ground; rear kitchenette rises north and needs separate hidden map collision.',
  'cafeteria_return':'South rack-base projected ground; upper tray stacks rise north. Original short-rack proportions preserved.',
  'cafeteria_queue':'Three post bases share a south baseline; narrow projected ground strip preserves uniform scale.',
  'cafeteria_tray':'Nonblocking tabletop36x20 placement cell; region keeps transparent spare depth to avoid deforming the tray/cup. Actual colored silhouette is shallower.'}
 note=notes[id]
 asset={'id':id,'texture':'res://art/props/cafeteria_v14/'+name,'texture_size':list(im.size),'region':region,'ground_rect':ground,'footprint_world_size':foot,'world_size':world,'elevation_world':elevation,'shadow_baked':False,'blocking':id!='cafeteria_tray','interactive':False,'source_kind':'built-in-imagegen-original-png','sha256':sha(path),'registration_note':note}
 assets.append(asset)
 qa.append({'id':id,'rgba':True,'source_size':list(im.size),'opaque_bounds':[bx,by,br-bx,bb-by],'alpha0_fraction':round(float((a[:,:,3]==0).mean()),6),'crop_excludes_core_pixels':outside,'ground_enclosed':inbounds,'uniform_scale':uniform,'scale':s,'visible_core_world_size':[round((br-bx)*s,4),round((bb-by)*s,4)],'copy_matches_source':sha(path)==sha(Path(source)),'source':source,'source_sha256':sha(Path(source)),'registration':note,'passed':outside==0 and inbounds and uniform and sha(path)==sha(Path(source))})
manifest={'schema':1,'version':'cafeteria-art-v14-20261005','style':'art-v03 / FINAL-WARM-01; approved A13 plain ration','assets':assets,'reuse':['res://art/props/prison_v08/communal_table_v08.png'],'pixel_policy':'source PNG byte-identical; crop/registration metadata only'}
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'schema':1,'passed':all(q['passed']for q in qa),'assets':qa,'scope':'original RGBA/crop/uniform registration checks; actual native composite separately reviewed; no collision or meal-logic tests'}
(ROOT/'docs/art/a14-qa-resources.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'passed':report['passed'],'assets':[{'id':e['id'],'region':e['region'],'ground_rect':e['ground_rect'],'world_size':e['world_size'],'elevation':e['elevation_world']}for e in assets]},ensure_ascii=False))
