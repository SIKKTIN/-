from pathlib import Path
import json
doc=Path(r'E:/Project/Godot/这次怎么逃/docs/art/architecture-v29')
t=json.loads((doc.parent/'a29-task-read-20261007.json').read_text(encoding='utf-8-sig'))
assert t['task']['assignment']['primaryId']=='20df60dc-6f5f-40ca-930a-a606b45a0dac'
f={'taskId':t['task']['id'],'revision':t['revision'],'feedbackId':'a29-start-20261007','status':'进行中','summary':'已读取用户厨房截图，接点属于横墙继续贯通、中央向下纵臂的T形。本人用内置imagegen专门绘制完整T压顶，不用两个旧L拼合；保留原V24/V27/V28风格和旧资产。拟20为132×80、24为136×80，左右臂各56，北臂深24，纵臂x56，80后接原V27。先精确源区/原生试拼/GPU图标交一套候选，实际厨房两个T点由制作人P62接入后审美复核。','evidence':[str(doc/'interface-draft.json')],'requestId':'a29-start-20261007'}
(doc/'start-feedback.json').write_text(json.dumps(f,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
