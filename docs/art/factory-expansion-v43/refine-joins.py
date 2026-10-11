"""Repair corner clearance and shared-wall T ports without changing the daily core."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=ROOT/'data/rooms/r04.json'
d=json.loads(p.read_text(encoding='utf-8-sig'))
walls=[];mapping={}
for i,r in enumerate(d['walls']):
 south=1480<=r[0]<2240 and r[1] in (2660,2680) and r[3] in (20,120,140)
 north=r[1]==100 and r[0] in (2480,2520,3280,3320) and r[3]==120
 if south or north:continue
 mapping[i]=len(walls);walls.append(r)
surfaces=[]
for s in d['architecture']['wall_surfaces']:
 if s['wall_index'] in mapping:
  s['wall_index']=mapping[s['wall_index']];surfaces.append(s)
d['walls']=walls;d['architecture']['wall_surfaces']=surfaces
def tile(rect,asset,parts):
 i=len(d['walls']);d['walls'].append(rect)
 d['architecture']['wall_surfaces'].append(dict(wall_index=i,height=20,grid_tile_asset=asset,collision_parts=parts))
tile([1480,2660,40,140],'prison_l_ne',[[0,120,40,20],[0,0,20,140]])
for x in range(1520,2000,40):tile([x,2680,40,120],'prison_h_b' if x%80==0 else 'prison_h_c',[[0,100,40,20]])
tile([2000,2680,20,120],'prison_h_short_c',[[0,100,20,20]])
for x,w in [(2020,80),(2100,80),(2180,20)]:tile([x,2680,w,20],f'prison_lintel_{w}',[])
tile([2200,2660,40,140],'prison_l_nw',[[0,120,40,20],[20,0,20,140]])
for x,w,a in [(2480,60,'prison_t_s'),(2540,20,'prison_h_short_c'),
              (3280,20,'prison_h_short_c'),(3300,60,'prison_t_s')]:
 tile([x,100,w,120],a,[[0,100,w,20]])
for x,w in [(1380,40),(1420,40),(1460,20)]:tile([x,2680,w,120],'prison_h_a' if w==40 else 'prison_h_short_c',[[0,100,w,20]])
for g in d['access_doors']:
 if g['id']=='service-side':g['rect']=[2020,2780,180,20];g['interaction_point']=[2110,2730]
for f in d['fixtures']:
 if f['id']=='service-side-visual':f['rect']=[2020,2780,180,20]
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Repaired equipment corner, closed bypass gap, and integrated two T ports.')
