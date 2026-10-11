import hashlib,json,subprocess
from pathlib import Path
p=Path('docs/dev/p87')
paths=['docs/tests/p87-door-readability-native.json','docs/tests/p87-boundaries-headless.json','docs/tests/p87-two-day-cycle.json']
counts=[]
for path in paths:
    r=json.loads(Path(path).read_text(encoding='utf-8'));assert not r['failed'];counts.append(len(r['checks']))
assert sum(counts)==91
before=json.loads(Path('docs/tests/p87-chase-before-valid.json').read_text(encoding='utf-8'))
after=json.loads(Path('docs/tests/p87-chase-after-valid.json').read_text(encoding='utf-8'))
assert before['map_sha256']==after['map_sha256']==json.loads((p/'baseline.json').read_text(encoding='utf-8'))['map_sha256']
comparison=[]
for a,b in zip(before['samples'],after['samples']):
    assert a['name']==b['name'] and a['saw_chase'] and b['saw_chase']
    comparison.append({'scenario':a['name'],'before_frame':a['frame'],'after_frame':b['frame'],'before_transition':a['transition'],'after_transition':b['transition'],'before_paths':a['paths'],'after_paths':b['paths']})
(p/'performance.json').write_text(json.dumps(comparison,indent=2)+'\n',encoding='utf-8')
restart={'session_id':'project@8a8938d42154c7a4','editor_pid':28456,'mode':'main','autosave':False,'helper_live':True,'current_run_errors':[],'prior_debug_pause':'misread prisoner.path in read-only eval; corrected by restarting this editor game only'}
(p/'restart.json').write_text(json.dumps(restart,indent=2)+'\n',encoding='utf-8')
files=subprocess.check_output(['git','diff','--cached','--name-only']).decode('utf-8').splitlines()
delivery={'checks':91,'counts':counts,'reports':paths,'comparison':comparison,'files':[]}
for f in files:delivery['files'].append({'file':f,'working_sha256':hashlib.sha256(Path(f).read_bytes()).hexdigest(),'index_sha256':hashlib.sha256(subprocess.check_output(['git','show',':'+f])).hexdigest()})
(p/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
r=json.loads((p/'task-before-delivery.json').read_text(encoding='utf-8'))['revision']
f={'taskId':'p87-door-layer-supervision-chase-performance-20261008','revision':r,'feedbackId':'p87-delivery-20261008','status':'待验收','summary':'门框位于角色下方；封闭车间失败寻路早退消除主要20ms尖峰。本机60帧两个触发场景最长帧36ms降至17ms；91项回归通过，原编辑器游戏已恢复运行。','evidence':['docs/dev/p87/report.md','docs/dev/p87/delivery.json','docs/dev/p87/performance.json','docs/dev/p87/restart.json']+paths+['docs/tests/p87-chase-before-valid.json','docs/tests/p87-chase-after-valid.json','docs/tests/p87-free-outside.png'],'requestId':'p87-delivery-20261008'}
(p/'feedback.json').write_text(json.dumps(f,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Passed:',sum(counts))
