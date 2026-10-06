from pathlib import Path
import json,hashlib,shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v29';runtime=doc/'runtime';runtime.mkdir(exist_ok=True)
names=[]
for width in [1200,960]:
    for kind in ['runtime','editor']:
        for side in ['left','right']:names.append(f'p62-{width}-{kind}-t-{side}.png')
    names.append(f'p62-{width}-t-palette.png')
    names.extend([f'p62-{width}-t-native.json',f'p62-{width}-native.json',f'p62-{width}-architecture-native.json'])
for name in names:shutil.copy2(root/'docs/tests'/name,runtime/name)
reports={}
for name in names:
    if not name.endswith('.json'):continue
    j=json.loads((runtime/name).read_text(encoding='utf-8-sig'))
    assert all(j['checks'].values()) and not j.get('failed',[]) and j['passed']==j['total'],name
    reports[name]=j['total']
preserved={}
for v in ['v24','v25','v26','v27','v28']:
    d=json.loads((root/('docs/art/architecture-'+v+'/delivery.json')).read_text(encoding='utf-8-sig'))
    preserved[v]=all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in d['files'])
assert all(preserved.values())
visual=dict(reference='user-kitchen-T-reference.png',reports=reports,total=sum(reports.values()),images=[n for n in names if n.endswith('.png')],review='p62-visual-review.md',old_deliveries_unchanged=preserved,state='art director actual review complete; independent producer review pending')
(doc/'p62-visual-evidence.json').write_text(json.dumps(visual,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
own=['README.md','prompt.json','interface.json','source-review.json','native-preview.png','native-detail.png','native-preview.json','native-icons-visible.json','icons-qa.json','native-preview.stdout.log','native-preview.stderr.log','build-manifest.py','prepare-qa.py','native-preview.gd','publish-candidate.py','freeze-delivery.py','p62-visual-review.md','p62-visual-evidence.json','user-kitchen-T-reference.png']
files=[root/'art/architecture/v29/manifest.json',root/'art/architecture/v29/cafeteria_t_master_v29.png',root/'art/editor/v09/manifest.json']+sorted((root/'art/editor/v09/icons').glob('*.tres'))+[doc/n for n in own]+[runtime/n for n in names]
manifest_sha=hashlib.sha256(files[0].read_bytes()).hexdigest()
d={'version':'architecture-v29-20261007-'+manifest_sha[:12],'entry':'art/architecture/v29/manifest.json','files':[dict(path=p.relative_to(root).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files],'production_png_count':1,'components':2,'icons':2,'runtime_checks':sum(reports.values()),'old_deliveries_unchanged':preserved,'review':'complete new T actual topology/style comparison, not resource-only approval'}
(doc/'delivery.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'version':d['version'],'files':len(files),'runtime_checks':d['runtime_checks']}))
