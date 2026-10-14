"""Pave the south public walkway using the existing outdoor tile material."""
from copy import deepcopy
from tools.register_valve_maintenance import ROOT, read, write, sha

DOC = ROOT / 'docs/art/energy-south-road-v1'
ROAD = 'energy-court-south-through-road'
APPROACH = 'energy-court-valve-south-approach'

def restore():
    path = ROOT/'data/rooms/r04.json'
    disk = sha(path)
    before = read(path)
    after = deepcopy(before)
    assert not any(s.get('id')==APPROACH for s in before['floor_regions'])
    road = next(s for s in after['floor_regions'] if s['id']==ROAD)
    material = dict(asset_id='loading_floor_v46',
                    manifest='res://art/environment/factory_v46/manifest.json',
                    tile_size=[320,320],tile_origin=[0,0],natural_ground=False,
                    energy_south_road_generated=True)
    road.update(material,rect=[2100,3960,3020,140])
    for key in ['polygon','outline_asset_id','outline_manifest','outline_width','edge_feather']:
        road.pop(key,None)
    approach = dict(material,id=APPROACH,rect=[3834,3757,192,203])
    # Road paving is above adjacent lawn edges, with one shared tile registration.
    after['floor_regions'].remove(road)
    after['floor_regions'].extend([road,approach])
    assert {k:v for k,v in before.items() if k!='floor_regions'} == \
           {k:v for k,v in after.items() if k!='floor_regions'}
    assert [s for s in before['floor_regions'] if s['id']!=ROAD] == \
           [s for s in after['floor_regions'] if s['id'] not in [ROAD,APPROACH]]
    assert sha(path)==disk,'Map changed during road preparation; retry from latest saved map.'
    write(DOC/'before-map.json',before)
    write(path,after)
    write(DOC/'after-map.json',after)
    write(DOC/'registration.json',dict(changed_floor_ids=[ROAD],added_floor_ids=[APPROACH],
          road_rect=road['rect'],approach_rect=approach['rect'],physical_changes=False,
          material=material,saved_map_sha256=sha(path)))
    print('Paved south road and valve approach; all other saved map content retained.')

if __name__=='__main__':restore()
