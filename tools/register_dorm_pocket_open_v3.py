"""Install the approved open-state art while retaining the accepted closed state."""
import copy
import hashlib
import json
import os
import shutil
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path(r'C:\Users\gst20\.codex\generated_images\01a12f0d-4fc4-7dd2-b6a0-d189a674ef6e\exec-8046b55c-2bf0-416e-8eab-e8748b97f315.png')
folder=ROOT/'art/architecture/dorm_door_v1'
target=folder/'open-stone-components-v3.png'
shutil.copyfile(SOURCE,target)
sha=hashlib.sha256(target.read_bytes()).hexdigest()
path=folder/'manifest.json'
original=path.read_bytes()
manifest=json.loads(original)
baseline=json.loads((ROOT/'docs/art/dorm-pocket-open-v3/baseline-manifest.json').read_text(encoding='utf-8'))
old={a['id']:a for a in baseline['assets']}
new_regions={'dorm_open_north_cap_v3':[621,176,78,184],
             'dorm_open_south_cap_v3':[621,659,78,185],
             'dorm_open_north_stone_v3':[699,176,82,184],
             'dorm_open_south_stone_v3':[699,659,82,185],
             'dorm_open_threshold_v3':[1001,24,145,979]}
common=dict(texture='res://art/architecture/dorm_door_v1/open-stone-components-v3.png',texture_size=[1536,1024],sha256=sha,source_kind='built-in-imagegen-original-png',runtime_size_limit=1024)
manifest['assets']=[a for a in manifest['assets'] if a['id'] not in new_regions]
for asset_id,region in new_regions.items():
    manifest['assets'].append(dict(common,id=asset_id,region=region,editor_hidden=True))

def patch(asset,destination,ground=False):
    p=dict(asset=asset,source=[0,0,1,1],destination=destination,rotation_quarters=3)
    if ground:p['ground_level']=True
    return p

patches=[patch('dorm_open_north_cap_v3',[0,0,14,20]),
         patch('dorm_open_south_cap_v3',[186,0,14,20]),
         patch('dorm_open_threshold_v3',[14,0,172,20],True),
         patch('dorm_open_north_stone_v3',[-14,-2,14,24]),
         patch('dorm_open_south_stone_v3',[200,-2,14,24])]
for a in manifest['assets']:
    if a['id'] not in ('doorway_dorm_side_open_v1','doorway_dorm_side_closed_v1'):continue
    p=a['door_presentation']
    # The open rendering is the ONLY state-specific production change.
    p['door_open_patches']=copy.deepcopy(patches)
    p['open_design']='stone-return-open-v3'
    assert p['door_closed_patches']==old[a['id']]['door_presentation']['door_closed_patches']
    assert p['closed_visual_solid_parts']==old[a['id']]['door_presentation']['closed_visual_solid_parts']
    assert p['visual_solid_parts']==old[a['id']]['door_presentation']['visual_solid_parts']
    if a['id']=='doorway_dorm_side_open_v1':
        a.update(common,region=new_regions['dorm_open_threshold_v3'],ground_rect=[0,0,145,979])
        a['name']='宿舍宽口移门 · 全开 / 石材收边'

actual={a['id']:a for a in manifest['assets']}
closed_id='doorway_dorm_side_closed_v1'
closed=copy.deepcopy(actual[closed_id]); accepted=copy.deepcopy(old[closed_id])
for state in (closed,accepted):
    state['door_presentation'].pop('door_open_patches',None)
    state['door_presentation'].pop('open_design',None)
assert closed==accepted,'Accepted closed appearance or rules changed'
for p in accepted['door_presentation']['door_closed_patches']:
    assert actual[p['asset']]==old[p['asset']],'Closed component changed'
    texture=ROOT/actual[p['asset']]['texture'].removeprefix('res://')
    assert hashlib.sha256(texture.read_bytes()).hexdigest()==actual[p['asset']]['sha256']
manifest['version']='dorm-pocket-open-v3'
assert path.read_bytes()==original,'Concurrent manifest edit detected'
temporary=path.with_suffix('.open-v3.tmp')
temporary.write_bytes((json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
os.replace(temporary,path)
record=dict(generator='built-in-imagegen',source=str(SOURCE),asset=str(target),sha256=sha,regions=new_regions,
            prompt='docs/art/dorm-pocket-open-v3/prompt.txt',concept='docs/art/dorm-pocket-open-concept-v3/concept.png',
            closed_state='accepted-v2-identical',closed_patches=accepted['door_presentation']['door_closed_patches'],
            aperture=200,clear_span=172,usable_body_anchor_span=72,map_rewritten=False)
(ROOT/'docs/art/dorm-pocket-open-v3/registration.json').write_bytes((json.dumps(record,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
print(json.dumps(record,ensure_ascii=False))
