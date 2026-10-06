from pathlib import Path
import json,hashlib,shutil,re
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v26';out=doc/'runtime';out.mkdir(exist_ok=True)
names=['p56-1200-walls-unobscured-final.png','p56-1200-walls-hud-final.png','p56-960-walls-hud-final.png','p56-1200-wall-detail-final.png','p56-1200-right-junctions-final.png','p56-editor-components-final.png','p56-runtime-components-final.png','p56-1200-planner-fps-layer-final.png']
reports=['p56-summary.json','p56-wall-fps-native-1200.json','p56-wall-fps-native-960.json','p56-wall-detail-native.json','p56-access-access-headless-1200.json','p56-editor-headless-1280.json','p56-editor-components-native-final.json']
files=[]
for name in names+reports:
    src=root/'docs/tests'/name;dst=out/name;shutil.copy2(src,dst)
    files.append({'source':str(src),'fixed_copy':str(dst),'sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'source_copy_matches':src.read_bytes()==dst.read_bytes()})
src=root/'docs/dev/p56/final-import.log';dst=out/'p56-final-import.log';shutil.copy2(src,dst)
log=dst.read_text(encoding='utf-8-sig',errors='replace');assert 'ERROR' not in log
files.append({'source':str(src),'fixed_copy':str(dst),'sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'source_copy_matches':src.read_bytes()==dst.read_bytes()})
summary=json.loads((out/'p56-summary.json').read_text(encoding='utf-8-sig'));assert summary['passed']==summary['total']==215
assert all(not report['failed'] and report['passed']==report['total'] for report in summary['reports'])
for name in reports[1:]:
    data=json.loads((out/name).read_text(encoding='utf-8-sig'))
    if isinstance(data['passed'],bool):
        assert data['passed'] and all(data['checks'].values())
    else:
        assert data['passed']==data['total'] and not data.get('failed',[])
shutil.copy2(Path(r'C:/Users/gst20/AppData/Local/Temp/codex-clipboard-7e6e944f-3e3f-44a0-a37d-a20039de687c.png'),doc/'rejected-style-user.png')
evidence={'schema':1,'reviewer':'主美','visual_passed':True,'review_file':'p56-visual-review.md','files':files,'producer_regression':summary,'final_import_error_count':0,'own_actual_native':json.loads((doc/'native-preview.json').read_text(encoding='utf-8')),'native_icons_visible':json.loads((doc/'native-icons-visible.json').read_text(encoding='utf-8')),'single_master_source':True,'residuals':['same material has soft contours','period128 can show texture repetition; not infinitely random'],'pixel_policy':'unaltered generated single master; native 2D geometry UV definitions and icons; evidence screenshots copied byte-identically'}
(doc/'p56-visual-evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
bundle=[root/'art/architecture/v26/manifest.json',root/'art/architecture/v26/wall_tiles_master_v26.png',root/'art/editor/v06/manifest.json']+list((root/'art/editor/v06/icons').glob('*.tres'))
bundle+=[doc/n for n in ['README.md','prompt.json','source-review.json','interface.json','assembly.gd','build-icons.gd','icons-qa.json','icons-native.stdout.log','icons-native.stderr.log','native-preview.gd','native-preview.png','native-preview.json','native-preview.stdout.log','native-preview.stderr.log','native-icons-visible.json','p56-visual-review.md','p56-visual-evidence.json','rejected-style-user.png']]
bundle+=list(out.iterdir())
rows=[{'path':str(p.relative_to(root)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in bundle]
version='architecture-v26-20261006-'+rows[0]['sha256'][:12]
delivery={'version':version,'entry':'art/architecture/v26/manifest.json','files':rows,'asset_count':14,'master_png_count':1,'editor_mesh_icon_count':14,'source_pixel_policy':'source copied unchanged from builtin imagegen; no separate art generation per component; no PNG editing','scope':'A26 maternal texture/components/icons/actual native and P56 visual comparison; program review separate'}
(doc/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'version':version,'files':len(rows),'master':1,'assets':14,'icons':14,'tests':215,'final_import_errors':0}))
