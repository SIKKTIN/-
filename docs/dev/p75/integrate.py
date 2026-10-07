from pathlib import Path

def edit(p, old, new):
    path=Path(p)
    s=path.read_text(encoding='utf-8-sig')
    assert old in s,(p,old)
    path.write_bytes(s.replace(old,new).encode('utf-8'))

edit('scripts/core/escape_game.gd','const GateWatch =','const StaffTraffic = preload("res://scripts/core/staff_traffic.gd")\nconst GateWatch =')
edit('scripts/core/escape_game.gd','var gate_watch','var staff_traffic\nvar gate_watch')
edit('scripts/core/escape_game.gd','\tgate_watch = GateWatch.new(self)','\tstaff_traffic = StaffTraffic.new(self)\n\tgate_watch = GateWatch.new(self)')
edit('scripts/core/escape_game.gd','\tif gate_watch:\n\t\tgate_watch.tick(delta)','\tif staff_traffic:\n\t\tstaff_traffic.update_gate()\n\tif gate_watch:\n\t\tgate_watch.tick(delta)')
edit('scripts/core/escape_game.gd','\tif prison_alert:\n\t\tprison_alert.reset()','\tif staff_traffic:\n\t\tstaff_traffic.reset()\n\tif prison_alert:\n\t\tprison_alert.reset()')
edit('scripts/actors/guard.gd','\treturn allowed_zone().grow(-radius).has_point(point)','\tif game.staff_traffic and game.staff_traffic.transiting(self):\n\t\treturn world.bounds.grow(-radius).has_point(point) or staff_exterior_allowed(point,radius)\n\treturn allowed_zone().grow(-radius).has_point(point)\n\nfunc staff_exterior_allowed(point: Vector2, radius: float = 17.0) -> bool:\n\treturn game.staff_traffic != null and game.staff_traffic.transiting(self) and game.staff_traffic.exterior_allowed(point,radius)')
edit('scripts/actors/guard.gd','\tif not curfew_alert() and not labor_enforcement() and state in','\tif game.staff_traffic and game.staff_traffic.tick_guard(self,delta): return\n\tif not curfew_alert() and not labor_enforcement() and state in')
edit('scripts/core/gate_watch.gd','\t\tguards.append(actor)','\t\tguards.append(actor)\n\t\tgame.staff_traffic.register(actor,"gate",actor.post)')
edit('scripts/core/gate_watch.gd','func blocking() -> bool:\n','func blocking() -> bool:\n\tif game.staff_traffic and game.staff_traffic.factory_passage(): return false\n')
p=Path('scripts/actors/gate_guard.gd'); s=p.read_text(encoding='utf-8-sig'); s=s[:s.index('func tick(')]+'''func tick(delta: float) -> void:
	if game.staff_traffic and game.staff_traffic.tick_guard(self,delta): return
	if global_alert() or labor_enforcement() or state == "chasing" or position.distance_to(post) > 4:
		super.tick(delta)
		return
	moved_this_frame = false
	if game.phase != "playing" or game.get_tree().paused: return
	if state == "talking" and chat_partner_id >= 0:
		facing = position.direction_to(game.actors[chat_partner_id].position)
	else:
		state = "patrol"
		facing = Vector2.LEFT
	target_id = -1
'''; p.write_bytes(s.encode())
edit('scripts/actors/gate_guard.gd','return on_duty() and not global_alert()','return not escaped and not game.staff_traffic.transiting(self) and on_duty() and not global_alert()')
edit('scripts/actors/workshop_overseer.gd','\tif not rules.on_duty():','\tif game.staff_traffic and game.staff_traffic.tick_guard(self,delta): return\n\tif not rules.on_duty():')
edit('scripts/core/workshop_rules.gd','\toverseer.escaped = not on_duty()','\tgame.staff_traffic.register(overseer,"overseer",overseer.position)')
edit('scripts/core/workshop_rules.gd','\tgame.world.set_access_closed(str(config.access_id),not open)','\tif game.staff_traffic and game.staff_traffic.workshop_passage(): open = true\n\tgame.world.set_access_closed(str(config.access_id),not open)')
edit('scripts/core/workshop_rules.gd','\t\toverseer.escaped = not overseer.global_alert()\n\t\tif not overseer.escaped: overseer.tick(delta)','\t\toverseer.tick(delta)')
edit('scripts/core/workshop_rules.gd','\toverseer.escaped = false\n\tfor actor','\tif overseer.escaped or game.staff_traffic.transiting(overseer):\n\t\toverseer.tick(delta)\n\t\treturn\n\tfor actor')
edit('scripts/world/prison_world.gd','\tif not inside_room(point, radius):','\tif not inside_room(point, radius) and not _staff_exterior(ignore_actor,point,radius):')
edit('scripts/world/prison_world.gd','func can_place_circle(','func _staff_exterior(actor, point: Vector2, radius: float = RADIUS) -> bool:\n\treturn actor != null and actor.has_method("staff_exterior_allowed") and actor.staff_exterior_allowed(point,radius)\n\nfunc can_place_circle(')
edit('scripts/world/prison_world.gd','\tif not inside_room(from) or not inside_room(to):','\tif (not inside_room(from) and not _staff_exterior(ignore_actor,from)) or (not inside_room(to) and not _staff_exterior(ignore_actor,to)):')
edit('scripts/presentation/actor_visual.gd','\t\t\t\tlabel = "监工追捕！" if actor.state == "chasing" else "监工 · 查岗"','\t\t\t\tlabel = "监工追捕！" if actor.state == "chasing" else "监工 · 查岗"\n\t\t\tif game.staff_traffic:\n\t\t\t\tvar commute: String = game.staff_traffic.label(actor)\n\t\t\t\tif not commute.is_empty(): label = commute')
edit('scripts/core/prison_alert.gd','\treset()\n\tcleared_minute = now','\tactive = false\n\tmissing_ids.clear()\n\tchecked_rooms.clear()\n\troutes.clear()\n\tinspection_day = -1\n\ttriggered_minute = -1\n\tcleared_minute = now')
p=Path('scripts/core/prison_alert.gd'); s=p.read_text(encoding='utf-8-sig'); a=s.index('\tfor index in range(2):',s.index('func _raise_alarm')); b=s.index('\tvar search_points:',a); s=s[:a]+'''	while reinforcements.size() < 2:
		var officer = Guard.new()
		officer.name = "SearchReinforcement%d" % (reinforcements.size()+1)
		game.add_child(officer)
		officer.configure(game.world,game)
		reinforcements.append(officer)
		game.staff_traffic.register(officer,"reinforcement",game.world.door.get_center()-Vector2(90,0),true)
		game.gate_watch.attach_visual(officer)
'''+s[b:]; s=s.replace('\t\tofficer.escaped = false\n\t\tofficer.show()','\t\t# Presence is controlled by crossing the exterior boundary, not the alarm.'); s=s.replace('\tif active and game.phase == "playing" and not game.get_tree().paused:','\tif game.phase == "playing" and not game.get_tree().paused:'); p.write_bytes(s.encode())
