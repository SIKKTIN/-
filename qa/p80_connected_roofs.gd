extends SceneTree

var game
var checks := {}
var images := []
var timings := []
var pixel_masks := {}

func _initialize() -> void: call_deferred("run")
func check(label: String, value: bool) -> void:
	checks[label] = value
	print(label+": "+str(value))
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func reveal(point: Vector2) -> void:
	game.actors[0].position = point
	game.room_visibility.tick(0.3)
	game.presentation.tick(0)
func picture(label: String) -> Image:
	await frame()
	await frame()
	var image: Image = root.get_texture().get_image()
	var path := "res://docs/tests/p80-"+label+".png"
	if label.ends_with("-covered"):
		var rects := []
		for edge in game.room_visibility.wall_edges.edges:
			var transform: Transform2D = edge.get_global_transform_with_canvas()
			for clip in edge.clips:
				var screen := Rect2(transform*clip.position,clip.size*game.map_camera.zoom).grow(-2).intersection(Rect2(Vector2.ZERO,Vector2(root.size)))
				if screen.has_area(): rects.append([screen.position.x,screen.position.y,screen.size.x,screen.size.y])
		pixel_masks[label.trim_suffix("-covered")] = rects
	image.save_png(path)
	images.append(path)
	return image
func run() -> void:
	OS.set_environment("ESCAPE_FRAME_MODE","60")
	root.size = Vector2i(1200,900)
	root.content_scale_size = root.size
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["lockpick","chat","backpack"],80)
	game.routine_panel.close()
	game.schedule.set_time_speed(0)
	game.get_node("HUD").hide()
	game.map_camera.following = false
	var rules = game.room_visibility
	var shell = rules.wall_edges
	check("all_rooms_use_original_wall_edges",rules.rooms.all(func(r): return r.get("retained_wall_edges",false)))
	check("retained_edges_above_roofs",shell.z_index==4095 and rules.covers.all(func(c): return c.z_index<shell.z_index))
	check("one_edge_node_per_wall",shell.edges.size()==shell.edges.map(func(e):return e.wall_index).reduce(func(a,b):a[b]=true;return a,{}).size())
	check("wall_paint_and_material_reused",shell.edges.all(func(e):return game.presentation.volumes.any(func(v):return v.kind=="wall" and v.wall_index==e.wall_index and v.material==e.material and v.display_rect==e.display_rect and v.world.art_textures[str(v.profile.grid_tile_asset)]==e.texture)))
	check("clipped_geometry_not_doubled",shell.edges.all(func(e):return range(e.clips.size()).all(func(i):return range(i+1,e.clips.size()).all(func(j):return not e.clips[i].intersects(e.clips[j])))))
	check("original_map_unchanged",FileAccess.get_sha256("res://data/rooms/r04.json")=="437b86cdc6e05cdb26f11a7b2dd633af90e0b8d425f0b64a0ea665dde5c04298")
	check("roof_coverage_unchanged",rules.covers.filter(func(c):return str(c.room.id).begins_with("dorm")).map(func(c):return c.roof)==[Rect2(100,100,600,340),Rect2(100,440,600,340),Rect2(100,780,600,360)])
	var collision: Array=[]
	for i in range(200):collision.append(game.world.can_place_circle(Vector2(120+(i%20)*185,260+floori(i/20.0)*210),17,null,false))
	for room in rules.rooms:
		reveal(room.area.get_center())
		check("independent_reveal_"+str(room.id),rules.covers.all(func(c):return not c.visible if c.room.id==room.id else c.visible) and shell.visible and shell.modulate.a==1)
	check("door_cutouts_preserved",rules.covers.all(func(c):return c.cutouts.all(func(o):return not c.panels.any(func(p):return p.has_point(o.get_center())))))
	check("collision_unchanged",range(200).all(func(i):return collision[i]==game.world.can_place_circle(Vector2(120+(i%20)*185,260+floori(i/20.0)*210),17,null,false)))
	if DisplayServer.get_name() != "headless":
		for period in ["day","night"]:
			game.presentation.lighting.set_period(period)
			for section in [{"id":"dorm","center":Vector2(750,670),"inside":Vector2(500,650),"zoom":0.68},{"id":"cafeteria","center":Vector2(1440,1620),"inside":Vector2(1300,1710),"zoom":0.65},{"id":"confinement","center":Vector2(750,1650),"inside":Vector2(500,1720),"zoom":0.68},{"id":"workshop","center":Vector2(1450,710),"inside":Vector2(1400,650),"zoom":0.65}]:
				game.map_camera.zoom = Vector2.ONE*section.zoom
				game.map_camera.position = (section.center-Vector2(root.size)/game.map_camera.zoom/2).max(Vector2.ZERO)
				game.map_camera.force_update_scroll()
				reveal(Vector2(740,1220))
				await picture(str(period)+"-"+section.id+"-covered")
				reveal(section.inside)
				await picture(str(period)+"-"+section.id+"-revealed")
	reveal(Vector2(740,650))
	await frame()
	await frame()
	var counts: Array=shell.edges.map(func(e):return e.draw_builds)
	var roof_counts: Array=rules.covers.map(func(c):return c.draw_builds)
	for i in range(120):
		var start := Time.get_ticks_usec()
		reveal(Vector2(740,650) if i%2==0 else Vector2(500,650))
		timings.append((Time.get_ticks_usec()-start)/1000.0)
		await frame()
	check("wall_edge_commands_retained_across_transitions",range(counts.size()).all(func(i):return counts[i]==shell.edges[i].draw_builds))
	# Godot calls _draw on a visibility show; the existing cover only records
	# its retained quads again, without rebuilding wall geometry or textures.
	check("roof_draws_bounded_to_visibility_shows",range(roof_counts.size()).all(func(i):return rules.covers[i].draw_builds-roof_counts[i]<=60 if rules.covers[i].room.id=="dorm-1" else roof_counts[i]==rules.covers[i].draw_builds))
	# Presentation may rebuild its volumes for a door/fixture revision. Edge
	# nodes own texture/geometry snapshots and never retain freed source nodes.
	game.world.fixtures_revision += 1
	game.presentation.tick(0)
	for edge in shell.edges:edge.queue_redraw()
	await frame()
	check("retained_edges_survive_volume_rebuild",shell.edges.all(func(e):return is_instance_valid(e) and e.texture!=null))
	game.load_room("r04",["lockpick","chat","backpack"],80)
	await frame()
	check("map_reload_replaces_single_shell",game.get_children().filter(func(c):return c.name=="RetainedRoofWallEdges").size()==1 and is_instance_valid(game.room_visibility.wall_edges))
	timings.sort()
	var failed: Array=checks.keys().filter(func(k):return not checks[k])
	var report := {"checks":checks,"failed":failed,"total":checks.size(),"images":images,"pixel_masks":pixel_masks,"wall_edges":game.room_visibility.wall_edges.edges.size(),"transition_cpu_ms":{"median":timings[timings.size()/2],"p95":timings[floori(timings.size()*0.95)],"max":timings.back()},"map_sha256":FileAccess.get_sha256("res://data/rooms/r04.json")}
	var tag := "headless" if DisplayServer.get_name()=="headless" else "native"
	FileAccess.open("res://docs/tests/p80-connected-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify({"failed":failed,"total":checks.size(),"wall_edges":report.wall_edges,"transition_cpu_ms":report.transition_cpu_ms}))
	quit(0 if failed.is_empty() else 1)
