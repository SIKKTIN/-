"""Register the unchanged imagegen atlas using alpha crop metadata only."""
import hashlib, json, shutil
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SRC = Path('C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-fd8911a5-b245-460f-b736-0810a30b9cc8.png')
ART = ROOT/'art/props/factory_v44'
ICONS = ROOT/'art/editor/v22/icons'
ART.mkdir(parents=True,exist_ok=True)
ICONS.mkdir(parents=True,exist_ok=True)
shutil.copy2(SRC,ART/'detail_atlas.png')
im=Image.open(SRC)
assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
w,h=im.size
specs=[
 ('drill_press','立式钻床',100,100),('parts_cabinet','零件抽屉柜',160,70),
 ('bench_tools','台面工具与虎钳',100,55),('shipping_crates','绑带木箱货堆',140,120),
 ('oil_drums','油桶围堰',160,100),('pallet_jack','手动搬运叉车',70,150),
 ('parcel_trolley','纸箱推车',90,100),('linen_basket','待洗布草篮',90,70),
 ('folded_linen','叠放布草与洗涤桶',100,50),('pipe_junction','阀门管线组合',200,60),
 ('weed_planter','旧铁盆灌木',80,70),('edge_weeds','碎石砖屑与杂草',150,100)]
sha=hashlib.sha256(SRC.read_bytes()).hexdigest()
assets=[]
for i,(key,name,width,depth) in enumerate(specs):
 col,row=i%4,i//4
 ys=[0,365,690,1024]
 cell=(col*w//4,ys[row],(col+1)*w//4,ys[row+1])
 if i==4:cell=(0,365,405,690)
 if i==5:cell=(480,365,768,690)
 if i==9:cell=(384,690,800,1024)
 if i==10:cell=(800,690,1152,1024)
 box=im.getchannel('A').crop(cell).point(lambda a:255 if a>=80 else 0).getbbox()
 assert box
 x=max(cell[0],cell[0]+box[0]-2);y=max(cell[1],cell[1]+box[1]-2)
 x1=min(cell[2],cell[0]+box[2]+2);y1=min(cell[3],cell[1]+box[3]+2)
 rw,rh=x1-x,y1-y;scale=width/rw;vh=rh*scale
 id=key+'_v44'
 assets.append(dict(id=id,name=name,texture='res://art/props/factory_v44/detail_atlas.png',
  texture_size=[w,h],region=[x,y,rw,rh],ground_rect=[0,rh-depth/scale,rw,depth/scale],
  footprint_world_size=[width,depth],world_size=[width,vh],render_size=[width,vh],
  elevation_world=max(0,vh-depth),render_mode='projected_prop',
  blocking=key not in ['bench_tools','folded_linen','pipe_junction','edge_weeds'],
  interactive=False,shadow_baked=key in ['bench_tools','edge_weeds'],
  authoring_set='factory-detail-v44',editor_subcategory='furnishings',
  alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
  editor_icon=f'res://art/editor/v22/icons/{id}.tres',source_kind='built-in-imagegen-original-png',sha256=sha))
SRC2=SRC.parent/'exec-ba22d71a-317d-4987-b89b-0d3758527e2c.png'
shutil.copy2(SRC2,ART/'variation_atlas.png')
im2=Image.open(SRC2);sha2=hashlib.sha256(SRC2.read_bytes()).hexdigest()
assert im2.mode=='RGBA' and im2.getchannel('A').getextrema()[0]==0
extra=[
 ('metal_shelf','电机与料箱矮架',180,80,(0,0,425,512),True),
 ('social_items','茶杯报纸与纸牌',90,45,(425,0,768,512),False),
 ('scrap_pile','废缆轮胎与金属边角料',150,110,(768,0,1152,512),True),
 ('sack_pallet','麻袋与工具箱托盘',130,100,(1152,0,1536,512),True),
 ('hedge','边缘灌木丛',260,110,(0,512,595,1024),False),
 ('shallow_weeds','稀疏杂草与碎石',120,85,(595,512,890,1024),False),
 ('bedside_cabinet','床边私人物品柜',60,40,(890,512,1135,1024),True),
 ('motor_parts','拆解电机与油壶',110,65,(1152,512,1536,1024),False)]
for key,name,width,depth,cell,blocking in extra:
 box=im2.getchannel('A').crop(cell).point(lambda a:255 if a>=80 else 0).getbbox()
 assert box
 x=max(cell[0],cell[0]+box[0]-2);y=max(cell[1],cell[1]+box[1]-2)
 x1=min(cell[2],cell[0]+box[2]+2);y1=min(cell[3],cell[1]+box[3]+2)
 rw,rh=x1-x,y1-y;scale=width/rw;vh=rh*scale;id=key+'_v44'
 assets.append(dict(id=id,name=name,texture='res://art/props/factory_v44/variation_atlas.png',
  texture_size=list(im2.size),region=[x,y,rw,rh],ground_rect=[0,rh-depth/scale,rw,depth/scale],
  footprint_world_size=[width,depth],world_size=[width,vh],render_size=[width,vh],
  elevation_world=max(0,vh-depth),render_mode='projected_prop',blocking=blocking,
  interactive=False,shadow_baked=not blocking,authoring_set='factory-detail-v44',editor_subcategory='furnishings',
  alpha_core_shader='res://art/architecture/v25/safe_edges_v25.gdshader',
  editor_icon=f'res://art/editor/v22/icons/{id}.tres',source_kind='built-in-imagegen-original-png',sha256=sha2))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
save(ART/'manifest.json',dict(schema=2,version='factory-detail-v44',assets=assets))
save(ROOT/'art/editor/v22/manifest.json',dict(schema=1,assets=[dict(id=a['id'],name=a['name'],category='furniture',editor_icon=a['editor_icon']) for a in assets]))
save(OUT/'art-registration.json',dict(originals=[str(SRC),str(SRC2)],sha256=[sha,sha2],assets=assets))
print(json.dumps(dict(registered=len(assets),regions=[a['region'] for a in assets])))
