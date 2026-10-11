import hashlib,json
from pathlib import Path
p=Path('docs/dev/p86')
source=Path('scripts/presentation/doorway_view.gd')
(p/'doorway_view-before.txt').write_bytes(source.read_bytes())
baseline={'map_sha256':hashlib.sha256(Path('data/rooms/r04.json').read_bytes()).hexdigest(),'renderer_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'free_png_sha256':hashlib.sha256(Path('art/architecture/doorways_v49/free.png').read_bytes()).hexdigest()}
(p/'baseline.json').write_text(json.dumps(baseline,indent=2)+'\n',encoding='utf-8')
s=json.loads((p/'project-status.json').read_text(encoding='utf-8'));owner=s['identity']['id']
task={'id':'p86-readable-door-hardware-20261008','title':'P86 提高正常游戏比例的门框辨识度','kind':'程序','priority':'高','selfReviewRole':'producer','dependencyIds':['p85-flush-door-art-integration-20261008'],'description':'用户确认自由通行门没有辨识度；修正端框切片压缩和小铆钉显示。','acceptance':'正常1倍画面下门框和铆钉清晰；只增强端框绘制，不改变门洞、碰撞和地图；进入前后保持一致、自由通行和铁门状态有效。','workScope':{'allowedPaths':['scripts/presentation/doorway_view.gd','qa/p86*','docs/dev/p86/**','docs/tests/p86*'],'entry':'res://scenes/main.tscn','interfaceContract':'端框在原门洞内放大，保留原纹理及缓存；不改变开口尺寸、脚底阻挡和门控状态。'}}
plan={'scheduleRevision':s['scheduleRevision'],'creates':[{'task':task,'assigneeId':owner,'reviewerId':owner}],'reason':'用户指出门框缺乏正常游戏比例辨识度。','requestId':'p86-plan-20261008'}
(p/'plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
