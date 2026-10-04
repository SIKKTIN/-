extends SceneTree

var checks := {}
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r01", ["chat", "lockpick", "strong"], 18)
	checks.small_map_no_pan = not game.map_camera.enabled_for_room and game.map_camera.position == Vector2.ZERO
	var config: Dictionary = game.room_config.duplicate(true)
	config.bounds = [80,100,1800,1100]
	config.walls = [[600,100,24,600]]
	config.door = [900,900,24,100]
	config.crate = [1000,1050,94,92]
	config.exit = [1790,590,90,220]
	config.guard_zone = [624,100,960,1100]
	config.guard_start = [760,420]
	game.world.configure(config, game.actors)
	game.guard.configure(game.world,game)
	game.map_camera.reset()
	checks.large_map_pan_enabled = game.map_camera.enabled_for_room
	var path: PackedVector2Array = game.world.find_path(Vector2(180,260),Vector2(1800,900),game.actors[0])
	checks.navigation_beyond_old_grid = not path.is_empty() and game.world.grid.region.end.x >= 94 and game.world.grid.region.end.y >= 60
	checks.guard_zone_constraint = game.world.find_path(game.guard.position,Vector2(180,260),game.guard).is_empty()
	game.map_camera.pan_by(Vector2(99999,99999))
	checks.camera_max_bound = game.map_camera.position == Vector2(884,526)
	game.map_camera.pan_by(Vector2(-99999,-99999))
	checks.camera_min_bound = game.map_camera.position == Vector2(6,-14)
	var hud: Vector2 = game.cards[0].position
	var old_actor: Vector2 = game.actors[0].position
	game.map_camera.pan_by(Vector2(500,400))
	checks.pan_does_not_move_people = game.actors[0].position == old_actor
	checks.hud_stays_fixed = game.cards[0].position == hud
	game.actors[0].position = Vector2(1250,900)
	game.select_actor(0)
	game.map_camera.locate_selected()
	checks.locate_selected = (game.get_global_transform_with_canvas()*game.actors[0].position).distance_to(Vector2(535,394)) < 1
	var goal := Vector2(1460,980)
	var screen: Vector2 = game.get_global_transform_with_canvas()*goal
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = screen
	game._unhandled_input(event)
	checks.scrolled_right_click_coordinates = game.orders.active.has(0) and game.orders.active[0].goal.distance_to(goal) < 0.01
	game.actors[0].position = Vector2(1830,700)
	checks.exit_within_bounds_works = game.world.check_exit(game.actors[0])
	checks.dynamic_exit_icon = game.world.exit_icon_rect().get_center().x > 1700
	game.load_room("r01",["chat","lockpick","strong"],18)
	checks.old_exit_still_works = game.world.inside_room(Vector2(1040,395))
	game.actors[0].position = Vector2(1040,395)
	checks.old_exit_trigger_unchanged = game.world.check_exit(game.actors[0])
	checks.return_resets_camera = game.map_camera.position == Vector2.ZERO and not game.map_camera.enabled_for_room
	var ok: bool = checks.values().all(func(x): return x == true)
	var f := FileAccess.open("res://docs/tests/p18-camera.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":ok,"checks":checks,"note":"Camera/navigation fixture checks; visual clipping and actual R03 paths validated in P19/P20."},"\t"))
	print(JSON.stringify({"passed":ok,"checks":checks}))
	quit(0 if ok else 1)
