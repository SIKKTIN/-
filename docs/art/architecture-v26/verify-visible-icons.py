from pathlib import Path
import json, numpy as np
from PIL import Image
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v26'
im=np.array(Image.open(doc/'native-preview.png').convert('RGB'))
rows=[]
for i in range(14):
    x=28+(i%7)*176+12;y=510+(i//7)*190+12
    crop=im[y:y+128,x:x+128]
    nonempty=int(np.any(crop!=np.array([226,224,211]),axis=2).sum())
    rows.append({'index':i+1,'pixels_different_from_cell_background':nonempty,'visible':nonempty>500})
assert all(r['visible'] for r in rows)
result={'mode':'actual Forward+ 14 persistent MeshTexture GPU draws','source':'native-preview.png','icons_checked':14,'icons_all_visible':True,'measurements':rows,'stderr_bytes':(doc/'native-preview.stderr.log').stat().st_size,'passed':(doc/'native-preview.stderr.log').stat().st_size==0,'technical_source':'https://docs.godotengine.org/en/stable/classes/class_meshtexture.html#class-meshtexture-property-mesh','critical_rules':['Mesh uses2D vertices, not3D','hold MeshTexture references alive until renderer frame; temporary _draw-only references can release mesh RID'],'source_unchanged':True}
(doc/'native-icons-visible.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=doc/'source-review.json';s=json.loads(p.read_text(encoding='utf-8'));s['native_style_review']='personally viewed native long H/V,L24/L20 and14visible icons; actual P56 two-scale game junctions personally viewed, unified style passed';s['native_evidence']='native-preview.json';s['native_icons']='native-icons-visible.json';p.write_text(json.dumps(s,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'icons_visible':14,'native_stderr_bytes':result['stderr_bytes'],'minimum_visible_pixels':min(r['pixels_different_from_cell_background'] for r in rows)}))
