extends SceneTree
const OUT := "res://docs/dev/p138/"
var checks := {}
var game
var viewer
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func check(label: String, result: bool) -> void: checks[label] = result
func put(kind: String) -> String:
	var id: String = game.inventory.add_ground(kind,game.actors[0].position)
	var result: Dictionary = game.inventory.try_pickup(0,id)
	check(kind+" pickup",result.ok)
	if not result.ok: print("PICKUP_FAILED ",kind," ",result)
	return id
func stand_beside(id: String) -> bool:
	var rect: Rect2 = game.looting.containers[id].fixture.rect
	for margin in [12,24,40,56]:
		for side in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
			var point: Vector2 = rect.get_center()+side*(rect.size/2+Vector2.ONE*margin)
			if not game.world.can_place_circle(point,8,game.actors[0],false,false): continue
			game.actors[0].position = point
			game.room_visibility.tick(1,true)
			if game.looting.reason(id).is_empty(): return true
	return false
func shot(name: String) -> void:
	await frame()
	await frame()
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p138-items.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p138-item-buttons.cfg")
	root.size = Vector2i(1280,820)
	root.content_scale_size = root.size
	var map_before := FileAccess.get_file_as_string("res://data/rooms/r04.json")
	viewer = load("res://scenes/editor/item_previewer.tscn").instantiate()
	root.add_child(viewer)
	await frame()
	var expected: int=JSON.parse_string(FileAccess.get_file_as_string("res://data/items/library.json")).items.size()
	check("all registered definitions visible in tool",viewer.catalog.definitions.size() == expected and viewer.visible_ids.size() == expected)
	var new_ids: Array = JSON.parse_string(FileAccess.get_file_as_string("res://art/items/expansion_v01/manifest.json")).items.map(func(i):return i.id)
	for id in new_ids:
		viewer.select_item(id)
		var icon: Texture2D = viewer.stage.texture
		check(id+" preview loads game icon",icon != null and icon.get_width() > 0 and icon.get_height() > 0)
		check(id+" has actual loot source",not viewer.catalog.sources(id).is_empty())
		var raw: Image = load(viewer.catalog.art[id].texture).get_image()
		check(id+" real alpha",raw.get_format() == Image.FORMAT_RGBA8 and raw.get_pixel(0,0).a == 0 and raw.get_used_rect().has_area())
	viewer.search.text = "通行证"
	viewer.filter_items()
	check("search filters by Chinese name",viewer.visible_ids == ["temporary_pass"])
	viewer.search.text = "no_such_item"
	viewer.filter_items()
	check("empty search clears stale preview",viewer.visible_ids.is_empty() and viewer.stage.texture == null)
	viewer.search.text = ""
	viewer.category_picker.select(viewer.category_ids.find("medical"))
	viewer.filter_items()
	check("category filter contains medical items",viewer.visible_ids.size() == 3 and "painkillers" in viewer.visible_ids)
	viewer.category_picker.select(0)
	viewer.reload_catalog()
	viewer.select_item("canvas_pouch")
	check("details display footprint and functional status",viewer.details.text.contains("2 × 2") and viewer.details.text.contains("可使用"))
	check("raw config is read only",not viewer.config_text.editable and viewer.config_text.text.contains("canvas_pouch"))
	await shot("item-previewer")
	viewer.hide()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	game.reset_round(["chat","backpack","strong"],138)
	game.actors[0].skill_id = "chat"
	game.world.admission_filter = Callable()
	var player_start: Vector2 = game.actors[0].position
	var inv = game.inventory
	check("runtime has all registered item definitions",inv.definitions.size() == expected)
	for id in new_ids:
		check(id+" runtime icon",game.items_view.icon_for(id) != null)
		var instance := put(id)
		check(id+" footprint matches preview",inv.item_size(id) == Vector2i(viewer.catalog.definitions[id].grid_size[0],viewer.catalog.definitions[id].grid_size[1]))
		check(id+" can be dropped",inv.try_drop(0,instance).ok)
	for kind in ["biscuits","canned_meat","instant_coffee","painkillers","antiseptic"]:
		var id := put(kind)
		var effect: Dictionary = inv.definitions[kind].restore
		game.attributes.values[0][effect.stat] = 40.0
		check(kind+" restores configured stat",inv.try_use(0,id).ok and game.attributes.values[0][effect.stat] == 40+effect.amount and not inv.owns(0,id))
		id = put(kind)
		game.attributes.values[0][effect.stat] = 100.0
		check(kind+" full stat prevents waste",not inv.try_use(0,id).ok and inv.owns(0,id))
		inv.try_drop(0,id)
	var held := put("work_clothes")
	check("multi-cell item manually moves",inv.move_item(0,held,Vector2i(3,2)).ok)
	var placement: Rect2i = inv.grid_layout(0)[held]
	var pouch := put("canvas_pouch")
	check("pouch expands 20 to 30 and consumes once",inv.capacity(0) == 20 and inv.try_use(0,pouch).ok and inv.capacity(0) == 30 and inv.instances[pouch].location == "consumed")
	check("expansion preserves manual placement",inv.grid_layout(0)[held] == placement)
	pouch = put("canvas_pouch")
	check("maximum capacity prevents repeated consumption",not inv.try_use(0,pouch).ok and inv.owns(0,pouch))
	inv.try_drop(0,pouch)
	for kind in ["duty_roster","delivery_note","work_id","temporary_pass","secret_note"]:
		var id := put(kind)
		check(kind+" opens non-consuming reading window",inv.try_use(0,id).ok and inv.owns(0,id) and inv.reading_dialog.visible and not inv.reading_dialog.dialog_text.is_empty())
		check(kind+" reader blocks world input",game.world_input_blocked(true))
		inv.reading_dialog.hide()
		inv.try_drop(0,id)
	check("closing reader restores input",not game.world_input_blocked(true))
	var gift := put("cigarettes")
	game.actors[1].position = game.actors[0].position+Vector2(12,0)
	game.actors[2].position = game.actors[0].position+Vector2(300,0)
	var relation_before: Dictionary = game.social.relation("prisoner:1").duplicate()
	check("gift consumes and raises affinity",inv.try_use(0,gift).ok and not inv.owns(0,gift) and game.social.relation("prisoner:1").like > relation_before.like)
	gift = put("cigarettes")
	game.actors[1].position = game.actors[0].position+Vector2(350,0)
	check("gift fails safely when nobody nearby",not inv.try_use(0,gift).ok and inv.owns(0,gift))
	inv.try_drop(0,gift)
	var material := put("duct_tape")
	check("unfinished crafting does not pretend to use material",not inv.try_use(0,material).ok and inv.owns(0,material))
	inv.try_drop(0,material)
	for seed in range(30):
		game.deal_seed = seed
		game.looting.reset()
		for container_id in game.looting.containers:
			game.looting._generate(container_id)
			var state: Dictionary = game.looting.containers[container_id]
			check("generated loot uses valid definitions",state.ids.all(func(id):return inv.definitions.has(inv.instances[id].definition_id)))
	var drawn: Dictionary = {}
	for item in inv.instances.values(): drawn[str(item.definition_id)] = true
	check("all 18 new kinds appear in real container generation",new_ids.all(func(id):return drawn.has(id)))
	var fixture: Dictionary = game.looting.containers.values().filter(func(c):return c.fixture.loot_profile == "industrial")[0]
	var return_id := put("repair_kit")
	var loot = game.looting
	loot.current_id = str(fixture.fixture.id)
	check("container is reachable",stand_beside(loot.current_id))
	var destination: Vector2i = preload("res://scripts/items/grid_packing.gd").first_space(fixture.layout,Vector2i(4,4),inv.item_size("repair_kit"))
	var stored: Dictionary = loot.move_item(return_id,"bag","source",destination)
	check("large new item can return to searched container",stored.ok and inv.instances[return_id].location == "container")
	if stored.ok:
		check("large new item can return to bag",loot.move_item(return_id,"source","bag",inv.find_space(0,"repair_kit")).ok and inv.owns(0,return_id))
	loot.close()
	game.actors[0].position = player_start
	game.room_visibility.tick(1,true)
	for id in inv.items(0): inv.try_drop(0,id)
	for kind in ["biscuits","canned_meat","instant_coffee","cigarettes","painkillers","antiseptic","duct_tape","screw_box","work_gloves","pliers","repair_kit","duty_roster","work_id"]: put(kind)
	game.fullscreen_ui.bag_open = true
	game.inventory_panel.selected_item = inv.items(0)[0] if not inv.items(0).is_empty() else ""
	game.fullscreen_ui.refresh()
	game.inventory_panel.refresh()
	await shot("new-items-in-bag")
	game.fullscreen_ui.bag_open = false
	game.reset_round(["chat","backpack","strong"],139)
	game.actors[0].skill_id = "chat"
	check("new round clears expansion",inv.extra_rows.is_empty() and inv.capacity(0) == 20)
	check("room file stays unchanged",FileAccess.get_file_as_string("res://data/rooms/r04.json") == map_before)
	game.queue_free()
	await frame()
	var editor = load("res://scenes/editor/map_editor.tscn").instantiate()
	root.add_child(editor)
	await frame()
	check("map palette contains all registered items",editor.catalog.entries.filter(func(e):return e.group == "items").size() == expected)
	var draft_before: Dictionary = editor.document.data.duplicate(true)
	editor.open_item_previewer()
	await frame()
	check("editor opens preview without changing draft",editor.item_preview_window.visible and editor.document.data == draft_before)
	editor.item_preview_window.hide()
	editor.queue_free()
	viewer.queue_free()
	await frame()
	await frame()
	var failed: Array = checks.keys().filter(func(label):return not checks[label])
	FileAccess.open(OUT+"items-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"\t"))
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
