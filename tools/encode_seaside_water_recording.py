"""Encode Godot-rendered capture frames; no generated artwork is edited."""
from pathlib import Path
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs/art/seaside-water-demo-v1'
paths=[DOC/'frames'/f'{i:03d}.png' for i in range(60)]
assert all(p.is_file() for p in paths)
frames=[Image.open(p) for p in paths]
frames[0].save(DOC/'water-demo.webp',format='WEBP',save_all=True,append_images=frames[1:],duration=100,loop=0,quality=78,method=4)
with Image.open(DOC/'water-demo.webp') as recording:assert recording.n_frames==60
before=Image.open(DOC/'frame-start.png');after=Image.open(DOC/'frame-later.png')
def changed(rect):
    x,y,x2,y2=rect
    return sum(before.getpixel((i,j))!=after.getpixel((i,j)) for j in range(y,y2) for i in range(x,x2))
report=json.loads((DOC/'checks.json').read_bytes())
report['checks']['water_region_really_animates']=changed((30,100,240,480))>10000
report['checks']['deck_core_remains_fixed']=changed((425,235,535,278))==0
report['recording']={'path':str(DOC/'water-demo.webp'),'frames':60,'duration_seconds':6,'origin':'native Godot framebuffer capture','format':'animated WebP'}
assert all(report['checks'].values()),report
(DOC/'checks.json').write_text(json.dumps(report,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
for frame in frames:frame.close()
before.close();after.close()
# Delete only the exact files this capture created; never recursively delete.
for p in paths:p.unlink()
try:(DOC/'frames').rmdir()
except OSError:pass
print('Encoded six-second native animation; water changes and fixed deck verified.')
