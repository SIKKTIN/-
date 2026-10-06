from pathlib import Path
import json,hashlib,shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v25';out=doc/'runtime';out.mkdir(exist_ok=True)
names=['p55-1200-walls-unobscured-final.png','p55-1200-walls-hud-final.png','p55-960-walls-hud-final.png','p55-1200-wall-detail-final.png','p55-1200-right-junctions-final.png','p55-1200-old-alpha-comparison-final.png','p55-1200-safe-alpha-comparison-final.png','p55-1200-planner-fps-layer-final.png']
reports=['p55-summary.json','p55-wall-fps-native-1200.json','p55-wall-fps-native-960.json','p55-wall-fps-headless-1200.json','p55-wall-detail-native.json','p55-access-access-headless-1200.json','p55-editor-headless-1280.json']
rows=[]
for name in names+reports:
    src=root/'docs/tests'/name;dst=out/name;shutil.copy2(src,dst)
    rows.append({'source':str(src),'fixed_copy':str(dst),'sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'source_copy_matches':src.read_bytes()==dst.read_bytes()})
summary=json.loads((out/'p55-summary.json').read_text(encoding='utf-8-sig'))
assert summary['passed']==summary['total']==220
assert all(not r['failed'] and r['passed']==r['total'] for r in summary['reports'])
manifest=json.loads((root/'art/architecture/v25/manifest.json').read_text(encoding='utf-8'))
prior=json.loads((root/'docs/art/architecture-v24/delivery.json').read_text(encoding='utf-8-sig'))
unchanged=all(hashlib.sha256((root/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in prior['files'])
assert unchanged
p=doc/'corner-source-review.json';review=json.loads(p.read_text(encoding='utf-8'));review['rejected_connection']['status']='four junctions personally reviewed in actual final game screenshots; passed continuous cap/front/plinth registration';review['final_actual_evidence']='p55-visual-evidence.json';p.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
evidence={'schema':1,'reviewer':'主美','visual_passed':True,'review_file':'p55-visual-review.md','files':rows,'producer_regression':summary,'own_resource_load':json.loads((doc/'godot-qa.json').read_text(encoding='utf-8-sig')),'own_actual_native_corner':json.loads((doc/'corner-native.json').read_text(encoding='utf-8-sig')),'A24_delivery_unchanged':unchanged,'source_pixel_policy':'new top/Lcorner PNG copied unchanged; source Atlas registrations only; runtime evidence copied byte-identically','residuals':['corner stone seams slightly denser and contours heavier than adjacent old wing','south continuation slightly warmer'],'not_claimed':'pixel-identical concept; captured FPS is not gameplay performance benchmark'}
(doc/'p55-visual-evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
files=[]
for rel in ['art/architecture/v25/manifest.json','art/architecture/v25/cafeteria_return_top_v25.png','art/architecture/v25/cafeteria_corner_l_v25.png','art/architecture/v25/safe_edges_v25.gdshader','art/editor/v05/manifest.json']:
    files.append(root/rel)
files+=list((root/'art/editor/v05/icons').glob('*.tres'))
files+=[doc/n for n in ['README.md','prompt.json','source-review.json','alpha-source-diagnosis.json','alpha-transfer-check.json','godot-qa.json','shader-native.json','shader-native.stdout.log','shader-native.stderr.log','shader-native.png','corner-prompts.json','corner-source-review.json','corner-interface.json','corner-native.gd','corner-native.json','corner-native.stdout.log','corner-native.stderr.log','corner-native.png','p55-visual-review.md','p55-visual-evidence.json','rejected-connection-user.png','connection-concept-target.png']]
files+=list(out.iterdir())
hashrows=[{'path':str(p.relative_to(root)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]
version='architecture-v25-20261006-'+hashrows[0]['sha256'][:12]
delivery={'version':version,'entry':'art/architecture/v25/manifest.json','files':hashrows,'asset_count':3,'new_png_count':2,'editor_icon_count':3,'reused_end_source':'res://art/architecture/v24/cafeteria_portal_v24.png','source_pixel_policy':'unchanged builtin generated PNGs; registered source sampling only','scope':'A25 assets, editor icons, shader and personally verified P55 fixed actual visual evidence','producer_program_review_separate':True}
(doc/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'delivery_version':version,'assets':3,'pngs':2,'icons':3,'A24_unchanged':unchanged,'producer_tests':summary['passed'],'evidence_files':len(rows)}))
