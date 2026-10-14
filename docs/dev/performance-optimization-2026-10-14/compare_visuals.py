from pathlib import Path
from PIL import Image
import numpy as np,json
base=Path(__file__).resolve().parent
results={}
for p in base.glob('source-*.png'):
 other=base/p.name.replace('source-','baked-',1)
 if not other.exists():continue
 # Focus on the world area; the HUD is not being rescaled by this change.
 with Image.open(p) as im:a=np.asarray(im.convert('RGB'),dtype=np.int16)[160:600,:1080]
 with Image.open(other) as im:b=np.asarray(im.convert('RGB'),dtype=np.int16)[160:600,:1080]
 delta=np.abs(a-b)
 results[p.stem.removeprefix('source-')]={'mean_rgb_error':float(delta.mean()),'pixels_with_channel_error_over20_percent':float((delta.max(axis=2)>20).mean()*100)}
source=json.loads((base/'source-registration.json').read_text(encoding='utf8'))
baked=json.loads((base/'baked-registration.json').read_text(encoding='utf8'))
report={'world_and_player_geometry_identical':source==baked,'views':results,'note':'These are quality diagnostics, not exact-pixel equivalence: lower-resolution mipmapped pixels intentionally differ. Frozen screenshot FPS badges are not performance samples.'}
(base/'visual-comparison.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report))
