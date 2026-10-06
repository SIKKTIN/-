from pathlib import Path
import json, hashlib, shutil
from PIL import Image
root=Path(r'E:/Project/Godot/这次怎么逃')
doc=root/'docs/art/architecture-v25'
asset=json.loads((doc/'corner-interface.json').read_text(encoding='utf-8'))['asset']
png=root/'art/architecture/v25/cafeteria_corner_l_v25.png'
asset['sha256']=hashlib.sha256(png.read_bytes()).hexdigest()
p=root/'art/architecture/v25/manifest.json'
m=json.loads(p.read_text(encoding='utf-8-sig')); m['assets']=[r for r in m['assets'] if r['id']!=asset['id']]+[asset]; p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
e=root/'art/editor/v05/manifest.json'
em=json.loads(e.read_text(encoding='utf-8-sig'));em['assets']=[r for r in em['assets'] if r['id']!=asset['id']]+[{'id':asset['id'],'name':asset['name'],'category':'furniture','editor_icon':asset['editor_icon']}]; e.write_text(json.dumps(em,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
icon='[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="'+asset['texture']+'" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2(42, 287, 825, 1133)\nmargin = Rect2(49.5, 67.98, 99, 135.96)\nfilter_clip = true\n'
(root/'art/editor/v05/icons/cafeteria_corner_l_v25.tres').write_text(icon,encoding='utf-8')
im=Image.open(png); alpha=im.getchannel('A'); source=Path("C:\\Users\\gst20\\.codex\\generated_images\\01a10697-9228-7c00-906b-43051bade1e0\\exec-18b1f8d3-7477-43fb-9383-bdc23da6b59d.png")
review={'schema':1,'size':im.size,'alpha_range':alpha.getextrema(),'solid_bbox_alpha200':alpha.point(lambda x:255 if x>200 else 0).getbbox(),'sha256':asset['sha256'],'source_copy_matches':source.read_bytes()==png.read_bytes(),'registration':asset,'rejected_connection':{'reason':'old frontal corner column occludes continuous coping, return begins beneath its foot','status':'producer integrating L module; not visually accepted'},'original_A24_delivery_unchanged':all(hashlib.sha256((root/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in json.loads((root/'docs/art/architecture-v24/delivery.json').read_text(encoding='utf-8-sig'))['files'])}
(doc/'corner-source-review.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
qa=doc/'godot-qa'
for rel in ['art/architecture/v25/manifest.json','art/architecture/v25/cafeteria_corner_l_v25.png','art/editor/v05/manifest.json','art/editor/v05/icons/cafeteria_corner_l_v25.tres']:
    dest=qa/rel; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(root/rel,dest)
v=(doc/'verify.gd').read_text(encoding='utf-8').replace('rows.size() == 2','rows.size() == 3')
(doc/'verify.gd').write_text(v,encoding='utf-8');(qa/'verify.gd').write_text(v,encoding='utf-8')
print(json.dumps({'asset':asset['id'],'sha256':asset['sha256'],'source_copy_matches':review['source_copy_matches'],'v24_unchanged':review['original_A24_delivery_unchanged']}))
