import json,shutil,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
ART=ROOT/'art/environment/factory_v45';ART.mkdir(parents=True,exist_ok=True)
SRC=Path('C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0')
files=['exec-35e49874-9cc3-444f-9b7c-3d9a08dfed5e.png','exec-ba16bfff-9d42-463d-aedf-4e24483d8f03.png']
assets=[];records=[]
for filename,target in zip(files,['floor_atlas.png','organic_atlas.png']):
 source=SRC/filename;shutil.copy2(source,ART/target)
 sha=hashlib.sha256(source.read_bytes()).hexdigest();im=Image.open(source)
 records.append(dict(original=str(source),project=str(ART/target),sha256=sha,mode=im.mode,size=list(im.size)))
 if target=='floor_atlas.png':
  names=[('common_floor_v45','生活区旧地砖'),('workshop_floor_v45','车间混凝土大板'),('warehouse_floor_v45','仓库深灰水泥'),('loading_floor_v45','装卸场粗骨料水泥'),('laundry_floor_v45','洗衣房浅绿小砖'),('earth_v45','外围碎石土草地')]
  for i,(id,name) in enumerate(names):
   region=[i%3*512+2,i//3*512+2,508,508]
   assets.append(dict(id=id,name=name,texture='res://art/environment/factory_v45/'+target,texture_size=list(im.size),region=region,source_kind='built-in-imagegen-original-png',sha256=sha))
 else:
  assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
  for i,(id,name) in enumerate([('grassland_v45','自由形草地'),('bush_edge_v45','不规则灌木边缘'),('earth_clearing_v45','自然土石空地'),('shrub_cluster_v45','团簇灌木')]):
   cell=(i%2*768,i//2*512,(i%2+1)*768,(i//2+1)*512)
   box=im.getchannel('A').crop(cell).point(lambda a:255 if a>=20 else 0).getbbox()
   assert box
   x=max(cell[0],cell[0]+box[0]-3);y=max(cell[1],cell[1]+box[1]-3)
   x1=min(cell[2],cell[0]+box[2]+3);y1=min(cell[3],cell[1]+box[3]+3)
   assets.append(dict(id=id,name=name,texture='res://art/environment/factory_v45/'+target,texture_size=list(im.size),region=[x,y,x1-x,y1-y],source_kind='built-in-imagegen-original-png',sha256=sha))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
save(ART/'manifest.json',dict(schema=2,assets=assets));save(OUT/'terrain-registration.json',dict(originals=records,assets=assets))
path=ROOT/'data/rooms/r04.json';disk=path.read_text(encoding='utf-8');d=json.loads(disk)
rng=__import__('random').Random(451);patches=[]
def patch(id,x,y,w,h,clip,turns=0,mirror=False):
 patches.append(dict(asset_id=id,rect=[x,y,w,h],clip_rect=clip,rotation_quarters=turns,mirror_x=mirror))
for i,x in enumerate(range(-50,4300,440)):
 patch(['bush_edge_v45','grassland_v45','shrub_cluster_v45'][i%3],x,2740+rng.randrange(-10,30),rng.randrange(400,610),rng.randrange(160,280),[0,2720,4240,320],2*(i%2),i%3==0)
for i,y in enumerate(range(140,2200,410)):
 patch(['bush_edge_v45','grassland_v45'][i%2],-110,y,240,490,[0,0,100,2260],1,i%2==0)
for i,y in enumerate(range(290,2710,390)):
 patch(['shrub_cluster_v45','bush_edge_v45'][i%2],4060,y,260,420,[4060,0,180,3040],1,i%3==0)
for i,x in enumerate(range(720,2200,500)):
 patch('bush_edge_v45',x,-25,610,220,[700,0,1500,280],0,i%2==0)
for i,x in enumerate(range(2640,4020,420)):
 patch('bush_edge_v45',x,-10,540,230,[2620,0,1620,260],0,i%2==0)
for i,(x,y,w,h) in enumerate([(40,2270,470,340),(150,2530,430,350),(20,2730,410,290)]):
 patch(['grassland_v45','earth_clearing_v45','shrub_cluster_v45'][i],x,y,w,h,[0,2260,600,780],0,i==1)
patch('grassland_v45',2600,1960,770,350,[2600,1960,760,340])
patch('shrub_cluster_v45',2950,2030,400,255,[2600,1960,760,340],0,True)
patch('earth_clearing_v45',2630,2040,450,240,[2600,1960,760,340])
d['terrain_patches']=patches
assert path.read_text(encoding='utf-8')==disk
save(path,d)
print(json.dumps(dict(materials=6,organic_assets=4,free_patches=len(patches))))
