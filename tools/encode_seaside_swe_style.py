"""Package native Godot captures, measured timings and unchanged art sources."""
from pathlib import Path
from PIL import Image
import hashlib
import json

root=Path(__file__).resolve().parents[1]
doc=root/'docs/art/seaside-swe-style-v2'
report=json.loads((doc/'performance.json').read_bytes())
assert all(report['checks'].values()), report['checks']
paths=[doc/'frames'/f'{i:03d}.png' for i in range(60)]
assert all(p.exists() for p in paths)
frames=[Image.open(p) for p in paths]
frames[0].save(doc/'style-water.webp',format='WEBP',save_all=True,append_images=frames[1:],duration=100,loop=0,quality=85,method=4)
with Image.open(doc/'style-water.webp') as video: assert video.n_frames==60
for f in frames: f.close()
manifest=json.loads((root/'art/fx/seaside_swe_style_v2/manifest.json').read_bytes())
assert hashlib.sha256((root/'art/fx/seaside_swe_style_v2/pier.png').read_bytes()).hexdigest()==manifest['pier']['sha256']
delivery={'status':'game-style sea prototype adapted and profiled','measurements':report,
          'recording':str(doc/'style-water.webp'),'recording_seconds':6,
          'recording_origin':'native Godot framebuffer; 0.1 simulated second per capture',
          'art_tool':'built-in image_gen; original transparent PNG retained byte for byte',
          'pier':str(root/'art/fx/seaside_swe_style_v2/pier.png'), 'prompt':str(doc/'pier-prompt.txt'),
          'style_changes':['muted gray-green sea','soft low-gloss highlights from solved height gradients',
                           'warm broken foam brush clusters controlled by transported foam field',
                           'game grass and shrubs','game player sprite','weathered wooden pier sprite'],
          'performance_changes':['shared textures and cached mipmaps','polynomial brush hash avoids per-pixel sine noise',
                                 'simulation stays on GPU; no per-frame CPU texture readback'],
          'map_unchanged':hashlib.sha256((root/'data/rooms/r04.json').read_bytes()).hexdigest()==manifest['map_sha256_at_start'],
          'scope':'independent prototype; live map and game scene unchanged; whole-map performance not yet measured'}
(doc/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for p in paths: p.unlink()
try:(doc/'frames').rmdir()
except OSError:pass
print('Packaged native style recording and measured GPU/memory report.')
