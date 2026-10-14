"""Verify retained closed assets and compare native screenshot pixels."""
import copy
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
baseline=json.loads((ROOT/'docs/art/dorm-pocket-open-v3/baseline-manifest.json').read_text(encoding='utf-8'))
current=json.loads((ROOT/'art/architecture/dorm_door_v1/manifest.json').read_text(encoding='utf-8'))
old={a['id']:a for a in baseline['assets']}
actual={a['id']:a for a in current['assets']}
checks={}
closed_id='doorway_dorm_side_closed_v1'
before=copy.deepcopy(old[closed_id]); after=copy.deepcopy(actual[closed_id])
for asset in (before,after):
    asset['door_presentation'].pop('door_open_patches',None)
    asset['door_presentation'].pop('open_design',None)
checks['closed_asset_metadata_identical']=before==after
for door_id in ('doorway_dorm_side_open_v1',closed_id):
    checks[door_id+'_closed_patches_identical']=actual[door_id]['door_presentation']['door_closed_patches']==old[door_id]['door_presentation']['door_closed_patches']
for part in old[closed_id]['door_presentation']['door_closed_patches']:
    asset_id=part['asset']
    checks[asset_id+'_metadata_identical']=actual[asset_id]==old[asset_id]
    texture=ROOT/actual[asset_id]['texture'].removeprefix('res://')
    checks[asset_id+'_original_png_identical']=hashlib.sha256(texture.read_bytes()).hexdigest()==old[asset_id]['sha256']
before_image=Image.open(ROOT/'docs/art/dorm-pocket-open-v3/closed-before.png').convert('RGBA')
after_image=Image.open(ROOT/'docs/tests/dorm-pocket-open-v3/closed-door-only.png').convert('RGBA')
checks['native_closed_pixels_identical']=before_image.size==after_image.size and before_image.tobytes()==after_image.tobytes()
movement=json.loads((ROOT/'docs/tests/dorm-pocket-open-v3/native-checks.json').read_text(encoding='utf-8'))
checks['native_passage_and_roof_checks_pass']=not movement['failed']
failed=[name for name,passed in checks.items() if not passed]
result={'checks':checks,'failed':failed,'movement_checks':len(movement['checks']),'closed_image_size':before_image.size}
(ROOT/'docs/tests/dorm-pocket-open-v3/closed-preservation.json').write_bytes((json.dumps(result,indent=2)+'\n').encode('utf-8'))
print(json.dumps(result))
assert not failed,failed
