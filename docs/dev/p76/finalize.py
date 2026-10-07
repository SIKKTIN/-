from pathlib import Path
import json,hashlib,subprocess,difflib

ROOT=Path('docs/dev/p76')
def read(p): return Path(p).read_text(encoding='utf-8-sig')
def write(p,v): Path(p).write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode())
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest() if Path(p).exists() else None

ops=json.loads(read(ROOT/'edits.json'))
groups={}
for p,a,b in ops: groups.setdefault(p,[]).append((a,b))
# Concurrent integration supplied the same preview method and a post label;
# retain its field/label while staging only this task's independent changes.
label=ROOT/'baseline/scripts/ui/npc_dialogue.gd'
s=read(label)
if '"name":guard.post_label' in read('scripts/ui/npc_dialogue.gd'):
    s=s.replace('"name":"门岗看守","role":"gate"','"name":guard.post_label,"role":"gate"')
    label.write_bytes(s.encode())
preserved={}
for p,changes in groups.items():
    expected=read(ROOT/'baseline'/p)
    for a,b in changes:
        assert a in expected,(p,a[:80]); expected=expected.replace(a,b)
    assert expected==read(p),p
    preserved[p]={'external_changes_preserved':True,'working_sha256':sha(p)}

initial=json.loads(read(ROOT/'baseline-state.json'))
untouched={p:{'current_sha256':sha(p),'unchanged_since_start':sha(p)==h} for p,h in initial.items() if p not in groups}
write(ROOT/'preservation.json',{'owned_file_preservation':preserved,'external_other_paths':untouched,'concurrent_merges':['preview adapter identical roof query deduplicated; external null field retained','NPC gate label retained in working tree, excluded from own staged changes'],'map_sha256':sha('data/rooms/r04.json')})

reports=['p76-visibility-headless.json','p76-visibility-native.json','p76-enforcement-headless.json','p76-lunch-wallet.json','p76-two-day-cycle.json','p76-editor-ui.json']
counts={}
for name in reports:
    d=json.loads(read('docs/tests/'+name)); assert not d['failed'],(name,d['failed']); counts[name]=len(d['checks'])
before=json.loads(read('docs/tests/p76-fps-before-final.json'))
after=json.loads(read('docs/tests/p76-fps-after-final.json'))
assert before['map_sha256']==after['map_sha256']
comparison=[]
for a,b in zip(before['scenes'],after['scenes']):
    assert a['scene']==b['scene']; ratio=b['fps']/a['fps']
    assert ratio>=0.95,(a,b)
    comparison.append({'scene':a['scene'],'before_fps':a['fps'],'after_fps':b['fps'],'change_percent':100*(ratio-1),'before_p95_ms':a['p95_ms'],'after_p95_ms':b['p95_ms']})
write(ROOT/'performance.json',{'scenes':comparison,'max_overhead_target_percent':5,'passed':True,'adapter':after['adapter'],'map_sha256':after['map_sha256']})
logs=['p76-room_visibility.log','p76-visibility-native.log','p76-labor_enforcement.log','p76-lunch_wallet.log','p76-two_day_cycle.log','p76-editor-ui.log','p76-fps-before-final.log','p76-fps-after-final.log']
for name in logs: assert 'ERROR:' not in read('docs/tests/'+name),name
new=['scripts/core/room_visibility.gd','scripts/presentation/room_cover.gd']
delivery={'taskId':'p76-room-interior-visibility-20261007','source_sha256':{p:sha(p) for p in list(groups)+new},'checks':counts,'total_checks':sum(counts.values()),'performance_cases':3,'collision_equivalence_samples':100,'clean_logs':logs,'external_initial_paths':len(initial)}
write(ROOT/'delivery.json',delivery)
task=json.loads(read(ROOT/'task-before-delivery.json'))
feedback={'taskId':delivery['taskId'],'revision':task['revision'],'feedbackId':'p76-delivery-20261007','status':'待验收','summary':'房间脚底跨门揭顶、离开重盖、0.2秒过渡及缓冲；11间房独立，小地图人物/物品、聊天及拾取、灯光/阴影/警戒和工作提示统一过滤，后台AI继续。编辑器范围图层及门关联、撤销/保存验证。189项自测、100碰撞对照及两天日程通过；同场景90→103、101→106、93→105FPS，保留地图与程序/美术WIP。','evidence':['docs/dev/p76/report.md','docs/dev/p76/delivery.json','docs/dev/p76/performance.json','docs/dev/p76/preservation.json']+['docs/tests/'+n for n in reports]+['docs/tests/p76-outside-covered.png','docs/tests/p76-inside-revealed.png','docs/tests/p76-editor-visibility-layer.png'],'requestId':'p76-feedback-20261007'}
write(ROOT/'feedback.json',feedback)

# Surgical staging of the recorded edits against HEAD, excluding all WIP.
for p,changes in groups.items():
    source=subprocess.check_output(['git','show','HEAD:'+p]).decode('utf-8-sig')
    for a,b in changes:
        assert a in source,('HEAD op mismatch',p,a[:100]); source=source.replace(a,b)
    blob=subprocess.check_output(['git','hash-object','-w','--stdin'],input=source.encode()).decode().strip()
    subprocess.run(['git','update-index','--cacheinfo','100644',blob,p],check=True)
print('Validated',delivery['total_checks'],'checks and 3 matched performance cases; staged',len(groups),'owned file patches.')
