from pathlib import Path
root=Path(__file__).resolve().parents[3]
s=(root/'qa/p137_full_day_final.gd').read_text(encoding='utf8')
s=s.replace('res://qa/p137_pacing_game.gd','res://qa/performance_optimization_20261014/game.gd').replace('res://docs/dev/p137/','res://docs/dev/performance-optimization-2026-10-14/')
s=s.replace('game.world.pathfinding.frame_records','game.world.pathfinding.audit_records')
s=s.replace(' await frame()',' await frame()')
# Clear the per-frame navigation log after reading it. The final game uses
# the current production bootstrap/frame with only timers added.
s=s.replace('\t\tif (now-start_usec)/1000000.0>930:break','\t\tgame.world.pathfinding.audit_records.clear()\n\t\tif (now-start_usec)/1000000.0>930:break')
(root/'qa/performance_optimization_20261014/full_day.gd').write_text(s,encoding='utf8')
