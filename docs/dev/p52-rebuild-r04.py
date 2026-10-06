"""Rebuild R04 room geometry from the agreed spatial plan, not image pixels."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
p = root / 'data/rooms/r04.json'
m = json.loads(p.read_text(encoding='utf-8'))
m['bounds'] = [80,100,2800,2200]
m['title'] = '黑工厂 · 管制生活区'
m['dormitories'] = [[100,130,400,232],[100,420,400,232],[100,710,400,232]]
m['walls'] = [
 [600,100,24,740],[600,1040,24,1260],
 [2140,100,24,660],[2140,940,24,1360],
 [720,140,1304,24],[720,140,24,440],[2000,140,24,660],
 [720,1200,200,24],[1100,1200,924,24],
 [720,1200,24,1000],[2000,1200,24,1000],[720,2180,1304,20],
 [1270,1224,20,206],[1910,1224,20,206],
]
for y in [130,420,710]:
 m['walls'] += [[100,y,400,16],[100,y,16,230],[484,y,16,230]]
m['door'] = [2140,760,24,180]
m['exit'] = [2800,760,80,180]
m['crate'] = [2164,1980,100,100]
m['guard_zone'] = [624,100,1516,2200]
m['guard_start'] = [680,960]
m['patrol'] = [[680,960],[1900,960],[2070,1100],[2070,2100],[680,2150],[680,1450]]
m['fixtures'] = [f for f in m['fixtures'] if not str(f.get('id','')).startswith('solitary-') and f['asset_id'] in ['bunk_bed','toilet_sink','cell_bars','workbench','tool_locker','notice_board']]
def prop(id,asset,r,block=True,sight=False,**extra):
 m['fixtures'].append(dict(id=id,asset_id=asset,rect=r,blocks_movement=block,blocks_sight=sight,**extra))
prop('canteen-counter','cafeteria_counter',[1290,1430,620,80],True,True)
prop('canteen-kitchen-collision','cafeteria_kitchen_collision',[1290,1230,620,200],True,True,hidden=True)
prop('canteen-queue','cafeteria_queue',[780,1500,230,14])
prop('canteen-return','cafeteria_return',[1840,1940,110,70])
for i,(x,y) in enumerate([(830,1710),(1370,1710),(830,2020),(1370,2020)]):
 prop(f'dine-table-{i}','communal_table',[x,y,210,105])
 prop(f'dine-tray-{i}','cafeteria_tray',[x+100,y+23,36,20],False,False,draw_depth=y+106)
for i,(x,y) in enumerate([(900,910),(1530,910)]): prop(f'activity-table-{i}','communal_table',[x,y,190,100])
for i,y in enumerate([1100,1460,1820]):
 m['walls'] += [[100,y,440,18],[100,y,18,284],[522,y,18,284],[100,y+270,220,14],[480,y+270,60,14]]
 prop(f'solitary-bed-{i}','solitary_bed',[135,y+90,72,112])
 prop(f'solitary-toilet-{i}','toilet_sink',[465,y+60,45,50])
 prop(f'solitary-vent-{i}','wall_vent',[270,y+36,72,1.5],False)
 prop(f'solitary-door-visual-{i}','solitary_door_closed',[320,y+270,160,28],False,False,access_id=f'solitary-{i}',closed_asset='solitary_door_closed',open_asset='solitary_door_open')
m['access_doors'] = [dict(id='cafeteria-entry',name='食堂定时门',kind='timed',rect=[920,1200,180,31.5],hours=[720,840],room_rect=[720,1200,1304,1000],evacuation=[1010,1100],initial_closed=True,blocks_sight=False)]
prop('cafeteria-door-visual','prison_gate_closed',[920,1200,180,31.5],False,False,access_id='cafeteria-entry',closed_asset='prison_gate_closed',open_asset='prison_gate_open')
prop('cafeteria-reader','access_reader',[1125,1190,24,1.333333],False)
m['confinement'] = dict(duration_minutes=120,cells=[])
for i,y in enumerate([1100,1460,1820]):
 m['access_doors'].append(dict(id=f'solitary-{i}',name=f'禁闭室{i+1}',kind='confinement',rect=[320,y+270,160,28],initial_closed=True,blocks_sight=True))
 m['confinement']['cells'].append(dict(id=f'cell-{i}',name=f'禁闭室{i+1}',rect=[100,y,440,284],spawn=[285,y+180],door_id=f'solitary-{i}',release=[400,y+330]))
for i,(asset,r) in enumerate([
 ('prison_notice_board',[1540,168,140,1.6]),('caged_wall_lamp',[880,172,36,1.5]),
 ('wall_vent',[1740,172,100,2.1]),('pipe_valve',[1900,210,82,1]),
 ('wash_basin',[1570,670,160,67.2]),('fire_extinguisher',[1950,780,25,1.14]),
 ('laundry_cart',[455,1000,68,48]),('caged_wall_lamp',[1670,1255,36,1.5])]):
 prop(f'expansion-{i}',asset,r,asset in ['wash_basin','laundry_cart'])
m['routine_points'] = dict(work=[[850,330],[1230,330],[850,570]],free=[[860,1080],[1400,1080],[1800,1080]],meal=[[1390,1560],[1590,1560],[1790,1560]],dine=[[920,1855],[1460,1855],[1040,1855]])
m['cafeteria'] = dict(enclosed=True,room_rect=[720,1200,1304,1000],entrance=[920,1200,180,31.5],access_id='cafeteria-entry',service_hours=[720,840],pickup_label=[790,1570],return_label=[1800,1890],wall_sign=[1120,1300,72,40],discipline_sign=[755,1910,104,64])
m['zones'] = [dict(name='寝室区',rect=[100,130,400,840],color='#a5b19a'),dict(name='加工车间',rect=[720,140,1304,660],color='#b4a27e'),dict(name='活动走廊',rect=[720,850,1304,290],color='#a5b19a'),dict(name='食堂',rect=[720,1200,1304,1000],color='#b6af8c'),dict(name='禁闭区',rect=[100,1100,440,1004],color='#8a9694'),dict(name='门岗 / 逃生通道',rect=[2164,100,716,2200],color='#92a5a0')]
for i,z in enumerate(m['zones']): z['id']=['cells','workshop','hall','canteen','confinement','escape'][i]
m['gate_guards'] = [dict(id='gate-watch-1',position=[2070,750]),dict(id='gate-watch-2',position=[2070,915])]
merchant=m['merchants'][0]
merchant['position']=[550,990]
merchant['routine']=[dict(minute=0,kind='rest',position=[550,1050]),dict(minute=480,kind='work',position=[1560,670]),dict(minute=660,kind='commute',position=[550,990]),dict(minute=720,kind='shop',position=[550,990]),dict(minute=840,kind='work',position=[1560,670]),dict(minute=960,kind='commute',position=[550,990]),dict(minute=1080,kind='shop',position=[550,990]),dict(minute=1200,kind='rest',position=[550,1050])]
for item in m['items']:
 if item['position'][1]>1000: item['position']=[1800,1080] if item['position'][0]>1000 else [790,1080]
m['lamps'] = [dict(position=point,radius=radius) for point,radius in [([330,170],280),([330,460],280),([330,750],280),([880,180],340),([1630,180],370),([1170,580],330),([800,1050],350),([1900,1050],350),([950,1350],340),([1670,1300],390),([900,1900],380),([1650,1950],400),([300,1140],220),([300,1500],220),([300,1860],220),([2500,680],360),([2750,1300],360)]]
p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
