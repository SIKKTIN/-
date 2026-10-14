extends RefCounted

const IDS := ["lin", "zhou", "xu", "lu"]
const VIEWS := ["back", "front", "side", "side"]
# Chair seat contact points, in the 1600x900 artwork coordinate system.
const SEATS := [Vector2(800,812),Vector2(800,164),Vector2(354,452),Vector2(1242,452)]
const HEIGHTS := [155.0,138.0,166.0,166.0]
const HIPS := [Vector2(0.5,0.78),Vector2(0.5,0.72),Vector2(0.37,0.76),Vector2(0.37,0.76)]
const TABLE := [Vector2(430,176),Vector2(1162,176),Vector2(1202,194),Vector2(1210,215),Vector2(1233,672),Vector2(1228,706),Vector2(1194,735),Vector2(413,735),Vector2(385,711),Vector2(369,677),Vector2(392,214),Vector2(398,195)]
const SOUTH_BACK := [Vector2(709,835),Vector2(888,835),Vector2(890,850),Vector2(881,892),Vector2(718,892),Vector2(710,850)]
const WEST_FRONT := [Vector2(295,458),Vector2(322,464),Vector2(330,502),Vector2(350,521),Vector2(333,537),Vector2(301,502)]
const EAST_FRONT := [Vector2(1280,462),Vector2(1305,457),Vector2(1301,501),Vector2(1270,534),Vector2(1253,519),Vector2(1278,502)]

static func pose_rect(index: int, texture: Texture2D) -> Rect2:
	var size: Vector2 = texture.get_size()*(float(HEIGHTS[index])/texture.get_height())
	var hip: Vector2 = HIPS[index]
	if index == 3: hip.x = 1.0-hip.x
	return Rect2(SEATS[index]-size*hip,size)

static func artwork_piece(canvas: CanvasItem, background: Texture2D, vertices: Array):
	var points := PackedVector2Array(vertices)
	var uv := PackedVector2Array()
	for point in points: uv.append(point/Vector2(1600,900))
	canvas.draw_polygon(points,PackedColorArray([Color.WHITE]),uv,background)

static func actor(canvas: CanvasItem, poses: Dictionary, index: int, upper_only := false):
	var texture: Texture2D = poses[IDS[index]][VIEWS[index]]
	var rect := pose_rect(index,texture)
	var fraction := 0.73 if upper_only else 1.0
	var source := Rect2(Vector2.ZERO,texture.get_size()*Vector2(1,fraction))
	var target := Rect2(Vector2.ZERO,rect.size*Vector2(1,fraction))
	canvas.draw_set_transform(Vector2(rect.end.x,rect.position.y) if index == 3 else rect.position,0,Vector2(-1,1) if index == 3 else Vector2.ONE)
	canvas.draw_texture_rect_region(texture,target,source)
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

static func draw(canvas: CanvasItem, background: Texture2D, poses: Dictionary, count: int):
	# Empty chairs and seats are the rear layer already present in the room artwork.
	canvas.draw_texture_rect(background,Rect2(Vector2.ZERO,Vector2(1600,900)),false)
	for index in range(1,count): actor(canvas,poses,index)
	# Actual tabletop silhouette hides knees, never the rectangular surrounding floor.
	artwork_piece(canvas,background,TABLE)
	for index in range(1,count): actor(canvas,poses,index,true)
	if count >= 3: artwork_piece(canvas,background,WEST_FRONT)
	if count >= 4: artwork_piece(canvas,background,EAST_FRONT)
	# Near player is in front of the table; the near chair back is in front of his hips.
	actor(canvas,poses,0)
	artwork_piece(canvas,background,SOUTH_BACK)
