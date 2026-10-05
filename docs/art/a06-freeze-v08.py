import json,hashlib
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[2];doc=root/'docs/art';folder=root/'art/props/prison_v08'
# Normalize only this task's new text files. PNGs and all prior project files stay byte-identical.
texts=[p for p in doc.glob('a06-*')if p.is_file()and p.suffix in ['.json','.py','.cjs','.txt','.html']]
texts += [p for p in (doc/'a06-native-v08').glob('*')if p.is_file()and p.name in ['check.gd','metadata.json','project.godot']]
texts += [folder/'manifest.json']
for p in texts:
    b=p.read_bytes();lf=b.replace(b'\r\n',b'\n')
    if b!=lf:p.write_bytes(lf)
inputs=json.loads((doc/'a06-image-inputs-v08.json').read_text(encoding='utf-8'))
points={'cell_bars':(250,420),'workbench':(800,535),'communal_table':(800,655),'notice_board':(800,770),'bunk_bed':(500,1240)}
samples=[]
for a in inputs['assets']:
    if a['id']in points:
        im=Image.open(a['source']);p=points[a['id']]
        samples.append({'id':a['id'],'canvas_sample':list(p),'alpha':im.getpixel(p)[3]})
with(doc/'a06-transparent-samples-v08.json').open('w',encoding='utf-8',newline='\n')as f:f.write(json.dumps({'scope':'source raw RGBA hole samples; not gameplay LOS','samples':samples,'passed':all(s['alpha']==0 for s in samples)},ensure_ascii=False,indent=2)+'\n')
manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
paths=[root/a['texture'].replace('res://','')for a in manifest['assets']]+[folder/'manifest.json']
paths += [doc/name for name in ['a06-imagegen-prompts-v08.json','a06-image-inputs-v08.json','a06-source-license-v08.json','a06-integration-v08.txt','a06-visual-review-v08.txt','a06-qa-resources-v08.json','a06-qa-native-v08.json','a06-qa-browser-v08.json','a06-transparent-samples-v08.json','a06-resource-preview-1280x720-v08r3.png','a06-resource-preview-960x540-v08r3.png']]
rows=[{'path':p.relative_to(root).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}for p in paths]
digest=hashlib.sha256('\n'.join(r['path']+' '+r['sha256']for r in rows).encode()).hexdigest()
text_rows=[p for p in paths if p.suffix!='.png']
lf_ok=all(b'\r\n'not in p.read_bytes()for p in text_rows)
reports={name:json.loads((doc/name).read_text(encoding='utf-8'))['passed']for name in ['a06-qa-resources-v08.json','a06-qa-native-v08.json','a06-qa-browser-v08.json','a06-transparent-samples-v08.json']}
delivery={'schema':1,'version':'prison-art-v08-20261005-'+digest[:12],'bundle_fingerprint_sha256':digest,'task_id':'3fd8d3a2-e0da-4c04-b2d8-3b0640a94391','manifest':'art/props/prison_v08/manifest.json','png_count':7,'raw_png_policy':'built-in imagegen original output copied byte-identically; no pixel edits','text_encoding':'UTF-8 LF','selected_text_lf':lf_ok,'files':rows,'qa':reports,'scope':'Resources, source registration and small-size composite previews. P23 actual R04 integration separately reviewed.'}
with(doc/'a06-delivery-v08.json').open('w',encoding='utf-8',newline='\n')as f:f.write(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'version':delivery['version'],'file_count':len(rows),'text_lf':lf_ok,'qa':reports}))
if not lf_ok or not all(reports.values()):raise SystemExit(1)
