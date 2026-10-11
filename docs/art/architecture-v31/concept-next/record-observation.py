from pathlib import Path
import json,hashlib,shutil
root=Path(r'E:/Project/Godot/这次怎么逃');doc=root/'docs/art/architecture-v31';concept=doc/'concept-next'
shutil.copy2(Path(r'C:/Users/gst20/AppData/Local/Temp/codex-clipboard-01d490fe-ea8b-47e8-9959-8ef7cce3b72c.png'),concept/'user-height-feedback.png')
t=json.loads((concept/'a31-task-read.json').read_text(encoding='utf-8-sig'))
d=json.loads((doc/'delivery.json').read_text(encoding='utf-8-sig'));assert all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in d['files'])
c=dict(taskId=t['task']['id'],revision=t['revision'],feedbackId='a31-final-v31-20261007',correctionVersion=t['guidance']['correctionVersion'],note='人类最新实际观察：目前仍没有表达期望的连接感觉，纵墙像低于横墙；明确要求试覆盖交接处横砖，横纵一样高，并先设计概念图。A31同源UV/相位事实保留，但先前完整连接可交审的判断没有解决这个同高阅读问题，不能称人类批准。主美用imagegen只做同高覆盖概念：纵墙顶伸至H顶线，覆盖交界横砖并去跨过纵墙的H底线；这是预览，不是新生产资产。冻结53文件完全不改，制作人已暂缓A31/P64 sync/push/重启，等待概念方向反馈。历史验收保留，实际替换需要后续明确授权和新任务契约。',deliveryVersion=d['version'],evidence=[str(concept/'user-height-feedback.png'),str(concept/'same-height-overlap-concept.png'),str(concept/'prompt.json')],requestId='a31-user-height-observation-20261007')
(concept/'a31-correction.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'version':d['version'],'frozen_hashes_unchanged':True,'preview_only':True}))
