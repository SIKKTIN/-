"""Register untouched imagegen originals through crop and ground metadata."""
from pathlib import Path
from PIL import Image
import hashlib,json
root=Path(__file__).resolve().parents[3]
folder=root/'art/props/cafeteria_v40'
assets=[]
for ident,name,file,width,depth in [
    ('cafeteria_counter_front_v40','食堂取餐台 · 浅俯视','counter_front_v40.png',600,20),
    ('cafeteria_backline_v40','食堂后排设备 · 靠墙','backline_v40.png',580,60)]:
    p=folder/file;im=Image.open(p)
    l,t,r,b=im.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
    l=max(0,l-2);t=max(0,t-2);r=min(im.width,r+2);b=min(im.height,b+2)
    w,h=r-l,b-t;k=width/w
    assets.append(dict(id=ident,name=name,texture='res://art/props/cafeteria_v40/'+file,
        texture_size=list(im.size),region=[l,t,w,h],ground_rect=[0,h-depth/k,w,depth/k],
        footprint_world_size=[width,depth],world_size=[width,h*k],render_size=[width,h*k],
        elevation_world=h*k-depth,render_mode='projected_prop',blocking=True,interactive=False,
        shadow_baked=False,authoring_set='cafeteria-v40',editor_subcategory='serving',
        alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
        editor_icon=f'res://art/editor/v18/icons/{ident}.tres',
        source_kind='built-in-imagegen-original-png',sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
        registration_note='Uniform source scale; crop metadata only. Rear row and serving counter are separate fixtures.'))
(folder/'manifest.json').write_text(json.dumps(dict(schema=2,version='cafeteria-perspective-v40',assets=assets),ensure_ascii=False,indent=2)+'\n','utf-8')
(root/'art/editor/v18/manifest.json').write_text(json.dumps(dict(schema=1,assets=[dict(id=a['id'],name=a['name'],editor_icon=a['editor_icon'],category='cafeteria') for a in assets],tools=[]),ensure_ascii=False,indent=2)+'\n','utf-8')
print(json.dumps([dict(id=a['id'],world_size=a['world_size'],footprint=a['footprint_world_size']) for a in assets]))
