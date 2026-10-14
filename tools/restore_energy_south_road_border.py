"""Restore the concept's raised pale coping and lawn behind the south road."""
from copy import deepcopy
from tools.register_valve_maintenance import ROOT, read, write, sha

DOC = ROOT/'docs/art/energy-south-road-v2'
ART = ROOT/'art/props/energy_south_road_v2'
MANIFEST = 'res://art/props/energy_south_road_v2/manifest.json'
CURB = 'energy_south_stone_curb_v2'
ROAD = 'energy-court-south-through-road'
APPROACH = 'energy-court-valve-south-approach'

def restore():
    path = ROOT/'data/rooms/r04.json'
    disk = sha(path)
    before = read(path)
    assert not any(f.get('energy_south_border_generated') for f in before['fixtures'])
    after = deepcopy(before)
    source = ROOT/'art/architecture/equipment_secure_v1/wall.png'
    # The original stone cap and baked lower shadow are used as an atlas region.
    # No source pixels are edited, and no new collision wall is introduced.
    asset = dict(id=CURB,name='能源区南侧道路 · 浅色石质路缘',
                 texture='res://art/architecture/equipment_secure_v1/wall.png',
                 texture_size=[1983,793],region=[24,195,1938,80],
                 world_size=[600,20],render_size=[600,20],
                 ground_rect=[0,32,1938,48],footprint_world_size=[600,12],
                 elevation_world=8,render_mode='projected_prop',proportion_locked=False,
                 blocking=False,interactive=False,shadow_baked=True,
                 alpha_core_shader='res://art/props/exercise_yard_v54/clean_cutout.gdshader',
                 runtime_size_limit=768,editor_subcategory='furnishings',
                 source_kind='existing-original-png-atlas-region',sha256=sha(source))
    write(ART/'manifest.json',dict(schema=2,version='energy-south-road-v2',assets=[asset]))
    catalog = ROOT/'scripts/presentation/prop_catalog.gd'
    text = catalog.read_text(encoding='utf-8')
    entry = '\t"'+MANIFEST+'",\n'
    if entry.strip() not in text:
        catalog.write_text(text.replace('\n]\n','\n'+entry+']\n',1),encoding='utf-8')
    road = next(s for s in after['floor_regions'] if s['id']==ROAD)
    road.update(asset_id='loading_floor_v1',manifest='res://art/environment/loading_yard_v1/manifest.json',
                tile_size=[240,240],tile_origin=[2140,3980],rect=[2140,3980,2980,120])
    approach = next(s for s in after['floor_regions'] if s['id']==APPROACH)
    approach.update(asset_id=road['asset_id'],manifest=road['manifest'],
                    tile_size=road['tile_size'],tile_origin=road['tile_origin'],rect=[3834,3757,192,223])
    floors=[]
    # Keep the two real entrances paved through the narrow rear grass verge.
    for i,(x,end) in enumerate([(2140,2850),(3130,3834),(4026,5120)]):
        s=dict(id=f'energy-south-road-rear-verge-{i}',asset_id='grass_base_v46',
               manifest='res://art/environment/factory_v46/manifest.json',
               rect=[x,3940,end-x,32],tile_size=[470,470],tile_origin=[0,0],
               natural_ground=True,energy_south_border_generated=True)
        after['floor_regions'].append(s);floors.append(s['id'])
    added=[]
    x=2140
    while x<5120:
        width=min(600,5120-x)
        f=dict(id=f'energy-south-road-stone-curb-{len(added)}',asset_id=CURB,
               rect=[x,3972,width,12],render_size=[width,20],draw_depth=0,
               blocks_movement=False,blocks_sight=False,exterior_shell=True,
               energy_south_border_generated=True)
        after['fixtures'].append(f);added.append(f['id']);x+=width
    excluded=['floor_regions','fixtures']
    assert {k:v for k,v in before.items() if k not in excluded}=={k:v for k,v in after.items() if k not in excluded}
    assert before['fixtures']==[f for f in after['fixtures'] if not f.get('energy_south_border_generated')]
    assert [s for s in before['floor_regions'] if s['id'] not in [ROAD,APPROACH]]== \
           [s for s in after['floor_regions'] if s['id'] not in [ROAD,APPROACH]+floors]
    assert sha(path)==disk,'Saved map changed during border preparation.'
    write(DOC/'before-map.json',before)
    write(path,after)
    write(DOC/'after-map.json',after)
    write(DOC/'registration.json',dict(changed_floor_ids=[ROAD,APPROACH],added_floor_ids=floors,
          added_fixture_ids=added,curb_asset_id=CURB,curb_span=[2140,3972,2980,12],
          source_png='res://art/architecture/equipment_secure_v1/wall.png',
          source_sha256=sha(source),physical_changes=False,saved_map_sha256=sha(path)))
    print('Restored continuous stone curb, rear grass verge, gray road tiles and paved entry joints.')

if __name__=='__main__':restore()
