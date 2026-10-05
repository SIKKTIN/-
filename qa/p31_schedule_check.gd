extends SceneTree

var game
var checks := {}
var observations := {}

func _initialize() -> void:
	call_deferred("run")

func at_minute(minute: float) -> void:
	game.schedule.clock_elapsed = (minute-480)/840*game.schedule.limit_seconds
	game.schedule.tick(false)

func restart(room := "r01") -> void:
	game.load_room(room,["chat","lockpick","strong"],31)
	game.set_process(false)
	game.schedule.set_time_speed(1)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for room in ["r01","r02","r03","r04"]:
		restart(room)
		checks[room+"_starts_at_08"] = game.schedule.clock_minutes() == 480
		for entry in [[480,"morning_work"],[720,"meal_rest"],[840,"afternoon_work"],[1080,"free_time"],[1200,"curfew"]]:
			at_minute(entry[0])
			checks[room+"_"+entry[1]] = game.schedule.snapshot().stage == entry[1]
		checks[room+"_curfew_night"] = game.schedule.is_curfew() and game.presentation.lighting.period == "night" and game.schedule.dog_active()
		checks[room+"_own_home_safe"] = game.actors.all(func(a): return game.schedule.in_dormitory(a.actor_id))
	restart()
	game.schedule.set_time_speed(4)
	game._process(0.1)
	checks.speed_four_clock_only = is_equal_approx(game.elapsed,0.1) and is_equal_approx(game.schedule.clock_elapsed,0.4)
	var clock: float = game.schedule.clock_minutes()
	game.schedule.set_time_speed(0.5)
	checks.change_speed_does_not_jump = game.schedule.clock_minutes() == clock
	game._process(0.2)
	checks.half_speed = is_equal_approx(game.schedule.clock_elapsed,0.5) and is_equal_approx(game.elapsed,0.3)
	game.schedule.set_time_speed(0)
	game.command_move(0,Vector2(200,235))
	var before: Vector2 = game.actors[0].position
	game._process(0.01)
	checks.zero_freezes_clock_not_movement = game.schedule.clock_elapsed == 0.5 and game.actors[0].position.distance_to(before) > 2
	game.orders.clear()
	game.actors[0].skill_id = "lockpick"
	game.actors[0].position = game.world.door.position+Vector2(-27,game.world.door.size.y/2)
	game.skills.toggle(0)
	game._process(0.1)
	checks.zero_clock_skill_still_runs = is_equal_approx(game.world.lock_progress,0.025) and game.schedule.clock_elapsed == 0.5
	checks.invalid_speed_rejected = not game.schedule.set_time_speed(-1) and not game.schedule.set_time_speed(17) and not game.schedule.set_time_speed(NAN)
	game.schedule.set_time_speed(0.5)
	game.reset_round(["chat","lockpick","strong"],31)
	checks.reset_keeps_speed_resets_clock = game.schedule.time_speed == 0.5 and game.schedule.clock_elapsed == 0 and game.elapsed == 0
	game.load_room("r04",["chat","lockpick","strong"],31)
	checks.change_room_keeps_speed = game.schedule.time_speed == 0.5 and game.schedule.clock_minutes() == 480
	game.schedule.set_time_speed(1)
	at_minute(1199.99)
	checks.before_curfew_normal = not game.guard.curfew_alert() and game.guard.half_fov() == PI/3
	game.world.open_door()
	game.actors[0].position = Vector2(680,1000)
	game.actors[2].escaped = true
	at_minute(1200)
	checks.curfew_returns_outside = game.orders.active.has(0) and game.schedule.dormitory(0).has_point(game.orders.active[0].goal)
	checks.curfew_preserves_escaped = game.actors[2].escaped and not game.orders.active.has(2)
	var old_goal: Vector2 = game.orders.active[0].goal
	game.orders.issue(0,Vector2(680,1100))
	game.schedule.tick(false)
	checks.curfew_return_once_allows_disobedience = game.orders.active[0].goal == Vector2(680,1100) and old_goal != game.orders.active[0].goal
	checks.curfew_chat_forbidden = game.skills.target_reason(game.actors[0]).contains("宵禁")
	checks.merchant_closes_at_20 = game.trade.reason(0,"prison_dealer").contains("收摊")
	checks.curfew_omnidirectional = game.guard.half_fov() == PI
	var home: Vector2 = game.actors[0].home
	game.guard.position = Vector2(900,760)
	game.guard.facing = Vector2.RIGHT
	checks.curfew_sees_behind = game.guard.sees(Vector2(840,760))
	checks.safe_room_not_seen = not game.guard.sees(home)
	game.presentation.lighting.tick()
	checks.red_curfew_light = game.presentation.lighting.guard_light.texture == game.presentation.lighting.curfew_beam_texture and game.presentation.lighting.guard_light.color == Color("ff9a74")
	restart()
	game.actors[0].position = Vector2(560,395)
	var blocked_position: Vector2 = game.actors[0].position
	at_minute(1200)
	checks.blocked_return_not_teleported = game.schedule.curfew_returns.get(0) == "blocked" and game.actors[0].position == blocked_position and not game.orders.active.has(0)
	restart()
	at_minute(1200)
	game.actors[0].escaped = true
	game.actors[1].escaped = true
	game.actors[2].position = Vector2(994,510)
	game.schedule.clock_elapsed = 180-0.02
	game.schedule.set_time_speed(1)
	game.command_move(2,Vector2(1040,510))
	game._process(0.1)
	checks.final_effective_step_can_win = game.phase == "complete" and game.schedule.clock_elapsed == 180
	restart()
	at_minute(1200)
	game.schedule.clock_elapsed = 180-0.4
	game.schedule.set_time_speed(4)
	var before_elapsed: float = game.elapsed
	game._process(1)
	checks.fast_deadline_clamps_actual_step = game.phase == "failed" and is_equal_approx(game.elapsed-before_elapsed,0.1) and game.schedule.remaining() == 0
	restart()
	game.developer_settings.preference_path = "user://p31-logic-test.cfg"
	game.developer_settings.change_speed(2)
	var cfg := ConfigFile.new()
	checks.speed_preference_saved = cfg.load("user://p31-logic-test.cfg") == OK and cfg.get_value("clock","speed") == 2
	var previous_path := OS.get_environment("ESCAPE_DEV_SETTINGS_PATH")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p31-logic-test.cfg")
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	fresh.set_process(false)
	checks.new_launch_loads_speed = fresh.schedule.time_speed == 2 and fresh.schedule.clock_minutes() == 480
	fresh.presentation.stop_all()
	fresh.queue_free()
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH",previous_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://p31-logic-test.cfg"))
	var passed: bool = checks.values().all(func(value): return value)
	observations.config = game.schedule.config
	FileAccess.open("res://docs/tests/p31-logic.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"observations":observations,"scope":"Deterministic logic fixtures; developer test preference isolated; no mobile device or human playtest."},"\t")+"\n")
	print("P31_LOGIC passed=",passed," checks=",checks.size()," failed=",checks.keys().filter(func(k): return not checks[k]))
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
