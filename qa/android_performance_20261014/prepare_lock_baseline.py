from pathlib import Path
root=Path(__file__).resolve().parents[2]
dest=Path(__file__).parent
world=(root/'scripts/world/prison_world.gd').read_text(encoding='utf8')
methods=[]
for name in ['set_access_closed','update_dorm_doors']:
    start=world.index('func '+name+'(')
    end=world.index('\nfunc ',start+1)
    methods.append(world[start:end].replace(' and not gate.closed',''))
(dest/'lock_baseline_world.gd').write_text('extends "res://scripts/world/prison_world.gd"\n'+'\n'.join(methods),encoding='utf8')
(dest/'lock_baseline_game.gd').write_text('extends "res://scripts/core/escape_game.gd"\nfunc _make_world():return preload("res://qa/android_performance_20261014/lock_baseline_world.gd").new()\n',encoding='utf8')
test=(root/'qa/p127_full_body_doors.gd').read_text(encoding='utf8')
test=test.replace('game=load("res://scenes/main.tscn").instantiate()','game=preload("res://qa/android_performance_20261014/lock_baseline_game.gd").new()\n\tgame.room_id="r04"')
test=test.replace('res://docs/tests/p127-full-body-doors.json','res://docs/tests/timed-card-lock/legacy-collision-baseline.json')
(dest/'lock_baseline_collision.gd').write_text(test,encoding='utf8')
