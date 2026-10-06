import json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
root=Path('E:/Project/Godot/这次怎么逃'); out=root/'art/architecture/v23'; docs=root/'docs/art/architecture-v23'; icons=root/'art/editor/v03/icons'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources={"materials":"C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-a75dcc1b-fc8f-42d9-b314-9b7f8ab9bc35.png","solitary":"C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-411f3543-cca0-437c-8491-c8b7443478d8.png","cafeteria":"C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-459769e1-1d3a-4e1a-b3b4-cba616575a6d.png","solitary_draft":"C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-28cd3cc7-09e3-4490-bb00-2d2555378cd5.png"}
names={'materials':'architecture_materials_v23.png','solitary':'solitary_door_pair_v23.png','cafeteria':'cafeteria_gate_pair_v23.png'}
assets=[]
specs=[('solitary_roof_v23','禁闭室不透明屋顶',[0,0,627,627],[96,96]),('solitary_wall_front_v23','禁闭室深灰墙面',[627,0,627,627],[128,110]),('solitary_coping_v23','禁闭室深灰压顶',[0,627,627,627],[64,64]),('cafeteria_wall_front_v23','食堂浅灰高墙',[627,627,627,627],[128,100])]
for id,name,region,world in specs:
 assets.append({'id':id,'name':name,'texture':'res://art/architecture/v23/architecture_materials_v23.png','texture_size':[1254,1254],'region':region,'world_size':world,'render_mode':'architecture_material','opaque':True,'shadow_baked':False,'blocking':False,'interactive':False,'repeat_axes':'x/y' if 'front' not in id else 'x','sha256':sha(out/names['materials'])})
reuse=root/'art/environment/low_wall_top_v02.png'
assets.append({'id':'cafeteria_coping_v23','name':'食堂浅石压顶','texture':'res://art/environment/low_wall_top_v02.png','texture_size':list(Image.open(reuse).size),'region':[0,0,*Image.open(reuse).size],'world_size':[64,64],'render_mode':'architecture_material','opaque':True,'shadow_baked':False,'blocking':False,'interactive':False,'reuse_existing':True,'source_note':'existing accepted low_wall_top_v02.png, unchanged','sha256':sha(reuse)})
pairs=[('solitary_door','禁闭室铁门','solitary',[(50,42,984,640),(1107,42,984,640)],[160,110],[160,20]),('cafeteria_gate','食堂侧滑栅栏','cafeteria',[(49,82,965,561),(1078,82,965,561)],[180,110],[180,31.5])]
review={'schema':1,'mode':'built-in imagegen','reference':'art/concepts/prison-roof-v21/scene-concept-v21r2.png','prompts':'docs/art/architecture-v23/prompts.json','outputs':[],'registration':{},'pixel_policy':'Selected generated PNGs copied byte-identically. Crops represented only by atlas metadata, no production pixels modified.'}
for prefix,name,key,regions,render,foot in pairs:
 source_image=Image.open(out/names[key]); rgba=np.array(source_image)
 rows=[]
 w,h=regions[0][2:]
 sx,sy=render[0]/w,render[1]/h
 ground=[0,round(h-foot[1]/sy,6),w,round(foot[1]/sy,6)]
 for state,reg in zip(['closed','open'],regions):
  id=prefix+'_'+state+'_v23'
  a={'id':id,'name':name+('·关闭' if state=='closed' else '·打开'),'texture':'res://art/architecture/v23/'+names[key],'texture_size':list(source_image.size),'region':list(reg),'world_size':render,'render_size':render,'footprint_world_size':foot,'ground_rect':ground,'anchor':[w/2,h],'scale_xy':[sx,sy],'elevation_world':render[1]-foot[1],'door_height':110,'render_mode':'embedded_door','pair':prefix+'_v23','state':state,'state_driven':True,'shadow_baked':False,'blocking':state=='closed','interactive':False,'plane':'east-west horizontal threshold','sha256':sha(out/names[key]),'registration_note':'Equal region size and shared bottom-center anchor/ground_rect. OPEN retains whole aperture, never crop to leaf. Render height independent of logical threshold width. Very slight aspect fit via explicit render_size.'}
  assets.append(a)
  alpha=rgba[reg[1]:reg[1]+reg[3],reg[0]:reg[0]+reg[2],3]
  yy,xx=np.where(alpha>64)
  rows.append({'state':state,'bbox_alpha_gt64':[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],'alpha_zero_ratio':float((alpha==0).mean())})
 review['registration'][prefix]={'regions':list(map(list,regions)),'shared_cell_size':[w,h],'render_size':render,'ground_rect':ground,'anchor':[w/2,h],'state_alpha':rows}
for a in assets:
 a['editor_icon']='res://art/editor/v03/icons/'+a['id']+'.tres'
 x,y,w,h=a['region']; pad=w*.06; pady=h*.06
 content=f'[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="{a["texture"]}" id="1_atlas"]\n\n[resource]\natlas = ExtResource("1_atlas")\nregion = Rect2({x}, {y}, {w}, {h})\nmargin = Rect2({pad:.6f}, {pady:.6f}, {2*pad:.6f}, {2*pady:.6f})\nfilter_clip = true\n'
 (icons/(a['id']+'.tres')).write_text(content,encoding='utf-8')
manifest={'schema':1,'version':'architecture-v23-20261006','style':'FINAL-WARM-01','concept':'res://art/concepts/prison-roof-v21/scene-concept-v21r2.png','assets':assets}
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
editor={'schema':1,'assets':[{'id':a['id'],'name':a['name'],'category':'furniture' if a['render_mode']=='architecture_material' else 'props','editor_icon':a['editor_icon']} for a in assets],'tools':[]}
(root/'art/editor/v03/manifest.json').write_text(json.dumps(editor,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for key,name in names.items():
 p=out/name;source=Path(sources[key]);im=Image.open(p)
 row={'source':str(source),'project_png':str(p.relative_to(root)).replace('\\','/'),'sha256':sha(p),'source_copy_matches':sha(p)==sha(source),'size':list(im.size),'mode':im.mode}
 assert row['source_copy_matches'];review['outputs'].append(row)
baseline=json.loads((root/'docs/art/door-wall-v20/old-assets-v20.json').read_text(encoding='utf-8-sig'))['files']
review['old_assets_checked']=len(baseline);review['changed_old_assets']=[v['path'] for v in baseline if sha(root/v['path'])!=v['sha256']]
assert not review['changed_old_assets']
im=np.array(Image.open(out/names['solitary']));sample=im[150:620,1350:1970,3]
im2=np.array(Image.open(out/names['cafeteria']));sample2=im2[160:580,1450:1970,3]
review['open_passage_alpha']={'solitary':{'rect':[1350,150,620,470],'opaque_pixel_ratio_gt64':float((sample>64).mean()),'max':int(sample.max())},'cafeteria':{'rect':[1450,160,520,420],'opaque_pixel_ratio_gt64':float((sample2>64).mean()),'max':int(sample2.max())}}
assert review['open_passage_alpha']['solitary']['opaque_pixel_ratio_gt64']==0
assert review['open_passage_alpha']['cafeteria']['opaque_pixel_ratio_gt64']==0
(docs/'source-review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'assets':len(assets),'source_copy_matches':all(x['source_copy_matches'] for x in review['outputs']),'old_assets_checked':review['old_assets_checked'],'open_passage_alpha':review['open_passage_alpha']}))

