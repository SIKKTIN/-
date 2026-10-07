extends SceneTree

var game
var checks := {}
var pictures := []

func _initialize() -> void: call_deferred("run")
func check(label: String, value: bool) -> void:
	checks[label] = value
	print(label+": "+str(value))

func refresh(point: Vector2, duration := 0.25) -> void:
	game.actors[0].position = point
	game.room_visibility.tick(duration)
	game.presentation.tick(0)

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.presentation.tick(0)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/tests/p76-"+name+".png"
	root.get_texture().get_image().save_png(path)
	pictures.append(path)
	if name in ["outside-covered","inside-revealed"]:
		var point: Vector2 = game.mini_map.global_position+game.mini_map.to_map(game.actors[1].position)
		var pixel: Color = root.get_texture().get_image().get_pixel(roundi(point.x),roundi(point.y))
		var is_green := pixel.g > pixel.r+0.2 and pixel.b > pixel.r+0.15
		check("minimap_hidden_worker_no_dot" if name=="outside-covered" else "minimap_visible_worker_has_dot",not is_green if name=="outside-covered" else is_green)

func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],70)
	game.routine_panel.close()
	for actor in game.actors: actor.immune_until = INF
	var rules = game.room_visibility
	check("birth_dorm_revealed",rules.active_id=="dorm-0" and rules.visible_at(game.actors[0].position))
	check("other_dorm_not_revealed",not rules.visible_at(game.actors[1].position))
	check("independent_rooms",rules.rooms.size()>=8 and rules.rooms.filter(func(r): return r.kind=="dorm").size()==3 and rules.rooms.filter(func(r): return r.kind=="confinement").size()==3)
	check("expanded_enclosed_rooms",["warehouse","laundry","equipment"].all(func(id): return rules.rooms.any(func(r): return r.id==id)))
	game.map_camera.following = false
	game.map_camera.center_on(Vector2(1120,570))
	refresh(Vector2(620,1040))
	var worker = game.actors[1]
	worker.position = Vector2(1230,330)
	game.routines.resume(1)
	var overseer = game.workshop.overseer
	game.presentation.tick(0)
	check("corridor_visible",rules.visible_at(game.actors[0].position) and rules.active_id.is_empty())
	check("npc_inside_does_not_reveal",not rules.visible_at(worker.position))
	check("hidden_npc_keeps_logical_presence",worker.visible and not worker.escaped)
	check("hidden_npc_body_not_drawn",game.presentation.visuals.filter(func(v): return v.actor==worker).all(func(v): return not v.visible))
	check("hidden_overseer_warning_not_drawn",game.presentation.guard_warnings.values().filter(func(w): return w.officer==overseer).all(func(w): return not w.visible))
	check("hidden_npc_not_in_dialogue",not game.dialogue.targets().any(func(t): return t.node==worker or t.node==overseer))
	check("hidden_overseer_distraction_rejected",not game.skills.chat_reason(game.actors[0],overseer).is_empty())
	var gate: Dictionary = game.world.access_by_id("workshop-entry")
	game.world.set_access_closed("workshop-entry",false)
	check("open_door_does_not_reveal",not rules.visible_at(overseer.position))
	var cover = rules.covers.filter(func(c): return c.room.id=="workshop")[0]
	check("outside_roof_opaque",cover.visible and cover.modulate.a==1)
	await shot("outside-covered")
	var id: String = game.inventory.add_ground("scrap",Vector2(1185,782))
	refresh(Vector2(1185,804))
	check("threshold_requires_entry",rules.active_id.is_empty())
	check("hidden_pickup_rejected",not game.inventory.try_pickup(0,id).ok)
	refresh(Vector2(1185,794),0.05)
	check("foot_crossing_reveals",rules.active_id=="workshop")
	check("roof_fades_not_instant",cover.modulate.a>0 and cover.modulate.a<1)
	refresh(Vector2(1185,802),0.01)
	check("doorway_hysteresis",rules.active_id=="workshop")
	refresh(Vector2(850,330))
	check("inside_roof_removed",not cover.visible and cover.modulate.a==0)
	check("inside_other_rooms_still_hidden",not rules.visible_at(Vector2(320,570)))
	check("inside_npc_and_dialogue_visible",rules.visible_at(worker.position) and game.dialogue.targets().any(func(t): return t.node==worker))
	check("interior_furniture_visible",game.presentation.volumes.filter(func(v): return v.kind=="fixture" and rules.room_at(v.footprint.get_center())=="workshop").any(func(v): return v.visible))
	game.map_camera.center_on(Vector2(1120,570))
	await shot("inside-revealed")
	refresh(Vector2(620,1040),0.05)
	check("leaving_hides_people_immediately",not rules.visible_at(worker.position) and not game.dialogue.targets().any(func(t): return t.node==worker))
	check("leaving_roof_fades_back",cover.modulate.a>0 and cover.modulate.a<1)
	rules.tick(0.3)
	check("leaving_roof_opaque",cover.modulate.a==1)
	check("visited_is_memory_not_live_vision",rules.visited.has("workshop") and not rules.visible_at(worker.position))
	await shot("left-covered-again")
	refresh(Vector2(1185,782))
	worker.position=Vector2(1185,750)
	game.presentation.tick(0)
	check("inside_dialogue_opens",game.dialogue.open("prisoner:1"))
	refresh(Vector2(1185,812))
	game.dialogue.tick()
	check("leaving_closes_hidden_dialogue",not game.dialogue.panel.visible)
	worker.position=Vector2(1230,330)
	game.routines.resume(1)
	var previous_room: String=rules.active_id
	paused=true
	game.actors[0].position=Vector2(850,330)
	rules.tick(1)
	check("pause_freezes_visibility_transition",rules.active_id==previous_room)
	paused=false
	rules.tick(0.25)
	refresh(Vector2(620,1040))
	var collision: Array=[]
	for index in range(100): collision.append(game.world.can_place_circle(Vector2(800+(index%10)*100,250+(index/10)*100),17,null,false))
	refresh(Vector2(850,330))
	check("visibility_never_changes_collision",range(100).all(func(index): return collision[index]==game.world.can_place_circle(Vector2(800+(index%10)*100,250+(index/10)*100),17,null,false)))
	refresh(Vector2(620,1040))
	var work_before: float = game.routines.work_minutes[1]
	game.schedule.clock_elapsed=(600-float(game.schedule.config.start_minutes))/1440.0*game.schedule.day_seconds
	game.schedule.tick(false)
	game.routines.tick()
	for step in range(30): game._process(0.05)
	check("hidden_npc_work_continues",game.routines.work_minutes[1]>work_before)
	var old_position: Vector2 = overseer.position
	for step in range(20): game._process(0.05)
	check("hidden_overseer_keeps_patrolling",old_position.distance_to(overseer.position)>1)
	game.presentation.lighting.set_period("night")
	game.presentation.lighting.tick()
	check("hidden_room_lamps_disabled",game.presentation.lighting.lamps.all(func(lamp): return not game.world.is_under_roof(lamp.position) or not lamp.enabled))
	game.room_access.capture(1)
	game.presentation.tick(0)
	check("hidden_cell_label_does_not_reveal_occupant",game.presentation.roof_buildings.filter(func(b): return b.spec.cell_id=="cell-1").all(func(b): return not b.status_label.text.contains("伙伴2")))
	game.room_access.capture(0)
	rules.tick(0.25)
	game.presentation.tick(0)
	check("custody_reveals_own_cell",rules.active_id=="cell-0" and rules.visible_at(game.actors[0].position))
	check("own_solitary_shell_removed",game.presentation.roof_buildings.filter(func(b): return b.spec.cell_id=="cell-0").all(func(b): return not b.visible))
	check("other_solitary_keeps_shell",game.presentation.roof_buildings.filter(func(b): return b.spec.cell_id=="cell-1").all(func(b): return b.visible))
	check("cell_walls_restored_inside",game.presentation.volumes.filter(func(v): return v.kind=="wall" and game.world.roofed_cells[0].rect.grow(1).encloses(v.footprint)).all(func(v): return v.visible))
	game.map_camera.center_on(Vector2(370,1270))
	await shot("custody-inside")
	game.room_access.release(0)
	rules.tick(0.25)
	game.presentation.tick(0)
	check("release_recloses_cell_view",not rules.visible_at(Vector2(285,1280)))
	game.reset_round(["chat","lockpick","backpack"],70)
	game.routine_panel.close()
	check("new_round_resets_memory",rules.visited.size()==1 and rules.active_id=="dorm-0")
	var Document = load("res://scripts/editor/map_document.gd")
	var document = Document.new()
	var map_hash := FileAccess.get_sha256("res://data/rooms/r04.json")
	check("editor_loads_regions",document.open_file("res://data/rooms/r04.json") and document.collection("visibility_rooms").size()==rules.rooms.size())
	var layer = load("res://scripts/editor/map_layers.gd").new()
	check("dedicated_visibility_layer",layer.key_for("visibility_rooms")=="visibility" and not layer.is_visible("visibility_rooms"))
	layer.preset("solo","visibility")
	check("layer_solo",layer.is_visible("visibility_rooms") and not layer.is_visible("walls"))
	var ref: Dictionary = document.add("visibility_rooms",Vector2(2300,1100))
	check("editor_region_rect",document.is_rect(ref) and document.geometry(ref).size==Vector2(320,240))
	var count: int = document.collection("visibility_rooms").size()
	document.undo()
	check("editor_undo_region",document.collection("visibility_rooms").size()==count-1)
	document.redo()
	check("editor_redo_region",document.collection("visibility_rooms").size()==count)
	document.set_property(ref,"door_ids",["workshop-entry"])
	check("editor_door_association",document.value(ref).door_ids==["workshop-entry"])
	document.begin()
	document.set_geometry(ref,Rect2(2300,1100,400,300))
	document.commit()
	check("editor_region_resize",document.geometry(ref).size==Vector2(400,300))
	check("editor_shape_valid",Document.check_shape(document.data).is_empty())
	var invalid: Dictionary = document.data.duplicate(true)
	invalid.visibility_rooms[0].door_ids=42
	check("invalid_door_array_rejected",not Document.check_shape(invalid).is_empty())
	invalid=document.data.duplicate(true)
	invalid.visibility_rooms[0].rect[2]=0
	check("empty_region_rejected",not Document.check_shape(invalid).is_empty())
	var trial: String = "res://data/rooms/p76_visibility_trial.json"
	check("editor_save_region",document.save_file(trial,true))
	var reopened = Document.new()
	check("editor_reload_preserves_regions",reopened.open_file(trial) and reopened.collection("visibility_rooms").size()==count and reopened.value(ref).door_ids==["workshop-entry"])
	DirAccess.remove_absolute(trial)
	check("original_map_preserved",FileAccess.get_sha256("res://data/rooms/r04.json")==map_hash)
	var canvas = load("res://scripts/editor/map_canvas.gd").new()
	root.add_child(canvas)
	canvas.size=Vector2(750,520)
	canvas.setup(document,layer)
	canvas.fit()
	await process_frame
	check("editor_preview_draws",is_instance_valid(canvas.architecture_preview) and document.entries().any(func(r): return r.group=="visibility_rooms"))
	var failed: Array = checks.keys().filter(func(k): return not checks[k])
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	var report := {"checks":checks,"failed":failed,"total":checks.size(),"rooms":rules.rooms.map(func(r): return str(r.id)),"pictures":pictures}
	FileAccess.open("res://docs/tests/p76-visibility-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
