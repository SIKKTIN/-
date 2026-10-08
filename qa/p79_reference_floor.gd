extends Node2D
const TextureTiles=preload("res://scripts/presentation/texture_tiles.gd")
const ROOM=Rect2()
var game
func _draw() -> void:
	var world=game.world
	var map_camera=game.map_camera
	var floor_texture=game.floor_texture
	var floor_tile_size=game.floor_tile_size
	var room_config=game.room_config
	var floor_area: Rect2 = world.bounds if world else ROOM
	var clip: Rect2 = floor_area
	if map_camera:
		clip = map_camera.world_view_rect()
	draw_rect(clip,Color("a6b2a3"))
	if floor_texture:
		var tile := Vector2(floor_tile_size,floor_tile_size)
		var origin := floor_area.position+((clip.position-floor_area.position)/tile).floor()*tile
		var painted := Rect2(origin,((clip.end-origin)/tile).ceil()*tile)
		TextureTiles.paint(self,floor_texture,painted,tile,clip)
	if ResourceLoader.exists("res://scripts/presentation/region_terrain.gd"): load("res://scripts/presentation/region_terrain.gd").paint(self,room_config,clip)
