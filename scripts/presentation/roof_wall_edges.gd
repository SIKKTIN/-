extends Node2D

const Components = preload("res://scripts/presentation/wall_components.gd")
const Sliding = preload("res://scripts/presentation/sliding_door_geometry.gd")
const Geometry = preload("res://scripts/presentation/roof_geometry.gd")

# The map's own painted wall fragments remain above the removable roof.
# Each wall is recorded once, including fragments shared by adjacent rooms.
class Edge extends Node2D:
	var texture: Texture2D
	var definition: Dictionary
	var textures: Dictionary
	var definitions: Dictionary
	var display_rect := Rect2()
	var wall_index := -1
	var clips: Array[Rect2] = []
	var draw_builds := 0

	func _draw() -> void:
		draw_builds += 1
		for clip in clips:
			Components.paint(self,texture,definition,display_rect,false,clip,Vector2.ZERO,textures,definitions)

var edges: Array = []
var strips: Array[Rect2] = []

func configure(rules) -> void:
	name = "RetainedRoofWallEdges"
	z_index = 4095
	var by_wall := Geometry.wall_edge_clips(rules.game.world,rules.rooms,rules.portal_cuts)
	var sliding_spans: Array = []
	for door in rules.doorways.doors:
		if not door.gate.has("sliding_door"): continue
		var sweep := Rect2()
		for fraction in [0.0,1.0]:
			for leaf in Sliding.leaves(door.gate,fraction):
				var area: Rect2 = leaf
				if posmod(int(door.gate.get("rotation_quarters",0)),4)>=2:
					area.position = Vector2(door.length,door.depth)-area.end
				area = door.transform*area
				sweep = area if not sweep.has_area() else sweep.merge(area)
		sliding_spans.append({"rect":sweep,"depth":door.z_index-1})
	for volume in rules.game.presentation.volumes:
		if volume.kind != "wall": continue
		var clips: Array[Rect2] = []
		clips.append_array(by_wall.get(volume.wall_index,[]))
		if clips.is_empty(): continue
		# A sliding leaf rests in front of the facade on either side of its
		# aperture. Only that travel span uses normal depth; the remaining
		# retained coping still stays above neighbouring removable roofs.
		# Split once, so animation never rebuilds static wall commands.
		for span in sliding_spans:
			var sweep: Rect2 = span.rect
			var remaining: Array[Rect2] = []
			var behind_leaf: Array[Rect2] = []
			for clip in clips:
				var hit := clip.intersection(sweep)
				if hit.has_area(): behind_leaf.append(hit)
				remaining.append_array(Geometry.subtract_all(clip,[sweep]))
			if not behind_leaf.is_empty():
				var edge := _add_edge(volume,behind_leaf)
				edge.z_as_relative = false
				edge.z_index = int(span.depth)
			clips = remaining
		if not clips.is_empty(): _add_edge(volume,clips)
	# Older maps without the modular wall atlas retain their existing trim.
	for room in rules.rooms:
		room.retained_wall_edges = edges.any(func(e): return e.clips.any(func(c): return c.intersects(room.roof_plan.roof)))

func _add_edge(volume, clips: Array[Rect2]) -> Edge:
	var edge := Edge.new()
	var id := str(volume.profile.grid_tile_asset)
	edge.texture = volume.world.art_textures[id]
	edge.definition = volume.definitions[id]
	edge.textures = volume.world.art_textures
	edge.definitions = volume.definitions
	edge.display_rect = volume.display_rect
	edge.wall_index = volume.wall_index
	edge.clips = clips
	edge.material = volume.material
	edge.texture_filter = volume.texture_filter
	edge.texture_repeat = volume.texture_repeat
	add_child(edge)
	edges.append(edge)
	return edge
