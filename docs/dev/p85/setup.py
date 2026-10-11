import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

base = Path('docs/dev/p85')
files = ['scripts/presentation/doorway_view.gd', 'scripts/presentation/doorway_geometry.gd', 'scripts/world/prison_world.gd', 'data/rooms/r04.json']
baseline = {'files': {}, 'map_sha256': hashlib.sha256(Path(files[-1]).read_bytes()).hexdigest()}
for f in files:
    raw = Path(f).read_bytes()
    (base / (Path(f).stem + '-before.txt')).write_bytes(raw)
    baseline['files'][f] = hashlib.sha256(raw).hexdigest()
(base/'baseline.json').write_text(json.dumps(baseline, indent=2)+'\n', encoding='utf-8')
art = Path('art/architecture/doorways_v49')
art.mkdir(parents=True, exist_ok=True)
assets = []
sources = [('free', 'exec-57c1ac50-376c-4042-90a7-a449ceed73c4.png'), ('grille', 'exec-19db0000-246c-4edf-937a-0896868dc958.png')]
origin = Path('C:/Users/gst20/.codex/generated_images/01a0f5a2-2112-79f1-85e2-6030a780d39d')
for style, filename in sources:
    target = art/(style+'.png')
    shutil.copy2(origin/filename,target)
    im = Image.open(target)
    assert im.mode == 'RGBA', im.mode
    box = im.getchannel('A').getbbox()
    assert im.getchannel('A').getextrema()[0]==0
    x,y,right,bottom = box
    assets.append({'id': 'door_'+style+'_v49', 'style':style, 'texture':'res://'+target.as_posix(), 'region':[x,y,right-x,bottom-y], 'world_size':[40,20], 'cap_ratio':0.105, 'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
    print(style, im.size, 'alpha bounds',box)
(art/'manifest.json').write_text(json.dumps({'version':'doorways-v49','assets':assets},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
status = json.loads((base/'project-status.json').read_text(encoding='utf-8'))
owner = status['identity']['id']
task = {'id':'p85-flush-door-art-integration-20261008','title':'P85 平齐自由通行门与铁门素材接入','kind':'程序','priority':'高','selfReviewRole':'producer','dependencyIds':['p84-small-foot-collision-20261008'],'description':'按用户批准的平齐概念图制作两种门资源并接入截图寝室侧门。用户直接授权本助手制作素材与集成。','acceptance':'自由通行和铁门两套透明素材；寝室1侧门使用自由通行款且始终可通行；端框完全在门洞范围内、不内凹；铁门显示开关状态；过门、夜间状态、遮挡前后和缓存检查通过。','workScope':{'allowedPaths':files+['art/architecture/doorways_v49/**','qa/p85*','docs/dev/p85/**','docs/tests/p85*'],'entry':'res://scenes/main.tscn','interfaceContract':'只将寝室1侧门kind设为open；其余开关/锁门逻辑、脚底半径8、地图几何不变。新门框保持现有门洞投影及墙线，渲染切片缓存，开关时局部重绘。'}}
plan = {'scheduleRevision':status['scheduleRevision'],'creates':[{'task':task,'assigneeId':owner,'reviewerId':owner}],'reason':'用户批准平齐概念图并要求制作两种门素材和自由通行入口接入。','requestId':'p85-plan-20261008'}
(base/'plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
