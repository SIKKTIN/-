"""Add a narrow, editable lawn and outer safety line to the valve compound."""
from copy import deepcopy
from tools.register_valve_maintenance import ROOT, read, write, sha

DOC = ROOT / 'docs/art/valve-perimeter-v2'
FLOOR_ID = 'energy-court-platform-green-edge'
OLD_OUTLINE = [(3740,3030),(4100,3030),(4280,3255),(4280,3705),
               (4100,3930),(3740,3930),(3560,3705),(3560,3255)]

def restore():
    path = ROOT / 'data/rooms/r04.json'
    disk = sha(path)
    before = read(path)
    assert before.get('valve_maintenance_version') == 'editable-v1'
    assert not any(s.get('valve_perimeter_generated') for s in before['ground_details'])
    after = deepcopy(before)
    grass = next(s for s in after['floor_regions'] if s['id'] == FLOOR_ID)
    # The base overlays the centre. A south notch keeps the stairs' approach paved.
    rect = [3635,3150,590,590]
    outline = [(3770,3150),(4090,3150),(4225,3285),(4225,3585),
               (4090,3740),(4002,3740),(4002,3675),(3858,3675),
               (3858,3740),(3770,3740),(3635,3585),(3635,3285)]
    grass.update(asset_id='grass_base_v46',
                 manifest='res://art/environment/factory_v46/manifest.json',
                 natural_ground=True,rect=rect,tile_origin=[0,0],tile_size=[470,470],
                 polygon=[[(x-rect[0])/rect[2],(y-rect[1])/rect[3]] for x,y in outline],
                 valve_perimeter_generated=True)
    for key in ['outline_asset_id','outline_manifest','outline_width','edge_feather','tint']:
        grass.pop(key,None)
    old_segments = {(tuple(OLD_OUTLINE[i]),tuple(OLD_OUTLINE[(i+1)%8])) for i in range(8)}
    def old_line(s):
        return s.get('kind')=='line' and s.get('energy_court_generated',False) and \
            (tuple(s.get('from',[])),tuple(s.get('to',[]))) in old_segments
    removed = [s for s in after['ground_details'] if old_line(s)]
    assert len(removed)==8
    after['ground_details'] = [s for s in after['ground_details'] if not old_line(s)]
    points = [(3763,3133),(4097,3133),(4242,3278),(4242,3592),
              (4097,3757),(4026,3757)]
    segments = list(zip(points,points[1:])) + [
        ((3834,3757),(3763,3757)),((3763,3757),(3618,3592)),
        ((3618,3592),(3618,3278)),((3618,3278),(3763,3133))]
    added = []
    for i,(a,b) in enumerate(segments):
        s = dict(id=f'valve-perimeter-yellow-{i}',kind='line',
                 color='#e2b642',opacity=.96,width=8,
                 **{'from':list(a),'to':list(b)},valve_perimeter_generated=True)
        after['ground_details'].append(s)
        added.append(s['id'])
    # No props, doors, roof masks, or collision rules change.
    assert {k:v for k,v in before.items() if k not in ['floor_regions','ground_details']} == \
           {k:v for k,v in after.items() if k not in ['floor_regions','ground_details']}
    assert [s for s in before['floor_regions'] if s['id']!=FLOOR_ID] == \
           [s for s in after['floor_regions'] if s['id']!=FLOOR_ID]
    assert sha(path)==disk, 'Map changed while preparing perimeter; rerun from latest map.'
    write(DOC/'before-map.json',before)
    write(path,after)
    write(DOC/'after-map.json',after)
    write(DOC/'registration.json',dict(changed_floor_id=FLOOR_ID,
          removed_ground_details=removed,added_ground_detail_ids=added,
          grass_world_outline=outline,entrance_gap=[3834,3757,192,0],
          source_material='res://art/environment/factory_v46/manifest.json#grass_base_v46',
          saved_map_sha256=sha(path),physical_changes=False))
    print('Updated narrow grass perimeter and 9 outer yellow segments; all physical objects retained.')

if __name__=='__main__':restore()
