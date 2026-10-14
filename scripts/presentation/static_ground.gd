extends Node2D

# Each retained item has its own bounds. The renderer can cull distant
# markings and wall shadows instead of submitting the entire factory.
class Paint extends Node2D:
	var mode: String
	var spec: Dictionary={}
	var rect:=Rect2()
	var color:=Color()
	func _draw():
		match mode:
			"detail":preload("res://scripts/presentation/site_details.gd").paint(self,[spec])
			"zone":draw_rect(rect,color)

var builds:=0
var revision: int=-1
const CHUNK_SIZE := 512.0
var shadow_chunk_count := 0
var shadow_triangle_count := 0

func rebuild(game, presentation):
	if revision==game.world.fixtures_revision:return
	revision=game.world.fixtures_revision
	builds+=1
	for child in get_children():child.free()
	var world=game.world
	for spec in game.room_config.get("ground_details",[]):
		var node:=Paint.new()
		node.mode="detail"
		node.spec=spec
		add_child(node)
	for zone in game.room_config.get("zones",[]):
		var values: Array=zone.rect
		var node:=Paint.new()
		node.mode="zone"
		node.rect=Rect2(values[0],values[1],values[2],values[3]).intersection(world.bounds)
		node.color=Color(zone.color)
		node.color.a=0.13
		add_child(node)
	var sources: Dictionary={}
	var soft: bool=presentation.profile.get("soft_shadows",false)
	if soft:
		for volume in presentation.volumes:
			if not sources.has(volume.footprint):sources[volume.footprint]=volume
	var chunks: Dictionary={}
	for wall in world.walls:
		var commands: Array=[]
		if soft:
			var volume=sources.get(wall)
			if volume==null:continue
			var id: String=volume.prop_id() if volume.kind!="wall" else volume.asset_id("wall_top","low_wall_top_v02")
			if presentation.asset_definitions.get(id,{}).get("shadow_baked",false):continue
			commands=preload("res://scripts/presentation/soft_shadow.gd").rect_commands(wall,volume.elevation,world.bounds,presentation.profile)
		else:
			commands.append([Rect2(wall.position+Vector2(5,4),wall.size).intersection(world.bounds),Color(0,0,0,0.12)])
		for command in commands:_append_shadow(chunks,command[0],command[1])
	shadow_chunk_count=chunks.size()
	shadow_triangle_count=0
	for key in chunks:
		var batch: Dictionary=chunks[key]
		var arrays: Array=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=batch.vertices
		arrays[Mesh.ARRAY_COLOR]=batch.colors
		arrays[Mesh.ARRAY_INDEX]=batch.indices
		var mesh:=ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		var node:=MeshInstance2D.new()
		node.name="ShadowChunk_%d_%d" % [key.x,key.y]
		node.position=Vector2(key)*CHUNK_SIZE
		node.mesh=mesh
		add_child(node)
		shadow_triangle_count+=batch.indices.size()/3

func _append_shadow(chunks: Dictionary, shape: Variant, color: Color) -> void:
	var polygon: PackedVector2Array
	if shape is Rect2:
		if not shape.has_area():return
		polygon=PackedVector2Array([shape.position,shape.position+Vector2(shape.size.x,0),shape.end,shape.position+Vector2(0,shape.size.y)])
	else:polygon=shape
	if polygon.size()<3:return
	var bounds:=Rect2(polygon[0],Vector2.ZERO)
	for point in polygon:bounds=bounds.expand(point)
	var low:=Vector2i(floori(bounds.position.x/CHUNK_SIZE),floori(bounds.position.y/CHUNK_SIZE))
	var high:=Vector2i(ceili(bounds.end.x/CHUNK_SIZE),ceili(bounds.end.y/CHUNK_SIZE))
	for y in range(low.y,high.y):
		for x in range(low.x,high.x):
			var key:=Vector2i(x,y)
			var origin:=Vector2(key)*CHUNK_SIZE
			var limit:=PackedVector2Array([origin,origin+Vector2(CHUNK_SIZE,0),origin+Vector2.ONE*CHUNK_SIZE,origin+Vector2(0,CHUNK_SIZE)])
			for piece in Geometry2D.intersect_polygons(polygon,limit):
				var triangles:=Geometry2D.triangulate_polygon(piece)
				if triangles.is_empty():continue
				if not chunks.has(key):chunks[key]={"vertices":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array()}
				var batch: Dictionary=chunks[key]
				var offset: int=batch.vertices.size()
				for point in piece:
					batch.vertices.append(point-origin)
					batch.colors.append(color)
				for vertex in triangles:batch.indices.append(offset+vertex)
