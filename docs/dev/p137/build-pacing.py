from pathlib import Path
root=Path(__file__).resolve().parents[3]
qa=root/'qa'
frame=(qa/'p137_frame.gd').read_text('utf-8')
for call,label in [('game.room_access.tick()','room_access'),('game.routines.tick()','routines'),('game.npc_life.tick(delta)','npc_life'),('game.staff_traffic.update_gate()','staff_traffic'),('game.gate_watch.tick(delta)','gate_watch'),('game.guard.tick(delta)','guard'),('game.workshop.tick(delta)','workshop'),('game.prison_alert.tick(delta)','prison_alert')]:
    lines=frame.splitlines()
    for i,line in enumerate(lines):
        if line.strip()==call:
            indent=line[:len(line)-len(line.lstrip())]
            lines[i:i+1]=[indent+'var fine_start_'+label+':=Time.get_ticks_usec()',line,indent+'game.profile_sections["fine_'+label+'"]=(Time.get_ticks_usec()-fine_start_'+label+')/1000.0']
            break
    else:
        # One-line conditional NPC call in the authoritative frame.
        old='\tif game.npc_life: game.npc_life.tick(delta)'
        assert label=='npc_life' and old in frame
        frame=frame.replace(old,'\tif game.npc_life:\n\t\tvar fine_start_npc_life:=Time.get_ticks_usec()\n\t\tgame.npc_life.tick(delta)\n\t\tgame.profile_sections["fine_npc_life"]=(Time.get_ticks_usec()-fine_start_npc_life)/1000.0')
        continue
    frame='\n'.join(lines)+'\n'
(qa/'p137_pacing_frame.gd').write_text(frame,'utf-8')
layer='extends "res://scripts/presentation/scene_layers.gd"\nvar draw_ms:=0.0\nfunc _draw() -> void:\n\tvar mark:=Time.get_ticks_usec()\n\tsuper._draw()\n\tdraw_ms=(Time.get_ticks_usec()-mark)/1000.0\n'
(qa/'p137_pacing_layer.gd').write_text(layer,'utf-8')
presentation=(root/'scripts/presentation/game_presentation.gd').read_text('utf-8').replace('preload("res://scripts/presentation/scene_layers.gd")','preload("res://qa/p137_pacing_layer.gd")')
(qa/'p137_pacing_presentation.gd').write_text(presentation,'utf-8')
bootstrap=(root/'scripts/core/game_bootstrap.gd').read_text('utf-8').replace('game.presentation = game.Presentation.new()','game.presentation = preload("res://qa/p137_pacing_presentation.gd").new()')
(qa/'p137_pacing_bootstrap.gd').write_text(bootstrap,'utf-8')
nav=(root/'scripts/world/world_navigation.gd').read_text('utf-8')
start=nav.index('func _path_on_grid(')
end=nav.index('\nfunc ',start+1)
pathbody=nav[start:end]
pathbody=pathbody.replace('\t# Overlay','\tvar nav_mark:=Time.get_ticks_usec()\n\tvar subtrace: Dictionary={"grid": "inspection" if navigation==world.inspection_grid else "portal_inspection" if navigation==world.portal_inspection_grid else "other"}\n\tcurrent_trace.subsearches.append(subtrace)\n\t# Overlay',1)
pathbody=pathbody.replace('\tvar raw := PackedVector2Array()','\tsubtrace["overlay_endpoints_ms"]=(Time.get_ticks_usec()-nav_mark)/1000.0\n\tvar raw := PackedVector2Array()')
pathbody=pathbody.replace('\t\traw = navigation.get_point_path(start,finish)','\t\tvar astar_mark:=Time.get_ticks_usec()\n\t\traw = navigation.get_point_path(start,finish)\n\t\tsubtrace["astar_ms"]=(Time.get_ticks_usec()-astar_mark)/1000.0\n\t\tsubtrace["astar_raw_points"]=raw.size()')
pathbody=pathbody.replace('\t\t\treturn PackedVector2Array()','\t\t\tsubtrace["total_ms"]=(Time.get_ticks_usec()-nav_mark)/1000.0\n\t\t\treturn PackedVector2Array()')
pathbody=pathbody.replace('\treturn result','\tsubtrace["total_ms"]=(Time.get_ticks_usec()-nav_mark)/1000.0\n\treturn result')
nav_wrapper='''extends "res://scripts/world/world_navigation.gd"
var frame_records: Array=[]
var current_trace: Dictionary={}
func find_path(from: Vector2,to: Vector2,ignore_actor=null,avoid_actors: bool=false,ignore_crate: bool=false) -> PackedVector2Array:
\tcurrent_trace={"from":str(from),"to":str(to),"actor":ignore_actor.get_script().resource_path if ignore_actor!=null else "none","state":str(ignore_actor.get("state")) if ignore_actor!=null else "none","subsearches":[]}
\tvar mark:=Time.get_ticks_usec()
\tvar result:=super.find_path(from,to,ignore_actor,avoid_actors,ignore_crate)
\tcurrent_trace["total_ms"]=(Time.get_ticks_usec()-mark)/1000.0
\tcurrent_trace["path_points"]=result.size()
\tframe_records.append(current_trace)
\treturn result
'''
(qa/'p137_pacing_navigation.gd').write_text(nav_wrapper+pathbody,'utf-8')
(qa/'p137_pacing_game.gd').write_text('extends "res://scripts/core/escape_game.gd"\nvar profile_sections: Dictionary={}\nvar profile_total_ms:=0.0\nfunc _ready() -> void:\n\tpreload("res://qa/p137_pacing_bootstrap.gd").configure(self)\n\tworld.pathfinding=preload("res://qa/p137_pacing_navigation.gd").new(world)\nfunc _process(delta: float) -> void:\n\tvar mark:=Time.get_ticks_usec()\n\tworld.pathfinding.frame_records.clear()\n\tpreload("res://qa/p137_pacing_frame.gd").tick(self,delta)\n\tprofile_total_ms=(Time.get_ticks_usec()-mark)/1000.0\n','utf-8')
print('Native automatic-process pacing instrumentation ready.')
