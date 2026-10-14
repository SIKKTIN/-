"""Polish only the approved courtyard's owned records; preserve concurrent work."""
from pathlib import Path
from copy import deepcopy
import json, math
from register_pipe_energy_court import ROOT, DOC, read, write, sha, assets

def rounded(rect, points, radius):
    x,y,w,h=rect
    world=[(x+a*w,y+b*h) for a,b in points]
    result=[]
    for i,p in enumerate(world):
        prev=world[i-1];nxt=world[(i+1)%len(world)]
        a=math.dist(p,prev);b=math.dist(p,nxt)
        r=min(radius,a*.28,b*.28)
        first=tuple(p[k]+(prev[k]-p[k])*r/a for k in range(2))
        last=tuple(p[k]+(nxt[k]-p[k])*r/b for k in range(2))
        for j in range(9):
            t=j/8
            v=[(1-t)**2*first[k]+2*(1-t)*t*p[k]+t*t*last[k] for k in range(2)]
            result.append([(v[0]-x)/w,(v[1]-y)/h])
    return result

def run():
    definitions=assets()
    path=ROOT/'data/rooms/r04.json'
    before=read(path);previous_sha=sha(path)
    assert before.get('pipe_energy_court_version')==1
    assert not before.get('pipe_energy_court_polish')
    d=deepcopy(before)
    old_ids=['energy-court-control-'+str(i) for i in range(3)]
    assert all(any(f['id']==s for f in d['fixtures']) for s in old_ids)
    d['fixtures']=[f for f in d['fixtures'] if f['id'] not in old_ids]
    def prop(key,asset,x,y,**extras):
        definition=definitions[asset]
        width,depth=definition['footprint_world_size']
        f=dict(id='energy-court-'+key,asset_id=asset,rect=[x,y,width,depth],
               energy_court_generated=True,blocking=definition.get('blocking',True))
        f.update(extras);d['fixtures'].append(f)
    prop('gray-control-bank','energy_control_bank_v1',3160,3600)
    prop('parts-canopy','energy_canopy_v1',4590,3600,exterior_shell=True)
    prop('service-bench','energy_bench_v1',4420,3820,exterior_shell=True)
    prop('wall-table-drums','energy_drums_v1',2560,3860)
    for i,y in enumerate([3490,3560,3630]):prop('return-red-extension-'+str(i),'energy_pipe_red_v1',2710,y)
    for i,y in enumerate([3540,3615]):prop('return-blue-extension-'+str(i),'energy_pipe_blue_v1',2736,y)
    for f in d['fixtures']:
        if f['id']=='energy-court-warehouse-elbow':f['rect'][1]=2875
        if f['id']=='energy-court-parts':f['rect'][0]=4800;f['rect'][1]=3890
        if f['id']=='energy-court-pallet':f['rect'][0]=4630;f['rect'][1]=3890
        if f['id']=='energy-court-jack':f['rect'][0]=4880;f['rect'][1]=3890
    border='res://art/environment/drying_yard_edges_v1/manifest.json'
    for region in d['floor_regions']:
        if not region.get('energy_court_generated'):continue
        key=region['id']
        if region.get('natural_ground') and region.get('polygon'):
            region['polygon']=rounded(region['rect'],region['polygon'],75)
            region['edge_feather']=14
            region.update(outline_asset_id='drying_pebble_edge_1_v1',outline_manifest=border,outline_width=12)
        elif key in ['energy-court-tree-west-walk','energy-court-tree-east-walk']:
            region['polygon']=rounded(region['rect'],region['polygon'],95)
            region.update(outline_asset_id='drying_pebble_edge_2_v1',outline_manifest=border,outline_width=10)
    # Low ivy grows along the room's outside feet and the gantry bases.
    for i,(x,y) in enumerate([(2160,2760),(2180,3060),(2180,3290),(2180,3560),(2150,3880),
                               (3500,3550),(3505,3770),(4530,3530),(4870,3510),(4520,3940)]):
        prop('ivy-'+str(i),'energy_shrubs_b_v1',x,y,blocking=False,exterior_shell=True)
    d['pipe_energy_court_polish']=1
    assert sha(path)==previous_sha,'Map changed during polish; no write performed.'
    write(DOC/'before-polish-map.json',before)
    write(path,d)
    write(DOC/'after-map.json',d)
    write(DOC/'candidate-map.json',d)
    registration=read(DOC/'map-registration.json')
    registration['new_fixture_ids']=[f['id'] for f in d['fixtures'] if f.get('energy_court_generated')]
    registration['polish_base_sha256']=previous_sha
    registration['after_sha256']=sha(path)
    write(DOC/'map-registration.json',registration)
    print('Polished approved courtyard: gray controls, canopy, continuous return pipes, curved stone/grass edges.')

if __name__=='__main__': run()
