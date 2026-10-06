from pathlib import Path
import json,hashlib
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v26'
p=doc/'interface.json';d=json.loads(p.read_text(encoding='utf-8'));d['status']='native and actual game/style/14visible icons passed; producer formal review pending';d['native_draw']='native-preview.png / stderr0';d['icon_draw']='native-icons-visible.json /14actual meshes';p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
d=json.loads((root/'art/architecture/v26/manifest.json').read_text(encoding='utf-8'))
assert len(d['assets'])==14 and len(set(a['texture'] for a in d['assets']))==1
assert all(isinstance(a['assembly_patches'],list) and a['assembly_patches'] for a in d['assets'])
bad=[]
for a in d['assets']:
    for patch in a['assembly_patches']:
        s=patch['source'];v=patch['destination']
        if s[0]<0 or s[1]<0 or s[0]+s[2]>1536.001 or s[1]+s[3]>1024.001 or min(v[2:])<=0:bad.append(a['id'])
assert not bad
p=doc/'source-review.json';sr=json.loads(p.read_text(encoding='utf-8'))
for version in ['v24','v25']:
    prior=json.loads((root/('docs/art/architecture-'+version+'/delivery.json')).read_text(encoding='utf-8-sig'))
    sr['old_delivery_unchanged'][version]=all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in prior['files'])
assert all(sr['old_delivery_unchanged'].values())
sr['positive_regions_valid']=True;sr['native_icons_actual_visible']=14
p.write_text(json.dumps(sr,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'assets':14,'all_positive_inbounds':True,'old_unchanged':sr['old_delivery_unchanged']}))
