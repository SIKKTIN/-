from pathlib import Path
import json
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v31'
t=json.loads((root/'docs/art/a31-task-read-20261007.json').read_text(encoding='utf-8-sig'))
start=dict(taskId=t['task']['id'],revision=t['revision'],feedbackId='a31-start-20261007',status='进行中',summary='已亲眼核用户圈点，承认A30/P63把正面柱石接窄顶面误当小色差。A31改为原V24 PNG同源UV，stem严格同V27 transpose/74.074横截/61.57068周期，从local24取56长源X223.1667；下段tile_origin local24、clip从80，保证相位56不重置。两角色horizontal_cap/longitudinal_stem供厨房保留原H只绘stem；无新PNG，无shared代码/data/Git改动。候选native图标后交actual完整纵墙审。',evidence=[str(doc/'interface.json'),str(doc/'user-style-mismatch.png')],requestId='a31-start-20261007')
(doc/'start-feedback.json').write_text(json.dumps(start,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
a=json.loads((doc/'a30-correction-task-read.json').read_text(encoding='utf-8-sig'))
c=dict(taskId=a['task']['id'],revision=a['revision'],feedbackId='a30-final-v30-20261007',correctionVersion=a['guidance']['correctionVersion'],note='用户明确拒绝P63：新T上部为正面柱石，下部V27为窄顶面加侧影，透视/块型/石缝不同。我上一轮判断可交审与仅细微石材差异是误判。保留A30原交付和验收历史，不把技术78+73通过当风格认可；已另派A31/P64采用冻结V24 PNG同源UV与V27相位续接，实际整条纵墙重新审。',deliveryVersion='architecture-v30-20261007-b9e0e175d3cb',evidence=[str(doc/'user-style-mismatch.png'),str(doc/'interface.json')],requestId='a30-user-perspective-correction-20261007')
(doc/'a30-correction.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
