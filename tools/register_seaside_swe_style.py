"""Keep the generated RGBA source unchanged and register its native atlas bounds."""
from pathlib import Path
from PIL import Image
import hashlib
import json
import shutil

root=Path(__file__).resolve().parents[1]
source=Path('C:/Users/gst20/.codex/generated_images/01a12de1-9940-7ee0-a361-bbf0f88d4681/exec-db626386-a8a1-485d-aa15-cc82b5cd394d.png')
out=root/'art/fx/seaside_swe_style_v2'
out.mkdir(parents=True,exist_ok=True)
target=out/'pier.png'
if target.exists(): assert target.read_bytes()==source.read_bytes()
else: shutil.copy2(source,target)
with Image.open(source) as im:
    assert im.mode=='RGBA'
    assert im.getchannel('A').getextrema()[0]==0
    size=list(im.size)
manifest={'version':'seaside-swe-style-v2','source_kind':'built-in-imagegen-original-RGBA',
          'pier':{'texture':'res://art/fx/seaside_swe_style_v2/pier.png','region':[175,50,676,1440],
                  'runtime_size_limit':1024,'source_dimensions':size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()},
          'water':'computed depth, velocity, height gradients and advected foam; no sea image',
          'grass':'res://art/environment/factory_v46/floor_atlas.png / [1024,512,512,512]',
          'scope':'independent style prototype; live map unchanged',
          'map_sha256_at_start':hashlib.sha256((root/'data/rooms/r04.json').read_bytes()).hexdigest()}
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assert target.read_bytes()==source.read_bytes()
print('Registered original transparent pier; source bytes and alpha preserved.')
