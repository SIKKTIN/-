"""Expand R04 using existing repeatable 20-unit architecture; preserve the daily core."""
import copy, hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
before_bytes=(OUT/'baseline/r04.json').read_bytes()
d=json.loads(before_bytes.decode('utf-8-sig'))
old=copy.deepcopy(d)
assets={}
for p in [ROOT/'art/props/prison_v42/manifest.json',ROOT/'art/props/factory_v43/manifest.json']:
 for a in json.loads(p.read_text(encoding='utf-8-sig'))['assets']:assets[a['id']]=a
d['title']='黑工厂 · 仓储与后勤扩建'
d['bounds']=[80,100,4000,3000]
d['exit']=[2220,100,180,100]
d['staff_exterior']=[2310,150]
d['guard_zone']=[624,100,3436,2880]
d['crate']=[2780,1740,100,100]
d['escape_routes']=[
 {'id':'main','name':'正门','rect':d['exit'],'approach':[2230,850]},
 {'id':'logistics','name':'物流出口','rect':[3800,100,180,100],'gate_id':'loading-exit','hours':[960,1020],'approach':[3890,320]},
 {'id':'service','name':'后勤出口','rect':[3760,2980,180,100],'gate_id':'rear-exit','approach':[3850,2880]}]

def tile(rect,asset,parts):
 i=len(d['walls']);d['walls'].append(rect)
 d['architecture']['wall_surfaces'].append({'wall_index':i,'height':20,'grid_tile_asset':asset,'collision_parts':parts})

serial=0
def hline(x0,x1,base,openings=(),left=None,right=None):
 global serial
 x=x0
 while x<x1:
  opening=next((p for p in openings if p[0]<=x<p[1]),None)
  if opening:
   width=min(80,opening[1]-x)
   tile([x,base-100,width,20],f'prison_lintel_{width}',[])
   x+=width;continue
  next_gap=min([p[0] for p in openings if p[0]>x]+[x1])
  if x==x0 and left:
   lower=left in ('prison_l_ne','prison_l_nw')
   height=140 if lower else 120
   parts=[[0,height-20,40,20]]
   if lower:parts.append([0,0,20,140])
   tile([x,base-(height-20),40,height],left,parts);x+=40;continue
  if right and x==x1-40:
   lower=right in ('prison_l_ne','prison_l_nw')
   height=140 if lower else 120
   parts=[[0,height-20,40,20]]
   if lower:parts.append([20,0,20,140])
   tile([x,base-(height-20),40,height],right,parts);x+=40;continue
  limit=min(next_gap,x1-40 if right and x<x1-40 else x1)
  width=min(40,limit-x)
  assert width in (20,40),(x,limit)
  serial+=1
  asset='prison_h_'+('a','b','c','d','e')[serial%5] if width==40 else 'prison_h_short_c'
  tile([x,base-100,width,120],asset,[[0,100,width,20]])
  x+=width

def vline(x,y0,y1,openings=()):
 y=y0
 while y<y1:
  gap=next((p for p in openings if p[0]<=y<p[1]),None)
  if gap:y=gap[1];continue
  end=min([p[0] for p in openings if p[0]>y]+[y1])
  height=min(120,end-y)
  # Use native long strips, and native single-cell pieces for remaining length.
  if height<120:height=20
  tile([x,y,20,height],'prison_v_long' if height==120 else 'prison_v_short',[[0,0,20,height]])
  y+=height

def room(x0,x1,top_base,bottom_base,top_open=(),bottom_open=(),left_open=(),right_open=(),north=True):
 if north:hline(x0,x1,top_base,top_open,'prison_l_se','prison_l_sw')
 hline(x0,x1,bottom_base,bottom_open,'prison_l_ne','prison_l_nw')
 vline(x0,top_base+20,bottom_base-120,left_open)
 vline(x1-20,top_base+20,bottom_base-120,right_open)

def fixture(id,asset,rect,sight=False,**extra):
 f={'id':id,'asset_id':asset,'rect':rect,'blocks_movement':True,'blocks_sight':sight}
 if asset in assets:
  a=assets[asset];f['render_size']=[rect[2],rect[2]*a['region'][3]/a['region'][2]]
 f.update(extra);d['fixtures'].append(f)
 return f

def gate_visual(id,rect,closed='prison_gate_closed_v37',opened='prison_gate_open_v37'):
 fixture(id+'-visual',closed,rect,False,blocks_movement=False,access_id=id,
         closed_asset=closed,open_asset=opened,render_size=[rect[2],100])

# Break only the eastern divider for the warehouse approach; leave old wall indices stable.
d['walls'][3]=[2140,940,24,100]
vline(2140,1220,2300)
# A separate enclosed main checkpoint prevents the new warehouse door bypassing it.
hline(2160,2500,960)
# Expanded northern and eastern perimeter, with two distinct northern terminals.
hline(2160,4080,200,[(2220,2400),(3800,3980)])
vline(4060,220,3100)
vline(2200,100,200)
vline(2400,100,200)
vline(3780,100,200)
vline(3980,100,200)
fixture('main-outlet-visual','prison_gate_open_v37',[2220,200,180,20],False,blocks_movement=False,render_size=[180,100])

# Large warehouse: staggered opaque racks, west entry and loading-yard exit.
room(2500,3340,200,2220, left_open=[(1040,1220)],right_open=[(1040,1240)],
     bottom_open=[(2880,3060)],north=False)
for i,(x,y) in enumerate([(2640,380),(2900,600),(3160,380),(2640,1160),(2900,1360),(3160,1160),(2640,1740),(2900,1700)]):
 fixture(f'warehouse-rack-{i}','warehouse_rack_v43',[x,y,120,340],True)
for i,(x,y) in enumerate([(2680,2260),(3140,2260),(3420,420),(3820,800),(3440,1820),(3820,2120)]):
 fixture(f'cargo-pallet-{i}','cargo_pallet_v43',[x,y,120,100],True)
fixture('warehouse-high-cabinet','tool_locker_v42',[3140,2020,90,40],True)
fixture('loading-truck','cargo_truck_v43',[3620,540,200,440],True)
fixture('loading-booth','guard_booth_v43',[3420,240,180,120],True)
d['items'] += [{'definition_id':'lock_tool','position':[2800,340]},
 {'definition_id':'lock_tool','position':[2820,1260]},
 {'definition_id':'door_key','position':[3080,1980]},
 {'definition_id':'scrap','position':[3520,2300]}]

# Open laundry loop and locked equipment preparation route south of the cafeteria.
room(720,1380,2420,2780,top_open=[(900,1080)],bottom_open=[(1100,1280)])
room(1480,2240,2420,2780,top_open=[(1700,1880)],bottom_open=[(2040,2220)])
for i,x in enumerate((780,940,1100)):
 fixture(f'laundry-washer-{i}','washing_machine_v43',[x,2460,100,90])
for i,x in enumerate((800,1040)):
 fixture(f'laundry-dryer-{i}','drying_rack_v43',[x,2600,100,150],True)
fixture('laundry-cart','laundry_cart_v42',[1220,2580,68,48])
fixture('laundry-wash-basin','wash_basin_v42',[1180,2460,160,67.2])
fixture('equipment-pump','equipment_pump_v43',[1540,2580,220,100],True)
for i,x in enumerate((1920,2080)):
 fixture(f'equipment-cabinet-{i}','electrical_cabinet_v43',[x,2480,90,60],True)
fixture('equipment-tool-cabinet','tool_locker_v42',[1800,2680,90,40],True)

# Opening in the existing cafeteria rear frontage, using the existing timed-room rule.
keep=[];index_map={}
for i,rect in enumerate(d['walls']):
 if 78<=i<=108 and 1160<=rect[0]<1340:continue
 index_map[i]=len(keep);keep.append(rect)
surfaces=[]
for s in d['architecture']['wall_surfaces']:
 if s['wall_index'] in index_map:
  s['wall_index']=index_map[s['wall_index']];surfaces.append(s)
d['walls']=keep;d['architecture']['wall_surfaces']=surfaces
hline(1160,1340,2220,[(1160,1340)])
d['access_doors'] += [
 {'id':'cafeteria-rear','name':'食堂后门','kind':'timed','rect':[1160,2220,180,20],
  'hours':[720,840],'room_rect':old['cafeteria']['room_rect'],'evacuation':[1250,2320],
  'initial_closed':True,'blocks_sight':False},
 {'id':'maintenance-entry','name':'设备间检修门','kind':'locked','rect':[1700,2420,180,20],
  'interaction_point':[1790,2370],'initial_closed':True,'blocks_sight':True},
 {'id':'service-side','name':'后勤侧门','kind':'latch','rect':[2040,2780,180,20],
  'interaction_point':[2130,2730],'initial_closed':True,'blocks_sight':False,
  'opens':['service-barrier','rear-exit']},
 {'id':'service-barrier','name':'后勤联动隔断','kind':'latch','rect':[1400,2860,20,120],
  'initial_closed':True,'blocks_sight':True},
 {'id':'loading-exit','name':'装卸出口','kind':'timed','rect':[3800,200,180,20],
  'hours':[960,1020],'room_rect':[3800,100,180,100],'evacuation':[3890,340],
  'initial_closed':True,'blocks_sight':False},
 {'id':'rear-exit','name':'后勤出口','kind':'latch','rect':[3760,2960,180,20],
  'initial_closed':True,'blocks_sight':False}]
for id in ('cafeteria-rear','maintenance-entry','service-side','loading-exit','rear-exit'):
 gate_visual(id,next(g['rect'] for g in d['access_doors'] if g['id']==id))
# The narrow modular service partition retracts when the equipment-room latch opens.
fixture('service-barrier-visual','prison_v_long',[1400,2860,20,120],False,
 blocks_movement=False,access_id='service-barrier',closed_asset='prison_v_long',
 open_asset='',render_size=[20,120])
vline(1400,2800,2860)
vline(1400,2980,3100)
hline(720,4060,2960,[(3760,3940)])
vline(3740,2980,3100);vline(3940,2980,3100)
# Isolate the outdoor yard from the prepared southern service route.
hline(2240,4060,2780)

d['zones']=[z for z in d['zones'] if z.get('id')!='escape']+[
 {'id':'escape','name':'门岗 / 正门通道','rect':[2164,220,336,740],'color':'#92a5a0'},
 {'id':'warehouse','name':'仓库','rect':[2520,220,800,2000],'color':'#a79a80'},
 {'id':'loading','name':'装卸场','rect':[3340,220,720,2560],'color':'#b3aa90'},
 {'id':'laundry','name':'洗衣房','rect':[740,2440,620,340],'color':'#99aaa2'},
 {'id':'equipment','name':'设备间','rect':[1500,2440,720,340],'color':'#94a29e'},
 {'id':'service','name':'后勤通道','rect':[720,2800,3340,160],'color':'#8e9c96'}]
d['gate_guards'] += [
 {'id':'warehouse-watch','position':[3060,1580],'blocks_primary':False,'name':'仓库巡查员','post_activity':'仓库巡查',
  'patrol':[[3060,1580],[3060,1740],[3080,1740],[3080,2080]]},
 {'id':'loading-watch','position':[3890,340],'blocks_primary':False,'name':'装卸场看守','post_activity':'装卸值守'}]
d['lamps'] += [{'position':p,'radius':r} for p,r in [([2810,320],430),([3080,1250],420),
 ([2870,2100],430),([3700,1260],480),([3820,2380],480),([1000,2450],400),
 ([1780,2490],430),([2700,2890],420),([3760,2890],420)]]
d['expansion']={'version':'factory-v43','grid':20,'logistics_hours':[960,1020],
 'priority':['warehouse','loading'],'loops':['warehouse-loading','laundry-living','equipment-service'],
 'review_points':{'warehouse':[2820,1120],'loading':[3700,1580],'laundry':[980,2570],
 'equipment':[1850,2610],'service':[2600,2880]}}

path=ROOT/'data/rooms/r04.json'
assert path.read_bytes()==before_bytes,'R04 changed concurrently: merge latest map before writing.'
path.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'integration.json').write_text(json.dumps({'bounds':d['bounds'],'new_assets':8,
 'fixtures_before':len(old['fixtures']),'fixtures_after':len(d['fixtures']),
 'walls_before':len(old['walls']),'walls_after':len(d['walls']),
 'core_fixture_rectangles_preserved':all(any(f['id']==o['id'] and f['rect']==o['rect'] for f in d['fixtures']) for o in old['fixtures']),
 'before_sha256':hashlib.sha256(before_bytes).hexdigest()},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'bounds':d['bounds'],'walls':len(d['walls']),'fixtures':len(d['fixtures'])}))
