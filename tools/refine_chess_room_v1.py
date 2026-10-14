"""Fit recreation frontage clear of the existing workshop's raised north wall."""
from copy import deepcopy
from restore_chess_room_v1 import ROOT,DOC,ART,read,write,sha
path=ROOT/'data/rooms/r04.json';start=sha(path);m=read(path)
assert m['chess_restoration_version']==1
reg=read(DOC/'layout-registration.json')
write(DOC/'refinement-input.json',m)
defs={a['id']:a for a in read(ART/'manifest.json')['assets']}
own={int(s['wall_index']) for s in m['architecture']['wall_surfaces'] if s.get('grid_tile_asset','').startswith('chess_')}
walls=[];mapping={}
for i,r in enumerate(m['walls']):
    if i in own:continue
    mapping[i]=len(walls);walls.append(r)
surfaces=[]
for s in m['architecture']['wall_surfaces']:
    i=int(s['wall_index'])
    if i in own:continue
    s['wall_index']=mapping[i];surfaces.append(s)
m['walls']=walls;m['architecture']['wall_surfaces']=surfaces
added=[]
def wall(id,x,y):
    a=defs[id];i=len(walls);walls.append([x,y,*a['world_size']]);added.append(i)
    surfaces.append(dict(wall_index=i,grid_tile_asset=id,height=20,coping_elevation=100,collision_parts=deepcopy(a['collision_parts'])))
for id,x,y in [('nw',880,100),('ne',1440,100),('sw',880,680),('se',1440,680)]:wall('chess_corner_'+id+'_v1',x,y)
for y in [100,700]:
    for x in range(920,1440,40):
        if y==700 and 1120<=x<1280:continue
        wall('chess_wall_h_%02d_v1'%(((x-920)//20)%16),x,y)
for x in [880,1460]:
    for y in range(220,680,20):wall('chess_wall_v_short_v1',x,y)
area=[900,220,560,580]
for group in ['visibility_rooms','zones']:
    next(v for v in m[group] if v['id']=='chess-room')['rect']=area.copy()
next(v for v in m['floor_regions'] if v['id']=='chess-room')['rect']=[880,200,600,620]
positions={'chess-table':(1110,320),'chess-card-table':(1110,550),
    'chess-stool-0':(1160,245),'chess-stool-1':(1040,375),'chess-stool-2':(1280,375),
    'chess-stool-3':(1160,435),'chess-stool-4':(1160,490),
    'chess-stool-5':(1040,605),'chess-stool-6':(1280,605),'chess-stool-7':(1160,670),
    'chess-tea':(1350,610),'chess-bin':(1370,665),'chess-sign':(945,733),'chess-door-visual':(1120,800)}
for f in m['fixtures']:
    if f['id'] in positions:f['rect'][:2]=positions[f['id']]
    if f['id']=='chess-sign':f['draw_depth']=822
gate=next(v for v in m['access_doors'] if v['id']=='chess-entry')
gate.update(rect=[1120,800,160,20],room_rect=area.copy(),evacuation=[1200,910])
free=[[1060,430],[1310,435],[1330,645]]
oldfree=reg['free_points']
for i,p in enumerate(m['routine_points']['free']):
    if p in oldfree:m['routine_points']['free'][i]=free[oldfree.index(p)]
next(s for s in m['resident_staff'] if s['id']=='bath-cashier')['position']=[2020,3550]
assert sha(path)==start
write(path,m);write(DOC/'restoration-output.json',m);write(DOC/'refinement-output.json',m)
reg.update(area=area,added_wall_indices=added,free_points=free,refinement_input_sha256=start,output_sha256=sha(path))
write(DOC/'layout-registration.json',reg)
print('Refined chess frontage:',area,'and',len(added),'wall tiles.')
