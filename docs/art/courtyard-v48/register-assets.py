"""Register original generated PNGs via alpha bounds; pixels remain untouched."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'art/props/courtyard_v48'
specs=[('garden_tree_island_v48','中央树岛与自强石碑','tree-island.png',400,365,460),('garden_bed_horizontal_v48','横向石边花坛','bed-horizontal.png',380,90,380),('garden_bed_vertical_v48','纵向石边花坛','bed-vertical.png',90,200,90)]
entries=[]
for id,name,file,fw,fh,rw in specs:
    path=OUT/file
    img=Image.open(path)
    b=img.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox()
    b=(max(0,b[0]-2),max(0,b[1]-2),min(img.width,b[2]+2),min(img.height,b[3]+2))
    width,height=b[2]-b[0],b[3]-b[1]
    rh=round(rw*height/width,3) if 'tree' in id else fh+12
    region=[b[0],b[1],width,height]
    texture='res://art/props/courtyard_v48/'+file
    icon='res://art/editor/v23/icons/'+id+'.tres'
    entries.append(dict(id=id,name=name,texture=texture,texture_size=list(img.size),region=region,footprint_world_size=[fw,fh],render_size=[rw,rh],world_size=[rw,rh],render_mode='projected_prop',blocking=True,interactive=False,shadow_baked=False,authoring_set='courtyard-v48',editor_subcategory='furnishings',alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',editor_icon=icon,source_kind='built-in-imagegen-original-png',sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (ROOT/icon.removeprefix('res://')).write_text(f'[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="{texture}" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2({b[0]}, {b[1]}, {width}, {height})\nfilter_clip = true\n',encoding='utf-8')
(OUT/'manifest.json').write_text(json.dumps(dict(schema=2,version='courtyard-v48',assets=entries),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Registered three untouched transparent garden props.')
