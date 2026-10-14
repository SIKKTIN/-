"""Match the cafeteria north coping to its existing blue steel perimeter."""
from pathlib import Path
import json, os, copy, hashlib
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/art/cafeteria-wall-style-v4'
def encoded(value):return (json.dumps(value,ensure_ascii=False,indent='\t')+'\n').encode('utf-8')
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    path=ROOT/'art/architecture/cafeteria_v2/manifest.json'
    map_path=ROOT/'data/rooms/r04.json'
    raw,map_raw=path.read_bytes(),map_path.read_bytes()
    catalog,m=json.loads(raw),json.loads(map_raw)
    defs={a['id']:a for a in catalog['assets']}
    ids=[]
    trim_height=28.595/301*100
    for a in catalog['assets']:
        if not a['id'].endswith('_north_v3'):continue
        original=defs[a['id'].replace('_north_v3','_v2')]
        a['name']=original['name'].split(' · ')[0]+' · 统一蓝灰包边'
        patches=[]
        body=copy.deepcopy(original['assembly_patches'][0])
        source=body['source']
        x,width=source[0],source[2]
        body['source']=[x,233,width,270]
        body['destination']=[0,trim_height,40,120-trim_height]
        patches.append(body)
        for p in original['assembly_patches'][1:]:
            part=copy.deepcopy(p)
            d=part['destination']
            if d[1]==20 and d[3]==80:
                part['destination']=[d[0],trim_height,d[2],120-trim_height]
                patches.append(part)
        patches.append(dict(source=[x,204,width,28.595],destination=[0,0,40,trim_height],role='blue_steel_coping'))
        if 'corner_nw' in a['id'] or 'corner_ne' in a['id']:
            part=copy.deepcopy(original['assembly_patches'][-1])
            part['destination']=[40-trim_height if 'corner_ne' in a['id'] else 0,0,trim_height,trim_height]
            part['role']='blue_steel_corner_return';patches.append(part)
        a['assembly_patches']=patches
        ids.append(a['id'])
    header=defs['cafeteria_north_door_coping_v3']
    header['name']='食堂上门楣 · 蓝灰金属包边'
    header['assembly_patches']=[]
    for x in range(0,180,40):
        width=min(40,180-x);source_width=120.375*width/40
        header['assembly_patches'].append(dict(source=[38,233,source_width,28.595*(20-trim_height)/trim_height],
            destination=[x,trim_height,width,20-trim_height],role='plaster_lintel'))
        header['assembly_patches'].append(dict(source=[38,204,source_width,28.595],
            destination=[x,0,width,trim_height],role='blue_steel_coping'))
    ids.append(header['id'])
    room=next(r for r in m['visibility_rooms'] if r['id']=='canteen')
    changed=[]
    for f in m['fixtures']:
        if f['id'] in ['canteen-redesign-window-0','canteen-redesign-window-1']:
            f['rect'][1]=room['rect'][1]-103;changed.append(f['id'])
    assert path.read_bytes()==raw and map_path.read_bytes()==map_raw,'Concurrent change during preparation'
    (OUT/'manifest-before.json').write_bytes(raw);(OUT/'map-before.json').write_bytes(map_raw)
    new_manifest,new_map=encoded(catalog),encoded(m)
    for target,data in [(path,new_manifest),(map_path,new_map)]:
        temp=target.with_suffix(target.suffix+'.style.tmp');temp.write_bytes(data);os.replace(temp,target)
    (OUT/'manifest-after.json').write_bytes(new_manifest);(OUT/'map-after.json').write_bytes(new_map)
    (OUT/'registration.json').write_bytes(encoded(dict(changed_asset_ids=ids,changed_fixture_ids=changed,
        trim_height=trim_height,source='Original cafeteria_v2 blue steel coping, identical source height and world scale to south wall',
        map_input_sha=hashlib.sha256(map_raw).hexdigest(),map_output_sha=hashlib.sha256(new_map).hexdigest())))
    print('Matched north and south blue steel coping; removed workshop stone references.')
if __name__=='__main__':main()
