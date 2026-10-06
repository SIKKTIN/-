from pathlib import Path
import json,hashlib,shutil,re
from PIL import Image
import numpy as np
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v31';qa=doc/'godot-qa';icons=root/'art/editor/v11/icons';icons.mkdir(parents=True,exist_ok=True)
for p in (qa/'art/editor/v11/icons').glob('*.tres'):(icons/p.name).write_text(re.sub(r' uid="uid://[^\"]+"','',p.read_text(encoding='utf-8-sig')),encoding='utf-8')
for n in ['native-preview.png','native-detail.png','native-preview.json','icons-qa.json']:shutil.copy2(qa/n,doc/n)
assert not (doc/'native-preview.stderr.log').read_text(encoding='utf-8-sig').strip()
pixels=np.asarray(Image.open(doc/'native-preview.png').convert('RGB')).astype(int);visible=[]
for i in range(2):
    x=266+i*620;b=pixels[545:673,x:x+128];bg=pixels[513,203+i*620];n=int((abs(b-bg).max(2)>12).sum());visible.append(dict(icon=i+1,nonbackground_pixels=n,visible=n>1500))
assert all(c['visible'] for c in visible)
(doc/'native-icons-visible.json').write_text(json.dumps(dict(checked=2,all_visible=True,checks=visible,basis='actual GPU visible MeshTexture pixels'),indent=2)+'\n',encoding='utf-8')
m=json.loads((root/'art/architecture/v31/manifest.json').read_text(encoding='utf-8-sig'));v=json.loads((root/'art/architecture/v27/manifest.json').read_text(encoding='utf-8-sig'));v={a['id']:a for a in v['assets']}
checks={};metrics={}
for a in m['assets']:
    cross=a['cross_width_world'];old=v['cafeteria_wall_v_l'+('_20' if cross==20 else '')+'_v27'];stem=a['assembly_patches'][-1];base=old['assembly_patches'][0]
    period=old['tile_period_world'];run=245/period
    end_x=stem['source'][0]+stem['source'][2];continuation_x=base['source'][0]+56*run
    checks[a['id']+'_same_source']=a['texture']==old['texture'] and a['sha256']==old['sha256']
    checks[a['id']+'_same_perspective']=stem['transpose']==base['transpose'] and stem['mirror_x']==base['mirror_x'] and stem['modulate']==base['modulate']
    checks[a['id']+'_same_cross']=stem['source'][1]==base['source'][1] and stem['source'][3]==base['source'][3] and stem['destination'][2]==base['destination'][2]
    checks[a['id']+'_same_run_scale']=abs(stem['source'][2]/56-run)<1e-10
    checks[a['id']+'_seam_continuous']=abs(end_x-continuation_x)<1e-10
    neck=a['assembly_patches'][1]
    checks[a['id']+'_contact_previous_cycle_tail']=abs(neck['source'][0]-(232+(period-3)*run))<1e-10 and abs(neck['source'][0]+neck['source'][2]-477)<1e-10
    checks[a['id']+'_contact_same_cross_perspective']=neck['transpose']==base['transpose'] and neck['source'][1]==base['source'][1] and neck['source'][3]==base['source'][3] and neck['destination']==[56,21,cross,3]
    metrics[str(cross)]=dict(stub_source_width=stem['source'][2],boundary_source_x=end_x,next_old_patch_source_x=continuation_x,boundary_phase=56,next_seam_local_y=24+period)
assert all(checks.values())
old={}
for version in ['v24','v25','v26','v27','v28','v29','v30']:
    d=json.loads((root/('docs/art/architecture-'+version+'/delivery.json')).read_text(encoding='utf-8-sig'));old[version]=all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in d['files'])
assert all(old.values())
(doc/'source-review.json').write_text(json.dumps(dict(new_production_png_count=0,source=m['master_texture'],sha256=m['master_sha256'],checks=checks,metrics=metrics,old_deliveries_unchanged=old,no_shader_regrade=True,review='strict same UV mapping; actual complete wall visual review pending'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(components=2,icons_actual_visible=True,source_checks=len(checks),old_unchanged=old)))

