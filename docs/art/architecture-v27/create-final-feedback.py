from pathlib import Path
import json
doc=Path(r'E:/Project/Godot/这次怎么逃/docs/art/architecture-v27')
t=json.loads((doc/'final-task-read.json').read_text(encoding='utf-8-sig'))
d=json.loads((doc/'delivery.json').read_text(encoding='utf-8-sig'))
summary='交付'+d['version']+'：保留用户第一版原V24横翼/厚门柱/门楣，0新增生产PNG；10个局部角/纵顶/端面和10对应同源MeshTexture图标。原压顶真实倒角/深边源窗232,192,245,74.074，石块节距61.57068，24/20只变截面；原翼角正面严格沿原翼原比例采样，整PNG不作U漂移。已实际复核1200/960、左右2倍、厨房、编辑器及游戏摆放。右extended最初黑缝已拒绝并修正：原middle连续，top_only跳过独特原翼face，只遮纵臂截面，移除旧尾柱；最新图该缝消除，原体积和风格恢复。主美判断符合第一版基准；134项实际功能/资源/规则检查另列，不能代替审美。10图标GPU可见，native stderr0。47文件hash冻结，旧A24/A25/A26不变；长墙原中段重复和烘焙阴影可辨，未承诺无限随机。待制作人独立审美验收，不代表用户已批准。'
paths=['art/architecture/v27/manifest.json','art/editor/v07/manifest.json','docs/art/architecture-v27/delivery.json','docs/art/architecture-v27/README.md','docs/art/architecture-v27/interface.json','docs/art/architecture-v27/source-review.json','docs/art/architecture-v27/contract-check.json','docs/art/architecture-v27/native-preview.png','docs/art/architecture-v27/native-detail.png','docs/art/architecture-v27/native-icons-visible.json','docs/art/architecture-v27/p57-visual-review.md','docs/art/architecture-v27/p57-visual-evidence.json','docs/art/architecture-v27/runtime/p57-local-repair-left.png','docs/art/architecture-v27/runtime/p57-local-repair-right.png','docs/art/architecture-v27/runtime/p57-1200-walls-hud.png','docs/art/architecture-v27/runtime/p57-960-walls-unobscured.png','docs/art/architecture-v27/runtime/p57-editor-components-final.png','docs/art/architecture-v27/runtime/p57-runtime-components-final.png']
root=doc.parents[2]
out={'taskId':t['task']['id'],'revision':t['revision'],'feedbackId':'a27-final-v27-20261006','status':'待验收','summary':summary,'evidence':[str(root/p) for p in paths],'requestId':'a27-final-v27-20261006'}
assert all(Path(p).is_file() for p in out['evidence'])
(doc/'final-feedback.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'revision':t['revision'],'evidence':len(paths)}))
