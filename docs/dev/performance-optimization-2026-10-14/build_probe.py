from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[3]
out=root/'qa/performance_optimization_20261014'
out.mkdir(exist_ok=True)
sources=['scripts/core/game_frame.gd','scripts/core/game_bootstrap.gd','scripts/presentation/game_presentation.gd']
hashes={p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in sources}
(Path(__file__).parent/'source-hashes.json').write_text(json.dumps(hashes,indent=2),encoding='utf8')
src=(root/sources[0]).read_text(encoding='utf-8-sig')
markers={'\tdelta = minf':'clock','\tif game.room_access:':'room_access','\tif game.workshop:':'workshop_gate','\tvar work_credit:':'accrual_routines','\tif game.npc_life:':'npc_life','\tgame.world.begin_ai_paths()':'ai_begin','\tif game.staff_traffic:':'staff_traffic','\tif game.gate_watch:':'gate_watch','\tif game.mobile_controls:':'mobile_input','\tgame.orders.tick':'orders','\tgame.trade.tick':'trade','\tif game.resident_staff:':'resident_staff','\tgame.skills.tick':'skills','\tgame.dog.tick':'dog','\tgame.guard.tick':'guard','\tif game.prison_alert:':'alert','\tgame.world.end_ai_paths()':'ai_end','\tif game.room_visibility:':'visibility','\tif game.dialogue:':'dialogue','\tif game.looting:':'loot','\tif game.bath_service:':'bath','\tif game.social:':'social','\tif game.tutorial:':'tutorial','\tif game.schedule and':'timeout','\tgame.guard_position':'camera','\tgame._update_ui':'hud','\tif game.presentation:':'presentation'}
lines=src.splitlines();result=[];active=False;prev=None;seen={}
for line in lines:
 if line.startswith('\tdelta = minf'):
  result+=['\tgame.profile_sections.clear()','\tvar audit_mark: int = Time.get_ticks_usec()'];active=True
 if active:
  name=next((v for k,v in markers.items() if line.startswith(k)),None)
  if name:
   seen[name]=seen.get(name,0)+1;name+=str(seen[name]) if seen[name]>1 else ''
   if prev: result += [f'\tgame.profile_sections["{prev}"]=(Time.get_ticks_usec()-audit_mark)/1000.0','\taudit_mark=Time.get_ticks_usec()']
   prev=name
 result.append(line)
if prev:result.append(f'\tgame.profile_sections["{prev}"]=(Time.get_ticks_usec()-audit_mark)/1000.0')
(out/'frame.gd').write_text('\n'.join(result)+'\n',encoding='utf8')
src=(root/sources[1]).read_text(encoding='utf-8-sig').replace('game.presentation = game.Presentation.new()','game.presentation = preload("res://qa/performance_optimization_20261014/presentation.gd").new()')
(out/'bootstrap.gd').write_text(src,encoding='utf8')
src=(root/sources[2]).read_text(encoding='utf-8-sig');start=src.index('func tick(delta: float)');end=src.index('\nfunc _loop',start)
tick=src[start:end];lines=tick.splitlines();result=['extends "res://scripts/presentation/game_presentation.gd"','var profile_times: Dictionary = {}'];prev=None
marks={'\tvar view:':'actors','\tif dog_visual:':'dog','\t_tick_scene()':'scene','\tif game.items_view:':'items','\tif lighting:':'lighting','\tif interaction:':'interaction','\tvar now :=':'audio'}
for line in lines:
 if line.startswith('func tick'):result+=[line,'\tprofile_times.clear()','\tvar audit_mark: int = Time.get_ticks_usec()'];continue
 name=next((v for k,v in marks.items() if line.startswith(k)),None)
 if name:
  if prev:result += [f'\tprofile_times["{prev}"]=(Time.get_ticks_usec()-audit_mark)/1000.0','\taudit_mark=Time.get_ticks_usec()']
  prev=name
 result.append(line)
result.append(f'\tprofile_times["{prev}"]=(Time.get_ticks_usec()-audit_mark)/1000.0')
(out/'presentation.gd').write_text('\n'.join(result)+'\n',encoding='utf8')
(out/'game.gd').write_text('''extends "res://scripts/core/escape_game.gd"
var profile_sections: Dictionary = {}
var profile_total_ms: float = 0
func _make_world():
 return preload("res://qa/performance_optimization_20261014/world.gd").new()
func _ready() -> void:
 preload("res://qa/performance_optimization_20261014/bootstrap.gd").configure(self)
func _process(delta: float) -> void:
 var mark: int = Time.get_ticks_usec()
 preload("res://qa/performance_optimization_20261014/frame.gd").tick(self,delta)
 profile_total_ms=(Time.get_ticks_usec()-mark)/1000.0
''',encoding='utf8')
print('Probe generated from current production source',hashes)
