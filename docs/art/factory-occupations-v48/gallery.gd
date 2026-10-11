extends Node2D
const Library=preload("res://scripts/presentation/character_library.gd")
const TextureSource=preload("res://scripts/presentation/world_texture.gd")
var clock:=0.0
var font: Font
var animation: Dictionary={}
const IDS := ["canteen_cook","clinic_medic","maintenance_technician","warehouse_clerk","truck_driver","cleaner"]
func _ready() -> void:
	font=load("res://art/fonts/NotoSansCJKsc-Regular.otf")
	for id in IDS:
		var asset: Dictionary=Library.all()[id]
		var frames: Array=[]
		for frame in asset.walk_animation.frames:frames.append(TextureSource.load_asset({"texture":asset.texture,"region":frame.region}))
		animation[id]=frames
func _process(delta: float) -> void:
	clock+=delta;queue_redraw()
func _draw() -> void:
	if font==null:return
	draw_rect(Rect2(0,0,1280,820),Color("e9e3d5"))
	draw_string(font,Vector2(28,39),"职业人物素材 · 站立与行走",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("303b46"))
	draw_string(font,Vector2(30,68),"大图为 2 倍预览，下方为游戏实际比例",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("687367"))
	var i:=0
	for id in IDS:
		var asset: Dictionary=Library.all()[id]
		var origin:=Vector2(24+(i%3)*416,100+(i/3)*350)
		draw_rect(Rect2(origin,Vector2(400,328)),Color("f5efe1"))
		draw_rect(Rect2(origin,Vector2(400,328)),Color("b1b4a2"),false,1)
		draw_string(font,origin+Vector2(16,31),asset.name,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("303b46"))
		var frame: Dictionary=asset.walk_animation.frames[int(clock*12)%8]
		var texture: Texture2D=animation[id][int(clock*12)%8]
		var ratio: float=float(asset.world_height)/float(asset.scale_height)
		for entry in [[Library.idle(id),asset.anchor.idle,origin+Vector2(102,216),2.0],[texture,frame.anchor,origin+Vector2(299,216),2.0],[texture,frame.anchor,origin+Vector2(200,299),1.0]]:
			var t: Texture2D=entry[0];var anchor: Array=entry[1];var size:=t.get_size()*ratio*float(entry[3])
			draw_texture_rect(t,Rect2(entry[2]-Vector2(anchor[0],anchor[1])*ratio*float(entry[3]),size),false)
		i+=1
