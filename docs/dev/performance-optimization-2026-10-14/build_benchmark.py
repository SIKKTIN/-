from pathlib import Path
root=Path(__file__).resolve().parents[3]
s=(root/'qa/performance_audit_20261014/run.gd').read_text(encoding='utf8').replace('performance_audit_20261014','performance_optimization_20261014').replace('performance-audit-2026-10-14/','performance-optimization-2026-10-14/')
a=s.index(' game.schedule.clock_elapsed=0;game.schedule.tick(false)')
b=s.index(' var textures: Array=[];var seen: Dictionary={}',a)
s=s[:a]+''' game.schedule.clock_elapsed=0;game.schedule.tick(false)
 await visit(Vector2(1640,1750))
 game.schedule.set_time_speed(1)
 game.frame_settings.apply(60,false)
 await sample("cap60_running",900)
 game.frame_settings.apply(0,false)
 await sample("uncapped_running",600)
 game.actors[0].immune_until=0
 game.schedule.clock_elapsed=(21*60.0-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
 game.schedule.tick(false)
 game.guard.position=game.actors[0].position+Vector2(150,0)
 game.guard.state="chasing";game.guard.target_id=0
 await sample("night_chase",300)
 game.set_process(false);game.profile_total_ms=0;game.profile_sections.clear();game.presentation.profile_times.clear()
 await sample("frozen_simulation")
'''+s[b:]
s=s.replace(' FileAccess.open("res://docs/dev/performance-optimization',' report.baked_hits=preload("res://scripts/presentation/runtime_texture_store.gd").hits\n report.baked_misses=preload("res://scripts/presentation/runtime_texture_store.gd").misses\n FileAccess.open("res://docs/dev/performance-optimization')
s=s.replace(' await sample("workshop_idle")',' await sample("workshop_apron_same_baseline")\n await visit(Vector2(1500,1380))\n await sample("workshop_interior")')
(root/'qa/performance_optimization_20261014/run.gd').write_text(s,encoding='utf8')
