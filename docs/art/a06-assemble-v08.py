"""Register original PNGs. No generated image pixels are edited.
Input source/ground calibration is separately reviewed and uses original canvas pixels.
"""
import json,hashlib,shutil
from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).resolve().parents[2];doc=root/'docs/art';folder=root/'art/props/prison_v08';folder.mkdir(parents=True,exist_ok=True)
inputs=json.loads((doc/'a06-image-inputs-v08.json').read_text(encoding='utf-8'))
assets=[];qa=[];sources=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for entry in inputs['assets']:
    id=entry['id'];source=Path(entry['source']);target=folder/(entry.get('filename',id+'_v08.png'))
    if target.exists()and sha(source)!=sha(target):raise RuntimeError('Refuse overwrite '+str(target))
    if not target.exists():shutil.copyfile(source,target)
    im=Image.open(target);a=np.asarray(im)
    assert im.mode=='RGBA',id+' must be RGBA'
    mask=a[:,:,3]>32;y,x=np.where(mask)
    box=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]
    margin=6
    region=[max(0,box[0]-margin),max(0,box[1]-margin),min(im.width,box[2]+margin)-max(0,box[0]-margin),min(im.height,box[3]+margin)-max(0,box[1]-margin)]
    g=entry['ground_canvas_rect']
    ground=[g[0]-region[0],g[1]-region[1],g[2],g[3]]
    world=entry['footprint_world_size'];scale=[world[0]/g[2],world[1]/g[3]]
    elevation=ground[1]*scale[1]
    registration_valid=ground[0]>=0 and ground[1]>=0 and ground[0]+ground[2]<=region[2] and ground[1]+ground[3]<=region[3]
    south_bottom_error=(region[1]+region[3]-(g[1]+g[3]))*scale[1]
    border_alpha_max=int(max(a[0,:,3].max(),a[-1,:,3].max(),a[:,0,3].max(),a[:,-1,3].max()))
    border=border_alpha_max<=1
    asset={'id':id,'texture':'res://'+target.relative_to(root).as_posix(),'texture_size':list(im.size),'region':region,'ground_rect':ground,'footprint_world_size':world,'elevation_world':round(elevation,4),'shadow_baked':False,'source_kind':'built-in-imagegen-original-png','sha256':sha(target)}
    assets.append(asset)
    qa.append({'id':id,'size':list(im.size),'mode':im.mode,'alpha_min':int(a[:,:,3].min()),'alpha_max':int(a[:,:,3].max()),'clear_outer_border':border,'outer_border_alpha_max':border_alpha_max,'border_policy':'<=1/255 raw-alpha quantization noise allowed; untouched PNG. Atlas excludes outside padding.','opaque_canvas_bounds':box,'region_in_canvas':region[0]>=0 and region[1]>=0 and region[0]+region[2]<=im.width and region[1]+region[3]<=im.height,'ground_registration_valid':registration_valid,'south_padding_world':round(south_bottom_error,4),'copy_matches_source':sha(source)==sha(target),'canvas_ground_calibration':g,'scale':[round(s,6)for s in scale],'horizontal_to_vertical_scale_ratio':round(scale[0]/scale[1],4)})
    sources.append({'id':id,'source_png':str(source),'project_png':target.relative_to(root).as_posix(),'source_sha256':sha(source),'sha256':sha(target),'copy_matches_source':sha(source)==sha(target),'prompt_id':entry.get('prompt_id',id),'calibration_note':entry.get('calibration_note','')})
manifest={'schema':1,'version':'prison-art-v08-20261005','style':'art-v03 / FINAL-WARM-01','assets':assets}
(folder/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
(doc/'a06-source-license-v08.json').write_text(json.dumps({'schema':1,'generation_mode':'built-in imagegen','license':'Project-owned generated original artwork; project-owned style references; no copied third-party game artwork','pixel_policy':'Raw original PNGs copied without pixel edits; registration via Atlas regions and ground_rect only','prompts':'docs/art/a06-imagegen-prompts-v08.json','sources':sources},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
old=json.loads((doc/'a06-old-asset-baseline-v08.json').read_text(encoding='utf-8'))['files'];changed=[f['path']for f in old if sha(root/f['path'])!=f['sha256']]
passed=all(q['copy_matches_source']and q['clear_outer_border']and q['alpha_min']==0 and q['alpha_max']>=254 and q['region_in_canvas']and q['ground_registration_valid']and 0<=q['south_padding_world']<2 for q in qa)and not changed
(doc/'a06-qa-resources-v08.json').write_text(json.dumps({'assets':qa,'old_assets_checked':len(old),'changed_old_assets':changed,'passed':passed,'scope':'PNG transparency/hash and registration metadata; not scene integration'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'count':len(assets),'passed':passed,'old_changed':changed,'assets':[{'id':a['id'],'region':a['region'],'ground_rect':a['ground_rect'],'elevation_world':a['elevation_world']}for a in assets]}))
