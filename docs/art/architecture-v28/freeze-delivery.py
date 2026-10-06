from pathlib import Path
import json,hashlib,shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v28';runtime=doc/'runtime';runtime.mkdir(exist_ok=True)
names=['p58-local-repair-left.png','p58-local-repair-right.png','p58-1200-walls-hud.png','p58-960-walls-hud.png','p58-1200-walls-unobscured.png','p58-960-walls-unobscured.png','p58-editor-components-final.png','p58-runtime-components-final.png','p58-1200-planner-fps-layer.png','p58-960-planner-fps-layer.png','p58-wall-fps-native-1200.json','p58-wall-fps-native-960.json','p58-wall-local-native.json','p58-editor-components-native.json','p58-preservation.json']
for name in names:shutil.copy2(root/'docs/tests'/name,runtime/name)
reports={}
for name in names:
    if not name.endswith('.json'):continue
    j=json.loads((runtime/name).read_text(encoding='utf-8-sig'))
    assert all(j['checks'].values()) and not j.get('failed',[]) and j['passed']==j['total'],name
    reports[name]=j['total']
visual=dict(reference='user-circled-corner-reference.png',reports=reports,total=sum(reports.values()),images=names[:10],review='p58-visual-review.md',state='art director actual review complete; independent producer review pending')
(doc/'p58-visual-evidence.json').write_text(json.dumps(visual,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
own=['README.md','prompt.json','interface.json','source-review.json','native-preview.png','native-detail.png','native-preview.json','native-icons-visible.json','icons-qa.json','native-preview.stdout.log','native-preview.stderr.log','build-manifest.py','prepare-qa.py','native-preview.gd','publish-candidate.py','freeze-delivery.py','p58-visual-review.md','p58-visual-evidence.json','user-circled-corner-reference.png']
files=[root/'art/architecture/v28/manifest.json',root/'art/architecture/v28/cafeteria_turn_master_v28.png',root/'art/editor/v08/manifest.json']+sorted((root/'art/editor/v08/icons').glob('*.tres'))+[doc/n for n in own]+[runtime/n for n in names]
manifest_sha=hashlib.sha256(files[0].read_bytes()).hexdigest()
d={'version':'architecture-v28-20261006-'+manifest_sha[:12],'entry':'art/architecture/v28/manifest.json','files':[dict(path=p.relative_to(root).as_posix(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files],'production_png_count':1,'components':4,'icons':4,'runtime_checks':sum(reports.values()),'old_deliveries_unchanged':json.loads((doc/'source-review.json').read_text())['old_deliveries_unchanged'],'review':'complete continuous L actual style comparison, not resource-only approval'}
(doc/'delivery.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'version':d['version'],'files':len(files),'runtime_checks':d['runtime_checks']}))
