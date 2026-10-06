from pathlib import Path
import json,hashlib
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v27'
m=json.loads((root/'art/architecture/v27/manifest.json').read_text(encoding='utf-8'))
i=json.loads((doc/'interface.json').read_text(encoding='utf-8'))
checks={}
checks['no_new_png']=not list((root/'art/architecture/v27').glob('*.png'))
checks['same_original_source']=all(a['texture']==m['master_texture'] and a['sha256']==m['master_sha256'] for a in m['assets'])
checks['source_sha']=hashlib.sha256((root/'art/architecture/v24/cafeteria_portal_v24.png').read_bytes()).hexdigest()==m['master_sha256']
checks['positive_bounded_geometry']=all(p['destination'][2]>0 and p['destination'][3]>0 and p['destination'][0]>=0 and p['destination'][1]>=0 and p['destination'][0]+p['destination'][2]<=a['render_size'][0]+1e-6 and p['destination'][1]+p['destination'][3]<=a['render_size'][1]+1e-6 for a in m['assets'] for p in a['assembly_patches'])
checks['no_full_png_phase_shift']=all('phase_axis' not in p for a in m['assets'] for p in a['assembly_patches'])
window=i['source_repeat_window']
checks['vertical_sampling_in_clean_window']=all(window[0]-1e-6<=p['source'][0] and p['source'][0]+p['source'][2]<=window[0]+window[2]+1e-6 and p['source'][1]==window[1] and p['source'][3]==window[3] for a in m['assets'] for p in a['assembly_patches'] if p.get('transpose'))
checks['original_wings_not_registered_as_new']=all('wing' not in a['id'] and 'jamb' not in a['id'] and 'lintel' not in a['id'] for a in m['assets'])
checks['all_icons_exist']=all((root/a['editor_icon'].removeprefix('res://')).is_file() for a in m['assets'])
checks['actual_gpu_icons_visible']=json.loads((doc/'native-icons-visible.json').read_text())['all_visible']
for v in ['v24','v25','v26']:
    old=json.loads((root/('docs/art/architecture-'+v+'/delivery.json')).read_text(encoding='utf-8-sig'))
    checks['frozen_'+v+'_unchanged']=all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in old['files'])
result={'passed':all(checks.values()),'checks':checks,'scope':'local source/geometry/resource verification; aesthetic approval requires actual P57 comparison'}
(doc/'contract-check.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result))
assert result['passed']
