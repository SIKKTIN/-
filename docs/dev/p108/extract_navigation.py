"""Extract path planning while retaining the world's collision/API state."""
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=ROOT/'scripts/world/prison_world.gd'
s=p.read_text(encoding='utf-8-sig')
names=['_rebuild_navigation','_finish_navigation','_refresh_navigation_cells','_navigation_sets','_prefer_portal_grid','_nearest_nav_point','find_path','_find_path','_sealed_room_separates','_closed_perimeter','_path_on_grid','_overlay_rect']
fields=set(re.findall(r'^(?:var|const)\s+(\w+)',s,re.M))
methods=set(re.findall(r'^func\s+(\w+)',s,re.M))-set(names)
globals=(fields|methods)-{'RADIUS','GRID_SIZE'}
tokens=re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*|\b[A-Za-z_]\w*\b')
bodies=[]
for name in names:
    m=re.search(r'^func '+name+r'\([^\n]*\n.*?(?=^func |\Z)',s,re.M|re.S)
    assert m,name
    old=m.group(); signature,body=old.split('\n',1)
    def qualify(m):
        t=m.group()
        return 'world.'+t if t in globals and (m.start()==0 or body[m.start()-1]!='.') else t
    code=tokens.sub(qualify,body)
    # Dynamic facade properties have Variant return types. Explicitly typed
    # locals remain typed; Variant-facing inferred bindings use normal '='.
    code=re.sub(r'^(\s*var \w+) := (.*world\..*)$',r'\1 = \2',code,flags=re.M)
    bodies.append(signature+'\n'+code)
    parameters=signature[signature.index('(')+1:signature.rindex(')')]
    args=[]
    for param in parameters.split(','):
        if param.strip():args.append(re.match(r'\s*(\w+)',param).group(1))
    prefix='' if '-> void:' in signature else 'return '
    wrapper=signature+'\n\t'+prefix+'navigation.'+name+'('+','.join(args)+')\n\n'
    s=s[:m.start()]+wrapper+s[m.end():]
helper='''extends RefCounted

# Cached grid planning and AI search budget. Collision/admission rules remain
# in PrisonWorld; all grids and counters retain their existing world API.
const RADIUS := preload("res://scripts/core/actor_footprint.gd").RADIUS
const GRID_SIZE := 20.0
var world

func _init(owner_world) -> void:
	world = owner_world

'''+''.join(bodies)
(ROOT/'scripts/world/world_navigation.gd').write_text(helper,encoding='utf-8')
s=s.replace('const GRID_SIZE := 20.0','const GRID_SIZE := 20.0\nvar navigation = preload("res://scripts/world/world_navigation.gd").new(self)')
p.write_text(s,encoding='utf-8')
print('Extracted cached navigation with unchanged public collision/path APIs.')
