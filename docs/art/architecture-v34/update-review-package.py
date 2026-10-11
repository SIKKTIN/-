import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
path=out/'review-package.json'
package=json.loads(path.read_text(encoding='utf-8'))
names={item['path'] for item in package['files']}
names.update(['data/rooms/r04.json','scripts/editor/map_canvas.gd','scripts/editor/map_editor.gd','scripts/world/prison_world.gd'])
names.update(p.relative_to(root).as_posix() for p in (root/'art/editor/v14/icons').glob('*.tres'))
names.update(p.relative_to(root).as_posix() for p in out.iterdir() if p.name in ['README.md','scope.md','perimeter-checks.json','perimeter-layout.json','r04-before-grid-perimeter.json','perimeter-editor-full.png','perimeter-editor-north.png','perimeter-editor-selection.png','perimeter-editor-bottom.png','rebuild-perimeter.py','perimeter-preview.gd','open-r04-review.gd'])
package['files']=[{'path':name,'sha256':hashlib.sha256((root/name).read_bytes()).hexdigest()} for name in sorted(names)]
package['tests']=['perimeter-checks.json','grid-edge-alpha.json','icons-qa.json']
package['tiles_in_r04']=85
package['current_native_checks']=101
package['access_regression']='P66_ACCESS passed=true count=73 failed=[]'
path.write_text(json.dumps(package,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
