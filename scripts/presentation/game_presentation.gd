extends Node

const ActorVisual = preload("res://scripts/presentation/actor_visual.gd")
const WorldVolume = preload("res://scripts/presentation/world_volume.gd")
const SceneLayers = preload("res://scripts/presentation/scene_layers.gd")
const LightingSystem = preload("res://scripts/presentation/lighting_system.gd")
const InteractionPrompt = preload("res://scripts/presentation/interaction_prompt.gd")
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
const DogVisual = preload("res://scripts/presentation/dog_visual.gd")
var game
var visuals: Array = []
var skill_icons: Dictionary = {}
var font: Font
var loops: Dictionary = {}
var streams: Dictionary = {}
var events: Array = []
var previous: Dictionary = {}
var mute_button: Button
var muted: bool = false
var label_states: Array[Label] = []
var font_size: int = 17
var asset_version: String = ""
var fx: Dictionary = {}
var card_symbols: Array[TextureRect] = []
var audio_available: bool = true
var profile: Dictionary = {}
var profile_id: String = "v01"
var volumes: Array = []
var scene_layers: Array = []
var asset_definitions: Dictionary = {}
var lighting
var interaction
var dog_visual

func configure(escape_game) -> void:
	game = escape_game
	audio_available = DisplayServer.get_name() != "headless"
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://art/fonts/NotoSansCJKsc-Regular.otf")
	var active: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/active.json"))
	profile_id = OS.get_environment("ESCAPE_ART_PROFILE")
	if profile_id not in ["v01","v02","v03"] or not FileAccess.file_exists("res://data/presentation/%s.json" % profile_id):
		profile_id = active.profile
	profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/%s.json" % profile_id))
	var delivery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.delivery))
	asset_version = delivery.version
	for id in ["chat","lockpick","strong"]:
		skill_icons[id] = load("res://art/ui/skill_%s_v01.png" % id)
	skill_icons["backpack"] = null # A05 provides the new passive skill icon.
	for id in ["selected","detected","searching","escaped","captured","cancelled"]:
		fx[id] = load("res://art/fx/%s_v01.png" % id)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.characters))
	var walk_definitions := {}
	var motion_path: String = OS.get_environment("ESCAPE_WALK_MANIFEST")
	if motion_path.is_empty():
		motion_path = str(active.get("character_motion",""))
	if profile_id == "v03" and not motion_path.is_empty() and FileAccess.file_exists(motion_path):
		var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(motion_path))
		for entry in motion.actors:
			walk_definitions[str(entry.actor_id)] = entry.walk_animation
	for asset in manifest.actors:
		asset = asset.duplicate(true)
		if walk_definitions.has(str(asset.actor_id)):
			asset.walk_animation = walk_definitions[str(asset.actor_id)]
		# Guard is a logic role. Its active appearance can be a civilian lookout,
		# and gate guards/reinforcements inherit this complete definition.
		var guard_appearance: String = str(active.get("guard_appearance",""))
		if str(asset.actor_id) == "guard" and not guard_appearance.is_empty() and FileAccess.file_exists(guard_appearance):
			asset = JSON.parse_string(FileAccess.get_file_as_string(guard_appearance))
		var actor = game.guard if str(asset.actor_id) == "guard" else game.actors[int(asset.actor_id)]
		actor.art_body = true
		actor.z_index = 15 if actor == game.guard else 20
		var visual = ActorVisual.new()
		visual.name = "ArtVisual"
		actor.add_child(visual)
		visual.configure(actor,game,asset,skill_icons,font)
		if actor == game.guard:
			visual.light_mask = 2
		visual.separate_information = profile.perspective
		actor.presentation_layers = profile.perspective
		visual.fx = fx
		visuals.append(visual)
		actor.queue_redraw()
	for file in ["environment","props"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile[file]))
		for asset in data.assets:
			asset_definitions[asset.id] = asset
			game.world.art_textures[asset.id] = _load_texture(asset)
	var prison_manifest := "res://art/props/prison_v08/manifest.json"
	if FileAccess.file_exists(prison_manifest):
		var prison_assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prison_manifest))
		for asset in prison_assets.assets:
			asset_definitions[asset.id] = asset
	var cafeteria_manifest := "res://art/props/cafeteria_v14/manifest.json"
	if FileAccess.file_exists(cafeteria_manifest):
		var cafeteria_assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cafeteria_manifest))
		for asset in cafeteria_assets.assets:
			asset_definitions[asset.id] = asset
	game.world.queue_redraw()
	game.floor_texture = game.world.art_textures[profile.floor_asset] if profile.has("floor_asset") else load(profile.floor)
	game.floor_tile_size = profile.floor_tile_size
	game.perspective_floor = profile.perspective
	if profile.perspective:
		game.world.presentation_layers = true
		game.world.art_textures.exit_v01 = load("res://art/props/exit_v01.png")
		for kind in ["ground","fixture_shadows","information"]:
			var layer = SceneLayers.new()
			layer.name = "Scene_%s" % kind
			game.add_child(layer)
			layer.configure(game,self,kind)
			scene_layers.append(layer)
		_refresh_volumes()
	_make_ui()
	lighting = LightingSystem.new()
	lighting.name = "Lighting"
	game.add_child(lighting)
	lighting.configure(game,mute_button.theme)
	interaction = InteractionPrompt.new()
	interaction.name = "InteractionPrompt"
	add_child(interaction)
	interaction.configure(game,self)
	dog_visual = DogVisual.new()
	dog_visual.name = "DogVisual"
	game.dog.add_child(dog_visual)
	dog_visual.configure(game,str(active.get("police_dog","")))
	_make_audio()
	reset()

func _load_texture(asset: Dictionary) -> Texture2D:
	return WorldTexture.load_asset(asset)

func _make_ui() -> void:
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = font_size
	var normal := StyleBoxTexture.new()
	normal.texture = load("res://art/ui/paper_card_v01.png")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		normal.set_texture_margin(side,12)
		normal.set_content_margin(side,8)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color("e0eee3")
	selected.border_color = Color("328b82")
	selected.set_border_width_all(3)
	selected.set_corner_radius_all(5)
	selected.set_content_margin_all(8)
	for state in ["normal","hover","pressed","disabled"]:
		theme.set_stylebox(state,"Button",normal if state == "normal" or state == "disabled" else selected)
		theme.set_color("font_color" if state == "normal" else "font_%s_color" % state,"Button",Color("303b46") if state != "disabled" else Color("68776e"))
	theme.set_stylebox("focus","Button",selected)
	theme.set_color("font_color","Label",Color("303b46"))
	for control in game.get_node("HUD").get_children():
		if control is Control:
			control.theme = theme
	for index in range(game.cards.size()):
		var card = game.cards[index]
		card.add_theme_font_size_override("font_size",17)
		card.set_meta("base_style",normal)
		card.set_meta("selected_style",selected)
		card.icon = skill_icons[game.actors[index].skill_id]
		card.add_theme_constant_override("icon_max_width",32)
		card.expand_icon = true
		var symbol := TextureRect.new()
		symbol.position = Vector2(123,60)
		symbol.size = Vector2(24,24)
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(symbol)
		card_symbols.append(symbol)
	game.hint_label.add_theme_font_size_override("font_size",15)
	game.hint_label.position.y = 560
	game.hint_label.size.y = 66
	game.skill_button.visible = false
	var controls := Label.new()
	controls.name = "ControlHint"
	controls.text = "轻点选人 / 空地移动\n拖主图或小地图移视野\n定位 / 停止见小地图"
	controls.position = Vector2(1029,648)
	controls.theme = theme
	controls.add_theme_font_size_override("font_size",12)
	game.get_node("HUD").add_child(controls)
	var instructions := Label.new()
	instructions.text = "轻点选人 / 空地移动 · 单指拖动视野 · 小地图点击 / 拖动 · 靠近点图标互动"
	instructions.position = Vector2(34,91)
	instructions.theme = theme
	instructions.add_theme_font_size_override("font_size",15)
	game.get_node("HUD").add_child(instructions)
	mute_button = Button.new()
	mute_button.name = "ToggleSound"
	mute_button.position = Vector2(819,35)
	mute_button.size = Vector2(159,42)
	mute_button.theme = theme
	mute_button.text = "声音：开"
	mute_button.pressed.connect(func():
		muted = not muted
		mute_button.text = "声音：关" if muted else "声音：开"
		if muted:
			stop_all()
	)
	game.get_node("HUD").add_child(mute_button)

func _make_audio() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/manifest.json"))
	for cue in manifest.cues:
		var stream: AudioStreamWAV = load(cue.file).duplicate()
		if cue.loop:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = stream.data.size() / 2
		streams[cue.id] = stream
		if cue.loop:
			var player := AudioStreamPlayer.new()
			player.name = cue.id
			player.stream = stream
			player.volume_db = -4
			add_child(player)
			loops[cue.id] = player

func reset() -> void:
	stop_all()
	if dog_visual:
		dog_visual.tick_visual(0)
	events.clear()
	previous = _state()
	for visual in visuals:
		visual.actor.moved_this_frame = false
		visual.flip_h = false
		visual.flash_time = 0
		visual.tick_visual(0)
	update_cards()
	_tick_scene()
	if lighting:
		lighting.tick()
	if interaction:
		interaction.refresh()

func _refresh_volumes() -> void:
	for volume in volumes:
		volume.free()
	volumes.clear()
	for fixture in game.world.fixtures:
		var id: String = fixture.asset_id
		if not game.world.art_textures.has(id) and asset_definitions.has(id):
			var texture: Texture2D = _load_texture(asset_definitions[id])
			if texture != null:
				game.world.art_textures[id] = texture
	for index in range(game.world.walls.size()):
		_add_volume("wall",index)
	for index in range(game.world.fixtures.size()):
		_add_volume("fixture",index)
	_add_volume("door")
	_add_volume("crate")
	for layer in scene_layers:
		if layer.kind == "fixture_shadows":
			layer.queue_redraw()

func _add_volume(kind: String, index: int = 0) -> void:
	var volume = WorldVolume.new()
	game.add_child(volume)
	volume.configure(game.world,kind,index,profile,asset_definitions)
	volumes.append(volume)

func _tick_scene() -> void:
	if not profile.get("perspective",false):
		return
	if volumes.size() != game.world.walls.size()+game.world.fixtures.size()+2:
		_refresh_volumes()
	for visual in visuals:
		visual.actor.z_index = int(visual.actor.position.y)
	for volume in volumes:
		volume.tick_visual()
	for layer in scene_layers:
		if layer.kind == "fixture_shadows":
			if layer.fixtures_revision != game.world.fixtures_revision:
				layer.fixtures_revision = game.world.fixtures_revision
				layer.queue_redraw()
		else:
			layer.queue_redraw()

func _state() -> Dictionary:
	return {"actions":game.skills.actions.duplicate(true),"guard":game.guard.state,"captures":game.captures,"door":game.world.door_open,"escaped":game.actors.map(func(a): return a.escaped),"immune":game.actors.map(func(a): return a.immune_until),"crate":game.world.crate.position,"phase":game.phase,"deal":game.deal_number}

func tick(delta: float) -> void:
	for visual in visuals:
		visual.tick_visual(delta)
	if dog_visual:
		dog_visual.tick_visual(delta)
	_tick_scene()
	if lighting:
		lighting.tick()
	if interaction:
		interaction.refresh()
	update_cards()
	var now := _state()
	var active: bool = game.phase == "playing" and not game.get_tree().paused and not muted and audio_available
	var chat: bool = game.actors.any(func(a): return a.action_state == "chatting")
	var lock: bool = game.actors.any(func(a): return a.action_state == "lockpicking")
	var push: bool = previous.get("crate",now.crate).distance_squared_to(now.crate) > 0.0001
	_loop("chat_loop",active and chat)
	_loop("lockpick_loop",active and lock)
	_loop("crate_move_loop",active and push)
	if previous.get("deal",now.deal) == now.deal:
		if now.captures > previous.get("captures",now.captures):
			cue("captured")
			for id in range(3):
				if now.immune[id] > previous.get("immune",now.immune)[id]:
					visuals[id].show_event("captured")
		if now.guard == "chasing" and previous.get("guard",now.guard) != "chasing":
			cue("detected")
		if now.door and not previous.get("door",now.door):
			cue("door_open")
		var old_escaped: Array = previous.get("escaped",now.escaped)
		for index in range(3):
			if now.escaped[index] and not old_escaped[index]:
				cue("escaped")
		if now.phase == "complete" and previous.get("phase",now.phase) != "complete":
			cue("complete")
		for id in previous.get("actions",{}):
			if not now.actions.has(id) and (previous.actions[id].kind != "lockpick" or not now.door) and not now.escaped[id] and now.captures == previous.get("captures",now.captures):
				cue("cancelled")
				visuals[id].show_event("cancelled")
	previous = now

func update_cards() -> void:
	for index in range(game.cards.size()):
		var card = game.cards[index]
		var actor = game.actors[index]
		card.icon = null if game.fullscreen_ui else skill_icons[actor.skill_id]
		if game.fullscreen_ui:
			card.text = ""
		card.add_theme_stylebox_override("normal",card.get_meta("selected_style") if actor.selected and not actor.escaped else card.get_meta("base_style"))
		var symbol: TextureRect = card_symbols[index]
		symbol.visible = not game.fullscreen_ui and (actor.escaped or actor.selected or visuals[index].flash_time > 0)
		symbol.texture = fx.escaped if actor.escaped else (fx[visuals[index].flash_state] if visuals[index].flash_time > 0 else fx.selected)

func _loop(id: String, active: bool) -> void:
	var player: AudioStreamPlayer = loops[id]
	if active and not player.playing:
		player.play()
	elif not active:
		player.stop()

func cue(id: String) -> void:
	events.append({"id":id,"elapsed":game.elapsed})
	if events.size() > 32:
		events.pop_front()
	if muted or game.get_tree().paused or not audio_available:
		return
	var player := AudioStreamPlayer.new()
	player.stream = streams[id]
	player.volume_db = -4
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func stop_all() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			if not loops.values().has(child):
				child.queue_free()

func _process(_delta: float) -> void:
	if game and (get_tree().paused or muted):
		stop_all()

func _exit_tree() -> void:
	stop_all()

func snapshot() -> Dictionary:
	var playback := {}
	for id in loops:
		playback[id] = loops[id].playing
	return {"asset_version":asset_version,"profile":profile_id,"render_settings":profile.duplicate(true),"visuals":visuals.map(func(v): return v.snapshot()),"loops":playback,"events":events.duplicate(true),"muted":muted,"lighting":lighting.snapshot() if lighting else {},"interaction":interaction.snapshot() if interaction else {}}
