"""Compose editable props and world-space floor dressing without changing routes."""
import json, math, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
path=ROOT/'data/rooms/r04.json'
source_text=path.read_text(encoding='utf-8')
d=json.loads(source_text)
# Idempotent for this detail pass; never restore a historical whole-map snapshot.
d['fixtures']=[f for f in d['fixtures'] if not f['id'].startswith('detail44-')]
assets={}
for p in [ROOT/'art/props/factory_v44/manifest.json',ROOT/'art/props/factory_v43/manifest.json',ROOT/'art/props/prison_v42/manifest.json',ROOT/'art/props/prison_v17/manifest.json']:
 for a in json.loads(p.read_text(encoding='utf-8'))['assets']:
  if a['id']=='notice_board':a['id']='prison_notice_board'
  assets[a['id']]=a
points=d['starts']+[d['guard_start']]+d['patrol']
for g in d['gate_guards']:points.append(g['position']);points.extend(g.get('patrol',[]))
for ps in d['routine_points'].values():points.extend(ps)
for item in d['items']:points.append(item['position'])
for m in d['merchants']:points.append(m['position']);points.extend(r['position'] for r in m.get('routine',[]))
points.extend([[1790,2370],[2110,2730],[1250,2320],[3890,340]])
for gate in d['access_doors']:
 x,y,w,h=gate['rect'];cx,cy=x+w/2,y+h/2
 points.extend([[cx,cy-85],[cx,cy+85]] if w>=h else [[cx-90,cy],[cx+90,cy]])
 points.extend([gate['interaction_point']] if 'interaction_point' in gate else [])
x,y,w,h=d['door'];points.extend([[x+w/2-90,y+h/2],[x+w/2+90,y+h/2]])
blocked=d['walls']+[d['crate'],d['door']]+[g['rect'] for g in d['access_doors']]+[f['rect'] for f in d['fixtures'] if f.get('blocks_movement',False)]
added=[];skipped=[]
def intersects(a,b,pad=2):
 return a[0]<b[0]+b[2]+pad and a[0]+a[2]+pad>b[0] and a[1]<b[1]+b[3]+pad and a[1]+a[3]+pad>b[1]
def circle_hits(p,r,radius=30):
 return math.hypot(max(r[0]-p[0],0,p[0]-r[0]-r[2]),max(r[1]-p[1],0,p[1]-r[1]-r[3]))<radius
def add(key,asset,x,y,width=None,depth=None,block=None,sight=None,z=None):
 a=assets[asset]
 default=a.get('footprint_world_size',a.get('world_size',[60,40]))
 width=width or default[0];depth=depth or default[1]
 r=[x,y,width,depth]
 block=a.get('blocking',True) if block is None else block
 if block and (any(intersects(r,b) for b in blocked) or any(circle_hits(p,r) for p in points)):
  skipped.append(dict(id=key,rect=r));return
 f=dict(id='detail44-'+key,asset_id=asset,rect=r,blocks_movement=block,blocks_sight=block if sight is None else sight)
 dims=a.get('render_size',a.get('world_size'))
 if dims:f['render_size']=[width,width*dims[1]/dims[0]]
 if z is not None:f['draw_depth']=z
 d['fixtures'].append(f);added.append(f)
 if block:blocked.append(r)

# Production area: occupied benches, machinery and raw/finished stock along edges.
for i,(x,y) in enumerate([(810,215),(1200,215),(810,455),(1200,455)]):
 add('bench-tools-'+str(i),'motor_parts_v44' if i%2 else 'bench_tools_v44',x,y,100,48,False,False,z=291 if i<2 else 531)
for i,(x,y) in enumerate([(1820,250),(1820,460)]):add('drill-'+str(i),'drill_press_v44',x,y,110,100)
for i,(x,y) in enumerate([(760,660),(1180,670)]):add('parts-'+str(i),'parts_cabinet_v44',x,y,180,65)
for i,(x,y) in enumerate([(1840,650),(1760,670)]):add('work-stock-'+str(i),'shipping_crates_v44',x,y,100,70)
add('work-trolley','parcel_trolley_v44',1390,670,80,90)
add('work-drum','oil_drums_v44',1900,370,80,55)
add('work-motor-shelf','metal_shelf_v44',760,380,160,60)
add('work-spares','metal_shelf_v44',1430,660,110,60)
add('work-material','sack_pallet_v44',1380,150,120,70)

# Corridor storage, notice points and useful silhouettes, without obstructing daily stops.
for i,(x,y) in enumerate([(740,900),(1860,1050),(1920,1390),(760,1940)]):add('planter-'+str(i),'weed_planter_v44',x,y,60,50)
for i,(x,y) in enumerate([(1160,860),(1760,860)]):add('hall-cabinet-'+str(i),'parts_cabinet_v44',x,y,130,45)
for i,(x,y) in enumerate([(970,902),(1600,902)]):add('hall-linen-'+str(i),'folded_linen_v44',x,y,60,30,False,False,z=1011)
for i,(x,y) in enumerate([(930,945),(1560,945)]):add('hall-cups-'+str(i),'social_items_v44',x,y,65,30,False,False,z=1012)
add('hall-bookcase','metal_shelf_v44',1780,920,110,50)
add('checkpoint-booth','guard_booth_v43',2400,340,80,55)
add('checkpoint-records','metal_shelf_v44',2370,650,100,50)
add('canteen-cart','parcel_trolley_v44',760,1360,70,80)
add('canteen-linen','folded_linen_v44',1180,1310,80,40,False,False)
add('canteen-planter','weed_planter_v44',1880,2080,60,40)
add('canteen-clean-basket','linen_basket_v44',780,1970,60,50)

# Dorm personal storage kept clear of spawn, bed and east-side circulation.
for i,y in enumerate([270,560,850]):
 add('dorm-basket-'+str(i),'linen_basket_v44',245,y-90,60,45)
 add('dorm-linen-'+str(i),'folded_linen_v44',135,y-58,65,30,False,False,z=y+61)
 add('dorm-personal-'+str(i),'bedside_cabinet_v44',340,y-95,60,40)

# Warehouse: mixed cargo islands break the uniform rack silhouette; central cross aisle stays open.
for i,(x,y,w,h) in enumerate([(2560,250,130,85),(2910,260,130,85),(3130,250,140,85),
 (2560,800,110,100),(3130,850,140,110),(2550,1540,130,105),(3150,1850,140,110)]):
 add('warehouse-crates-'+str(i),'sack_pallet_v44' if i%3==1 else 'shipping_crates_v44',x,y,w,h)
for i,(x,y) in enumerate([(2540,910),(3120,1560)]):add('warehouse-drums-'+str(i),'oil_drums_v44',x,y,160,90)
add('warehouse-parts','parts_cabinet_v44',2780,1960,100,60)
add('warehouse-jack','pallet_jack_v44',2800,770,65,145)
add('warehouse-trolley','parcel_trolley_v44',2770,1450,75,90)
add('warehouse-basket','parcel_trolley_v44',2780,2050,60,60)
add('warehouse-motor-shelf','metal_shelf_v44',2780,440,100,55)
add('warehouse-packing-shelf','metal_shelf_v44',3120,950,170,65)
add('warehouse-packages','sack_pallet_v44',2780,1550,85,60)
add('warehouse-scrap','scrap_pile_v44',3160,1730,120,75)
add('south-cargo','shipping_crates_v44',2460,2390,140,100)
add('south-drum','oil_drums_v44',2880,2480,160,90)
add('south-trolley','parcel_trolley_v44',3200,2540,90,100)

# Loading yard: cargo edges, working vehicle bay, unloading equipment and waiting goods.
for i,(x,y,w,h) in enumerate([(3420,640,130,100),(3400,1290,160,120),(3430,1460,130,110),
 (3920,480,110,100),(3920,1060,120,100),(3900,1490,140,100),(3400,2080,140,100),
 (3400,2340,160,120),(3600,2500,160,120),(3900,2510,140,120)]):
 add('yard-crates-'+str(i),'sack_pallet_v44' if i%3==2 else 'shipping_crates_v44',x,y,w,h)
for i,(x,y) in enumerate([(3400,1620),(3880,1870),(3420,2550)]):add('yard-drums-'+str(i),'oil_drums_v44',x,y,160,100)
add('yard-jack','pallet_jack_v44',3570,1110,75,160)
add('yard-trolley','parcel_trolley_v44',3540,1990,90,100)
add('yard-dispatch','parts_cabinet_v44',3440,1060,120,55)
add('yard-papers-tools','bench_tools_v44',3460,1040,70,35,False,False,z=1116)
add('yard-spares-shelf','metal_shelf_v44',3400,920,140,55)
add('yard-scrap','scrap_pile_v44',3940,2260,100,80)
add('yard-sacks','sack_pallet_v44',3430,1920,120,85)

# Laundry and equipment room details fit into remaining short wall strips.
for i,(x,y) in enumerate([(760,2550),(1210,2690)]):add('wash-basket-'+str(i),'linen_basket_v44',x,y,70,50)
add('wash-linen','folded_linen_v44',1180,2520,100,50,False,False,z=2529)
add('washer-supplies','folded_linen_v44',940,2450,75,30,False,False,z=2551)
add('wash-dirty-basket','linen_basket_v44',1300,2580,50,50)
add('equipment-pipe','pipe_junction_v44',1510,2460,180,45,False,False,z=2545)
add('equipment-pipe-2','pipe_junction_v44',1550,2720,180,45,False,False,z=2780)
add('equipment-service','parts_cabinet_v44',1920,2590,120,50)
add('equipment-toolset','bench_tools_v44',1930,2570,85,40,False,False,z=2641)
add('equipment-oil-can','motor_parts_v44',1820,2660,55,30,False,False,z=2721)
add('service-cargo','shipping_crates_v44',3200,2820,100,65)

# Scrapyard corner and green/vermin-prone perimeter: ground patches do not block paths.
for i,(x,y) in enumerate([(140,2390),(280,2420),(150,2690)]):add('scrapyard-'+str(i),'shipping_crates_v44',x,y,140,110)
add('scrapyard-drum','oil_drums_v44',360,2680,160,100)
for i,(x,y) in enumerate([(360,2510),(180,2830),(2400,2650)]):add('scrap-pile-'+str(i),'scrap_pile_v44',x,y,120,80)
add('scrapyard-sacks','sack_pallet_v44',360,2410,120,80)
for i,(x,y) in enumerate([(110,2240),(370,2330),(130,2530),(410,2860),(190,2940),
 (2310,2460),(2640,2580),(3120,2670),(3440,2690),(3990,400),(3990,1260),
 (3990,2220),(3460,480),(2480,2300)]):
 add('weeds-'+str(i),['edge_weeds_v44','shallow_weeds_v44','hedge_v44'][i%3],x,y,80 if x>3900 else 160,65,False,False,z=12)
rng=random.Random(44)
x=120;i=0
while x<3690:
 width=rng.choice([130,170,210,250]);depth=rng.choice([50,60,70])
 add('south-edge-'+str(i),['hedge_v44','shallow_weeds_v44','edge_weeds_v44'][i%3],x,3010+rng.randrange(0,20),width,depth,False,False,z=12)
 x+=width+rng.randrange(5,90);i+=1
for i,y in enumerate(range(500,2660,210)):
 add('east-edge-'+str(i),['shallow_weeds_v44','hedge_v44','edge_weeds_v44'][i%3],3970+rng.randrange(0,20),y+rng.randrange(-40,40),85,60,False,False,z=12)
for i,(x,y,w) in enumerate([(110,2290,250),(220,2350,220),(140,2900,270),(3350,2680,180),(2310,2500,200)]):
 add('green-cluster-'+str(i),'hedge_v44',x,y,w,80,False,False,z=12)
for i,(x,y) in enumerate([(2310,2250),(2360,2550),(3880,2690),(3440,890)]):add('outer-planter-'+str(i),'weed_planter_v44',x,y,85,75)

# Wall attachments use the established wall plane and depth, not floating floor props.
for i,(x,y) in enumerate([(2770,175),(3100,175),(830,2380),(1900,2380),(3520,2740)]):
 add('wall-lamp-'+str(i),'caged_wall_lamp',x,y,36,1.5,False,False,z=y+60)
for i,(x,y) in enumerate([(2600,190),(1960,2400),(750,2410),(3380,2740)]):
 add('extinguisher-'+str(i),'fire_extinguisher',x,y,24,1.1,False,False,z=y+50)
for i,(x,y) in enumerate([(2800,180),(940,2380),(1820,2380)]):
 add('notice-'+str(i),'prison_notice_board',x,y,100,1.2,False,False,z=y+50)

marks=[]
def line(a,b,color='#b4a368',width=5,dashed=False):marks.append(dict(kind='dash' if dashed else 'line',**{'from':a,'to':b},color=color,width=width,opacity=.68))
def rectmark(r,color='#b4a368'):
 x,y,w,h=r
 for a,b in [([x,y],[x+w,y]),([x+w,y],[x+w,y+h]),([x+w,y+h],[x,y+h]),([x,y+h],[x,y])]:line(a,b,color,4)
def hatch(r):marks.append(dict(kind='hatch',rect=r,color='#c2aa68',opacity=.7))
def label(p,t,size=26):marks.append(dict(kind='label',position=p,text=t,size=size,color='#d6ccb0',opacity=.68))
def drain(r):marks.append(dict(kind='drain',rect=r))
marks.append(dict(kind='surface',rect=[3340,220,720,2560],color='#717974',opacity=.25))
marks.append(dict(kind='surface',rect=[100,2240,480,760],color='#59634d',opacity=.19))
marks.append(dict(kind='surface',rect=[2260,2440,1040,330],color='#788371',opacity=.18))
# Truck bay, a clear pedestrian edge, and three staging/storage areas.
rectmark([3580,500,280,550]);line([3850,400],[3850,2650],dashed=True)
for i,r in enumerate([[3400,1220,180,570],[3380,2020,200,370],[3860,1440,180,820]]):
 rectmark(r);label([r[0]+12,r[1]+40],'%02d'%(i+1),22)
hatch([3580,1030,280,30]);hatch([3760,260,240,20]);hatch([3360,1060,20,180])
for y in [1360,2160]:
 line([3700,y+65],[3700,y-25],'#c8b878',7)
 line([3700,y-25],[3678,y],'#c8b878',6);line([3700,y-25],[3722,y],'#c8b878',6)
label([3640,475],'装卸',28)
# Warehouse rack foundations and numbered shelf lanes; central cross aisle stays plain.
for i,f in enumerate([f for f in d['fixtures'] if f['id'].startswith('warehouse-rack-')]):
 x,y,w,h=f['rect'];rectmark([x-10,y-10,w+20,h+20],'#a49765');label([x+14,y+h+42],'%s%02d'%('A' if i<3 else 'B',i+1),22)
hatch([2530,1060,160,18]);hatch([3180,1070,120,18])
line([2850,1000],[3190,1000],'#c0b68e',3,True)
# Workstations, utility drains and safety paint.
for r in [[1780,210,200,400],[1510,2560,270,150],[1910,2450,280,130]]:rectmark(r)
hatch([1510,2710,270,20]);hatch([1700,2440,180,18]);hatch([2020,2760,180,16])
for r in [[1380,1390,120,18],[1740,1390,100,18],[900,2580,100,16],[1180,2640,100,16],[3560,2600,160,22]]:drain(r)
for x,y,text in [(760,815,'加工车间'),(750,2250,'食堂'),(790,2785,'洗衣房'),(1530,2785,'设备间'),(2580,2250,'仓库'),(2450,2930,'后勤通道')]:label([x,y],text,24)
d['ground_details']=marks
# Fail if another editor changes the file during this short read/write operation.
assert path.read_text(encoding='utf-8')==source_text, 'R04 changed during composition; retry using latest data.'
path.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'detail-registration.json').write_text(json.dumps(dict(added=len(added),total_fixtures=len(d['fixtures']),ground_marks=len(marks),skipped=skipped,ids=[f['id'] for f in added]),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(added=len(added),total=len(d['fixtures']),marks=len(marks),skipped=skipped)))
