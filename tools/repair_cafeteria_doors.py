"""Use the existing equipment-room fronts and warehouse side-door assembly."""
from pathlib import Path
from copy import deepcopy
import json,os,hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/cafeteria-doors-v3'
def encode(value):return (json.dumps(value,ensure_ascii=False,indent='\t')+'\n').encode('utf-8')
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    path=ROOT/'data/rooms/r04.json';manifest=ROOT/'art/architecture/cafeteria_v2/manifest.json'
    raw,art_raw=path.read_bytes(),manifest.read_bytes();m,catalog=json.loads(raw),json.loads(art_raw)
    fixtures={f['id']:f for f in m['fixtures']};defs={a['id']:a for a in catalog['assets']}
    if fixtures['cafeteria-entry-visual45']['asset_id']=='doorway_energy_closed_v1':
        print('Cafeteria door repair already installed.');return
    changed=[];gates=[]
    for id in ['cafeteria-entry','cafeteria-entry-east','cafeteria-south']:
        g=next(g for g in m['access_doors'] if g['id']==id)
        f=next(f for f in m['fixtures'] if f.get('access_id')==id)
        x,y,w,h=g['rect'];visual=[x+w/2-90,y+h-120,180,120]
        g.update(asset_id='doorway_energy_closed_v1',rotation_door_visual_rect=visual)
        f.update(asset_id='doorway_energy_closed_v1',open_asset='doorway_energy_open_v1',
                 closed_asset='doorway_energy_closed_v1',render_size=[180,120],rotation_door_visual_rect=visual)
        gates.append(id);changed.append(f['id'])
    # This side opening keeps its original free-passage behavior, as warehouse doors do.
    f=fixtures['campus-life-west-meal'];x,y,w,h=f['rect']
    f.update(asset_id='doorway_workshop_open_v2',open_asset='doorway_workshop_open_v2',
             closed_asset='doorway_workshop_closed_v2',render_size=[180,120],rotation_quarters=3,
             rotation_door_visual_rect=[x,y+h/2-90,120,180])
    changed.append(f['id'])
    removed=['cafeteria-entry-stone-header-v3','cafeteria-entry-east-stone-header-v3']
    m['fixtures']=[f for f in m['fixtures'] if f['id'] not in removed]
    # Fit the lower facade to the same 120-high frame, keeping its solid foot line.
    wall_indices=[];created={}
    for surface in m['architecture']['wall_surfaces']:
        old_id=surface.get('grid_tile_asset','');i=int(surface['wall_index']);wall=m['walls'][i]
        if not old_id.startswith('cafeteria_') or not old_id.endswith('_v2'):continue
        straight=wall[1]==2420 and wall[3]==100 and '_h_' in old_id
        corner=wall[1]==2400 and old_id in ['cafeteria_corner_sw_v2','cafeteria_corner_se_v2']
        if not (straight or corner):continue
        new_id=old_id.replace('_v2','_south_v3')
        if new_id not in created:
            if straight:
                a=deepcopy(defs[old_id.replace('_v2','_north_v3')])
            else:
                a=deepcopy(defs[old_id]);north='cafeteria_corner_nw_north_v3' if 'sw' in old_id else 'cafeteria_corner_ne_north_v3'
                a['assembly_patches']=deepcopy(defs[north]['assembly_patches'])
            a.update(id=new_id,name=defs[old_id]['name'].split(' · ')[0]+' · 统一门框高度',authoring_set='cafeteria-doors-v3')
            a['world_size']=[40,120];a['render_size']=[40,120];a['grid_tile']['rows']=6
            a['connections']=deepcopy(defs[old_id]['connections'])
            a['connection_tag']=defs[old_id]['connection_tag'].replace('v2','doors-v3')
            a['collision_parts']=deepcopy(surface['collision_parts'])
            if straight:
                for part in a['collision_parts']:part[1]+=20
            created[new_id]=a
        surface['grid_tile_asset']=new_id;surface['coping_elevation']=100
        if straight:
            wall[1]-=20;wall[3]+=20
            for part in surface['collision_parts']:part[1]+=20
        wall_indices.append(i)
    catalog['assets'].extend(created.values())
    new_map,new_art=encode(m),encode(catalog)
    assert path.read_bytes()==raw and manifest.read_bytes()==art_raw,'Map changed during preparation'
    (OUT/'map-before.json').write_bytes(raw);(OUT/'map-after.json').write_bytes(new_map)
    (OUT/'manifest-before.json').write_bytes(art_raw)
    for target,data in [(manifest,new_art),(path,new_map)]:
        temp=target.with_suffix(target.suffix+'.doors.tmp');temp.write_bytes(data);os.replace(temp,target)
    (OUT/'registration.json').write_bytes(encode(dict(changed_fixture_ids=changed,removed_fixture_ids=removed,
        gate_ids=gates,wall_indices=wall_indices,added_asset_ids=list(created),
        map_input_sha256=hashlib.sha256(raw).hexdigest(),map_output_sha256=hashlib.sha256(new_map).hexdigest(),
        reference_front='doorway_energy_*_v1',reference_side='campus-warehouse-west',new_raster_assets=0)))
    print('Updated three equipment-style front doors, warehouse-style west door and compatible lower facade.')
if __name__=='__main__':main()
