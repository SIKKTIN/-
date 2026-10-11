"""Trace the approved concept's wall topology, then re-register existing contents."""
import copy,json,random,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
path=ROOT/'data/rooms/r04.json';disk=path.read_text(encoding='utf-8')
d=json.loads(disk);old=json.loads((OUT/'baseline/r04.json').read_text(encoding='utf-8'))
def save(p,value):p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
regions={
 'workshop':([744,164,1256,636],[820,320,1360,720]),
 'hall':([720,850,1304,290],[820,1060,1360,320]),
 'canteen':([720,1230,1304,1000],[820,1420,1360,560]),
 'warehouse':([2520,220,800,2000],[2600,380,760,1540]),
 'loading':([3340,220,720,2560],[3400,300,620,1980]),
 'laundry':([740,2440,620,340],[820,2040,880,440]),
 'equipment':([1500,2440,720,340],[1760,2060,740,420]),
 'service':([720,2800,3340,160],[620,2520,3140,160])}
for i in range(3):regions['dorm'+str(i)]=([100,130+i*290,400,232],[120,220+i*340,560,300])
for i,y in enumerate([1100,1460,1820]):regions['solitary'+str(i)]=([100,y,440,284],[120,1260+i*320,560,300])
def contains(r,p):return r[0]<=p[0]<r[0]+r[2] and r[1]<=p[1]<r[1]+r[3]
def classify(p):
 for name,(before,after) in regions.items():
  if contains(before,p):return name
 if p[0]<720:return 'west-path'
 if p[0]<2520:return 'main-path'
 return 'loading'
def point(p,name=None):
 name=name or classify(p)
 if name=='west-path':return [750,round(300+(p[1]-130)*.94,2)]
 if name=='main-path':return [2400,round(340+(p[1]-220)*.82,2)]
 a,b=regions[name];return [round(b[0]+(p[0]-a[0])*b[2]/a[2],2),round(b[1]+(p[1]-a[1])*b[3]/a[3],2)]
def mapped_rect(r,name):
 a,b=regions[name];p=point(r[:2],name);return p+[round(r[2]*b[2]/a[2],2),round(r[3]*b[3]/a[3],2)]

# Landmarks traced from approved-concept.png; 2.9 world units per reference pixel.
# Walls retain their native 20-unit components. Terrain intentionally does not.
H=[];V=[]
def h(id,x0,x1,y,gaps=()):H.append(dict(id=id,x0=x0,x1=x1,y=y,gaps=list(gaps)))
def v(id,x,y0,y1,gaps=()):V.append(dict(id=id,x=x,y0=y0,y1=y1,gaps=list(gaps)))
h('west-north',100,700,200)
v('west-outer',100,200,2240)
v('west-room-fronts',680,200,2240,[(400,520),(740,860),(1080,1220),(1420,1540),(1740,1860),(2060,2180)])
for y in [540,880,1240,1560,1880,2240]:h('west-divider-'+str(y),100,700,y)
# The concept's stepped west perimeter continues from the cell block to the rear wall.
v('west-perimeter-step',600,2240,2700)
h('north-life-connection',700,800,280)
v('north-west-step',680,200,300)
h('workshop-north',800,2200,280)
v('life-west',800,300,2500,[(1140,1300),(1500,1640),(2220,2360)])
v('life-east',2180,300,2000,[(1200,1360)])
h('workshop-hall-divider',800,2200,1040,[(1260,1420),(1780,1940)])
h('hall-canteen-divider',800,2200,1400,[(980,1140),(2020,2180)])
h('canteen-laundry-divider',800,2200,2000,[(1000,1160),(2020,2180)])
v('laundry-equipment-divider',1720,2000,2500,[(2300,2440)])
h('equipment-north-step',2200,2540,2040)
v('equipment-step',2180,2000,2040)
v('equipment-east',2520,2040,2500,[(2320,2480)])
h('back-of-life',800,2540,2500)
# Main checkpoint is at the north gate, as in the concept; hall access is on its west side.
h('main-gate-frontage',2180,2620,200,[(2240,2560)])
v('main-west-perimeter',2180,200,300)
v('main-east-perimeter',2600,200,340)
v('main-warehouse-divider',2580,340,1940,[(1200,1360)])
h('main-cross-gate',2200,2600,1400,[(2300,2480)])
h('main-south',2200,2600,1940)
# Warehouse is one continuous building, with two yard portals and no invented south doorway.
h('warehouse-north',2600,3380,340)
v('warehouse-yard-divider',3360,340,1940,[(600,760),(1540,1700)])
h('warehouse-south',2580,3380,1940)
# Garden recess and loading-yard south wall create the dogleg rear route.
v('garden-west',2580,1940,2240)
v('garden-east',3360,1940,2240)
h('garden-south',2580,3380,2240)
h('yard-north',3380,4060,280,[(3760,3960)])
v('yard-east-perimeter',4040,280,2700)
h('yard-rear-divider',3380,4060,2240,[(3600,3780)])
h('south-perimeter',600,4060,2700,[(3800,3980)])

walls=[];surfaces=[];joints=[];occupied=[]
def tile(r,asset,parts):
 i=len(walls);walls.append(r);surfaces.append(dict(wall_index=i,height=20,grid_tile_asset=asset,collision_parts=parts))
def v_exists(x,y):return any(s['x']==x and s['y0']<=y<s['y1'] and not any(a<=y<b for a,b in s['gaps']) for s in V)
serial=0
for s in H:
 y=s['y'];js=[]
 for vs in V:
  x=vs['x']
  if not s['x0']<=x<s['x1'] or any(a<=x<b for a,b in s['gaps']):continue
  up=v_exists(x,y-30);down=v_exists(x,y+30)
  if not up and not down:continue
  left=x>s['x0'];right=x+20<s['x1']
  if left and right:
   asset='prison_t_cross' if up and down else 'prison_t_n' if up else 'prison_t_s';origin=x-20;width=60;height=120
  else:
   asset=('prison_t_e' if right else 'prison_t_w') if up and down else ('prison_l_se' if right else 'prison_l_sw') if down else ('prison_l_ne' if right else 'prison_l_nw')
   origin=x if right else x-20;width=40;height=140 if up and not down else 120
  if origin<s['x0'] or origin+width>s['x1']:continue
  top=y-(height-20)
  parts=[[0,height-20,width,20]]
  if up:parts.append([x-origin,0,20,height])
  js.append((origin,width,height,asset,parts,top,x))
  joints.append(dict(x=x,y=y,top=top,end=y+20))
 x=s['x0']
 while x<s['x1']:
  gap=next(((a,b) for a,b in s['gaps'] if a<=x<b),None)
  if gap:
   width=80 if gap[1]-x>=80 else 20;tile([x,y-100,width,20],'prison_lintel_'+str(width),[]);x+=width;continue
  join=next((j for j in js if j[0]==x),None)
  if join:
   origin,width,height,asset,parts,top,vx=join;tile([x,top,width,height],asset,parts);x+=width;continue
  limit=min([s['x1']]+[a for a,b in s['gaps'] if a>x]+[j[0] for j in js if j[0]>x])
  width=min(40,limit-x);assert width in (20,40),(s,x,limit)
  serial+=1;asset='prison_h_'+('a','b','c','d','e')[serial%5] if width==40 else 'prison_h_short_c'
  tile([x,y-100,width,120],asset,[[0,100,width,20]]);x+=width
for s in V:
 y=s['y0']
 while y<s['y1']:
  cuts=s['gaps']+[(j['top'],j['end']) for j in joints if j['x']==s['x']]
  cut=next(((a,b) for a,b in cuts if a<=y<b),None)
  if cut:y=min(s['y1'],cut[1]);continue
  end=min([s['y1']]+[a for a,b in cuts if a>y]);height=120 if end-y>=120 else 20
  tile([s['x'],y,20,height],'prison_v_long' if height==120 else 'prison_v_short',[[0,0,20,height]])
  y+=height
d['bounds']=[0,0,4240,3040];d['walls']=walls;d['architecture']={'wall_surfaces':surfaces}
d['title']='黑工厂 · 概念图墙线与分区地面'
d['door']=[2240,200,320,20];d['exit']=[2240,80,320,100];d['staff_exterior']=[2400,120]
d['guard_zone']=[700,140,3340,2560]
d['escape_routes']=copy.deepcopy(old['escape_routes'])
d['escape_routes'][0].update(rect=d['exit'],approach=[2400,260])
d['escape_routes'][1].update(rect=[3760,160,200,100],approach=[3860,400])
d['escape_routes'][2].update(rect=[3800,2720,180,140],approach=[3890,2600])
d['dormitories']=[[120,220+i*340,560,300] for i in range(3)]
d['starts']=[point(p,'dorm'+str(i)) for i,p in enumerate(old['starts'])]
d['dorm_doors']=[dict(actor_id=i,rect=[680,400+i*340,20,120]) for i in range(3)]
d['guard_start']=[750,1300];d['patrol']=[[750,1300],[1500,1300],[2400,1260],[2400,1620],[750,2140],[750,2470]]
d['routine_points']={key:[point(p,'workshop' if key=='work' else 'hall' if key=='free' else 'canteen') for p in ps] for key,ps in old['routine_points'].items()}
d['routine_points']['meal']=[[1490,1640],[1700,1640],[1900,1640]]
d['workshop']=copy.deepcopy(old['workshop']);d['workshop']['room_rect']=[820,320,1360,720]
d['workshop']['overseer_start']=point(old['workshop']['overseer_start'],'workshop')
d['workshop']['patrol']=[point(p,'workshop') for p in old['workshop']['patrol']]
d['cafeteria']=copy.deepcopy(old['cafeteria']);d['cafeteria']['room_rect']=[820,1420,1360,560];d['cafeteria']['entrance']=[980,1400,160,20]
for key in ['pickup_label','return_label']:d['cafeteria'][key]=point(old['cafeteria'][key],'canteen')
d['cafeteria']['wall_sign']=[1450,1350,90,42];d['cafeteria']['discipline_sign']=[850,1810,104,64]
d['crate']=mapped_rect(old['crate'],'warehouse')
d['items']=[dict(item,position=point(item['position'])) for item in old['items']]
d['merchants']=copy.deepcopy(old['merchants'])
for m in d['merchants']:
 m['position']=point(m['position']);m['routine']=[dict(r,position=point(r['position'])) for r in m.get('routine',[])]
d['gate_guards']=copy.deepcopy(old['gate_guards'])
for g in d['gate_guards']:
 if g.get('blocks_primary',True):g['position']=[2320 if g['id'].endswith('1') else 2500,330]
 else:
  name='warehouse' if 'warehouse' in g['id'] else 'loading';g['position']=point(g['position'],name);g['patrol']=[point(p,name) for p in g.get('patrol',[])]
  if name=='warehouse':g.update(position=[3310,1440],patrol=[[3310,1440],[3310,1580],[3300,1660],[3300,1820]])
d['lamps']=[dict(l,position=point(l['position'])) for l in old['lamps']]
d['confinement']=copy.deepcopy(old['confinement'])
for i,c in enumerate(d['confinement']['cells']):
 c.update(rect=[120,1260+i*320,560,300],spawn=[400,1440+i*320],release=[750,1480+i*320])
 c['building']={'roofed':True,'height':100,'roof':'solitary_roof_v23','front':'solitary_wall_front_v23','top':'solitary_coping_v23','roof_tile_size':[320,240]}
gates=copy.deepcopy(old['access_doors'])
gr={
 'cafeteria-entry':[980,1400,160,20],'cafeteria-rear':[1000,2000,160,20],
 'workshop-entry':[1260,1040,160,20],
 'maintenance-entry':[2020,2000,160,20],'service-side':[2520,2320,20,160],
 'service-barrier':[3600,2240,180,20],'loading-exit':[3760,280,200,20],
 'rear-exit':[3800,2700,180,20]}
for i in range(3):gr['solitary-'+str(i)]=[680,1420+i*320,20,120]
for g in gates:
 g['rect']=gr[g['id']];g.pop('interaction_point',None)
 if g['id'].startswith('cafeteria'):g.update(room_rect=d['cafeteria']['room_rect'],evacuation=[1060,1310])
 if g['id']=='maintenance-entry':g['interaction_point']=[2100,1945]
 if g['id']=='service-side':g['interaction_point']=[2470,2400]
 if g['id']=='loading-exit':g.update(room_rect=[3760,160,200,100],evacuation=[3860,400])
gates += [dict(id='workshop-entry-east',name='车间东门',kind='workshop',rect=[1780,1040,160,20],initial_closed=False,blocks_sight=False,linked_to='workshop-entry'),
 dict(id='cafeteria-entry-east',name='食堂东门',kind='timed',rect=[2020,1400,160,20],hours=[720,840],room_rect=d['cafeteria']['room_rect'],evacuation=[2100,1320],initial_closed=True,blocks_sight=False),
 dict(id='laundry-equipment',name='设备间内侧检修门',kind='locked',rect=[1720,2300,20,140],interaction_point=[1670,2370],initial_closed=True,blocks_sight=True,linked_to='maintenance-entry')]
d['access_doors']=gates
fixtures=[]
for source in old['fixtures']:
 f=copy.deepcopy(source);id=f['id'];p=f['rect'][:2]
 if 2520<=p[0]<3340 and p[1]>=2220:continue  # The reference has a soil garden here, not staging pallets.
 if 'bars_left' in id or 'bars_right' in id or f.get('access_id') or id=='main-outlet-visual':continue
 if id.startswith('detail44-') and any(t in id for t in ['weeds-','south-edge','east-edge','green-cluster','outer-planter','scrapyard','scrap-pile','checkpoint']):continue
 name=classify(p)
 if id.startswith('solitary-'):
  name='solitary'+str(int(id.split('-')[-1]))
 if name not in regions:continue
 f['rect']=mapped_rect(f['rect'],name)
 a,b=regions[name];sx=b[2]/a[2]
 if 'render_size' in f:f['render_size']=[round(value*sx,3) for value in f['render_size']]
 if 'draw_depth' in f:f['draw_depth']=round(point([p[0],f['draw_depth']],name)[1])
 if name=='warehouse' and f.get('blocks_movement',False) and f['rect'][0]+f['rect'][2]>3280:
  f['rect'][0]=round(3280-f['rect'][2],2)  # Keep a real 80-unit aisle alongside both yard portals.
 if id in ['dine-table-2','dine-table-3','dine-tray-2','dine-tray-3','laundry-dryer-0','laundry-dryer-1']:
  f['rect'][1]=round(f['rect'][1]-70,2)
  if 'draw_depth' in f:f['draw_depth']-=70
 fixtures.append(f)
def gate_visual(id,r,closed='prison_gate_closed_v37',opened='prison_gate_open_v37'):
 vertical=r[3]>r[2]
 f=dict(id=id+'-visual45',asset_id=closed,rect=r,blocks_movement=False,blocks_sight=False,render_size=[24,r[3]] if vertical else [r[2],100])
 if vertical:f['rotation_quarters']=1
 if id not in ['hall-east','hall-west','canteen-west','laundry-west','warehouse-west','warehouse-east-upper','warehouse-east-lower','main-cross']:
  f.update(access_id=id,closed_asset=closed,open_asset=opened)
 else:f['asset_id']=opened
 fixtures.append(f)
for g in gates:gate_visual(g['id'],g['rect'])
for i in range(3):
 gate_visual('dorm-'+str(i),[680,400+i*340,20,120]);fixtures[-1].pop('access_id',None);fixtures[-1]['dorm_actor_id']=i
for id,r in [('hall-east',[2180,1200,20,160]),('hall-west',[800,1140,20,160]),('canteen-west',[800,1500,20,140]),('laundry-west',[800,2220,20,140]),
 ('warehouse-west',[2580,1200,20,160]),('warehouse-east-upper',[3360,600,20,160]),('warehouse-east-lower',[3360,1540,20,160]),('main-cross',[2300,1400,180,20])]:gate_visual(id,r)
# Main gate visual binds to the actual primary state in WorldVolume.
fixtures.append(dict(id='main-gate-visual45',asset_id='prison_gate_closed_v37',rect=d['door'],blocks_movement=False,blocks_sight=False,render_size=[320,100],primary_gate=True))
d['fixtures']=fixtures
d['visibility_rooms']=[]
# Regenerate room rectangles from the new layout (preserve the existing visibility system).
d.pop('visibility_rooms',None)
d['zones']=[dict(id=name,name=label,rect=r,color=color) for name,label,r,color in [
 ('cells','寝室',[120,220,560,1000],'#a49f8b'),('workshop','加工车间',[820,320,1360,720],'#9ca099'),
 ('hall','活动走廊',[820,1060,1360,320],'#a8a794'),('canteen','食堂',[820,1420,1360,560],'#aaa58e'),
 ('confinement','禁闭室',[120,1260,560,940],'#939a90'),('escape','门岗 / 正门通道',[2220,140,360,1800],'#999d93'),
 ('warehouse','仓库',[2600,380,760,1540],'#999c93'),('loading','装卸场',[3400,300,620,1980],'#adab9c'),
 ('laundry','洗衣房',[820,2040,880,440],'#a5b3a2'),('equipment','设备间',[1760,2060,740,420],'#989d92'),
 ('service','后勤通道',[620,2520,3140,160],'#a6a58f')]]
for z in d['zones']:z['hide_label']=False
# Distinct surface materials, not transparent tints of the same underlying floor.
floor=[]
def surface(id,asset,r,tile):floor.append(dict(id=id,asset_id=asset,rect=r,tile_size=tile))
surface('exterior-base','earth_v45',d['bounds'],[930,930])
surface('life-west-walk','loading_floor_v45',[700,200,100,2300],[720,720])
surface('life-rear-walk','loading_floor_v45',[600,2500,1940,200],[720,720])
surface('main-passage','loading_floor_v45',[2200,100,400,1840],[720,720])
surface('service-horizontal','loading_floor_v45',[2540,2240,1260,460],[720,720])
surface('rear-outlet','loading_floor_v45',[3780,2300,280,560],[720,720])
for i in range(3):surface('dorm-'+str(i),'common_floor_v45',[120,220+i*340,560,320],[620,620])
surface('workshop','workshop_floor_v45',[800,300,1400,760],[900,900])
surface('hall','common_floor_v45',[800,1040,1400,380],[620,620])
surface('canteen','common_floor_v45',[800,1400,1400,620],[620,620])
surface('laundry','laundry_floor_v45',[800,2000,940,500],[540,540])
surface('equipment','warehouse_floor_v45',[1740,2040,800,460],[720,720])
surface('warehouse','warehouse_floor_v45',[2580,360,800,1580],[720,720])
surface('loading','loading_floor_v45',[3380,280,680,2040],[820,820])
for i in range(3):surface('solitary-'+str(i),'warehouse_floor_v45',[120,1260+i*320,560,320],[720,720])
d['floor_regions']=floor
# Keep functional paint, remapped; remove earlier whole-region color tints and obsolete captions.
marks=[]
for source in old.get('ground_details',[]):
 m=copy.deepcopy(source)
 if m['kind'] in ['surface','label']:continue
 if 'rect' in m:
  name=classify(m['rect'][:2])
  if name not in regions:continue
  m['rect']=mapped_rect(m['rect'],name)
 else:
  name=classify(m['from'])
  if name not in regions:continue
  m['from']=point(m['from'],name);m['to']=point(m['to'],name)
 marks.append(m)
d['ground_details']=marks
d['expansion']=copy.deepcopy(old['expansion'])
d['expansion'].update(version='concept-terrain-v45',review_points={'warehouse':[2850,1200],'loading':[3750,1600],'laundry':[1550,2220],'equipment':[2300,2240],'service':[3200,2600]})
d['concept_plan']={'reference':'docs/art/factory-expansion-v43/approved-concept.png','source_units_per_pixel':2.9,'west_perimeter_step':[[100,2240],[600,2240],[600,2700],[3800,2700]],'horizontal':H,'vertical':V}
assert path.read_text(encoding='utf-8')==disk,'Concurrent R04 edit; rerun against latest data.'
save(path,d);save(OUT/'wall-plan.json',d['concept_plan'])
print(json.dumps(dict(walls=len(walls),fixtures=len(fixtures),floors=len(floor),bounds=d['bounds'])))
