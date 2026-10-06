import json,hashlib
from pathlib import Path
from PIL import Image
import numpy as np
root=Path('E:/Project/Godot/这次怎么逃');d=root/'docs/art/architecture-v24';out=root/'art/architecture/v24';icons=root/'art/editor/v04/icons'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources={"closed":"C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-c903f9f0-5249-4f89-8f3e-c0fa17efc022.png","open":"C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-560ee8e0-9e13-4a21-9e16-0022e5a9683f.png","portal":"C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-6e15c3a1-5a15-419e-8a2c-3e8ca2ca7e5a.png"}
files={'closed':'solitary_shell_closed_v24.png','open':'solitary_shell_open_v24.png','portal':'cafeteria_portal_v24.png'}
assets=[]
region=[60,95,1430,778];render=[456,298];sx,sy=render[0]/region[2],render[1]/region[3]
door_anchor=[1005-region[0],867-region[1]]
offset=[round(300-door_anchor[0]*sx,6),round(298-door_anchor[1]*sy,6)]
ground=[round(-offset[0]/sx,6),round(-offset[1]/sy,6),round(440/sx,6),round(284/sy,6)]
mouth=[865,565,280,302];patch=[868,562,277,305]
patch_render=[round((patch[0]-region[0])*sx,6),round((patch[1]-region[1])*sy,6),round(patch[2]*sx,6),round(patch[3]*sy,6)]
mouth_render=[round((mouth[0]-region[0])*sx,6),round((mouth[1]-region[1])*sy,6),round(mouth[2]*sx,6),round(mouth[3]*sy,6)]
for state in ['closed','open']:
 assets.append({'id':'solitary_shell_'+state+'_v24','name':'完整禁闭建筑·'+('关闭' if state=='closed' else '打开'),'texture':'res://art/architecture/v24/'+files[state],'texture_size':[1550,1015],'region':region,'world_size':render,'render_size':render,'footprint_world_size':[440,284],'ground_rect':ground,'anchor':[region[2]/2,door_anchor[1]],'door_anchor':door_anchor,'door_anchor_render':[door_anchor[0]*sx,door_anchor[1]*sy],'render_offset_from_room':offset,'door_region':mouth_render,'door_region_source':mouth,'door_state_patch_region':patch,'door_state_patch_render_rect':patch_render,'pair':'solitary_shell_v24','state':state,'state_driven':True,'render_mode':'architecture_shell','blocking':False,'interactive':False,'shadow_baked':False,'self_shading_baked':True,'sha256':sha(out/files[state]),'registration_note':'Logical doorway local[255,270,90,28], bottom298. Place stable CLOSED shell by measured door_anchor; runtime OPEN uses only door_state_patch_region over matching render rect. No whole-OPEN swap and no roof retile.'})
# The whole portal is an original-art reference, not a uniformly stretched runtime entrance.
portal_region=[46,172,2082,375]
assets.append({'id':'cafeteria_portal_v24','name':'完整食堂门墙原图','texture':'res://art/architecture/v24/'+files['portal'],'texture_size':[2170,725],'region':portal_region,'world_size':[674.568,121.5],'render_size':[674.568,121.5],'render_mode':'architecture_portal_reference','blocking':False,'interactive':False,'shadow_baked':False,'self_shading_baked':True,'sha256':sha(out/files['portal']),'runtime_use':'Use module layout in assembly.json; original portal aperture naturally narrower than gameplay180. Do not stretch whole portal to600 and assume opening180.','door_region_source':[837,259,407,288]})
mods=[
 ('cafeteria_wing_left_v24','食堂完整左门翼',[46,172,791,375],[200,121.5]),
 ('cafeteria_wing_right_v24','食堂完整右门翼',[1244,172,884,375],[220,121.5]),
 ('cafeteria_wall_mid_v24','食堂连续墙中段',[140,172,573,375],[144,121.5]),
 ('cafeteria_jamb_left_v24','食堂左石门柱含内侧收口',[713,172,124,375],[32,121.5]),
 ('cafeteria_jamb_right_v24','食堂右石门柱含内侧收口',[1244,172,118,375],[32,121.5]),
 ('cafeteria_lintel_v24','食堂厚石门楣',[837,172,407,87],[180,31.5]),
 ('cafeteria_corner_post_v24','食堂厚石转角柱',[46,172,94,375],[28,121.5])]
for id,name,reg,world in mods:
 yscale=world[1]/reg[3]
 foot=[world[0],31.5 if 'lintel' not in id else 1]
 ground2=[0,round(reg[3]-foot[1]/yscale,6),reg[2],round(foot[1]/yscale,6)]
 assets.append({'id':id,'name':name,'texture':'res://art/architecture/v24/'+files['portal'],'texture_size':[2170,725],'region':reg,'world_size':world,'render_size':world,'footprint_world_size':foot,'ground_rect':ground2,'anchor':[reg[2]/2,reg[3]],'render_mode':'architecture_wall_module','blocking':False,'interactive':False,'shadow_baked':False,'self_shading_baked':True,'sha256':sha(out/files['portal']),'registration_note':'Whole painted structural slice, not top/front textures. Align module bottom at one baseline; no extra rectangular coping. Root collision remains map-owned.'})
for a in assets:
 a['editor_icon']='res://art/editor/v04/icons/'+a['id']+'.tres'
 x,y,w,h=a['region'];px=w*.06;py=h*.06
 (icons/(a['id']+'.tres')).write_text(f'[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="{a["texture"]}" id="1_atlas"]\n\n[resource]\natlas = ExtResource("1_atlas")\nregion = Rect2({x}, {y}, {w}, {h})\nmargin = Rect2({px:.6f}, {py:.6f}, {px*2:.6f}, {py*2:.6f})\nfilter_clip = true\n',encoding='utf-8')
manifest={'schema':1,'version':'architecture-v24-20261006','style':'FINAL-WARM-01','reference':'approved A22 user target','assets':assets}
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
editor={'schema':1,'assets':[{'id':a['id'],'name':a['name'],'category':'furniture','editor_icon':a['editor_icon']} for a in assets],'tools':[]}
(root/'art/editor/v04/manifest.json').write_text(json.dumps(editor,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assembly={'schema':1,'version':manifest['version'],'solitary':{'stable_base':'solitary_shell_closed_v24','open_state':'solitary_shell_open_v24','render_size':render,'door_anchor_source_in_region':door_anchor,'render_offset_from_room':offset,'door_state_patch_region':patch,'door_state_patch_render_rect':patch_render,'logical_door_rect':[255,270,90,28],'mouth_world_width':mouth_render[2],'mouth_world_height':mouth_render[3],'draw_order':'One CLOSED base at room offset. When open, sample ONLY OPEN patch at same destination. Do not redraw/retile roof or add another door frame/plaque.'},'cafeteria':{'layout_size':[600,121.5],'ground_threshold':[200,90,180,31.5],'parts':[{'id':'cafeteria_wing_left_v24','rect':[0,0,200,121.5]},{'id':'cafeteria_wing_right_v24','rect':[380,0,220,121.5]},{'id':'cafeteria_lintel_v24','rect':[200,0,180,31.5]}],'gate':{'closed':'cafeteria_gate_closed_v23','open':'cafeteria_gate_open_v23','rect':[200,31.5,180,90],'source_manifest':'res://art/architecture/v23/manifest.json'},'extensions':'Use wall_mid between corner_post and jamb slices for longer runs. Crop last mid segment, do not stretch one middle over a long wall. Keep top/bottom baseline; use original complete modules for corners rather than long pale strips.','label':'No baked cafeteria text; root paints 食堂 and reader once on right wall.','vertical_returns':'No separate v24 long north-south wall sprite; preserve corridor width and join the return under corner_post. Judge final P54 view for visible join artifacts.'}}
(out/'assembly.json').write_text(json.dumps(assembly,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
review={'schema':1,'mode':'built-in imagegen','prompt_file':'docs/art/architecture-v24/prompts.json','reference':'C:/Users/gst20/AppData/Local/Temp/codex-clipboard-b23e7114-b431-45ba-a14f-c9f00f4c8440.png','pixel_policy':'All selected generated PNGs copied byte-identically. Only atlas metadata/crops; no production pixel editing. OPEN runtime replacement limited to metal-mouth patch to preserve stone/roof.','outputs':[]}
for k,fn in files.items():
 p=out/fn;src=Path(sources[k]);im=Image.open(p)
 row={'source':str(src),'project_png':str(p.relative_to(root)).replace('\\','/'),'sha256':sha(p),'source_copy_matches':sha(p)==sha(src),'size':list(im.size),'mode':im.mode}
 assert row['source_copy_matches'];review['outputs'].append(row)
a=np.array(Image.open(out/files['portal']))[:,:,3];gap=a[265:538,850:1230]
review['cafeteria_gap_alpha']={'rect':[850,265,380,273],'opaque_ratio_gt64':float((gap>64).mean()),'max':int(gap.max())}
assert (gap>64).sum()==0
prev=json.loads((root/'docs/art/architecture-v23/delivery.json').read_text(encoding='utf-8'))['files'];prevpng=json.loads((root/'docs/art/architecture-v23/source-review.json').read_text(encoding='utf-8'))['outputs']
review['v23_delivery_unchanged']=all(sha(root/v['path'])==v['sha256'] for v in prev) and all(sha(root/v['project_png'])==v['sha256'] for v in prevpng)
assert review['v23_delivery_unchanged']
(d/'source-review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'assets':len(assets),'door_offset':offset,'door_mouth_render':mouth_render,'patch_rect_render':patch_render,'portal_gap':review['cafeteria_gap_alpha'],'v23_unchanged':review['v23_delivery_unchanged']}))

