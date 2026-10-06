from pathlib import Path
import json,hashlib,shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v32';runtime=doc/'runtime';runtime.mkdir(exist_ok=True)
names=sorted(p.name for p in (root/'docs/tests').glob('p65-*') if p.suffix in ['.png','.json'])
assert len([n for n in names if n.endswith('.png')])>=12
reports={}
for name in names:
    shutil.copy2(root/'docs/tests'/name,runtime/name)
    if name.endswith('.json'):
        j=json.loads((runtime/name).read_text(encoding='utf-8-sig'))
        if 'checks' in j:
            checks=j['checks'];ok=all(checks.values()) if isinstance(checks,dict) else all(c.get('passed',False) for c in checks)
            assert ok and not j.get('failed',[]),name
            reports[name]=j.get('total',len(checks))
        assert j.get('passed',True) is not False,name
preserved={}
for v in ['v24','v25','v26','v27','v28','v29','v30','v31']:
    d=json.loads((root/('docs/art/architecture-'+v+'/delivery.json')).read_text(encoding='utf-8-sig'))
    preserved[v]=all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in d['files'])
assert all(preserved.values())
(doc/'p65-visual-evidence.json').write_text(json.dumps(dict(reports=reports,images=[n for n in names if n.endswith('.png')],old_deliveries_unchanged=preserved,review='p65-visual-review.md',approved_reference='approved-concept-c.png',state='actual visual review complete, independent producer review pending'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
own=['README.md','prompt.json','interface.json','source-review.json','native-preview.png','native-detail.png','native-preview.json','native-icons-visible.json','icons-qa.json','native-preview.stdout.log','native-preview.stderr.log','build-manifest.py','prepare-qa.py','native-preview.gd','publish-candidate.py','freeze-delivery.py','p65-visual-review.md','p65-visual-evidence.json','approved-concept-c.png']
files=[root/'art/architecture/v32/manifest.json',root/'art/architecture/v32/rounded_wall_master_v32.png',root/'art/editor/v12/manifest.json']+sorted((root/'art/editor/v12/icons').glob('*.tres'))+[doc/n for n in own]+[runtime/n for n in names]
manifest_sha=hashlib.sha256(files[0].read_bytes()).hexdigest()
d=dict(version='architecture-v32-20261007-'+manifest_sha[:12],entry='art/architecture/v32/manifest.json',files=[dict(path=p.relative_to(root).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files],production_png_count=1,components=6,icons=6,old_deliveries_unchanged=preserved,review='approved C same-height curved junction and same-source completeV, actual default/mirror junctions and two sizes; technical checks do not establish aesthetics')
(doc/'delivery.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'version':d['version'],'files':len(files),'reports':reports}))


