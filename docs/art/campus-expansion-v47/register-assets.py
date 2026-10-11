"""Register atlas regions without repainting or modifying generated pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
atlas=ROOT/'art/props/campus_v47/campus_atlas.png'
image=Image.open(atlas)
w,h=image.size
specs=[
 ('medical_cot_v47','医务室单人床',140,210),
 ('medical_cabinet_v47','医药柜',130,65),
 ('medical_trolley_v47','医疗推车',90,75),
 ('shower_bank_v47','公共淋浴设施',300,130),
 ('changing_lockers_v47','更衣柜',220,70),
 ('changing_bench_v47','浴室长凳',190,70),
 ('office_desk_v47','值班办公桌',185,100),
 ('monitor_console_v47','监控台',250,100),
 ('filing_cabinet_v47','档案柜',140,65),
 ('basketball_hoop_v47','篮球架',120,45),
 ('park_bench_v47','庭院长椅',190,65),
 ('yard_lamp_v47','园区照明灯',70,35)]
entries=[]
for i,(id,name,fw,fh) in enumerate(specs):
 col,row=i%3,i//3
 cell=(col*w//3,row*h//4,(col+1)*w//3,(row+1)*h//4)
 # Only inspect alpha to measure sprite bounds; original atlas remains intact.
 alpha=image.getchannel('A').crop(cell)
 b=alpha.point(lambda a:255 if a>=16 else 0).getbbox()
 x0=max(cell[0],cell[0]+b[0]-4);y0=max(cell[1],cell[1]+b[1]-4)
 x1=min(cell[2],cell[0]+b[2]+4);y1=min(cell[3],cell[1]+b[3]+4)
 rw,rh=x1-x0,y1-y0
 render_h=round(fw*rh/rw,3)
 fh=min(fh,render_h)
 entry=dict(id=id,name=name,texture='res://art/props/campus_v47/campus_atlas.png',
            texture_size=[w,h],region=[x0,y0,rw,rh],
            ground_rect=[0,round(rh-fh*rw/fw,3),rw,round(fh*rw/fw,3)],
            footprint_world_size=[fw,fh],world_size=[fw,render_h],render_size=[fw,render_h],
            elevation_world=round(render_h-fh,3),render_mode='projected_prop',blocking=True,
            interactive=False,shadow_baked=False,authoring_set='campus-v47',
            editor_subcategory='furnishings',alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
            editor_icon=f'res://art/editor/v23/icons/{id}.tres',
            source_kind='built-in-imagegen-original-png',sha256=hashlib.sha256(atlas.read_bytes()).hexdigest())
 entries.append(entry)
 icon=ROOT/f'art/editor/v23/icons/{id}.tres'
 icon.write_text(f'[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://art/props/campus_v47/campus_atlas.png" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2({x0}, {y0}, {rw}, {rh})\nfilter_clip = true\n',encoding='utf-8')
(atlas.parent/'manifest.json').write_text(json.dumps(dict(schema=2,version='campus-v47',assets=entries),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ROOT/'art/editor/v23/manifest.json').write_text(json.dumps(dict(schema=1,assets=[dict(id=e['id'],name=e['name'],editor_icon=e['editor_icon']) for e in entries]),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Registered',len(entries),'transparent atlas sprites',image.size)
