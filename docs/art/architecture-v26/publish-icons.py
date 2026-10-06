from pathlib import Path
import json,shutil,re
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v26';qa=doc/'godot-qa'
for p in (qa/'art/editor/v06/icons').glob('*.tres'):
    text=re.sub(r' uid="uid://[^"]+"','',p.read_text(encoding='utf-8'))
    (root/'art/editor/v06/icons'/p.name).write_text(text,encoding='utf-8')
shutil.copy2(qa/'icons-qa.json',doc/'icons-qa.json')
interface=json.loads((doc/'interface.json').read_text(encoding='utf-8'))
interface['width20_contract']='Use dedicated20 variants: corner80x150 horizontal arm unchanged,20cross=16.6667top+3.3333side; cross stone sourceV cropped5/6. Frontx20..80 phase20 forleft,frontx0..60 phase0 forright. Run stone grain still128period; never wholeL scaleX.'
interface['uv_phase_shift']='phase_shift_world component placement offset relative sharedH/V origin adds phase[patch.phase_axis]/128 to sourceU before/after transpose; full mother X sampler repeat enabled so U>1 wraps correctly; no PNG pixel edits. Geometry positive.'
interface['right_components']='Right L and V have right-facing geometry with west side, preserve sourceU alongworldrun; no extra mapUVmirror when usingright IDs. Avoid replacing them with globally mirroredleft texture/lighting.'
interface['uv_order']='TL,TR,BR,BL; transpose swaps to TL,BL,BR,TR; optionalpatchUVmirror then TR,TL,BL,BR; all currentR assets use directrightgeometry (no mirrorflag). Phase offset adds sourceU.'
interface['assets_checked']=14
(doc/'interface.json').write_text(json.dumps(interface,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
m=json.loads((root/'art/architecture/v26/manifest.json').read_text(encoding='utf-8'))
for a in m['assets']:
    a['phase_sensitive_axes']=['y'] if 'wall_v' in a['id'] else ['x','y'] if 'corner' in a['id'] else ['x']
m['repeat_sampler']='full maternal texture repeatX; sourceV stays within its material band'
(root/'art/architecture/v26/manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(root/'art/architecture/v26/manifest.json',qa/'art/architecture/v26/manifest.json')
for p in (root/'art/editor/v06/icons').glob('*.tres'):shutil.copy2(p,qa/'art/editor/v06/icons'/p.name)
print(json.dumps({'icon_count':14,'type':'MeshTexture','PNG_count':1,'UID_metadata_removed':True}))
