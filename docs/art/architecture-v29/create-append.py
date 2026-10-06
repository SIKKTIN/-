from pathlib import Path
import json,hashlib,shutil
doc=Path(r'E:/Project/Godot/这次怎么逃/docs/art/architecture-v29');root=doc.parents[2]
t=json.loads((doc/'append-task-read.json').read_text(encoding='utf-8-sig'));d=json.loads((doc/'delivery.json').read_text(encoding='utf-8-sig'))
g=t['guidance'];assert g['feedbackState']=='pending'
assert all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in d['files'])
extra=doc/'additional-ev2';extra.mkdir(exist_ok=True)
names=['p62-runtime-t-components.png','p62-runtime-t-components.json','p62-access-access-headless-1200.json']
for n in names:shutil.copy2(root/'docs/tests'/n,extra/n)
c=json.loads((extra/names[1]).read_text(encoding='utf-8-sig'));a=json.loads((extra/names[2]).read_text(encoding='utf-8-sig'))
assert c['passed']==c['total']==12 and all(c['checks'].values())
assert a['passed'] is True and all(a['checks'].values()) and len(a['checks'])==73
note={'deliveryVersion':d['version'],'original_40_hashes_unchanged':True,'new_delivery_content':False,'extra_component_checks':12,'program_rule_checks':73,'visual_observation':'art director viewed actual standalone20/24 T: both arms and central stem, two notches show original floor; exact132x80/136x80','files':[{'path':str(extra/n),'sha256':hashlib.sha256((extra/n).read_bytes()).hexdigest()} for n in names]}
(extra/'evidence.json').write_text(json.dumps(note,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
request={'taskId':t['task']['id'],'revision':t['revision'],'feedbackId':g['feedbackId'],'evidenceVersion':g['evidenceVersion'],'note':'原40文件交付SHA及素材/接口/验收依据不变，仅补充制作人随后提供的同构建actual运行独立T20/24图。主美已亲眼查看：两规格是完整T，左右臂、stem实绘，两个内空透原地面，不被bbox影填满；12/12组件实际检查。P62门禁/禁闭/救人/全逃回归73/73另列，不代替审美。原ev1的两尺寸96项和美术结论保留。','deliveryVersion':d['version'],'evidence':[str(extra/n) for n in names]+[str(extra/'evidence.json')],'requestId':'a29-extra-runtime-ev2-20261007'}
(doc/'append-request.json').write_text(json.dumps(request,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'original_frozen_hashes_match':True,'extra_native':12,'rule_checks':73,'evidenceVersion':g['evidenceVersion']}))
