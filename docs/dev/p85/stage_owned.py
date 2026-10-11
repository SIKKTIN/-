import hashlib
import json
import subprocess
from pathlib import Path

def head(path):
    return subprocess.check_output(['git','show','HEAD:'+path]).decode('utf-8').replace('\r\n','\n')

def stage_content(path, text):
    blob = subprocess.check_output(['git','hash-object','-w','--stdin'],input=text.encode('utf-8')).decode().strip()
    subprocess.run(['git','update-index','--add','--cacheinfo','100644,'+blob+','+path],check=True)

world = 'scripts/world/prison_world.gd'
text = head(world)
old = '\tfor entry in config.get("dorm_doors",[]):\n\t\tdorm_doors.append({"actor_id":int(entry.actor_id),"rect":_rect(entry.rect),"closed":false})'
new = '\tfor entry in config.get("dorm_doors",[]):\n\t\tvar gate: Dictionary = entry.duplicate(true)\n\t\tgate.actor_id = int(entry.actor_id)\n\t\tgate.rect = _rect(entry.rect)\n\t\tgate.closed = false\n\t\tdorm_doors.append(gate)'
assert old in text
text = text.replace(old,new,1)
old = '\t\tvar closed: bool = locked and not points.any(func(point): return gate.rect.get_center().distance_to(point) <= 85)'
new = '\t\tvar closed: bool = str(gate.get("kind","dorm")) != "open" and locked and not points.any(func(point): return gate.rect.get_center().distance_to(point) <= 85)'
assert old in text
text = text.replace(old,new,1)
stage_content(world,text)
map_path = 'data/rooms/r04.json'
text = head(map_path)
marker = '  "dorm_doors": [\n    {\n      "actor_id": 0,\n'
assert text.count(marker)==1
text = text.replace(marker,marker+'      "kind": "open",\n',1)
stage_content(map_path,text)
view = 'scripts/presentation/doorway_view.gd'
assert head(view)==Path('docs/dev/p85/doorway_view-before.txt').read_text(encoding='utf-8')
subprocess.run(['git','add','--',view,'art/architecture/doorways_v49/free.png','art/architecture/doorways_v49/grille.png','art/architecture/doorways_v49/manifest.json','art/architecture/doorways_v49/README.md','art/architecture/doorways_v49/generation.json'],check=True)
audit = [{'file':world,'method':'two owned dorm metadata/open-state deltas applied to HEAD; unrelated WIP kept unstaged'}, {'file':map_path,'method':'single dorm-0 kind:open insertion applied to HEAD; unrelated map WIP kept unstaged'}, {'file':view,'method':'clean baseline matched HEAD; full owned renderer change staged'}]
Path('docs/dev/p85/index-audit.json').write_text(json.dumps(audit,indent=2)+'\n',encoding='utf-8')
subprocess.run(['git','diff','--cached','--check'],check=True)
subprocess.run(['git','diff','--cached','--stat'],check=True)
