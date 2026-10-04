extends SceneTree

var game

func _initialize() -> void:
	call_deferred("_run")

func capture(path: String) -> void:
	game.presentation.tick(0)
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.load_room("r02",["chat","lockpick","strong"],33)
	var p = game.presentation
	var before: Dictionary = game.snapshot()
	await capture("res://docs/tests/p13-preparation-v02-baseline.png")
	p.profile.soft_shadows = true
	await capture("res://docs/tests/p13-preparation-soft-shadow.png")
	var checks := {}
	checks.current_asset_is_v02 = p.asset_version == "art-v02-perspective-20261004-54a7161c7820"
	checks.visual_only_no_logic_change = game.snapshot() == before
	checks.all_prop_ground_mapping = p.volumes.filter(func(v): return v.kind != "wall").all(func(v): return v.display_rect.position == v.footprint.position-Vector2(0,20) and v.display_rect.size == v.footprint.size+Vector2(0,20))
	var atlas: AtlasTexture = p._load_texture({"texture":"res://art/environment/floor_tile_v02.png","region":[0,0,128,128]})
	checks.direct_region_no_pixel_rewrite = atlas.atlas.resource_path == "res://art/environment/floor_tile_v02.png" and atlas.get_size() == Vector2(128,128)
	var report := {"passed":checks.values().all(func(v): return v == true),"checks":checks,"scope":"renderer preparation and soft shadow preview over v02; A04 textures not integrated","asset_version":p.asset_version,"window":[root.size.x,root.size.y]}
	var file := FileAccess.open("res://docs/tests/p13-preparation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("P13_PREPARATION ",JSON.stringify(report))
	p.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.06).timeout
	quit(0 if report.passed else 1)
