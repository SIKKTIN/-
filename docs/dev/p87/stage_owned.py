import json,subprocess
from pathlib import Path
p=Path('docs/dev/p87')
src='scripts/world/prison_world.gd'
before=(p/'prison_world-before.txt').read_text(encoding='utf-8')
work=Path(src).read_text(encoding='utf-8')
fields='var sealed_room_revision := -1\nvar sealed_rooms: Dictionary = {}\n'
check='\t# A failed JPS search can traverse the entire factory. Reject only when\n\t# fixed solids prove a complete closed perimeter separates the endpoints.\n\tif not planning_guard_doors and _sealed_room_separates(from,to):\n\t\treturn PackedVector2Array()\n'
start=work.index('func _sealed_room_separates(')
end=work.index('func _path_on_grid(',start)
helpers=work[start:end]
assert work.replace(fields,'',1).replace(check,'',1).replace(helpers,'',1)==before
head=subprocess.check_output(['git','show','HEAD:'+src]).decode('utf-8').replace('\r\n','\n')
marker='var ai_paths_deferred := 0\n';assert marker in head
head=head.replace(marker,marker+fields,1)
marker='\tif motion_clear(from,to,ignore_actor,avoid_actors,ignore_crate):\n\t\treturn PackedVector2Array([to])\n\tif static_nav_dirty:';assert marker in head
head=head.replace(marker,marker.replace('\tif static_nav_dirty:',check+'\tif static_nav_dirty:'),1)
marker='func _path_on_grid(';assert marker in head
head=head.replace(marker,helpers+marker,1)
blob=subprocess.check_output(['git','hash-object','-w','--stdin'],input=head.encode('utf-8')).decode().strip()
subprocess.run(['git','update-index','--add','--cacheinfo','100644,'+blob+','+src],check=True)
view='scripts/presentation/doorway_view.gd'
assert subprocess.check_output(['git','show','HEAD:'+view]).decode('utf-8')==(p/'doorway_view-before.txt').read_text(encoding='utf-8')
subprocess.run(['git','add','--',view],check=True)
audit=[{'file':src,'method':'only sealed-room cache, proof and early return applied to HEAD; existing map-route WIP left unstaged'},{'file':view,'method':'clean HEAD baseline; only ground-layer change staged'},{'file':'qa/p87_before_world.gd','method':'exact pre-task runtime snapshot as isolated before-benchmark fixture; not used by application'}]
(p/'index-audit.json').write_text(json.dumps(audit,indent=2)+'\n',encoding='utf-8')
subprocess.run(['git','diff','--cached','--check'],check=True)
subprocess.run(['git','diff','--cached','--stat'],check=True)
