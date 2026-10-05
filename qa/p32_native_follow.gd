extends SceneTree

const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
class TimedWall extends "res://scripts/presentation/world_volume.gd":
	var draw_us := 0
	var draw_count := 0
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		super._draw()
		draw_us = Time.get_ticks_usec()-start
		draw_count += 1
var game
var checks := {}
var prefix := "p32-native"
var frames := 0
var focused := 0

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	root.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw
	frames += 1
	focused += int(root.has_focus())

func shot(suffix: String) -> void:
	await frame()
	root.get_texture().get_image().save_png("res://docs/tests/"+prefix+"-"+suffix+".png")

func at_minute(value: float) -> void:
	game.schedule.clock_elapsed = (value-480)/840*game.schedule.limit_seconds
	game.schedule.tick(false)
	game.presentation.tick(0)
	game._update_ui()

func cost(use_fix: bool) -> Dictionary:
	var counts := {}
	for volume in game.presentation.volumes:
		volume.profile = game.presentation.profile.duplicate(true)
		volume.profile.wall_outline_aa = use_fix
		volume.profile.wall_side_gradient = use_fix
		volume.queue_redraw() # Explicit profile change, not camera motion.
		if volume is TimedWall:
			counts[volume.get_instance_id()] = volume.draw_count
	var cpu: Array = []
	var calls: Array = []
	var wall_cpu: Array = []
	var redraws := 0
	var rebuild_us := 0
	var start := Time.get_ticks_msec()
	# Performance monitors update periodically. Exclude boot/capture spikes and
	# allow an entire refresh interval before collecting the settled batch.
	while Time.get_ticks_msec()-start < 2000:
		game.map_camera.manual_pan_by(Vector2(0.125,0.125))
		game.presentation.tick(0)
		await frame()
		var total := 0
		for volume in game.presentation.volumes:
			if volume is TimedWall and volume.draw_count > counts[volume.get_instance_id()]:
				total += volume.draw_us
				redraws += volume.draw_count-counts[volume.get_instance_id()]
				counts[volume.get_instance_id()] = volume.draw_count
		rebuild_us += total
		if Time.get_ticks_msec()-start >= 1200:
			cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			wall_cpu.append(total)
	cpu.sort()
	calls.sort()
	wall_cpu.sort()
	return {"process_ms_median":cpu[cpu.size()/2],"process_ms_p95":cpu[int(cpu.size()*0.95)],"cached_wall_cpu_us_median":wall_cpu[wall_cpu.size()/2],"wall_initial_rebuild_us":rebuild_us,"wall_redraw_count":redraws,"draw_calls_median":calls[calls.size()/2],"samples":cpu.size()}

func run() -> void:
	prefix += "-"+OS.get_cmdline_user_args()[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.load_room("r04",["chat","lockpick","strong"],32)
	game.schedule.set_time_speed(0)
	root.grab_focus()
	await frame()
	var walls_before: String = str(game.world.walls)
	var cache_before: int = WorldTexture.cache.size()
	checks.production_flags = game.presentation.profile.wall_outline_aa and game.presentation.profile.wall_side_gradient
	var top_id: String = game.presentation.profile.material_slots.wall_top
	checks.prefiltered_texture = game.world.art_textures[top_id].get_image().has_mipmaps()
	game.actors[0].position = Vector2(550,490)
	game.map_camera.locate_selected()
	checks.route_accepted = game.orders.issue(0,Vector2(578,820))
	var previous: Vector2 = game.map_camera.position
	var follow_start := previous
	var fractional := 0
	var maximum_step := 0.0
	var reverse_steps := 0
	for index in range(180):
		game._process(1.0/120)
		await frame()
		var point: Vector2 = game.map_camera.position
		fractional += int(point.distance_to(point.round()) > 0.01)
		maximum_step = maxf(maximum_step,point.distance_to(previous))
		reverse_steps += int(point.y < previous.y-0.001)
		previous = point
		if index == 90:
			await shot("day-follow")
	checks.following_still_enabled = game.map_camera.following
	checks.smooth_fractional_camera = fractional > 150 and maximum_step < 3 and reverse_steps == 0
	checks.camera_follows_distance = game.map_camera.position.distance_to(follow_start) > 250
	checks.route_arrived = game.actors[0].position.distance_to(Vector2(578,820)) < 3
	checks.no_capture_safe_corridor = game.captures == 0
	# These are the actual curfew transition and production lights, not a fake tint.
	at_minute(1200)
	checks.curfew_rules = game.schedule.is_curfew() and game.presentation.lighting.guard_light.texture == game.presentation.lighting.curfew_beam_texture
	for index in range(30):
		game._process(1.0/120)
		await frame()
	await shot("curfew-follow")
	checks.wall_geometry_unchanged = str(game.world.walls) == walls_before
	# Same production _draw with timer instrumentation; no alternate renderer.
	for index in range(game.presentation.volumes.size()):
		var volume = game.presentation.volumes[index]
		if volume.kind == "wall":
			var timed := TimedWall.new()
			game.add_child(timed)
			timed.configure(game.world,"wall",volume.wall_index,volume.profile,volume.definitions)
			game.presentation.volumes[index] = timed
			volume.free()
	var baseline := await cost(false)
	var memory_before := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var candidate := await cost(true)
	checks.wall_commands_cached = baseline.wall_redraw_count == game.world.walls.size() and candidate.wall_redraw_count == game.world.walls.size() and candidate.cached_wall_cpu_us_median == 0
	var wall = game.presentation.volumes.filter(func(volume): return volume.kind == "wall" and volume.wall_index == 0)[0]
	var count: int = wall.draw_count
	var original: Rect2 = game.world.walls[0]
	game.world.walls[0] = Rect2(original.position+Vector2(1,0),original.size)
	game.presentation.tick(0)
	await frame()
	checks.geometry_invalidates_commands = wall.draw_count == count+1 and wall.footprint == game.world.walls[0]
	game.world.walls[0] = original
	game.presentation.tick(0)
	await frame()
	checks.restored_geometry = str(game.world.walls) == walls_before and wall.footprint == original
	checks.no_extra_texture_cache = WorldTexture.cache.size() == cache_before
	checks.no_extra_texture_memory = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) == memory_before
	checks.focused = focused > frames*0.95
	var passed: bool = checks.values().all(func(value): return value)
	var report := {"passed":passed,"checks":checks,"window":[root.size.x,root.size.y],"frames":frames,"focused_frames":focused,"camera":{"fractional_frames":fractional,"max_step":maximum_step,"reverse_steps":reverse_steps},"performance":{"baseline":baseline,"candidate":candidate,"texture_cache_count":cache_before,"texture_memory_bytes":memory_before,"texture_memory_after":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)},"scope":"Native D3D12 full scene. Normal orders/AI/rendering run with controlled 1/120 delta; native framebuffer captures. Performance samples are single sequential batches under current GPU load after 1.2s warmup per mode, not device benchmarks or physical display tearing measurements."}
	FileAccess.open("res://docs/tests/"+prefix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("P32_NATIVE passed=",passed," failed=",checks.keys().filter(func(key): return not checks[key])," camera=",report.camera," cost=",report.performance)
	game.presentation.stop_all()
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
