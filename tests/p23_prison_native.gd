extends SceneTree

var game
var checks := {}
var images: Array = []
var suffix: String
var metrics := {}

func _initialize() -> void:
	call_deferred("run")

func frame(name: String = "") -> void:
	game._update_ui()
	game.presentation.tick(0)
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if name != "":
		var path := "res://docs/tests/p23-%s-%s.png"%[name,suffix]
		root.get_texture().get_image().save_png(path)
		images.append(path)

func touch(down: bool, point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = down
	event.index = 0
	event.position = root.get_final_transform()*point
	Input.parse_input_event(event)

func tap(point: Vector2) -> void:
	touch(true,point)
	await frame()
	touch(false,point)
	await frame()

func run() -> void:
	suffix = "%dx%d"%[root.size.x,root.size.y]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r04",["backpack","lockpick","strong"],23)
	root.grab_focus()
	root.warp_mouse(Vector2(535,394))
	await frame()
	checks.four_rooms_available = game.room_selector.item_count == 4 and not game.room_selector.is_item_disabled(3)
	checks.new_room_selected = game.room_selector.selected == 3
	checks.all_seven_textures_loaded = ["bunk_bed","cell_bars","toilet_sink","workbench","tool_locker","communal_table","notice_board"].all(func(id): return game.world.art_textures.has(id) and game.world.art_textures[id] != null and (not game.world.art_textures[id] is AtlasTexture or game.world.art_textures[id].atlas != null))
	var volumes: Array = game.presentation.volumes.filter(func(v): return v.kind == "fixture")
	checks.twenty_five_props_instanced = volumes.size() == 25
	var mapped := true
	var layered := true
	for volume in volumes:
		var definition: Dictionary = game.presentation.asset_definitions.get(volume.prop_id(),{})
		if not definition.has("ground_rect") or not game.world.art_textures.has(volume.prop_id()):
			mapped = false
			continue
		var texture: Texture2D = game.world.art_textures[volume.prop_id()]
		var ground: Array = definition.ground_rect
		var scale: Vector2 = volume.display_rect.size/texture.get_size()
		var restored := Rect2(volume.display_rect.position+Vector2(ground[0],ground[1])*scale,Vector2(ground[2],ground[3])*scale)
		mapped = mapped and restored.position.distance_to(volume.footprint.position) < 0.01 and restored.size.distance_to(volume.footprint.size) < 0.01
		layered = layered and volume.z_index == int(volume.footprint.end.y)
	checks.sprite_ground_registered_to_collision = mapped
	checks.prop_depth_sorted = layered
	checks.real_occluders_match_sight_rules = game.presentation.lighting.occluders.size() == game.world.sight_rects().size()
	checks.ten_lights_loaded = game.presentation.lighting.lamps.size() == 10
	checks.no_edge_scrolling = not game.map_camera.snapshot().edge_scroll
	var cards: Array = game.cards.map(func(c): return c.position)
	for period in ["day","night"]:
		game.presentation.lighting.set_period(period)
		for zone in game.room_config.zones:
			var area: Array = zone.rect
			var center := Vector2(area[0]+area[2]/2,area[1]+area[3]/2)
			await tap(game.mini_map.global_position+game.mini_map.to_map(center))
			var offset: Vector2 = (center-game.map_camera.VIEW.get_center()).clamp(game.world.bounds.position-game.map_camera.VIEW.position,game.world.bounds.end-game.map_camera.VIEW.end)
			checks[period+"_"+str(zone.id)+"_touch_minimap"] = game.map_camera.position.distance_to(offset) < 1 and game.orders.active.is_empty()
			await frame("r04-"+str(zone.id)+"-"+period)
	checks.hud_fixed_across_zones = cards == game.cards.map(func(c): return c.position)
	await tap(game.mini_map.locate_button.get_global_rect().get_center())
	checks.touch_returns_to_cell_actor = game.map_camera.position == Vector2(6,-14)
	metrics.locate = {"offset":[game.map_camera.position.x,game.map_camera.position.y],"focused":root.has_focus(),"selected_actor":game.selected_actor_id,"button_rect":str(game.mini_map.locate_button.get_global_rect())}
	game.presentation.lighting.set_period("day")
	await frame("r04-start")
	var passed: bool = checks.values().all(func(v): return v == true)
	var file := FileAccess.open("res://docs/tests/p23-prison-native-%s.json"%suffix,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"metrics":metrics,"images":images,"scope":"Rendered native Windows Godot 4.7.2; frozen gameplay fixture for art/GUI registration and real touch events via Input.parse_input_event. No Android/iOS or human gameplay evidence."},"\t"))
	print(JSON.stringify({"passed":passed,"checks":checks,"metrics":metrics,"images":images}))
	quit(0 if passed else 1)
