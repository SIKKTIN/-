from pathlib import Path
import hashlib,json,subprocess

def read(p): return Path(p).read_text(encoding='utf-8-sig')
def write(p,d): Path(p).write_bytes((json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode())
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest() if Path(p).exists() else None
def world_patch(s):
    edits=[('func can_place_circle(','func _staff_exterior(actor, point: Vector2, radius: float = RADIUS) -> bool:\n\treturn actor != null and actor.has_method("staff_exterior_allowed") and actor.staff_exterior_allowed(point,radius)\n\nfunc can_place_circle('),('\tif not inside_room(point, radius):','\tif not inside_room(point, radius) and not _staff_exterior(ignore_actor,point,radius):'),('\tif not inside_room(from) or not inside_room(to):','\tif (not inside_room(from) and not _staff_exterior(ignore_actor,from)) or (not inside_room(to) and not _staff_exterior(ignore_actor,to)):')]
    for old,new in edits:
        assert old in s
        s=s.replace(old,new)
    return s

baseline=json.loads(read('docs/dev/p75/baseline-state.json'))
preserved={p:sha(p)==h for p,h in baseline.items() if p!='scripts/world/prison_world.gd'}
preserved['world_external_changes_preserved']=world_patch(read('docs/dev/p75/baseline/scripts/world/prison_world.gd'))==read('scripts/world/prison_world.gd')
assert all(preserved.values()),[p for p,v in preserved.items() if not v]
write('docs/dev/p75/preservation.json',{'checks':preserved,'preserved_paths':len(baseline),'map_sha256':sha('data/rooms/r04.json')})
own=['scripts/actors/gate_guard.gd','scripts/actors/guard.gd','scripts/actors/workshop_overseer.gd','scripts/core/escape_game.gd','scripts/core/gate_watch.gd','scripts/core/prison_alert.gd','scripts/core/workshop_rules.gd','scripts/core/staff_traffic.gd','scripts/presentation/actor_visual.gd','scripts/world/prison_world.gd']
reports=['p75-staff-traffic.json','p75-rules-dialogue-headless.json','p75-enforcement-headless.json','p75-lunch-wallet.json','p75-two-day-cycle.json','p75-native-departure.json','p75-live-runtime.json']
counts={}
for name in reports:
    d=json.loads(read('docs/tests/'+name)); assert not d['failed'],(name,d['failed']); counts[name]=len(d['checks'])
logs=['p75-staff-traffic.log','p75-rules_and_dialogue.log','p75-labor_enforcement.log','p75-lunch_wallet.log','p75-two-day.log','p75-native-departure.log','p75-live-runtime.log']
for name in logs: assert 'SCRIPT ERROR:' not in read('docs/tests/'+name) and 'ERROR:' not in read('docs/tests/'+name),name
delivery={'taskId':'p75-physical-staff-entrance-exit-20261007','source_sha256':{p:sha(p) for p in own},'checks':counts,'total_checks':sum(counts.values()),'clean_logs':logs,'external_preserved':len(baseline)}
write('docs/dev/p75/delivery.json',delivery)
task=json.loads(read('docs/dev/p75/task-before-delivery.json'))
print('Task keys:',list(task.keys()))
revision=task.get('revision',task['task'].get('revision'))
assert revision
feedback={'taskId':delivery['taskId'],'revision':revision,'feedbackId':'p75-delivery-20261007','status':'待验收','summary':'监工、门岗和增援使用持续身份，从车间门及厂区铁门步行进出；仅地图外退场，重报警原地折返。监工7/13点提前进场，12/18点退岗；临时钥匙开门不覆盖玩家永久解锁。192项自测通过，实际离岗及返岗149FPS，两天四班到岗、无误抓，34路径外部WIP保留。','evidence':['docs/dev/p75/report.md','docs/dev/p75/delivery.json','docs/dev/p75/preservation.json']+['docs/tests/'+n for n in reports]+['docs/tests/p75-depart-workshop.png','docs/tests/p75-depart-factory.png'],'requestId':'p75-feedback-20261007'}
write('docs/dev/p75/feedback.json',feedback)
head=subprocess.check_output(['git','show','HEAD:scripts/world/prison_world.gd']).decode('utf-8-sig')
own_world=world_patch(head).encode()
blob=subprocess.check_output(['git','hash-object','-w','--stdin'],input=own_world).decode().strip()
subprocess.run(['git','update-index','--cacheinfo','100644',blob,'scripts/world/prison_world.gd'],check=True)
print('Verified',delivery['total_checks'],'checks; preserved',len(baseline),'paths; own world hunk staged.')
