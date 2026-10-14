"""Apply measured visual refinements to the latest saved cafeteria layout."""
from restore_cafeteria_v2 import *

if __name__=='__main__':
    definitions,_=register()
    path=ROOT/'data/rooms/r04.json'; raw=path.read_bytes(); initial=sha(path); m=read(path)
    assert m['cafeteria_restoration_version']==2
    f={r['id']:r for r in m['fixtures']}
    assert f['canteen-counter']['rect'][1] in [2080,2100]
    f['canteen-counter']['rect'][1]=2100
    counter=f['canteen-counter'];a=definitions['cafeteria_counter_v2']
    food=f['canteen-redesign-service-food']
    food['rect'][1]=counter['rect'][1]+counter['rect'][3]-a['world_size'][1]+29
    food['draw_depth']=counter['rect'][1]+counter['rect'][3]+1
    f['canteen-return']['rect'][0:2]=[2000,2330]
    next(s for s in m['resident_staff'] if s['id']=='canteen-cook')['position']=[1515,2040]
    m['cafeteria']['pickup_label']=[1410,2110]
    m['cafeteria']['return_label']=[1995,2295]
    for s in m['architecture']['wall_surfaces']:
        if s.get('grid_tile_asset','').endswith('_v2') and s['grid_tile_asset'].startswith('cafeteria_'):
            s['coping_elevation']=80
    if 'canteen-covered-bins' not in f:
        m['fixtures'].append(dict(id='canteen-covered-bins',asset_id='cafeteria_covered_bins_v2',rect=[2005,2390,60,28],blocks_movement=True,blocks_sight=False))
    assert sha(path)==initial,'Map changed during refinement.'
    (DOC/'refinement-input.json').write_bytes(raw)
    write(path,m);write(DOC/'restoration-output.json',m)
    write(DOC/'refinement-output.json',m)
    registration=read(DOC/'layout-registration.json')
    registration['changed_fixture_ids']=sorted(set(registration['changed_fixture_ids'])|{'canteen-covered-bins'})
    registration['after_sha256']=sha(path)
    write(DOC/'layout-registration.json',registration)
    print('Refined cook/counter depth, return zone and 80-unit coping elevation.')
