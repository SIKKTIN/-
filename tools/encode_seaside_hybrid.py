from pathlib import Path
from PIL import Image
import json,hashlib,statistics
root=Path(__file__).resolve().parents[1]
doc=root/'docs/art/seaside-hybrid-v3'
record=json.loads((doc/'recording.json').read_bytes())
validation=json.loads((doc/'validation.json').read_bytes())
profile=json.loads((doc/'performance-final.json').read_bytes())
assert all(validation['checks'].values())
assert record['shader_emission_verified'] and profile['passed']
stamps=record['timestamps_ms']
paths=[doc/'frames'/f'{i:03d}.png' for i in range(len(stamps))]
assert len(paths)>60 and all(p.exists() for p in paths)
durations=[max(1,b-a) for a,b in zip(stamps,stamps[1:])]
durations.append(round(statistics.median(durations)))
frames=[Image.open(p) for p in paths]
frames[0].save(doc/'hybrid-water.webp',format='WEBP',save_all=True,append_images=frames[1:],duration=durations,loop=0,quality=87,method=4)
with Image.open(doc/'hybrid-water.webp') as clip:assert clip.n_frames==len(paths)
for f in frames:f.close()
sim=record['simulation_timestamps']
assert .94<(sim[-1]-sim[0])/((stamps[-1]-stamps[0])/1000)<1.06
delivery={'status':'validated and profiled independent hybrid sea prototype',
          'performance':profile,'checks':validation['checks'],
          'visible_spray_pixels':record['visible_spray_pixels'],
          'native_recording':str(doc/'hybrid-water.webp'),'recording_seconds':sum(durations)/1000,
          'recording_frames':len(paths),'recording_simulation_rate':(sim[-1]-sim[0])/((stamps[-1]-stamps[0])/1000),
          'map_writes_by_this_task':False,
          'map_hash_observed_at_start':'6008672c5875b2881931602ac7abf2cd752758452ce9e1ae2fb819911a07439f',
          'map_hash_at_delivery':hashlib.sha256((root/'data/rooms/r04.json').read_bytes()).hexdigest(),
          'scope':'Prototype files only; map was concurrently edited elsewhere and has not been restored or overwritten by this task.'}
(doc/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Only delete the exact native intermediate frames produced by this recorder.
for p in paths:p.unlink()
try:(doc/'frames').rmdir()
except OSError:pass
print('Packaged',len(paths),'native frames;',sum(durations)/1000,'seconds;',record['visible_spray_pixels'],'visible spray pixels.')
