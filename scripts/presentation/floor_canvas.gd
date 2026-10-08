extends Node2D

var game
var cached_area := Rect2()
var key: Array = []
var builds := 0

func configure(owner_game) -> void:
	game=owner_game
	name="RetainedFloor"
	z_index=-2000
	texture_filter=game.texture_filter
	_process(0)

func _process(_delta: float) -> void:
	if not game: return
	var view: Rect2=game.map_camera.world_view_rect() if game.map_camera else game.world.bounds
	var next_key := [game.world.fixtures_revision,game.floor_texture,game.floor_tile_size]
	if key!=next_key or not cached_area.encloses(view):
		key=next_key
		# Keep world-registered terrain ahead of the camera. It scrolls with
		# the world; only reaching this margin requires new drawing commands.
		cached_area=view.grow(256)
		queue_redraw()

func _draw() -> void:
	if game:
		builds+=1
		game.paint_floor(self,cached_area)
