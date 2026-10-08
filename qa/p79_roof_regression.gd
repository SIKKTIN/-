extends SceneTree

const Geometry = preload("res://scripts/presentation/roof_geometry.gd")
var game
var checks := {}
var pictures: Array = []

func _initialize() -> void: call_deferred("run")
func check(label: String, value: bool) -> void:
	checks[label] = value
	print(label+": "+str(value))

func refresh(point: Vector2, dt := 0.3) -> void:
	game.actors[0].position = point
	game.room_visibility.tick(dt)
	game.presentation.tick(0)

func shot(label: String, point: Vector2, overview := false) -> void:
	if DisplayServer.get_name()=="headless": return
	game.map_camera.zoom = Vector2.ONE*0.29 if overview else Vector2.ONE
	game.map_camera.position = game.world.bounds.position if overview else point-Vector2(600,360)
	game.map_camera.force_update_scroll()
	game.presentation.tick(0)
	if overview: game.get_node("HUD").hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/tests/p79-"+label+".png"
	root.get_texture().get_image().save_png(path)
	pictures.append(path)
	game.get_node("HUD").show()

func run() -> void:
	root.size = Vector2i(1200,720)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","backpack"],70)
	game.routine_panel.close()
	game.orders.clear()
	for actor in game.actors: actor.immune_until = INF
	var rules = game.room_visibility
	check("one_section_per_enclosed_room",rules.covers.size()==rules.rooms.size() and rules.covers.size()==11)
	check("four_material_styles",["concrete","dark_concrete","metal_green","metal_light"].all(func(s): return rules.covers.any(func(c): return c.style==s)))
	check("all_assets_loaded",rules.covers.all(func(c): return c.roof_texture!=null))
	check("roof_extends_to_wall_headers",rules.covers.filter(func(c): return c.room.id=="workshop").all(func(c): return c.roof.position.y<c.area.position.y))
	check("legacy_south_shell_disabled",game.presentation.roof_buildings.all(func(b): return not b.visible))
	check("side_doors_keep_original_orientation",rules.covers.filter(func(c): return c.room.kind in ["dorm","confinement"]).all(func(c): return c.ports.any(func(p): return p.side=="east")))
	check("cafeteria_has_north_and_south_ports",rules.covers.filter(func(c): return c.room.id.begins_with("cafeteria")).all(func(c): return c.ports.any(func(p):return p.side=="north") and c.ports.any(func(p):return p.side=="south")))
	check("shared_dorm_coping_seams",rules.covers.filter(func(c): return c.room.id=="dorm-1").all(func(c): return "north" in c.shared_edges and "south" in c.shared_edges))
	check("ungated_warehouse_passage_kept",rules.covers.filter(func(c): return c.room.id=="warehouse").all(func(c): return c.ports.any(func(p): return p.id=="open-passage")))
	for cover in rules.covers:
		check("no_mesh_blocks_port_"+str(cover.room.id),cover.cutouts.all(func(c):return not cover.panels.any(func(p):return p.has_point(c.get_center()))))
	var shape := Rect2(0,0,300,300)
	var ports: Array[Rect2] = [Rect2(0,100,20,80),Rect2(280,100,20,80),Rect2(100,0,80,20),Rect2(100,280,80,20)]
	var mesh := Geometry.subtract_all(shape,ports)
	check("four_direction_mesh_openings",ports.all(func(p): return not mesh.any(func(m): return m.has_point(p.get_center()))))
	check("four_direction_mesh_interior_opaque",mesh.any(func(m): return m.has_point(Vector2(150,150))))
	refresh(Vector2(740,1300))
	check("corridor_stays_outdoors",rules.active_id.is_empty() and rules.visible_at(game.actors[0].position))
	check("outside_all_sections_opaque",rules.covers.all(func(c): return c.visible and c.modulate.a==1))
	await shot("compound-covered",Vector2.ZERO,true)
	await shot("cafeteria-north-door",Vector2(1440,1420))
	await shot("confinement-side-doors",Vector2(500,1600))
	for room in rules.rooms:
		refresh(room.area.get_center())
		check("reveal_only_"+str(room.id),rules.active_id==str(room.id) and rules.covers.all(func(c): return (not c.visible) if c.room.id==room.id else c.visible))
		check("hidden_neighbours_"+str(room.id),rules.rooms.all(func(r): return rules.visible_at(r.area.get_center()) if r.id==room.id else not rules.visible_at(r.area.get_center())))
	refresh(Vector2(1300,1710))
	await shot("cafeteria-revealed",Vector2(1440,1650))
	await shot("compound-cafeteria-revealed",Vector2.ZERO,true)
	var before: Array=[]
	for i in range(200): before.append(game.world.can_place_circle(Vector2(120+(i%20)*185,260+floori(i/20.0)*210),17,null,false))
	var builds: Array = rules.covers.map(func(c): return c.draw_builds)
	var shadow_layer = game.presentation.scene_layers.filter(func(l):return l.kind=="fixture_shadows")[0]
	var shadow_builds: int = shadow_layer.fixture_shadow_builds
	refresh(Vector2(740,1300))
	for i in range(100):
		rules.tick(0.01)
		game.presentation.tick(0)
	check("visibility_keeps_collision",range(200).all(func(i): return before[i]==game.world.can_place_circle(Vector2(120+(i%20)*185,260+floori(i/20.0)*210),17,null,false)))
	check("cached_meshes_not_redrawn_on_ticks",range(builds.size()).all(func(i): return builds[i]==rules.covers[i].draw_builds))
	check("shadow_geometry_cache_reused",shadow_layer.fixture_shadow_builds==shadow_builds)
	check("leave_restores_all_roofs",rules.covers.all(func(c): return c.visible and c.modulate.a==1))
	var worker = game.actors[1]
	worker.position = rules.rooms.filter(func(r):return r.id=="workshop")[0].area.get_center()
	game.presentation.tick(0)
	check("hidden_npc_dialogue_filtered",not game.dialogue.targets().any(func(t):return t.node==worker))
	check("hidden_npc_visual_filtered",game.presentation.visuals.filter(func(v):return v.actor==worker).all(func(v):return not v.visible))
	check("doors_stay_visible_under_hidden_sections",game.presentation.volumes.filter(func(v):return v.kind=="fixture" and game.world.fixtures[v.wall_index].has("access_id")).all(func(v):return v.visible))
	await shot("left-cafeteria-covered",Vector2(1440,1420))
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var report := {"checks":checks,"failed":failed,"total":checks.size(),"pictures":pictures,"sections":rules.covers.map(func(c):return {"id":c.room.id,"style":c.style,"area":str(c.area),"roof":str(c.roof),"ports":c.ports.map(func(p):return p.side),"shared_edges":c.shared_edges,"panels":c.panels.size()})}
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open("res://docs/tests/p79-roofs-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ROOF_REPORT "+JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)
