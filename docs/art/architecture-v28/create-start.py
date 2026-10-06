from pathlib import Path
import json
doc=Path(r'E:/Project/Godot/这次怎么逃/docs/art/architecture-v28')
t=json.loads((doc.parents[0]/'a28-task-read.json').read_text(encoding='utf-8-sig'))
assert t['task']['assignment']['primaryId']=='20df60dc-6f5f-40ca-930a-a606b45a0dac'
feedback={'taskId':t['task']['id'],'revision':t['revision'],'feedbackId':'a28-start-20261006','status':'进行中','summary':'按用户瓦片积木要求制作专用完整L转角，转弯内部亮面、倒角和内侧暗边连续，不能再用横条/竖条交叠代替造型。保留V24横墙柱楣和V27直纵顶，只替接点小范围。内置imagegen首稿已生成，正在针对角顶分离缝修订；四个左右24/20定义、两端接口和透明空区待原生试拼后确定。不改旧PNG/共享scripts/data/Git。','evidence':[str(doc/'interface-draft.json')],'requestId':'a28-start-20261006'}
(doc/'start-feedback.json').write_text(json.dumps(feedback,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
