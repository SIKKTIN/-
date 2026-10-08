extends RefCounted

# Feet only, centred at the registered world foot origin. Sprite bounds,
# selection rings and detection/capture distances are independent of this.
const RADIUS := 8.0

# Independent projected body used only at door jambs/leaves. Includes the
# head and shoes of the 60–64px character art, not selection/status UI.
const DOOR_BODY := Rect2(-18,-64,36,68)

static func body_at(feet: Vector2) -> Rect2:
	return Rect2(feet+DOOR_BODY.position,DOOR_BODY.size)

static func door_anchor_obstacle(solid: Rect2) -> Rect2:
	# Minkowski difference: forbidden foot origins for a body/door overlap.
	# Shrinking by epsilon permits exact edge contact in both move and path.
	return Rect2(solid.position-DOOR_BODY.end,solid.size+DOOR_BODY.size).grow(-0.001)
