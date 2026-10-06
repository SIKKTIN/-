from pathlib import Path
import json,hashlib,shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v27';runtime=doc/'runtime';runtime.mkdir(exist_ok=True)
names=['p57-local-repair-left.png','p57-local-repair-right.png','p57-1200-walls-hud.png','p57-960-walls-hud.png','p57-1200-walls-unobscured.png','p57-960-walls-unobscured.png','p57-editor-components-final.png','p57-runtime-components-final.png','p57-1200-planner-fps-layer.png','p57-960-planner-fps-layer.png','p57-wall-fps-native-1200.json','p57-wall-fps-native-960.json','p57-wall-local-native.json','p57-editor-components-native.json','p57-access-access-headless-1200.json']
for name in names: shutil.copy2(root/'docs/tests'/name,runtime/name)
reports={}
for name in names:
    if not name.endswith('.json'):continue
    j=json.loads((runtime/name).read_text(encoding='utf-8-sig'));checks=j.get('checks',{})
    assert all(checks.values()) and not j.get('failed',[]),name
    if isinstance(j.get('passed'),bool):assert j['passed'],name
    elif 'total' in j:assert j['passed']==j['total'],name
    reports[name]={'checks':len(checks),'passed':True}
visual={'reference':'user-first-version-reference.png','source_sha256':'030e32dafb5064c21d4838867ce280ca8b71a264acfcb5e01f6348eab13ef2ff','images':names[:10],'reports':reports,'art_judgment':'p57-visual-review.md','delivery_state':'candidate for independent producer review; not human approval'}
(doc/'p57-visual-evidence.json').write_text(json.dumps(visual,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
own_docs=['README.md','build-manifest.py','prepare-qa.py','native-preview.gd','publish-candidate.py','check-contract.py','freeze-delivery.py','interface.json','source-review.json','contract-check.json','native-preview.png','native-detail.png','native-preview.json','icons-qa.json','native-icons-visible.json','native-preview.stdout.log','native-preview.stderr.log','p57-visual-review.md','p57-visual-evidence.json','user-first-version-reference.png']
files=[root/'art/architecture/v27/manifest.json',root/'art/editor/v07/manifest.json']+sorted((root/'art/editor/v07/icons').glob('*.tres'))+[doc/n for n in own_docs]+[runtime/n for n in names]
manifest_sha=hashlib.sha256(files[0].read_bytes()).hexdigest()
delivery={'version':'architecture-v27-20261006-'+manifest_sha[:12],'entry':'art/architecture/v27/manifest.json','files':[{'path':p.relative_to(root).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files],'existing_texture':{'path':'art/architecture/v24/cafeteria_portal_v24.png','sha256':visual['source_sha256']},'new_production_png':0,'components':10,'source_unchanged':True,'runtime_checks':sum(v['checks'] for v in reports.values()),'aesthetic_review':'first-version comparison by art director; independent producer pending'}
(doc/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'version':delivery['version'],'files':len(files),'checks':delivery['runtime_checks']}))
