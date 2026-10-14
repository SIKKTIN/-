"""Compose existing original wall art into a taller north wall without moving colliders."""
from pathlib import Path
from copy import deepcopy
import hashlib, json, os

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/art/cafeteria-north-wall-v3'
MAP = ROOT / 'data/rooms/r04.json'
MANIFEST = ROOT / 'art/architecture/cafeteria_v2/manifest.json'

def encoded(value):
    return (json.dumps(value, ensure_ascii=False, indent='\t')+'\n').encode('utf-8')

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    map_raw, manifest_raw = MAP.read_bytes(), MANIFEST.read_bytes()
    m, catalog = json.loads(map_raw), json.loads(manifest_raw)
    definitions = {a['id']: a for a in catalog['assets']}
    if any(s.get('grid_tile_asset','').endswith('_north_v3') for s in m['architecture']['wall_surfaces']):
        print('North wall refinement already installed.'); return
    room = next(r for r in m['visibility_rooms'] if r['id']=='canteen')
    foot_y = room['rect'][1]
    selected = [s for s in m['architecture']['wall_surfaces']
                if s.get('grid_tile_asset','').startswith('cafeteria_')
                and s['grid_tile_asset'].endswith('_v2')
                and m['walls'][int(s['wall_index'])][1:4:2] == [foot_y-100,100]]
    assert len(selected)>20, 'Unexpected cafeteria wall geometry'
    created = {}
    for surface in selected:
        old_id = surface['grid_tile_asset']
        new_id = old_id.removesuffix('_v2')+'_north_v3'
        if new_id not in created:
            a = deepcopy(definitions[old_id])
            a.update(id=new_id, name=a['name'].split(' · ')[0]+' · 石质压顶上墙',
                     authoring_set='cafeteria-north-v3', world_size=[40,120], render_size=[40,120],
                     collision_parts=[[0,100,40,20]], connection_tag=a['connection_tag'].replace('v2','north-v3'))
            a['grid_tile']['rows']=6
            patches=[]
            for patch in a['assembly_patches']:
                p=deepcopy(patch)
                d=p['destination']
                if d==[0,0,40,100]:
                    # Remove the thin metal top rim and retain plaster/tile face.
                    p['source'][1]=238; p['source'][3]=254
                    p['destination']=[0,20,40,100]
                    patches.append(p)
                elif d[1]==20 and d[3]==80:
                    p['destination'][3]=100;patches.append(p)
                # The original top corner's thin metal triangle is replaced below.
            index=int(old_id.split('_h_')[1].split('_')[0]) if '_h_' in old_id and 'short' not in old_id else 0
            cap_x=49+(index%8)*259.25
            patches.append(dict(texture_asset='workshop_wall_h_00',source=[cap_x,202,259.25,66],
                                destination=[0,0,40,20],role='stone_coping'))
            if 'corner_nw' in old_id or 'corner_ne' in old_id:
                right='corner_ne' in old_id
                patches.append(dict(texture_asset='workshop_wall_h_00',source=[cap_x,202,66,66],
                                    destination=[20 if right else 0,0,20,20],rotation_quarters=1,
                                    clip_polygon=[[1,0],[1,1],[0,1]] if right else [[0,0],[1,1],[0,1]],
                                    role='stone_corner_return'))
            a['assembly_patches']=patches;created[new_id]=a
        i=int(surface['wall_index']);w=m['walls'][i]
        w[1]-=20;w[3]+=20
        surface.update(grid_tile_asset=new_id,collision_parts=[[0,100,40,20]],coping_elevation=100)
    header_id='cafeteria_north_door_coping_v3'
    cap=deepcopy(definitions['cafeteria_wall_h_00_v2'])
    cap.update(id=header_id,name='食堂上门楣 · 连续石质压顶',world_size=[180,20],render_size=[180,20],
               authoring_set='cafeteria-north-v3',render_mode='architecture_tiled_facade',blocking=False,
               collision_parts=[],assembly_patches=[])
    cap.pop('grid_tile',None);cap.pop('connections',None);cap.pop('connection_tag',None)
    for x in range(0,180,40):
        width=min(40,180-x)
        cap['assembly_patches'].append(dict(texture_asset='workshop_wall_h_00',source=[49,202,259.25*width/40,66],
                                          destination=[x,0,width,20],role='stone_coping'))
    created[header_id]=cap
    fixtures={f['id']:f for f in m['fixtures']};changed=[]
    for access_id in ['cafeteria-entry','cafeteria-entry-east']:
        fixture=next(f for f in m['fixtures'] if f.get('access_id')==access_id)
        x,y,width,height=fixture['rect'];left=x+width/2-90
        fixture['rotation_door_visual_rect']=[left,foot_y-100,180,100]
        next(g for g in m['access_doors'] if g['id']==access_id)['rotation_door_visual_rect']=[left,foot_y-100,180,100]
        changed.append(fixture['id'])
        id=access_id+'-stone-header-v3'
        m['fixtures'].append(dict(id=id,asset_id=header_id,rect=[left,foot_y-120,180,20],
                                  render_size=[180,20],blocks_movement=False,blocks_sight=False,draw_depth=foot_y+4))
        changed.append(id)
    for id in ['canteen-redesign-window-0','canteen-redesign-window-1']:
        f=fixtures[id];x,y,width,height=f['rect'];new_width=110
        f['rect']=[x+(width-new_width)/2,foot_y-94,new_width,height*new_width/width]
        changed.append(id)
    catalog['assets'].extend(created.values())
    new_map,new_manifest=encoded(m),encoded(catalog)
    assert MAP.read_bytes()==map_raw and MANIFEST.read_bytes()==manifest_raw, 'Files changed during preparation'
    (OUT/'map-before.json').write_bytes(map_raw);(OUT/'map-after.json').write_bytes(new_map)
    (OUT/'manifest-before.json').write_bytes(manifest_raw)
    for path,data in [(MANIFEST,new_manifest),(MAP,new_map)]:
        temp=path.with_suffix(path.suffix+'.north-wall.tmp');temp.write_bytes(data);os.replace(temp,path)
    (OUT/'registration.json').write_bytes(encoded(dict(wall_indices=[int(s['wall_index']) for s in selected],
        changed_fixture_ids=changed,added_asset_ids=list(created),input_sha256=hashlib.sha256(map_raw).hexdigest(),
        output_sha256=hashlib.sha256(new_map).hexdigest(),approach='Native assembly of unchanged original PNG textures')))
    print(f'Updated {len(selected)} north wall tiles, two door headers and two windows.')

if __name__=='__main__':main()
