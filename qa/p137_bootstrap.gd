extends RefCounted

# Keep startup dependency order explicit. Components retain the game facade;
# game lifetime/reset/input remain in escape_game.gd.
static func configure(game) -> void:
	var config: Dictionary = _load_room(game)
	if config.is_empty(): return
	_create_world(game,config)
	_create_services(game)

static func _load_room(game) -> Dictionary:
	game.frame_settings=preload("res://scripts/core/frame_settings.gd").new()
	game.frame_settings.configure()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/%s.json" % game.room_id))
	var args := OS.get_cmdline_user_args()
	var preview_index := args.find("--editor-room")
	if preview_index >= 0:
		if preview_index+1 >= args.size():
			push_error("Editor preview needs a map JSON path.")
			game.get_tree().quit(1)
			return {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(args[preview_index+1]))
		if not parsed is Dictionary:
			push_error("Editor preview map JSON is invalid.")
			game.get_tree().quit(1)
			return {}
		var document = load("res://scripts/editor/map_document.gd").new()
		if not document.open_file(args[preview_index+1]) or not document.validate().errors.is_empty():
			push_error("Editor preview map failed validation.")
			game.get_tree().quit(1)
			return {}
		config = document.data
		game.room_id = str(config.id)
		game.editor_preview_mode = true
		OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://map-editor-playtest-developer.cfg")
		OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://map-editor-playtest-buttons.cfg")
	# The floor shares the prefiltered static-world textures; character sheets
	# retain their existing linear sampling (they have no mipmap chain).
	game.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return config

static func _create_world(game, config: Dictionary) -> void:
	for index in range(3):
		var actor = game.Prisoner.new()
		actor.name = "Prisoner%d" % (index + 1)
		actor.actor_id = index
		actor.home = game.STARTS[index]
		actor.skill_id = ["chat", "lockpick", "strong"][index]
		game.add_child(actor)
		game.actors.append(actor)
	game.world = game._make_world()
	game.world.name = "World"
	game.add_child(game.world)
	game.room_config = config
	game.world.configure(config,game.actors)
	for index in range(game.actors.size()):
		var start: Array = config.starts[index]
		game.actors[index].home = Vector2(start[0],start[1])
	game.guard = game.Guard.new()
	game.guard.name = "Guard"
	game.add_child(game.guard)
	game.guard.configure(game.world,game)
	game.dog = game.PoliceDog.new()
	game.dog.name = "PoliceDog"
	game.add_child(game.dog)
	game.dog.configure(game)
	game.skills = game.Skills.new(game)
	game.orders = game.MoveOrders.new(game)
	game.inventory = game.Inventory.new(game)
	game.quick_items = preload("res://scripts/items/quick_items.gd").new(game)
	game.trade = game.Trade.new(game)
	game._build_ui()
	game.reset_round()

static func _create_services(game) -> void:
	game.presentation = preload("res://qa/p137_presentation.gd").new()
	game.presentation.name = "Presentation"
	game.add_child(game.presentation)
	game.presentation.configure(game)
	game.items_view = game.ItemsView.new()
	game.items_view.name = "ItemsView"
	game.add_child(game.items_view)
	game.items_view.configure(game)
	game.inventory_panel = game.InventoryPanel.new()
	game.inventory_panel.name = "InventoryPanel"
	game.add_child(game.inventory_panel)
	game.inventory_panel.configure(game)
	game.shop_panel = game.ShopPanel.new()
	game.shop_panel.name = "ShopPanel"
	game.add_child(game.shop_panel)
	game.shop_panel.configure(game)
	game.map_camera = game.MapCamera.new()
	game.map_camera.name = "MapCamera"
	game.add_child(game.map_camera)
	game.map_camera.configure(game)
	game.mini_map = game.MiniMap.new()
	game.mini_map.name = "MiniMap"
	game.get_node("HUD").add_child(game.mini_map)
	game.mini_map.configure(game)
	game.schedule = game.PrisonSchedule.new()
	game.schedule.name = "Schedule"
	game.add_child(game.schedule)
	game.schedule.configure(game)
	game.developer_settings = game.DeveloperSettings.new()
	game.developer_settings.name = "DeveloperSettings"
	game.add_child(game.developer_settings)
	game.developer_settings.configure(game)
	game.routines = game.DailyRoutine.new(game)
	game.routines.tick()
	game.mobile_controls = game.MobileControls.new()
	game.add_child(game.mobile_controls)
	game.mobile_controls.configure(game)
	game.fullscreen_ui = game.FullscreenHUD.new()
	game.add_child(game.fullscreen_ui)
	game.fullscreen_ui.configure(game)
	game.map_viewer = preload("res://scripts/ui/map_viewer.gd").new()
	game.add_child(game.map_viewer)
	game.map_viewer.configure(game)
	game.staff_traffic = game.StaffTraffic.new(game)
	game.gate_watch = game.GateWatch.new(game)
	game.gate_watch.reset(game.room_config)
	game.prison_alert = game.PrisonAlert.new(game)
	game.attributes = game.ActorAttributes.new(game)
	game.room_access = game.RoomAccess.new(game)
	game.room_access.tick()
	game.workshop = game.WorkshopRules.new(game)
	game.workshop.reset()
	game.social = preload("res://scripts/core/social_world.gd").new(game)
	game.dialogue = game.NpcDialogue.new()
	game.add_child(game.dialogue)
	game.dialogue.configure(game)
	game.room_visibility = preload("res://scripts/core/room_visibility.gd").new(game)
	game.room_visibility.reset()
	game.looting=preload("res://scripts/items/looting.gd").new()
	game.add_child(game.looting)
	game.looting.configure(game)
	var social_labels = preload("res://scripts/presentation/social_labels.gd").new()
	game.add_child(social_labels)
	social_labels.configure(game)
	game.npc_life = preload("res://scripts/core/npc_life.gd").new(game)
	game.fullscreen_ui.layout()
	var retained_floor=preload("res://scripts/presentation/floor_canvas.gd").new()
	game.add_child(retained_floor)
	retained_floor.configure(game)
	game.tutorial = game.TutorialDay.new()
	game.tutorial.name = "TutorialDay"
	game.add_child(game.tutorial)
	game.tutorial.configure(game)
	if game.editor_preview_mode:
		game.room_selector.disabled = true
		var return_bar = load("res://scripts/editor/preview_return.gd").new()
		game.get_node("HUD").add_child(return_bar)
		return_bar.configure(game)
