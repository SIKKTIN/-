extends Node2D

# Each retained item has its own bounds. The renderer can cull distant
# markings and wall shadows instead of submitting the entire factory.
class Paint extends Node2D:
	var mode: String
	var spec: Dictionary={}
	var rect:=Rect2()
	var clip:=Rect2()
	var color:=Color()
	var height:=0.0
	var settings: Dictionary={}
	func _draw():
		match mode:
			"detail":preload("res://scripts/presentation/site_details.gd").paint(self,[spec])
			"zone","hard_shadow":draw_rect(rect,color)
			"soft_shadow":preload("res://scripts/presentation/soft_shadow.gd").contact_rect(self,rect,height,clip,settings)

var builds:=0
var revision: int=-1

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
	for wall in world.walls:
		var node:=Paint.new()
		if soft:
			var volume=sources.get(wall)
			if volume==null:node.free();continue
			var id: String=volume.prop_id() if volume.kind!="wall" else volume.asset_id("wall_top","low_wall_top_v02")
			if presentation.asset_definitions.get(id,{}).get("shadow_baked",false):node.free();continue
			node.mode="soft_shadow"
			node.rect=wall
			node.height=volume.elevation
			node.clip=world.bounds
			node.settings=presentation.profile
		else:
			node.mode="hard_shadow"
			node.rect=Rect2(wall.position+Vector2(5,4),wall.size).intersection(world.bounds)
			node.color=Color(0,0,0,0.12)
		add_child(node)
