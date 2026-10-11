import hashlib
import json
import subprocess
from pathlib import Path
from PIL import Image

p = Path('docs/dev/p85')
reports = ['docs/tests/p85-boundaries-native.json','docs/tests/p85-editor-editor-native.json','docs/tests/p85-two-day-cycle.json']
counts = []
for f in reports:
    r = json.loads(Path(f).read_text(encoding='utf-8'))
    assert not r['failed'], (f,r['failed'])
    counts.append(len(r['checks']))
assert sum(counts)==90, counts
before=json.loads((p/'r04-before.txt').read_text(encoding='utf-8'))
after=json.loads(Path('data/rooms/r04.json').read_text(encoding='utf-8'))
before['dorm_doors'][0]['kind']='open'
assert before==after
art=Path('art/architecture/doorways_v49')
generation=json.loads((art/'generation.json').read_text(encoding='utf-8'))
asset_checks=[]
for asset in generation['assets']:
    target=art/asset['output']
    image=Image.open(target)
    raw=target.read_bytes()
    assert raw==Path(asset['generated_source']).read_bytes()
    assert image.mode=='RGBA' and image.getchannel('A').getextrema()==(0,255)
    asset_checks.append({'file':str(target),'mode':image.mode,'size':list(image.size),'alpha_extrema':[0,255],'source_byte_identical':True,'sha256':hashlib.sha256(raw).hexdigest()})
(p/'asset-checks.json').write_text(json.dumps(asset_checks,indent=2)+'\n',encoding='utf-8')
files=subprocess.check_output(['git','diff','--cached','--name-only']).decode('utf-8').splitlines()
delivery={'version':'p85-doorways-v49','unique_checks':90,'report_counts':counts,'reports':reports,'assets':asset_checks,'map_semantic_delta':'dorm_doors[0].kind=open only','files':[]}
for file in files:
    delivery['files'].append({'file':file,'working_sha256':hashlib.sha256(Path(file).read_bytes()).hexdigest(),'index_sha256':hashlib.sha256(subprocess.check_output(['git','show',':'+file])).hexdigest()})
(p/'delivery.json').write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
r=json.loads((p/'task-before-delivery.json').read_text(encoding='utf-8'))['revision']
f={'taskId':'p85-flush-door-art-integration-20261008','revision':r,'feedbackId':'p85-delivery-20261008','status':'待验收','summary':'自由通行/铁门两套透明v49资源完成，寝室1入口接入平齐自由通行门框；90项原生门、编辑器和两日日程检查通过。','evidence':['docs/dev/p85/report.md','docs/dev/p85/delivery.json','docs/dev/p85/asset-checks.json']+reports+['docs/tests/p85-free-door-outside.png','docs/tests/p85-free-door-inside.png','docs/tests/p85-iron-door-closed.png','docs/tests/p85-iron-door-open.png'],'requestId':'p85-delivery-20261008'}
(p/'feedback.json').write_text(json.dumps(f,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Validated reports:',counts,'total:',sum(counts))
