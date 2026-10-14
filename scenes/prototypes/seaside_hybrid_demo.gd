extends "res://scenes/prototypes/seaside_hybrid_ui.gd"
const WorldTexture = preload("res://scripts/presentation/world_texture.gd")
var pier_art: Texture2D
var player_art: Texture2D
var grass_art: Texture2D
var shrubs: Array[Texture2D] = []

func _ready() -> void:
	super._ready()
	grass_art=WorldTexture.load_asset({"texture":"res://art/environment/factory_v46/floor_atlas.png","region":[1024,512,512,512]})
	surface_material.shader=load("res://art/fx/seaside_hybrid_v3/surface.gdshader")
	surface_material.set_shader_parameter("grass_map",grass_art)
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/fx/seaside_swe_style_v2/manifest.json"))
	pier_art=WorldTexture.load_asset(manifest.pier)
	var character_manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/manifest-v03.json"))
	var player:Dictionary=character_manifest.actors[0]
	player_art=WorldTexture.load_asset({"texture":player.texture,"region":player.frames.idle})
	var environment:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/environment/factory_v46/manifest.json"))
	for asset in environment.assets:
		if str(asset.id).begins_with("shrub_single_"): shrubs.append(WorldTexture.load_asset(asset))
	for child in get_children():
		if child is Label and child.text.begins_with("2D 计算海水"):
			child.text="2D 海水 · FFT 海浪 + 近岸模拟"
			child.add_theme_color_override("font_color",Color("e6dcc6"))
		elif child is ColorRect and child!=water:
			child.color=Color("303b37")
	note.text="两层计算海浪 · 近岸 / 桥墩碰撞 · 随流泡沫与喷溅；左键点击水面可施加扰动。"
	_create_spray()
	pier.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var edges:=ShaderMaterial.new()
	edges.shader=load("res://art/architecture/v25/safe_edges_v25.gdshader")
	pier.material=edges
	pier.queue_redraw()

func _draw_pier() -> void:
	if mode!=0 or pier_art==null: return
	var s:=water.size
	var planting: Array[Vector2]=[Vector2(.16,.91),Vector2(.26,.94),Vector2(.75,.89),Vector2(.84,.94),Vector2(.91,.87)]
	for i in planting.size():
		if shrubs.is_empty(): break
		var t:Texture2D=shrubs[i%shrubs.size()]
		var width:=42.0; var height:=width*t.get_height()/float(t.get_width())
		pier.draw_texture_rect(t,Rect2(s*planting[i]-Vector2(width/2,height/2),Vector2(width,height)),false)
	if not show_pier: return
	# Artwork is mapped to the same T deck and immersed piers used by the numerical sample.
	var deck:=Rect2(s*Vector2(.392,.306),s*Vector2(.216,.654))
	pier.draw_texture_rect(pier_art,deck,false)
	if player_art!=null:
		var height:=42.0
		var width:=height*player_art.get_width()/float(player_art.get_height())
		var feet:=s*Vector2(.5,.415)
		pier.draw_circle(feet+Vector2(3,2),8,Color(0,0,0,.18))
		pier.draw_texture_rect(player_art,Rect2(feet-Vector2(width/2,height),Vector2(width,height)),false)

func use_style(enabled: bool) -> void:
	surface_material.shader=load("res://art/fx/seaside_swe_style_v2/surface.gdshader" if enabled else "res://art/fx/seaside_swe_v1/surface.gdshader")
	if enabled: surface_material.set_shader_parameter("grass_map",grass_art)
	_refresh()

var spray: GPUParticles2D
func _create_spray() -> void:
	spray=GPUParticles2D.new();spray.position=water.position;spray.amount=600;spray.lifetime=1.3
	spray.visibility_rect=Rect2(-100,-100,1400,900);spray.local_coords=true;spray.randomness=0.8
	var process:=ShaderMaterial.new();process.shader=load("res://art/fx/seaside_hybrid_v3/spray.gdshader")
	process.set_shader_parameter("canvas_size",water.size);spray.process_material=process
	var draw_material:=ShaderMaterial.new();draw_material.shader=load("res://art/fx/seaside_hybrid_v3/drop.gdshader")
	spray.material=draw_material
	var img:=Image.create(6,6,false,Image.FORMAT_RGBA8);img.fill(Color.WHITE);spray.texture=ImageTexture.create_from_image(img)
	add_child(spray);move_child(spray,get_children().find(pier));spray.emitting=true

func _refresh() -> void:
	super._refresh()
	if not solver.initialized:return
	surface_material.set_shader_parameter("ocean_map",solver.ocean_texture)
	surface_material.set_shader_parameter("foam_map",solver.foam_textures[solver.front])
	surface_material.set_shader_parameter("world_size",Vector2(solver.grid_size)*solver.WIDTH_METRES/solver.grid_size.x)
	if spray!=null:
		var mat:=spray.process_material as ShaderMaterial
		mat.set_shader_parameter("sim_state",solver.state_textures[solver.front]);mat.set_shader_parameter("bed_map",solver.bed_texture)
		mat.set_shader_parameter("foam_map",solver.foam_textures[solver.front]);mat.set_shader_parameter("enabled",not solver.paused and solver.foam_enabled and mode==0)
		spray.speed_scale=0.0 if solver.paused else 1.0

func set_view(index: int) -> void:
	super.set_view(index)
	if spray!=null:spray.visible=index==0

func _process(_delta: float) -> void:
	if spray!=null and is_instance_valid(solver):
		spray.speed_scale=0.0 if solver.paused else 1.0
