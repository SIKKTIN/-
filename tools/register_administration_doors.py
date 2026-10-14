"""Reuse the proven workshop door assembly for duty and office entrances.

No PNG pixels or workshop definitions are changed. Open/closed variants keep
the same frame, art extent, silhouette collision and foreground depth rules.
"""
from copy import deepcopy
from pathlib import Path
import hashlib, json

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/administration-doors-v2'
def read(p): return json.loads(p.read_bytes())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,data):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')

def register():
    source=ROOT/'art/architecture/workshop_door_v2/manifest.json'
    originals={a['id']:a for a in read(source)['assets']}
    assets=[]
    for room,label in [('duty','值班室'),('office','办公室')]:
        for state,pose in [('open','全开'),('closed','关闭')]:
            a=deepcopy(originals[f'doorway_workshop_{state}_v2'])
            a.update(id=f'doorway_{room}_{state}_v2',name=f'{label}钢门 · {pose}',
                     footprint_world_size=[180,20],reused_from=f'doorway_workshop_{state}_v2')
            a['door_presentation'].update(door_art=f'doorway_{room}_open_v2',door_art_closed=f'doorway_{room}_closed_v2')
            assets.append(a)
            if room=='duty':
                alias=deepcopy(a)
                alias.update(id=f'doorway_duty_{state}_v1',replacement_asset=a['id'],editor_hidden=True)
                assets.append(alias)
    write(ROOT/'art/architecture/administration_doors_v2/manifest.json',dict(schema=2,version='administration-doors-v2',assets=assets))
    path=ROOT/'data/rooms/r04.json';raw=path.read_bytes();data=json.loads(raw)
    fixture={a['id']:a for a in data['fixtures']};gate=next(a for a in data['access_doors'] if a['id']=='office-entry')
    assert fixture['campus-duty']['rect']==[3900,680,180,20]
    assert fixture['campus-office-entry-visual']['rect']==[4360,680,180,20]
    assert gate['kind']=='locked' and gate['initial_closed']
    fixture['campus-duty'].update(asset_id='doorway_duty_open_v2',open_asset='doorway_duty_open_v2',
                                 closed_asset='doorway_duty_closed_v2',render_size=[180,120])
    fixture['campus-office-entry-visual'].update(asset_id='doorway_office_closed_v2',open_asset='doorway_office_open_v2',
                                 closed_asset='doorway_office_closed_v2',render_size=[180,120])
    gate.update(asset_id='doorway_office_closed_v2',interaction_point=[4450,737])
    # Keep name plates clear of the steel header and swinging leaves and
    # register outside the room mask so the closed roof cannot hide them.
    fixture['duty-sign']['rect']=[4085,665,90,25.6451612903226]
    fixture['office-entry-sign']['rect']=[4570,665,95,1]
    assert path.read_bytes()==raw,'Saved map changed during registration; rebase before applying.'
    DOC.mkdir(parents=True,exist_ok=True)
    (DOC/'before-map.json').write_bytes(raw)
    write(path,data)
    (DOC/'after-map.json').write_bytes(path.read_bytes())
    write(DOC/'registration.json',dict(source_manifest=str(source),source_sha256=sha(source),
        source_png='res://art/architecture/workshop_door_v2/components.png',
        source_png_sha256=sha(ROOT/'art/architecture/workshop_door_v2/components.png'),
        definitions=[a['id'] for a in assets],changed_fixture_ids=['campus-duty','campus-office-entry-visual','duty-sign','office-entry-sign'],
        input_map_sha256=hashlib.sha256(raw).hexdigest(),output_map_sha256=sha(path),
        duty_default_state='open; closed variant available in editor',office_default_state='locked; keys and lockpicking use office-entry',
        map_permissions_preserved=True,png_modified=False))
    print('Registered two-state duty/office door assemblies on the latest saved R04.')

if __name__=='__main__': register()
