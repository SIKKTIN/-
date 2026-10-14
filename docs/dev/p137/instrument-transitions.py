from pathlib import Path
root=Path(__file__).resolve().parents[3]
p=root/'qa/p137_transition_navigation.gd'
s=p.read_text('utf-8')
b=(root/'scripts/world/world_navigation.gd').read_text('utf-8')
start=b.index('func _refresh_navigation_cells(')
end=b.index('\nfunc ',start+1)
body=b[start:end].replace(' -> void:\n',' -> void:\n\tvar checkpoint:=Time.get_ticks_usec()\n',1)
body=body.replace('\tvar cells: Dictionary = {}','\tvar index_ms: float=(Time.get_ticks_usec()-checkpoint)/1000.0\n\tcheckpoint=Time.get_ticks_usec()\n\tvar cells: Dictionary = {}')
body+='\n\trefresh_details.append({"index_ms":index_ms,"cells_ms":(Time.get_ticks_usec()-checkpoint)/1000.0,"cells":cells.size()})\n'
a=s.index('func _refresh_navigation_cells(')
z=s.index('\nfunc ',a+1)
s=s[:a]+body+s[z:]
if 'var refresh_details:' not in s:
    s=s.replace('var rebuild_ms: Array=[]','var rebuild_ms: Array=[]\nvar refresh_details: Array=[]\nvar finish_ms: Array=[]')
    s+='\nfunc _finish_navigation(layout: Array) -> void:\n\tvar mark:=Time.get_ticks_usec()\n\tsuper._finish_navigation(layout)\n\tfinish_ms.append((Time.get_ticks_usec()-mark)/1000.0)\n'
p.write_text(s,'utf-8')
p=root/'qa/p137_transitions.gd'
s=p.read_text('utf-8')
if '"refresh_details":' not in s:
    s=s.replace('"body_rects":','"refresh_details":game.world.pathfinding.refresh_details.duplicate(true),"finish_ms":game.world.pathfinding.finish_ms.duplicate(),"body_rects":')
    s=s.replace('game.world.pathfinding.cells_ms.clear()','game.world.pathfinding.cells_ms.clear()\n\tgame.world.pathfinding.refresh_details.clear()\n\tgame.world.pathfinding.finish_ms.clear()')
p.write_text(s,'utf-8')
