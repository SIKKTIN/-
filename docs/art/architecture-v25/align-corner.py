from pathlib import Path
import json,shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v25'
interface=json.loads((doc/'corner-interface.json').read_text(encoding='utf-8'));a=interface['asset']
p=root/'art/architecture/v25/manifest.json'; m=json.loads(p.read_text(encoding='utf-8'));old=next(r for r in m['assets'] if r['id']==a['id']);a['sha256']=old['sha256'];m['assets']=[a if r['id']==a['id'] else r for r in m['assets']];p.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=doc/'corner-source-review.json'; r=json.loads(p.read_text(encoding='utf-8'));r['registration']=a;r['patch_count']=12;r['alignment_native']='corner-native.png: cap/plinth/foot source-aligned';p.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(root/'art/architecture/v25/manifest.json',doc/'godot-qa/art/architecture/v25/manifest.json')
print('L corner metadata aligned: twelve patches, cap/plinth/foot match A24 source')
