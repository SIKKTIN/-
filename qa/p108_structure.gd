extends "res://qa/p101_npc_responses.gd"

func run():
	OS.set_environment("ESCAPE_TUTORIAL_MODE","off")
	OS.set_environment("ESCAPE_DEV_SETTINGS_PATH","user://p108-structure.cfg")
	OS.set_environment("ESCAPE_BUTTON_LAYOUT_PATH","user://p108-structure-buttons.cfg")
	root.size=Vector2i(1200,720)
	root.content_scale_size=root.size
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frame()
	game.set_process(false)
	game.fullscreen_ui.set_process(false)
	check("single_player_has_one_status_card",game.cards.size()==1 and game.actors.size()==3)
	check("retired_planner_not_constructed",game.get("routine_panel")==null and not game.routines.has_method("apply_today"))
	check("retired_skill_controls_not_constructed",game.get_node("HUD").find_child("UseSkill",true,false)==null and game.get("hint_label")==null)
	check("retired_transfer_controls_not_constructed",game.inventory_panel.get("transfer_buttons")==null and game.inventory_panel.get("label")==null)
	check("pathfinding_has_separate_component",game.world.pathfinding.get_script().resource_path=="res://scripts/world/world_navigation.gd")
	game.schedule.set_time_speed(1)
	var clock_before: float=game.schedule.clock_elapsed
	game.fullscreen_ui.toggle_menu()
	game._process(3)
	check("menu_still_blocks_input_and_clock",paused and game.world_input_blocked() and game.schedule.clock_elapsed==clock_before)
	game.fullscreen_ui.close_menu()
	game._process(0.1)
	check("resume_restores_clock_without_jump",not paused and game.schedule.clock_elapsed>clock_before and game.schedule.clock_elapsed-clock_before<0.2)
	game.select_actor(2)
	check("npc_cannot_be_selected",game.selected_actor_id==0)
	var old_catalog:=GDScript.new()
	old_catalog.source_code=FileAccess.get_file_as_string("res://docs/dev/p108/baseline/scripts/presentation/prop_catalog.gd.txt")
	check("baseline_catalog_compiles",old_catalog.reload()==OK)
	var before: Dictionary=old_catalog.assets()
	var after: Dictionary=load("res://scripts/presentation/prop_catalog.gd").assets()
	# Keep the refactor's source baseline, except the explicitly redesigned
	# bedside cabinet. Its stable ID keeps existing maps and saves compatible.
	var sources_preserved: bool=before.keys().all(func(id):return after.has(id))
	for id in before:
		if not after.has(id):sources_preserved=false;continue
		var original: Dictionary=before[id].duplicate(true)
		var current: Dictionary=after[id].duplicate(true)
		if id=="bedside_cabinet_v44":
			check("bedside_replacement_registered_and_loadable",current.authoring_set=="bedside-v51" and load(current.texture) is Texture2D and FileAccess.get_sha256(current.texture)==str(current.sha256))
			continue
		if current.get("proportion_locked",false):
			for field in ["world_size","render_size","footprint_world_size","elevation_world","proportion_locked","proportion_reference_human_height"]:
				original.erase(field)
				current.erase(field)
		if original!=current:sources_preserved=false
	check("catalog_preserves_every_source_asset",sources_preserved)
	var document=load("res://scripts/editor/map_document.gd").new()
	check("editor_still_opens_current_map",document.open_file("res://data/rooms/r04.json"))
	var validation: Dictionary=document.validate()
	if not validation.errors.is_empty() or not validation.warnings.is_empty():print(validation)
	check("editor_validates_current_map",validation.errors.is_empty() and validation.warnings.is_empty())
	check("editor_scene_remains_loadable",load("res://scenes/editor/map_editor.tscn") is PackedScene)
	var parsed:=[]
	var paths:=PackedStringArray()
	collect_scripts("res://scripts",paths)
	for path in paths:
		var script=load(path)
		if script==null or not script.can_instantiate():parsed.append(path)
	check("every_production_script_compiles",parsed.is_empty())
	var failed: Array=checks.keys().filter(func(key):return not checks[key])
	FileAccess.open("res://docs/tests/p108-structure.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"invalid_scripts":parsed,"compiled_script_count":paths.size(),"asset_count":after.size()},"\t"))
	quit(0 if failed.is_empty() else 1)

func collect_scripts(dir: String, output: PackedStringArray):
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):output.append(dir+"/"+name)
	for name in DirAccess.get_directories_at(dir):collect_scripts(dir+"/"+name,output)
