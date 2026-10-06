from pathlib import Path
import json,hashlib,shutil,re
from PIL import Image
import numpy as np
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v32';qa=doc/'godot-qa';icons=root/'art/editor/v12/icons';icons.mkdir(parents=True,exist_ok=True)
for p in (qa/'art/editor/v12/icons').glob('*.tres'):(icons/p.name).write_text(re.sub(r' uid="uid://[^\"]+"','',p.read_text(encoding='utf-8-sig')),encoding='utf-8')
for n in ['native-preview.png','native-detail.png','native-preview.json','icons-qa.json']:shutil.copy2(qa/n,doc/n)
assert not (doc/'native-preview.stderr.log').read_text(encoding='utf-8-sig').strip()
pixels=np.asarray(Image.open(doc/'native-preview.png').convert('RGB')).astype(int);visible=[]
for i in range(6):
    x=146+(i%3)*400;y=514+(i//3)*165;b=pixels[y:y+128,x:x+128];bg=pixels[y-2,x-50];n=int((abs(b-bg).max(2)>12).sum());visible.append(dict(icon=i+1,nonbackground_pixels=n,visible=n>600))
assert all(c['visible'] for c in visible),visible
(doc/'native-icons-visible.json').write_text(json.dumps(dict(checked=6,all_visible=True,checks=visible,basis='actual GPU MeshTexture pixels; includes narrow longV20 icons, threshold600'),indent=2)+'\n',encoding='utf-8')
m=json.loads((root/'art/architecture/v32/manifest.json').read_text(encoding='utf-8-sig'));assets={a['id']:a for a in m['assets']};checks={}
for cross in [20,24]:
    t=assets['cafeteria_t_20_v32' if cross==20 else 'cafeteria_t_v32'];stem=t['assembly_patches'][-1];v=assets['cafeteria_wall_v_l'+('_20' if cross==20 else '')+'_v32'];base=v['assembly_patches'][0];scale=base['destination'][3]/base['source'][3]
    checks[str(cross)+'_same_source']=t['texture']==v['texture'] and t['sha256']==v['sha256']
    checks[str(cross)+'_same_cross_uv']=stem['source'][0]==base['source'][0] and stem['source'][2]==base['source'][2] and stem['destination'][2]==base['destination'][2]
    checks[str(cross)+'_same_longitudinal_scale']=abs(stem['destination'][3]/stem['source'][3]-scale)<1e-10
    checks[str(cross)+'_phase_continuity']=abs(stem['source'][1]+stem['source'][3]-(base['source'][1]+56/scale))<1e-10
    checks[str(cross)+'_round_contact']=len(t['assembly_patches'])==9 and t['inner_arc_bounds'][0]==[48,21,8,3]
assert all(checks.values())
old={}
for version in ['v24','v25','v26','v27','v28','v29','v30','v31']:
    d=json.loads((root/('docs/art/architecture-'+version+'/delivery.json')).read_text(encoding='utf-8-sig'));old[version]=all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in d['files'])
assert all(old.values())
png=root/'art/architecture/v32/rounded_wall_master_v32.png';source=Path(r'C:/Users/gst20/.codex/generated_images/01a10697-9228-7c00-906b-43051bade1e0/exec-3286cd4c-7b85-4b97-b695-0164f7be5a0d.png');assert png.read_bytes()==source.read_bytes();im=Image.open(png);alpha=np.asarray(im)[:,:,3];assert alpha[800,250]==0 and alpha[800,750]==0
(doc/'source-review.json').write_text(json.dumps(dict(new_production_png_count=1,source=m['master_texture'],sha256=m['master_sha256'],raw_imagegen_copy_matches=True,size=list(im.size),checks=checks,old_deliveries_unchanged=old,lower_notches_alpha0=True,background_alpha_note='source low-alpha fringe exists outside; inheritedsafe_edges removesbelow0.03 and attenuateslowalpha, actual native review checks no apron. PNG never painted/thresholded.',review='same source T and entire V, new curved connection; actual P65 full-wall review pending'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(components=6,icons_actual_visible=True,source_checks=len(checks),old_unchanged=old)))

