from pathlib import Path
import json
root=Path('E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v25'
t=json.loads((doc/'final-task-read.json').read_text(encoding='utf-8-sig'))
d=json.loads((doc/'delivery.json').read_text(encoding='utf-8'))
evidence=[root/'art/architecture/v25/manifest.json',root/'art/editor/v05/manifest.json']+[doc/n for n in ['delivery.json','p55-visual-review.md','p55-visual-evidence.json','corner-interface.json','corner-source-review.json','corner-prompts.json','alpha-transfer-check.json','shader-native.json','corner-native.json']]+[doc/'runtime'/n for n in ['p55-1200-walls-unobscured-final.png','p55-1200-wall-detail-final.png','p55-1200-right-junctions-final.png','p55-960-walls-hud-final.png']]
f={'taskId':'a25-cafeteria-walls-alpha-20261006','revision':t['revision'],'feedbackId':'a25-final-v25-20261006','status':'待验收','summary':'交付'+d['version']+'：新增真正平整纵墙顶+窄暗侧、一次南端面、连续L转角，共3资产/2新原图/3图标；左/右外角与厨房20宽接点实际完整图和真实2x近景亲眼复核，压顶连续90度转弯、横front与灰基脚对齐，旧外前柱绘制让位。12源区已按cap/plinth/脚配准；已发现并修正程序重复裁切坐标与负矩形镜像错误。新版alpha shader不放大低alpha杂点，实体核心不透底；真实GPU绘制/资源3项通过，制作人P55最终回归220/220。A24全部交付hash不变，新PNG原样copy。仍有转角石缝略密/描边稍重、south续接略暖的小差异，记录不冒充逐像素还原；运行图FPS非性能benchmark。待制作人独立验收。','evidence':[str(p) for p in evidence],'requestId':'a25-final-v25-20261006'}
(doc/'final-feedback.json').write_text(json.dumps(f,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'revision':t['revision'],'feedbackId':f['feedbackId'],'evidence_count':len(evidence)}))