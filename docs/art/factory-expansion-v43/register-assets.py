"""Register untouched imagegen originals with alpha crop metadata and editor icons."""
import hashlib, json, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SRC = Path('C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-c89f1654-b69f-4cee-ab72-8579e055ca87.png')
ART = ROOT/'art/props/factory_v43'
ICONS = ROOT/'art/editor/v21/icons'
ART.mkdir(parents=True, exist_ok=True)
ICONS.mkdir(parents=True, exist_ok=True)
shutil.copy2(SRC, ART/'expansion_atlas.png')
image = Image.open(SRC)
assert image.mode == 'RGBA' and image.getchannel('A').getextrema()[0] == 0
w,h = image.size
specs = [
 ('warehouse_rack_v43','仓库货架 · 纵向',120,340,'furnishings'),
 ('cargo_pallet_v43','托盘货堆',120,100,'furnishings'),
 ('cargo_truck_v43','装卸货车 · 纵向',200,440,'furnishings'),
 ('washing_machine_v43','工业洗衣机',100,90,'furnishings'),
 ('drying_rack_v43','晾衣架 · 纵向',100,150,'furnishings'),
 ('equipment_pump_v43','设备泵组',220,100,'furnishings'),
 ('electrical_cabinet_v43','电气柜',90,60,'furnishings'),
 ('guard_booth_v43','门岗亭',180,120,'furnishings')]
sha=hashlib.sha256(SRC.read_bytes()).hexdigest()
assets=[]
for i,(id,name,width,depth,category) in enumerate(specs):
 col,row=i%4,i//4
 cell=(col*w//4,row*h//2,(col+1)*w//4,(row+1)*h//2)
 if i==6:cell=(cell[0],550,cell[2],cell[3])  # Exclude the neighboring truck's tiny gutter overlap.
 # Alpha threshold only locates the sprite; pixels are never altered or re-saved.
 alpha=image.getchannel('A').crop(cell)
 box=alpha.point(lambda a:255 if a>=80 else 0).getbbox()
 assert box
 x0,y0=max(cell[0],cell[0]+box[0]-3),max(cell[1],cell[1]+box[1]-3)
 x1,y1=min(cell[2],cell[0]+box[2]+3),min(cell[3],cell[1]+box[3]+3)
 rw,rh=x1-x0,y1-y0
 scale=width/rw
 visual_height=rh*scale
 # Baseline anchored; preserve aspect ratio rather than stretching atlas cells.
 assets.append(dict(id=id,name=name,texture='res://art/props/factory_v43/expansion_atlas.png',
  texture_size=[w,h],region=[x0,y0,rw,rh],ground_rect=[0,rh-depth/scale,rw,depth/scale],
  footprint_world_size=[width,depth],world_size=[width,visual_height],render_size=[width,visual_height],
  elevation_world=max(0,visual_height-depth),render_mode='projected_prop',blocking=True,
  interactive=False,shadow_baked=False,authoring_set='factory-expansion-v43',editor_subcategory=category,
  alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
  editor_icon=f'res://art/editor/v21/icons/{id}.tres',source_kind='built-in-imagegen-original-png',sha256=sha))
def save(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
save(ART/'manifest.json',{'schema':2,'version':'factory-expansion-v43','assets':assets})
save(ROOT/'art/editor/v21/manifest.json',{'schema':1,'assets':[dict(id=a['id'],name=a['name'],category='furniture',editor_icon=a['editor_icon']) for a in assets]})
save(OUT/'art-registration.json',{'original':str(SRC),'sha256':sha,'assets':[{'id':a['id'],'region':a['region'],'render_size':a['render_size']} for a in assets]})
print(json.dumps({'registered':len(assets),'sha256':sha,'regions':[a['region'] for a in assets]}))
