import json, shutil, hashlib, random
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ART = ROOT / 'art/environment/factory_v46'
SRC = Path('C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0')
ART.mkdir(parents=True, exist_ok=True)
OUT.mkdir(parents=True, exist_ok=True)
path = ROOT / 'data/rooms/r04.json'
disk = path.read_text(encoding='utf-8')
d = json.loads(disk)
baseline = OUT / 'baseline'
baseline.mkdir(exist_ok=True)
if not (baseline / 'r04.json').exists():
    (baseline / 'r04.json').write_text(disk, encoding='utf-8')
shutil.copy2(SRC / 'exec-22ed80b8-2430-44e7-9044-27f335dc2a73.png', OUT / 'approved-concept-c.png')
assets, records = [], []
names = [('common_floor_v46','生活区灰绿地砖'),('workshop_floor_v46','车间冷灰大板'),('warehouse_floor_v46','仓库深灰砖'),('loading_floor_v46','通道装卸场灰绿铺地'),('laundry_floor_v46','洗衣房浅绿小砖'),('grass_base_v46','外围橄榄草地')]
for filename, target in [('exec-5faeca62-1a6f-4264-881b-fb7d28c423e5.png','floor_atlas.png'), ('exec-d10f8646-b148-4204-a6cd-6050278efa15.png','organic_atlas.png')]:
    source = SRC / filename
    shutil.copy2(source, ART / target)
    sha = hashlib.sha256(source.read_bytes()).hexdigest()
    im = Image.open(source)
    records.append(dict(original=str(source), project=str(ART / target), sha256=sha, mode=im.mode, size=list(im.size)))
    if target == 'floor_atlas.png':
        for i,(id,name) in enumerate(names):
            assets.append(dict(id=id,name=name,texture='res://art/environment/factory_v46/'+target,texture_size=list(im.size),region=[i%3*512,i//3*512,512,512],source_kind='built-in-imagegen-original-png',sha256=sha))
    else:
        assert im.mode == 'RGBA' and im.getchannel('A').getextrema()[0] == 0
        for i,(id,name) in enumerate([('soil_island_v46','自然泥土斑块'),('grass_band_v46','自由草地边缘'),('earth_clearing_v46','土石空地'),('shrub_cluster_v46','低矮灌木团簇')]):
            cell = (i%2*768,i//2*512,(i%2+1)*768,(i//2+1)*512)
            box = im.getchannel('A').crop(cell).point(lambda a:255 if a>=20 else 0).getbbox()
            assert box
            x=max(cell[0],cell[0]+box[0]-3); y=max(cell[1],cell[1]+box[1]-3)
            x1=min(cell[2],cell[0]+box[2]+3); y1=min(cell[3],cell[1]+box[3]+3)
            assets.append(dict(id=id,name=name,texture='res://art/environment/factory_v46/'+target,texture_size=list(im.size),region=[x,y,x1-x,y1-y],source_kind='built-in-imagegen-original-png',sha256=sha,fixed_orientation=True,preserve_aspect=True))
        # Register individual upright bushes from the original atlas for narrow
        # west/east margins. Only crop metadata changes; pixels stay untouched.
        for i,region in enumerate([[854,712,233,216],[1021,546,259,196],[1223,749,226,177]]):
            assets.append(dict(id='shrub_single_%d_v46'%i,name='单株灌木 %d'%(i+1),texture='res://art/environment/factory_v46/'+target,texture_size=list(im.size),region=region,source_kind='built-in-imagegen-original-png',sha256=sha,fixed_orientation=True,preserve_aspect=True))
def save(p,value):
    p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
save(ART/'manifest.json',dict(schema=2,assets=assets))
save(OUT/'terrain-registration.json',dict(originals=records,assets=assets))
replace = dict(zip(['common_floor_v45','workshop_floor_v45','warehouse_floor_v45','loading_floor_v45','laundry_floor_v45','earth_v45'],[n[0] for n in names]))
sizes={'common_floor_v46':640,'workshop_floor_v46':960,'warehouse_floor_v46':640,'loading_floor_v46':640,'laundry_floor_v46':480,'grass_base_v46':930}
for region in d['floor_regions']:
    region['asset_id']=replace.get(region['asset_id'],region['asset_id'])
    size=sizes[region['asset_id']]
    region['tile_size']=[size,size]
    if region['id']=='exterior-base':region['natural_ground']=True
patches=[]
rng=random.Random(461)
def patch(id,x,y,w,h,clip,turns=0,mirror=False):
    patches.append(dict(asset_id=id,rect=[x,y,w,h],clip_rect=clip,rotation_quarters=turns,mirror_x=mirror))
south=[0,2720,4240,320];west=[0,0,100,2260];east=[4060,0,180,3040]
# Broad dirt breaks across continuous grass, then small separated shrub groups.
for i,x in enumerate(range(-90,4300,470)):
    patch('soil_island_v46' if i%2 else 'earth_clearing_v46',x,2750+rng.randrange(-10,45),rng.randrange(380,520),rng.randrange(170,250),south,2*(i%2),i%3==0)
for i,x in enumerate(range(90,4300,610)):
    patch('shrub_cluster_v46',x,2770+rng.randrange(-5,55),290,175,south,0,i%2==0)
for i,y in enumerate(range(130,2240,510)):
    patch('earth_clearing_v46',-65,y,230,400,west,1,i%2==0)
    patch('shrub_cluster_v46',-15,y+190,115,200,west,1,i%2==0)
for i,y in enumerate(range(260,2700,510)):
    patch('soil_island_v46',4045,y,205,400,east,1,i%2==0)
    patch('shrub_cluster_v46',4080,y+200,150,240,east,1,i%2==0)
for i,(start,end,clip) in enumerate([(720,2150,[700,0,1500,280]),(2670,4020,[2620,0,1620,260])]):
    for j,x in enumerate(range(start,end,560)):
        patch('earth_clearing_v46',x,-15,430,200,clip,0,j%2==0)
        patch('shrub_cluster_v46',x+140,30,290,175,clip,0,j%2==0)
recess=[0,2260,600,780]
for i,(x,y,w,h) in enumerate([(40,2280,440,290),(220,2520,370,240),(20,2750,350,230)]):
    patch('soil_island_v46',x,y,w,h,recess,0,i==1)
patch('shrub_cluster_v46',65,2425,295,180,recess)
patch('shrub_cluster_v46',255,2690,280,175,recess,0,True)
garden=[2600,1960,760,280]
patch('earth_clearing_v46',2670,1980,500,230,garden)
patch('shrub_cluster_v46',3000,2060,280,170,garden,0,True)
patch('grass_band_v46',2590,1965,450,130,garden)
# Keep the repeated source sprites from becoming evenly spaced scenery rows.
# These are free world-space transforms, not changes to the generated pixels.
for p in patches:
    x,y,w,h=p['rect']
    clip=p['clip_rect']
    if clip==south:
        x+=rng.randrange(-145,146);y+=rng.randrange(-75,86)
    elif clip==west or clip==east:
        y+=rng.randrange(-100,101)
    elif clip not in [garden,recess]:
        x+=rng.randrange(-95,96);y+=rng.randrange(-30,61)
    factor=rng.uniform(0.76,1.22)
    p['rect']=[round(x),round(y),round(w*factor),round(h*factor)]
    # Painted vegetation/rocks encode an upright camera and fixed lighting.
    # Variation comes from placement and uniform scale, never UV rotation.
    p['rotation_quarters']=0
    p['mirror_x']=False
    if p['asset_id']=='shrub_cluster_v46' and clip in [west,east]:
        p['asset_id']='shrub_single_%d_v46'%(patches.index(p)%3)
        w=80 if clip==west else 105
        x=rng.randrange(3,18) if clip==west else 4070+rng.randrange(0,30)
        y=p['rect'][1]
        source=next(a['region'] for a in assets if a['id']==p['asset_id'])
        p['rect']=[x,y,w,round(w*source[3]/source[2],3)]
    else:
        source=next(a['region'] for a in assets if a['id']==p['asset_id'])
        x,y,w,h=p['rect'];ratio=source[2]/source[3]
        new_w=(w*h*ratio)**0.5;new_h=new_w/ratio
        p['rect']=[round(x+(w-new_w)/2,3),round(y+(h-new_h)/2,3),round(new_w,3),round(new_h,3)]
d['terrain_manifest']='res://art/environment/factory_v46/manifest.json'
d['terrain_patches']=patches
d['terrain_style']={'version':46,'approved_concept':'docs/art/factory-terrain-v46/approved-concept-c.png','style':'C · 灰绿游戏瓦片与简化土草'}
before=json.loads(disk)
assert {k:v for k,v in before.items() if k not in ['floor_regions','terrain_patches','terrain_manifest','terrain_style']} == {k:v for k,v in d.items() if k not in ['floor_regions','terrain_patches','terrain_manifest','terrain_style']}
assert path.read_text(encoding='utf-8') == disk, 'Concurrent map edit; retry registration against latest state.'
save(path,d)
for file in ['review.gd','open-editor.gd']:
    text=(ROOT/'docs/art/factory-terrain-v45'/file).read_text(encoding='utf-8').replace('factory-terrain-v45','factory-terrain-v46').replace('V45','V46').replace('分区地面与概念图墙线','C版灰绿地面与自然外围')
    (OUT/file).write_text(text,encoding='utf-8')
print(json.dumps(dict(materials=6,organic_assets=7,free_patches=len(patches),preserved_geometry=True)))
