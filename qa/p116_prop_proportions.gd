extends "res://qa/p105_collision.gd"

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p116-proportions.cfg")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	var assets: Dictionary=preload("res://scripts/presentation/prop_catalog.gd").assets()
	var sizes: Dictionary={}
	var count:=0
	var source_hashes: Dictionary={}
	for volume in game.presentation.volumes:
		if volume.kind!="fixture":continue
		var asset: Dictionary=assets.get(volume.prop_id(),{})
		if not asset.get("proportion_locked",false):continue
		count+=1
		var id: String=volume.prop_id()
		var source: Array=asset.region
		check("source_aspect_"+str(volume.wall_index),is_equal_approx(volume.display_rect.size.x/volume.display_rect.size.y,float(source[2])/float(source[3])))
		if sizes.has(id):check("same_asset_same_size_"+str(volume.wall_index),sizes[id].is_equal_approx(volume.display_rect.size))
		else:sizes[id]=volume.display_rect.size
		if not source_hashes.has(asset.texture):source_hashes[asset.texture]=FileAccess.get_sha256(asset.texture)==str(asset.sha256)
	check("all_fixed_prop_instances_calibrated",count==203)
	check("original_art_pixels_preserved",source_hashes.values().all(func(ok):return ok))
	var bed_index: int=game.world.fixtures.find_custom(func(f):return str(f.asset_id)=="bunk_bed_v42")
	var fixture: Dictionary=game.world.fixtures[bed_index]
	var bed=game.presentation.volumes.filter(func(v):return v.kind=="fixture" and v.wall_index==bed_index)[0]
	var expected: Vector2=bed.display_rect.size
	var saved_rect: Rect2=fixture.rect
	fixture.rect=Rect2(saved_rect.position,saved_rect.size*Vector2(2,0.5))
	fixture.render_size=[400,30]
	bed._wall_geometry_valid=false
	bed.tick_visual()
	check("legacy_render_override_cannot_stretch_sprite",bed.display_rect.size.is_equal_approx(expected))
	fixture.erase("render_size")
	fixture.rect=saved_rect
	bed._wall_geometry_valid=false
	bed.tick_visual()
	check("bed_ground_contact_matches_collision",absf(bed.display_rect.end.y-fixture.rect.end.y)<0.001)
	var main=game.actors[0]
	main.position=Vector2(2300,2700)
	game.world.admission_filter=Callable()
	check("shrunk_bed_has_no_old_invisible_side_block",game.world.can_place_circle(Vector2(saved_rect.position.x-10,saved_rect.get_center().y),8,main,false,false))
	check("bed_ground_contact_still_blocks_feet",not game.world.can_place_circle(saved_rect.get_center(),8,main,false,false))
	var document=load("res://scripts/editor/map_document.gd").new()
	check("editor_opens_calibrated_map",document.open_file("res://data/rooms/r04.json"))
	var ref: Dictionary=document.add("fixtures",Vector2(2450,2350),"tool_locker_v42")
	var normal: Rect2=document.geometry(ref)
	document.begin()
	document.set_geometry(ref,Rect2(normal.position+Vector2(30,40),normal.size*Vector2(2,0.5)))
	document.commit()
	check("editor_resize_keeps_canonical_proportions",document.geometry(ref).size.is_equal_approx(normal.size))
	document.undo()
	check("editor_undo_restores_placement",document.geometry(ref).is_equal_approx(normal))
	document.redo()
	check("editor_redo_keeps_canonical_proportions",document.geometry(ref).size.is_equal_approx(normal.size))
	var preview=load("res://scripts/editor/preview_geometry.gd").new()
	preview.update(document.data,false)
	preview.art_textures=game.world.art_textures
	var painter=load("res://scripts/presentation/world_volume.gd").new()
	root.add_child(painter)
	painter.configure(preview,"fixture",ref.index,game.presentation.profile,assets)
	check("editor_and_game_use_same_prop_dimensions",painter.display_rect.size.is_equal_approx(sizes.tool_locker_v42))
	painter.free()
	check("courtyard_layout_keeps_authored_dimensions",not assets.garden_tree_island_v48.get("proportion_locked",false) and not assets.garden_bed_horizontal_v48.get("proportion_locked",false))
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	FileAccess.open("res://docs/tests/p116-proportions.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"calibrated_instances":count,"asset_types":sizes.size()},"\t"))
	quit(0 if failed.is_empty() else 1)
