"""Continue the red-marked workshop streets, retaining all saved architecture."""
from copy import deepcopy
from math import ceil
from tools.register_valve_maintenance import ROOT, read, write, sha

DOC=ROOT/'docs/art/workshop-roads-v4'
ART=ROOT/'art/props/workshop_roads_v4'
MANIFEST='res://art/props/workshop_roads_v4/manifest.json'

def restore():
    path=ROOT/'data/rooms/r04.json';disk=sha(path)
    before=read(path);after=deepcopy(before)
    assert not any(f.get('workshop_roads_generated') for f in before['fixtures'])
    paving=dict(asset_id='loading_floor_v1',manifest='res://art/environment/loading_yard_v1/manifest.json',
                tile_size=[240,240],tile_origin=[2140,3980],natural_ground=False,workshop_roads_generated=True)
    plan=[('north-avenue',[880,820,3400,120]),('central-spine',[2120,940,160,880]),
          ('workshop-one-front',[700,1700,1420,120]),('workshop-two-front',[2280,1740,2000,160])]
    floors=[]
    for key,rect in plan:
        s=dict(paving,id='workshop-road-'+key,rect=rect)
        after['floor_regions'].append(s);floors.append(s['id'])
    original=read(ROOT/'art/props/energy_south_road_v2/manifest.json')['assets'][0]
    assets=[];definitions={};added=[]
    def asset(length):
        if length in definitions:return definitions[length]
        a=deepcopy(original);width=min(1938,ceil(1938*length/600))
        a.update(id=f'workshop_road_curb_{length}_v4',name=f'车间连接道路 · 石质路缘 {length}',
                 region=[24,195,width,80],world_size=[length,20],render_size=[length,20],
                 footprint_world_size=[length,12],ground_rect=[0,32,width,48],editor_hidden=length!=600)
        assets.append(a);definitions[length]=a['id'];return a['id']
    def curb(key,x,y,length):
        offset=0
        while offset<length:
            part=min(600,length-offset)
            f=dict(id=f'workshop-road-{key}-{offset}',asset_id=asset(part),
                   rect=[x+offset,y,part,12],render_size=[part,20],draw_depth=0,
                   blocks_movement=False,blocks_sight=False,exterior_shell=True,workshop_roads_generated=True)
            after['fixtures'].append(f);added.append(f['id']);offset+=part
    # Existing workshop/canteen facades define the remaining road sides.
    curb('chess-front-curb',880,812,560)
    curb('yard-front-west-curb',2060,812,460)
    curb('yard-front-east-curb',2720,812,460)
    curb('workshop-one-front-curb',880,1708,1240)
    curb('south-east-west-curb',2280,1892,1240)
    curb('south-east-east-curb',3660,1892,620)
    assert {k:v for k,v in before.items() if k not in ['fixtures','floor_regions']}== \
           {k:v for k,v in after.items() if k not in ['fixtures','floor_regions']}
    assert before['floor_regions']==[s for s in after['floor_regions'] if not s.get('workshop_roads_generated')]
    assert before['fixtures']==[s for s in after['fixtures'] if not s.get('workshop_roads_generated')]
    write(ART/'manifest.json',dict(schema=2,version='workshop-roads-v4',assets=assets))
    catalog=ROOT/'scripts/presentation/prop_catalog.gd';text=catalog.read_text(encoding='utf-8')
    entry='\t"'+MANIFEST+'",\n'
    if entry.strip() not in text:catalog.write_text(text.replace('\n]\n','\n'+entry+']\n',1),encoding='utf-8')
    assert sha(path)==disk,'Map changed while preparing workshop streets; reread latest saved map.'
    write(DOC/'before-map.json',before);write(path,after);write(DOC/'after-map.json',after)
    write(DOC/'registration.json',dict(added_floor_ids=floors,added_fixture_ids=added,
          paving_rects=[r for _,r in plan],definition_ids=[a['id'] for a in assets],
          source_png=original['texture'],source_sha256=original['sha256'],
          yard_entry_gap=[2520,820,200,0],tree_court_entry_gap=[3520,1900,140,0],
          existing_map_content_unchanged=True,new_blocking_objects=False,saved_map_sha256=sha(path)))
    print('Paved four marked workshop streets, with matching stone edging and open courtyard connections.')

if __name__=='__main__':restore()
