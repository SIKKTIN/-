extends RefCounted

const WorldScale = preload("res://scripts/core/world_scale.gd")

# Feet only, centred at the registered world foot origin. Sprite bounds,
# selection rings and detection/capture distances are independent of this.
const RADIUS := 8.0
const ASPECT := Vector2(1, 0.375) # 16px wide, 6px deep ground contact.

static func front_contact_y(rect: Rect2) -> float:
	return rect.end.y+RADIUS*ASPECT.y

static func hits_rect(feet: Vector2, radius: float, solid: Rect2) -> bool:
	var closest := feet.clamp(solid.position, solid.end)
	return ((feet-closest)/ASPECT).length_squared() < radius*radius-0.001

static func inset(area: Rect2, radius: float = RADIUS) -> Rect2:
	return area.grow_individual(-radius, -radius*ASPECT.y, -radius, -radius*ASPECT.y)

static func expand(area: Rect2, radius: float = RADIUS) -> Rect2:
	return area.grow_individual(radius, radius*ASPECT.y, radius, radius*ASPECT.y)

# Full projected character at door jambs/leaves, including head and shoes.
# Status UI is excluded; ordinary floor/wall movement still uses 8x3 feet.
const DOOR_BODY := Rect2(-18*WorldScale.HUMAN,-64*WorldScale.HUMAN,36*WorldScale.HUMAN,64*WorldScale.HUMAN+4)

static func body_at(feet: Vector2) -> Rect2:
	return Rect2(feet+DOOR_BODY.position,DOOR_BODY.size)

static func door_anchor_obstacle(solid: Rect2) -> Rect2:
	# Minkowski difference: forbidden foot origins for a body/door overlap.
	# Shrinking by epsilon permits exact edge contact in both move and path.
	return Rect2(solid.position-DOOR_BODY.end,solid.size+DOOR_BODY.size).grow(-0.001)

# Still the whole person, but transparent space above the hair and beside
# the head/shoes should not block a slanted, fully-open clinical door leaf.
static func silhouette_obstacles(solid: Rect2) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var scale := WorldScale.HUMAN
	for body in [Rect2(-16*scale,-60*scale,32*scale,30*scale),Rect2(-18*scale,-30*scale,36*scale,20*scale),Rect2(-16*scale,-10*scale,32*scale,10*scale+4)]:
		result.append(Rect2(solid.position-body.end,solid.size+body.size).grow(-0.001))
	return result
