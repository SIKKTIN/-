extends Node2D

const Components = preload("res://scripts/presentation/wall_components.gd")
const Geometry = preload("res://scripts/presentation/roof_geometry.gd")

# The map's own painted wall fragments remain above the removable roof.
# Each wall is recorded once, including fragments shared by adjacent rooms.
class Edge extends Node2D:
	var texture: Texture2D
	var definition: Dictionary
	var display_rect := Rect2()
	var wall_index := -1
	var clips: Array[Rect2] = []
	var draw_builds := 0

	func _draw() -> void:
		draw_builds += 1
		for clip in clips:
			Components.paint(self,texture,definition,display_rect,false,clip)

var edges: Array = []
var strips: Array[Rect2] = []

func configure(rules) -> void:
	name = "RetainedRoofWallEdges"
	z_index = 4095
	var by_wall := Geometry.wall_edge_clips(rules.game.world,rules.rooms,rules.portal_cuts)
	for volume in rules.game.presentation.volumes:
		if volume.kind != "wall": continue
		var clips: Array[Rect2] = []
		clips.append_array(by_wall.get(volume.wall_index,[]))
		if clips.is_empty(): continue
		var edge := Edge.new()
		var id := str(volume.profile.grid_tile_asset)
		edge.texture = volume.world.art_textures[id]
		edge.definition = volume.definitions[id]
		edge.display_rect = volume.display_rect
		edge.wall_index = volume.wall_index
		edge.clips = clips
		edge.material = volume.material
		edge.texture_filter = volume.texture_filter
		edge.texture_repeat = volume.texture_repeat
		add_child(edge)
		edges.append(edge)
	# Older maps without the modular wall atlas retain their existing trim.
	for room in rules.rooms:
		room.retained_wall_edges = edges.any(func(e): return e.clips.any(func(c): return c.intersects(room.roof_plan.roof)))
