from pathlib import Path
import json
doc=Path(r'E:/Project/Godot/这次怎么逃/docs/art/architecture-v30')
t=json.loads((doc.parent/'a30-task-read-20261007.json').read_text(encoding='utf-8-sig'))
assert t['task']['assignment']['primaryId']=='20df60dc-6f5f-40ca-930a-a606b45a0dac'
f={'taskId':t['task']['id'],'revision':t['revision'],'feedbackId':'a30-start-20261007','status':'进行中','summary':'已亲眼看人类批准的自然砌接概念。按普通石块与石缝咬合重做新PNG，不给旧大T板调色；浅米灰、线宽/明暗/磨损密度对原H/V，去亮色斑点、独立黑框和双影。拟保留132/136×80、stemx56、北深24、y80接V27，构造改为普通矩形砌块咬合，去旧大三角肩部；先新源和原生试拼，候选交P63接actual再冻结。旧素材/shared代码/data/Git不改。','evidence':[str(doc/'interface-draft.json')],'requestId':'a30-start-20261007'}
(doc/'start-feedback.json').write_text(json.dumps(f,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
