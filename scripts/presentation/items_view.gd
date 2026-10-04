extends Node2D

var game
var assets: Dictionary = {}
var textures: Dictionary = {}
var merchant_asset: Dictionary = {}

func configure(owner_game) -> void:
	game = owner_game
	z_index = 21
	reload_assets()

func reload_assets() -> void:
	var path := "res://docs/art/inventory-assets-v07.json"
	if not FileAccess.file_exists(path):
		return
	assets = JSON.parse_string(FileAccess.get_file_as_string(path))
	for section in ["items", "icons"]:
		for id in assets.get(section, {}):
			var spec: Dictionary = assets[section][id]
			textures[id] = _texture(spec)
	merchant_asset = assets.get("merchant", {})
	if not merchant_asset.is_empty():
		textures["merchant"] = _texture(merchant_asset)
	if textures.has("backpack"):
		game.presentation.skill_icons["backpack"] = textures.backpack

func _texture(spec: Dictionary) -> Texture2D:
	var path := str(spec.texture)
	var original: Texture2D
	if FileAccess.file_exists(path+".import"):
		original = load(path)
	else:
		var raw := Image.load_from_file(path)
		if raw == null or raw.is_empty():
			return null
		original = ImageTexture.create_from_image(raw)
	if not spec.has("region"):
		return original
	var rect: Array = spec.region
	var atlas := AtlasTexture.new()
	atlas.atlas = original
	atlas.region = Rect2(rect[0], rect[1], rect[2], rect[3])
	atlas.filter_clip = true
	return atlas

func icon_for(id: String) -> Texture2D:
	return textures.get(id)

func _draw() -> void:
	if not game:
		return
	for item in game.inventory.instances.values():
		if item.location != "ground":
			continue
		var point := Vector2(item.position[0], item.position[1])
		var id := str(item.definition_id)
		if textures.get(id) != null:
			draw_texture_rect(textures[id], Rect2(point - Vector2(13, 24), Vector2(26, 26)), false)
		else:
			draw_circle(point - Vector2(0, 10), 11, Color("e1c787"))
			draw_arc(point - Vector2(0, 10), 11, 0, TAU, 24, Color("536052"), 2, true)
	for merchant in game.trade.merchants.values():
		var point := Vector2(merchant.position[0], merchant.position[1])
		if not merchant_asset.get("shadow_baked",false):
			draw_ellipse(point+Vector2(0,2),15,4,Color(0,0,0,0.14))
		if textures.get("merchant") != null:
			var texture: Texture2D = textures.merchant
			var height := float(merchant_asset.get("world_height", 64))
			var ratio := height / texture.get_height()
			var anchor: Array = merchant_asset.get("anchor", [texture.get_width()/2.0, texture.get_height()])
			draw_texture_rect(texture, Rect2(point - Vector2(anchor[0], anchor[1])*ratio, texture.get_size()*ratio), false)
		else:
			draw_circle(point - Vector2(0, 44), 10, Color("e8bf8c"))
			draw_rect(Rect2(point - Vector2(14, 33), Vector2(28, 31)), Color("568880"))
			draw_line(point - Vector2(0, 60), point - Vector2(0, 51), Color("536052"), 25)
	if not game.perspective_floor:
		paint_information(self)

func paint_information(canvas: CanvasItem) -> void:
	for item in game.inventory.instances.values():
		if item.location == "ground":
			var point := Vector2(item.position[0],item.position[1])
			var label := str(game.inventory.definitions.get(item.definition_id,{}).get("short",item.definition_id))
			canvas.draw_string(game.presentation.font,point+Vector2(-14,16),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e1e9df") if game.presentation.lighting.period == "night" else Color("536052"))
	for merchant in game.trade.merchants.values():
		var point := Vector2(merchant.position[0],merchant.position[1])
		var badge := Rect2(point+Vector2(-32,12),Vector2(64,23))
		canvas.draw_rect(badge,Color("f2ebdd"))
		canvas.draw_string(game.presentation.font,badge.position+Vector2(5,17),"商人",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("303b46"))
