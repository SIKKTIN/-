"""Pave the user-marked west spine and drying-yard/bath cross connection."""
from copy import deepcopy
from math import ceil
from tools.register_valve_maintenance import ROOT, read, write, sha

DOC=ROOT/'docs/art/west-service-roads-v3'
ART=ROOT/'art/props/west_service_roads_v3'
MANIFEST='res://art/props/west_service_roads_v3/manifest.json'

def restore():
    path=ROOT/'data/rooms/r04.json';disk=sha(path)
    before=read(path);after=deepcopy(before)
    assert not any(f.get('west_service_roads_generated') for f in before['fixtures'])
    assets=[];curb_assets={}
    original=read(ROOT/'art/props/energy_south_road_v2/manifest.json')['assets'][0]
    def curb_asset(length):
        if length in curb_assets:return curb_assets[length]
        a=deepcopy(original);width=min(1938,ceil(1938*length/600))
        a.update(id=f'west_service_curb_{length}_v3',name=f'西侧连接道路 · 石质路缘 {length}',
                 region=[24,195,width,80],world_size=[length,20],render_size=[length,20],
                 footprint_world_size=[length,12],ground_rect=[0,32,width,48],
                 editor_hidden=length!=600)
        assets.append(a);curb_assets[length]=a['id'];return a['id']
    added=[]
    def run(key,x,y,length,turn=0):
        offset=0
        while offset<length:
            piece=min(600,length-offset)
            f=dict(id=f'west-service-road-{key}-{offset}',asset_id=curb_asset(piece),
                   rect=[x,y+offset,12,piece] if turn%2 else [x+offset,y,piece,12],
                   render_size=[piece,20],rotation_quarters=turn,draw_depth=0,
                   blocks_movement=False,blocks_sight=False,exterior_shell=True,
                   west_service_roads_generated=True)
            after['fixtures'].append(f);added.append(f['id']);offset+=piece
    # Canteen/bath walls already bound the west side. The exposed lawn edge
    # needs a curb; the branch mouth is deliberately open from y3180 to3400.
    run('drying-east-curb',2112,2520,660,1)
    run('drying-south-curb',1620,3172,500)
    run('east-curb',2276,1820,2120,3)
    floors=[]
    paving=dict(asset_id='loading_floor_v1',manifest='res://art/environment/loading_yard_v1/manifest.json',
                tile_size=[240,240],tile_origin=[2140,3980],natural_ground=False,
                west_service_roads_generated=True)
    for key,rect in [('west-spine',[2120,1820,160,2280]),('bath-cross-connection',[1300,3180,980,220])]:
        s=dict(paving,id='west-service-road-'+key,rect=rect)
        after['floor_regions'].append(s);floors.append(s['id'])
    after['floor_regions'].append(dict(id='west-service-road-east-verge',asset_id='grass_base_v46',
        manifest='res://art/environment/factory_v46/manifest.json',rect=[2280,2400,20,1540],
        tile_size=[470,470],tile_origin=[0,0],natural_ground=True,west_service_roads_generated=True))
    floors.append('west-service-road-east-verge')
    # Move only the original energy-yard decorative bushes that would cover
    # the new lane. Smaller calibrated variants keep the road unobstructed.
    source_assets=read(ROOT/'art/props/pipe_energy_court_v1/manifest.json')['assets']
    shrub_ids={}
    for suffix,w in [('a',54),('b',48)]:
        a=deepcopy(next(s for s in source_assets if s['id']==f'energy_shrubs_{suffix}_v1'))
        ratio=w/a['world_size'][0]
        a.update(id=f'west_service_verge_shrubs_{suffix}_v3',name=f'西侧连接道路 · 路缘矮草丛 {suffix.upper()}',
                 world_size=[w,a['world_size'][1]*ratio],render_size=[w,a['render_size'][1]*ratio],
                 footprint_world_size=[w,a['footprint_world_size'][1]*ratio],
                 elevation_world=a['elevation_world']*ratio)
        assets.append(a);shrub_ids[suffix]=a['id']
    modified=[]
    owned={f'energy-court-shrub-{i}' for i in range(6)}|{f'energy-court-ivy-{i}' for i in range(5)}
    for f in after['fixtures']:
        if f['id'] not in owned:continue
        assert f.get('energy_court_generated')
        suffix='a' if f['asset_id']=='energy_shrubs_a_v1' else 'b'
        end=f['rect'][1]+f['rect'][3]
        f.update(asset_id=shrub_ids[suffix],rect=[2288,end-8,12,8],
                 blocks_movement=False,blocks_sight=False,west_service_roads_repositioned=True)
        modified.append(f['id'])
    write(ART/'manifest.json',dict(schema=2,version='west-service-roads-v3',assets=assets))
    catalog=ROOT/'scripts/presentation/prop_catalog.gd';text=catalog.read_text(encoding='utf-8')
    entry='\t"'+MANIFEST+'",\n'
    if entry.strip() not in text:catalog.write_text(text.replace('\n]\n','\n'+entry+']\n',1),encoding='utf-8')
    assert {k:v for k,v in before.items() if k not in ['fixtures','floor_regions']} == \
           {k:v for k,v in after.items() if k not in ['fixtures','floor_regions']}
    assert before['floor_regions']==[s for s in after['floor_regions'] if not s.get('west_service_roads_generated')]
    assert [f for f in before['fixtures'] if f['id'] not in modified]== \
           [f for f in after['fixtures'] if f['id'] not in modified and not f.get('west_service_roads_generated')]
    assert sha(path)==disk,'Map changed while preparing roads; reload latest saved map.'
    write(DOC/'before-map.json',before);write(path,after);write(DOC/'after-map.json',after)
    sources=sorted({a['texture'] for a in assets})
    write(DOC/'registration.json',dict(added_floor_ids=floors,added_fixture_ids=added,
         modified_decor_ids=modified,definition_ids=[a['id'] for a in assets],
         paving_rects=[[2120,1820,160,2280],[1300,3180,980,220]],
         retained_manual_curbs=True,source_pngs=[dict(path=p,sha256=sha(ROOT/p.removeprefix('res://'))) for p in sources],
         saved_map_sha256=sha(path),new_blocking_objects=False))
    print('Paved marked west spine and cross connection; retained saved floors and hand-positioned south curbs.')

if __name__=='__main__':restore()
