"""Build the approved single-campus expansion from the preserved live map.

Keep the original living area's fixture identities and relative coordinates.
Rebuild walls from one explicit topology so art, collision and editor agree.
"""
import copy
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
base = json.loads((OUT / 'baseline/r04.json').read_text(encoding='utf-8-sig'))
d = copy.deepcopy(base)
DY = 1100


def shifted(values, dx=0, dy=DY):
    return [round(values[0]+dx, 2), round(values[1]+dy, 2)] + values[2:]


def cargo_point(p):
    return shifted(p, 1740, 1000)


def mapped(p):
    return cargo_point(p) if p[0] >= 2580 else shifted(p)


H, V = [], []


def h(id, x0, x1, y, gaps=()):
    H.append(dict(id=id, x0=x0, x1=x1, y=y, gaps=list(gaps)))


def v(id, x, y0, y1, gaps=()):
    V.append(dict(id=id, x=x, y0=y0, y1=y1, gaps=list(gaps)))


# Original living block, its real openings and all daily interaction points.
for s in base['concept_plan']['horizontal']:
    if s['id'].startswith('west-') or s['id'] in [
        'workshop-north', 'workshop-hall-divider',
        'hall-canteen-divider', 'canteen-laundry-divider', 'equipment-north-step',
        'back-of-life']:
        c = copy.deepcopy(s)
        c['y'] += DY
        if c['id'] == 'back-of-life':
            c['gaps'] = [[1040, 1220], [2060, 2240]]
        if c['id'] == 'canteen-laundry-divider':
            c['gaps'] = [[1220,1400],[2020,2180]]
        H.append(c)
for s in base['concept_plan']['vertical']:
    if s['id'] in ['west-outer', 'west-room-fronts', 'west-perimeter-step',
                   'north-west-step', 'life-west', 'life-east',
                   'laundry-equipment-divider', 'equipment-step', 'equipment-east']:
        c = copy.deepcopy(s)
        c.update(y0=s['y0']+DY, y1=s['y1']+DY,
                 gaps=[[a+DY, b+DY] for a,b in s['gaps']])
        if c['id'] == 'west-perimeter-step':
            continue  # The new outer perimeter continues around the whole site.
        V.append(c)
for s in V:
    if s['id'] == 'equipment-east': s['gaps'] = [[3300,3460]]

# Continuous site boundary: only three deliberately controlled exterior exits.
h('campus-north', 100, 5820, 200, [(3300,3620),(5500,5700)])
v('campus-west-north', 100, 200, 1300)
v('campus-west-south', 100, 3340, 4200)
h('campus-south', 100, 5820, 4200, [(5560,5760)])
v('campus-east', 5800, 200, 4200)

# Two extra dorms continue the same west-side architecture and door proportions.
h('dorm-wing-top', 100, 700, 620)
h('dorm-wing-divider', 100, 700, 960)
v('dorm-wing-front', 680, 620, 1300, [(800,940),(1140,1280)])


def building(id, x0, x1, y0, y1, north=(), south=(), west=(), east=()):
    h(id+'-north', x0, x1, y0, north)
    h(id+'-south', x0, x1, y1, south)
    v(id+'-west', x0, y0, y1, west)
    v(id+'-east', x1-20, y0, y1, east)


building('bath', 820, 1420, 400, 1040, south=[(1020,1200)])
building('clinic', 1500, 2180, 400, 1040, south=[(1780,1960)])
building('yard', 2300, 3200, 340, 1120,
         south=[(2620,2820)], west=[(600,760)], east=[(660,820)])
building('duty', 3800, 4220, 440, 1120, south=[(3920,4100)])
building('office', 4280, 4700, 440, 1120, south=[(4400,4580)])
building('monitor', 4760, 5180, 440, 1120, south=[(4880,5060)])
building('workshop-two', 2480, 3980, 1380, 2140,
         north=[(3320,3500)], south=[(2720,2900)], east=[(1800,1960)])
building('tools', 3820, 4220, 2340, 2920,
         west=[(2580,2740)], south=[(3940,4120)])
building('warehouse', 4320, 5120, 1340, 3540,
         west=[(2540,2700)], east=[(1660,1820),(3020,3180)],
         south=[(4580,4760)])
h('loading-service-divider', 5120, 5820, 3660, [(5300,5480)])
building('repair', 2700, 3500, 3620, 4020,
         north=[(3000,3180)], south=[(3220,3400)])
building('waste', 3600, 4300, 3620, 4020,
         north=[(3900,4080)], east=[(3800,3960)])

# Reuse the established native modular wall/junction builder. It only consumes
# H/V and produces wall geometry; no historical map contents are executed.
builder = (ROOT/'docs/art/factory-terrain-v45/rebuild-plan.py').read_text(encoding='utf-8')
builder = builder[builder.index('walls=[];surfaces=[];joints=[];occupied=[]'):
                  builder.index("d['bounds']=[0,0,4240,3040]")]
exec(builder)
d['walls'] = walls
d['architecture'] = dict(wall_surfaces=surfaces)
d['bounds'] = [0,0,6000,4500]
d['title'] = '黑工厂园区 · 七天单图生活与逃脱'
d['escape_days'] = 7
d['demo_single_map'] = True
d['starts'] = [shifted(p) for p in base['starts']]
d['dormitories'] = [shifted(p) for p in base['dormitories']]
d['dorm_doors'] = [dict(g, rect=shifted(g['rect'])) for g in base['dorm_doors']]
d['guard_start'] = shifted(base['guard_start'])
d['guard_zone'] = [700,220,5100,3940]
d['patrol'] = [shifted(p) for p in base['patrol']] + [[750,1180],[2240,1220],[3400,1220],[4200,2260],[4200,3440]]
d['patrol'][1][1]=2360
d['patrol'][9]=[4260,2260]
d['crate'] = cargo_point(base['crate'])
d['door'] = [3300,200,320,20]
d['exit'] = [3300,80,320,100]
d['staff_exterior'] = [3460,120]
d['escape_routes'] = [
    dict(id='main',name='正门',rect=d['exit'],approach=[3460,320]),
    dict(id='logistics',name='物流出口',rect=[5500,80,200,100],
         gate_id='loading-exit',hours=[960,1020],approach=[5600,380]),
    dict(id='service',name='后勤出口',rect=[5560,4220,200,180],
         gate_id='rear-exit',approach=[5660,4100])]
d['routine_points'] = {k:[shifted(p) for p in ps] for k,ps in base['routine_points'].items()}
# NPCs use the established independent-life controller to visit the new outdoors.
d['routine_points']['free'] += [[2500,970],[3000,940],[2440,2680],[3100,3520],[4140,3200],[2260,1220]]
for p in d['routine_points']['free'][:3]:p[1]=2360
d['routine_points']['free'][4]=[2920,950]
d['workshop'] = copy.deepcopy(base['workshop'])
d['workshop']['room_rect'] = shifted(base['workshop']['room_rect'])
d['workshop']['overseer_start'] = shifted(base['workshop']['overseer_start'])
d['workshop']['patrol'] = [shifted(p) for p in base['workshop']['patrol']]
d['cafeteria'] = copy.deepcopy(base['cafeteria'])
for key in ['room_rect','entrance','pickup_label','return_label','wall_sign','discipline_sign']:
    if key in d['cafeteria']: d['cafeteria'][key] = shifted(d['cafeteria'][key])
for cell in d['confinement']['cells']:
    for key in ['rect','spawn','release']: cell[key] = shifted(cell[key])
for merchant in d['merchants']:
    merchant['position'] = shifted(merchant['position'])
    for entry in merchant['routine']: entry['position'] = shifted(entry['position'])
d['items'] = [dict(item,position=mapped(item['position'])) for item in base['items']]
d['lamps'] = [dict(l,position=mapped(l['position'])) for l in base['lamps']]
d['access_doors'] = copy.deepcopy(base['access_doors'])
for gate in d['access_doors']:
    if gate['id'] == 'loading-exit':
        gate.update(rect=[5500,200,200,20],room_rect=[5500,80,200,100],evacuation=[5600,380])
    elif gate['id'] == 'rear-exit': gate['rect'] = [5560,4200,200,20]
    elif gate['id'] == 'service-barrier': gate['rect'] = [5300,3660,180,20]
    else:
        for key in ['rect','room_rect','evacuation','interaction_point']:
            if key in gate: gate[key] = shifted(gate[key])
    if gate['id'] == 'service-side': gate.update(rect=[2520,3300,20,160],interaction_point=[2470,3380])
    if gate['id'] == 'cafeteria-rear':gate['rect']=[1220,3100,180,20]
    if gate['id'].startswith('cafeteria-') and 'evacuation' in gate:gate['evacuation'][1]=2360

d['gate_guards'] = copy.deepcopy(base['gate_guards'])
for g in d['gate_guards']:
    if g.get('blocks_primary',True):
        g['position'] = [3380 if g['id'].endswith('1') else 3560,330]
    elif g['id'] == 'warehouse-watch':
        g.update(position=[5040,2450],patrol=[[5040,2450],[5040,2820],[4860,3420],[4430,3360]])
    else: g.update(position=[5580,470],patrol=[[5580,470],[5580,1200],[5590,2300],[5530,3400]])
d['gate_guards'] += [dict(id='campus-watch',name='园区巡查员',post_activity='园区巡查',
                         blocks_primary=False,position=[3420,1180],
                         patrol=[[3420,1180],[2240,1180],[750,1180],[750,2340],[2440,2440],[4200,2260]])]

# Register existing props at their original scale; remove only old free door
# fixtures, which are re-authored below against the new authoritative topology.
d['fixtures'] = []
for original in base['fixtures']:
    if original.get('primary_gate') or (original['asset_id'].startswith(('prison_gate_','doorway_')) and not original.get('access_id')):
        continue
    f = copy.deepcopy(original)
    shift = (1740,1000) if f['rect'][0]>=2580 else (0,DY)
    f['rect'] = shifted(f['rect'],*shift)
    if 'draw_depth' in f: f['draw_depth'] += shift[1]
    if f.get('access_id'):
        f['rect'] = next(g['rect'].copy() for g in d['access_doors'] if g['id']==f['access_id'])
    if f['id'] == 'loading-booth': f['rect'] = [5350,330,155,92.81]
    if f['id'] == 'canteen-queue': f['blocks_movement'] = False
    d['fixtures'].append(f)

assets = {}
for p in ['prison_v42','factory_v43','factory_v44','campus_v47']:
    for a in json.loads((ROOT/f'art/props/{p}/manifest.json').read_text(encoding='utf-8-sig'))['assets']:
        assets[a['id']] = a


def fixture(id, asset, rect, sight=False, moving=True, **extra):
    a = assets.get(asset,{})
    render = a.get('render_size')
    if render:
        render = [rect[2],round(rect[2]*render[1]/render[0],2)]
    elif a.get('region'):
        r = a['region']; render = [rect[2],round(rect[2]*r[3]/r[2],2)]
    f = dict(id='campus-'+id,asset_id=asset,rect=rect,blocks_movement=moving,blocks_sight=sight)
    if render: f['render_size'] = render
    f.update(extra)
    d['fixtures'].append(f)
    return f


def free_door(id, rect):
    fixture(id,'doorway_free_v48',rect,moving=False,
            render_size=[24,rect[3]] if rect[3]>rect[2] else [rect[2],24],
            rotation_quarters=1 if rect[3]>rect[2] else 0)


def controlled(id, name, rect, kind='locked', **extra):
    d['access_doors'].append(dict(id=id,name=name,rect=rect,kind=kind,
                                 initial_closed=True,blocks_sight=False,**extra))
    f = fixture(id+'-visual','prison_gate_closed_v37',rect,moving=False,
                access_id=id,closed_asset='prison_gate_closed_v37',open_asset='prison_gate_open_v37',
                render_size=[24,rect[3]] if rect[3]>rect[2] else [rect[2],100])
    if rect[3]>rect[2]: f['rotation_quarters']=1


# True doorframes at every new connection; body clearance comes from shared geometry.
free_ports = {
 'dorm-extra-1':[680,800,20,140], 'dorm-extra-2':[680,1140,20,140],
 'bath':[1020,1040,180,20], 'clinic':[1780,1040,180,20],
 'yard-south':[2620,1120,200,20], 'yard-west':[2300,600,20,160],
 'yard-east':[3180,660,20,160], 'duty':[3920,1120,180,20],
 'workshop-two-north':[3320,1380,180,20], 'workshop-two-south':[2720,2140,180,20],
 'workshop-two-east':[3960,1800,20,160],
 'warehouse-west':[4320,2540,20,160], 'warehouse-east-north':[5100,1660,20,160],
 'warehouse-east-south':[5100,3020,20,160], 'warehouse-south':[4580,3540,180,20],
 'laundry-west':[800,3320,20,140], 'laundry-south':[1040,3600,180,20],
 'repair-north':[3000,3620,180,20], 'repair-south':[3220,4020,180,20],
 'waste-north':[3900,3620,180,20], 'waste-east':[4280,3800,20,160],
 'life-west-hall':[800,2240,20,160], 'life-west-meal':[800,2600,20,140],
 'life-east-hall':[2180,2300,20,160]}
for id,r in free_ports.items(): free_door(id,r)
controlled('office-entry','办公室铁门',[4400,1120,180,20])
controlled('monitor-entry','监控室铁门',[4880,1120,180,20])
controlled('tools-entry','工具房铁门',[3820,2580,20,160])
controlled('tools-rear','工具房后门',[3940,2920,180,20],linked_to='tools-entry')
controlled('equipment-rear','设备间后门',[2060,3600,180,20],linked_to='maintenance-entry')
fixture('main-gate','prison_gate_closed_v37',d['door'],moving=False,
        primary_gate=True,render_size=[320,100])

# Extra dorms use existing repeatable furnished living room assets.
for i,y in enumerate([720,1060]):
    fixture(f'dorm-bed-{i}','bunk_bed_v42',[155,y,154,194])
    fixture(f'dorm-wash-{i}','toilet_sink_v42',[582,y,70,71])
    fixture(f'dorm-basket-{i}','linen_basket_v44',[330,y,84,58])
    fixture(f'dorm-cabinet-{i}','bedside_cabinet_v44',[456,y,84,52],True)
for i,x in enumerate([890,1110]):
    fixture(f'bath-basin-{i}','wash_basin_v42',[x,530,175,75])
    fixture(f'bath-locker-{i}','tool_locker_v42',[x,750,100,45],True)
fixture('bath-basket','linen_basket_v44',[1240,820,84,58])
for i,x in enumerate([1560,1910]):
    fixture(f'clinic-bed-{i}','solitary_bed',[x,540,130,170])
    fixture(f'clinic-cabinet-{i}','bedside_cabinet_v44',[x,820,84,52],True)
fixture('clinic-basin','wash_basin_v42',[1730,480,145,62])
fixture('clinic-linen','folded_linen_v44',[1570,560,80,38],moving=False,draw_depth=712)
for i,(x,y) in enumerate([(2420,980),(2860,980),(2400,430)]):
    fixture(f'yard-seat-{i}','communal_table_v42',[x,y,160,75])
for i,(x,y) in enumerate([(2420,480),(3000,480),(2440,900),(3000,900)]):
    fixture(f'yard-planter-{i}','weed_planter_v44',[x,y,65,50])
for i,x in enumerate([3850,4330,4810]):
    fixture(f'admin-desk-{i}','bedside_cabinet_v44',[x,580,170,80],True)
    fixture(f'admin-cabinet-{i}','tool_locker_v42',[x,830,95,45],True)
    fixture(f'admin-board-{i}','prison_notice_board',[x+40,480,135,2],moving=False)
for i,(x,y) in enumerate([(2600,1520),(3100,1520),(2600,1810),(3100,1810)]):
    fixture(f'work-two-bench-{i}','workbench_v42',[x,y,195,79])
    fixture(f'work-two-tools-{i}','motor_parts_v44',[x+24,y-7,110,54],moving=False,draw_depth=y+81)
for i,y in enumerate([1510,1790]):
    fixture(f'work-two-drill-{i}','drill_press_v44',[3640,y,120,114],True)
fixture('work-two-parts','parts_cabinet_v44',[2520,1990,195,74],True)
fixture('work-two-locker','tool_locker_v42',[3500,1510,98,45],True)
for i,y in enumerate([2450,2780]):
    fixture(f'tools-locker-{i}','tool_locker_v42',[4030,y,100,45],True)
fixture('tools-parts','parts_cabinet_v44',[3860,2430,130,50],True)
for i,x in enumerate([4420,4680,4880]):
    fixture(f'warehouse-extra-{i}','warehouse_rack_v43',[x,3110,114,260],True)
fixture('repair-bench','workbench_v42',[2800,3760,195,79])
fixture('repair-tools','bench_tools_v44',[2820,3754,110,54],moving=False,draw_depth=3841)
fixture('repair-cabinet','parts_cabinet_v44',[3260,3740,140,54],True)
fixture('repair-drums','oil_drums_v44',[3080,3840,110,60],True)
for i,(x,y) in enumerate([(3650,3760),(3980,3750),(3780,3880)]):
    fixture(f'waste-scrap-{i}','scrap_pile_v44',[x,y,140,72])
fixture('waste-pallet','sack_pallet_v44',[4110,3760,110,66],True)
for i,x in enumerate([2760,3560]):
    fixture(f'garden-bench-{i}','communal_table_v42',[x,3380,180,70])
for i,(x,y,w) in enumerate([(2800,2700,250),(3360,2700,250),(2780,3110,200),(3630,3110,180)]):
    fixture(f'garden-hedge-{i}','hedge_v44',[x,y,w,55],True)

d['items'] += [dict(definition_id='lock_tool',position=[3950,2820]),
               dict(definition_id='scrap',position=[2900,3950]),
               dict(definition_id='scrap',position=[4200,3970])]

# Replace temporary furnishings with the newly authored perspective-matched art.
replacements = {
 'clinic-bed-0':'medical_cot_v47', 'clinic-bed-1':'medical_cot_v47',
 'clinic-cabinet-0':'medical_cabinet_v47', 'clinic-cabinet-1':'medical_cabinet_v47',
 'clinic-basin':'medical_trolley_v47',
 'bath-basin-0':'shower_bank_v47', 'bath-basin-1':'shower_bank_v47',
 'bath-locker-0':'changing_lockers_v47', 'bath-locker-1':'changing_bench_v47',
 'admin-desk-0':'office_desk_v47', 'admin-desk-1':'office_desk_v47',
 'admin-desk-2':'monitor_console_v47',
 'admin-cabinet-0':'filing_cabinet_v47', 'admin-cabinet-1':'filing_cabinet_v47',
 'admin-cabinet-2':'filing_cabinet_v47',
 'yard-seat-0':'park_bench_v47', 'yard-seat-1':'park_bench_v47',
 'yard-seat-2':'park_bench_v47', 'garden-bench-0':'park_bench_v47',
 'garden-bench-1':'park_bench_v47'}
for f in d['fixtures']:
    key=f['id'].removeprefix('campus-')
    if key not in replacements: continue
    asset=assets[replacements[key]]
    f['asset_id']=asset['id']
    width=asset['footprint_world_size'][0]
    height=asset['footprint_world_size'][1]
    f['rect']=[f['rect'][0],f['rect'][1],width,height]
    f['render_size']=asset['render_size'].copy()
d['fixtures']=[f for f in d['fixtures'] if f['id']!='campus-bath-basin-1']
for f in d['fixtures']:
    if f['id']=='campus-bath-locker-1': f['rect'][0]=1140
    if f['id']=='campus-yard-seat-1': f['rect'][0]=2860
fixture('yard-hoop','basketball_hoop_v47',[2690,490,120,45],True)
for i,(x,y) in enumerate([(2290,1170),(3380,1290),(4230,3390),(5300,3900)]):
    fixture(f'yard-lamp-{i}','yard_lamp_v47',[x,y,70,35],True)
for p in [[1100,470],[1830,470],[2730,860],[3990,600],[4470,600],[4950,600],
          [2920,1640],[3650,1940],[4050,2630],[3100,3750],[3990,3850],[5660,4020]]:
    d['lamps'].append(dict(position=p,radius=350))

zones = []
for zone in base['zones']:
    if zone['id'] in ['escape','warehouse','loading','service']: continue
    z=copy.deepcopy(zone);z['rect']=shifted(z['rect'])
    if z['id']=='workshop': z['name']='一号车间'
    zones.append(z)
new_zones = {
 'dorm-wing':('北寝室',[120,640,560,640]),
 'bath':('公共浴室',[840,420,560,600]), 'clinic':('医务室',[1520,420,640,600]),
 'yard':('放风院',[2320,360,860,740]), 'duty':('值班室',[3820,460,380,640]),
 'office':('办公室',[4300,460,380,640]), 'monitor':('监控室',[4780,460,380,640]),
 'workshop-two':('二号车间',[2500,1400,1460,720]),
 'tools':('工具房',[3840,2360,360,540]),
 'warehouse':('仓库',[4340,1360,760,2160]), 'loading':('装卸场',[5140,220,640,3420]),
 'garden':('中央庭院',[2600,2600,1180,940]),
 'repair':('维修间',[2720,3640,760,360]), 'waste':('垃圾站',[3620,3640,660,360]),
 'service':('后勤通道',[740,4020,5060,160]), 'escape':('正门通道',[3240,220,460,1080])}
for id,(name,r) in new_zones.items():
    zones.append(dict(id=id,name=name,rect=r,color='#9ca099',hide_label=False))
d['zones']=zones

# Authored visibility regions support the same consistent roofs and body-aware
# door reveal rules in every added room. Outdoor spaces remain naturally visible.
room_specs = [dict(id=f'dorm-{i}',name=f'寝室{i+1}',rect=r.copy(),kind='dorm',door_ids=[])
              for i,r in enumerate(d['dormitories'])]
room_specs += [dict(id=f'dorm-extra-{i}',name='北寝室',rect=[120,640+i*340,560,300],kind='room',door_ids=[])
               for i in range(2)]
for cell in d['confinement']['cells']:
    room_specs.append(dict(id=cell['id'],name=cell['name'],rect=cell['rect'],kind='confinement',door_ids=[cell['door_id']]))
for id in ['workshop','canteen','laundry','equipment','bath','clinic','duty','office','monitor','workshop-two','tools','warehouse','repair','waste']:
    z=next(z for z in zones if z['id']==id)
    r=z['rect'].copy()
    if id=='laundry': r=[820,3120,900,480]
    if id=='equipment': r=[1740,3160,780,440]
    ids=[g['id'] for g in d['access_doors'] if r[0]-40<=g['rect'][0]<=r[0]+r[2]+40 and r[1]-40<=g['rect'][1]<=r[1]+r[3]+40]
    room_specs.append(dict(id=id,name=z['name'],rect=r,kind='room',door_ids=ids))
d['visibility_rooms']=room_specs

# Base paths first; room-specific materials then match their furnishings.
d['floor_regions']=[dict(id='exterior-base',asset_id='grass_base_v46',rect=d['bounds'],tile_size=[930,930],natural_ground=True)]


def floor(id, r, material='loading', size=640, **extra):
    d['floor_regions'].append(dict(id=id,asset_id=material+'_floor_v46',rect=r,tile_size=[size,size],**extra))


for id,r in [
 ('west-life-path',[700,200,120,3420]), ('north-life-plaza',[700,220,1600,1160]),
 ('yard-main-loop',[2200,220,1600,1160]), ('north-admin-loop',[3200,1120,2600,260]),
 ('east-work-loop',[3980,1340,340,2320]), ('hall-plaza',[2200,2160,2120,1480]),
 ('west-work-loop',[2200,1340,280,820]), ('admin-frontage',[3780,420,1420,720]),
 ('south-life-loop',[120,3600,2580,580]), ('service-walk',[2540,3540,3260,660]),
 ('loading-yard',[5120,200,680,4000]), ('main-outlet',[3300,80,320,180]),
 ('logistics-outlet',[5500,80,200,180]), ('service-outlet',[5560,4200,200,200])]: floor(id,r)
for region in base['floor_regions']:
    if region['id'] in ['exterior-base','main-passage','service-horizontal','rear-outlet','warehouse','loading']: continue
    region=copy.deepcopy(region);region['rect']=shifted(region['rect'])
    d['floor_regions'].append(region)
floor_envelopes = {
 'dorm-wing':[100,620,600,700], 'bath':[820,400,600,660],
 'clinic':[1500,400,680,660], 'yard':[2300,340,900,800],
 'duty':[3800,440,420,700], 'office':[4280,440,420,700],
 'monitor':[4760,440,420,700], 'workshop-two':[2480,1380,1500,780],
 'tools':[3820,2340,400,600], 'warehouse':[4320,1340,800,2220],
 'repair':[2700,3620,800,420], 'waste':[3600,3620,700,420]}
for id,z in new_zones.items():
    if id in ['garden','service','escape','loading']: continue
    material = 'workshop' if id in ['workshop-two','repair'] else 'warehouse' if id in ['warehouse','tools','waste'] else 'laundry' if id=='bath' else 'common'
    floor('campus-'+id,floor_envelopes.get(id,z[1]),material,960 if material=='workshop' else 640)
floor('garden-paving',[2700,2640,1180,920])

# Preserve old industrial markings, translated with their actual fixtures.
d['ground_details']=[]
for original in base['ground_details']:
    s=copy.deepcopy(original)
    for k in ['rect','position','from','to']:
        if k in s:s[k]=mapped(s[k])
    d['ground_details'].append(s)


def line(a,b,width=4,color='#dad7b7'):
    d['ground_details'].append(dict(kind='line',**{'from':a,'to':b},width=width,color=color,opacity=.65))


for a,b in [([2490,510],[3020,510]),([3020,510],[3020,880]),([3020,880],[2490,880]),
            ([2490,880],[2490,510]),([2490,695],[3020,695]),
            ([2650,510],[2650,620]),([2650,620],[2850,620]),([2850,620],[2850,510])]:line(a,b)
for i in range(18):
    a=math.tau*i/18;b=math.tau*(i+1)/18
    line([2755+70*math.cos(a),695+70*math.sin(a)],
         [2755+70*math.cos(b),695+70*math.sin(b)],3)
d['ground_details'] += [dict(kind='label',position=[1550,485],text='＋',size=54,color='#aa6a5a',opacity=.8),
                       dict(kind='label',position=[4790,530],text='监控值班',size=24,color='#667971',opacity=.75)]

# Natural landscaping is limited to designated strips and garden islands so it
# never covers interior floors or hides door openings.
d['terrain_patches']=[]
rng=random.Random(106)
for clip in [[0,0,6000,90],[0,4300,6000,200],[0,90,90,4210],[5840,90,160,4210],
             [2800,2800,700,480]]:
    count=22 if clip[2]>1000 else 15 if clip[3]>1000 else 7
    for i in range(count):
        x=rng.uniform(clip[0],clip[0]+clip[2]);y=rng.uniform(clip[1],clip[1]+clip[3])
        w=rng.uniform(130,230)
        d['terrain_patches'].append(dict(asset_id='soil_island_v46' if i%3 else 'earth_clearing_v46',
                                        rect=[round(x-w/2,2),round(y-w*.3,2),round(w,2),round(w*.62,2)],clip_rect=clip))
        if i%2==0:
            d['terrain_patches'].append(dict(asset_id=f'shrub_single_{i%3}_v46',
                                            rect=[round(x-60,2),round(y-60,2),120,120],clip_rect=clip))

review = {'bath':[1100,890],'clinic':[1810,900],'yard':[2760,790],
          'duty':[4000,980],'office':[4480,980],'monitor':[4960,980],
          'workshop-two':[2900,1980],'tools':[3990,2750],
          'warehouse':[4700,2860],'loading':[5620,2250],
          'repair':[3050,3880],'waste':[4110,3900],'garden':[3260,3300]}
d['expansion'] = dict(version='campus-seven-days-v47',grid=20,
    logistics_hours=[960,1020],priority=list(review),
    loops=['dorm-work-canteen','yard-admin-production','courtyard-warehouse-loading','laundry-repair-service'],
    review_points=review,source_area=4240*3040,total_area=6000*4500,
    living_translation=[0,DY],approved_concept='docs/art/campus-expansion-v47/approved-concept.png')
d['concept_plan']=dict(reference='docs/art/campus-expansion-v47/approved-concept.png',horizontal=H,vertical=V)
import runpy
runpy.run_path(str(ROOT/'docs/dev/p107/courtyard.py'))['apply_courtyard'](d)
(ROOT/'data/rooms/r04.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(bounds=d['bounds'],walls=len(walls),fixtures=len(d['fixtures']),
                     rooms=len(room_specs),zones=len(zones),area_ratio=round(6000*4500/(4240*3040),3)),ensure_ascii=False))
