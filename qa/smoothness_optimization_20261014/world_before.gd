extends "res://scripts/world/prison_world.gd"
func _init():
 pathfinding=load("res://qa/smoothness_optimization_20261014/navigation_before.gd").new(self)

 solid_index=load("res://docs/dev/smoothness-optimization-2026-10-14/solid_spatial_index-before.gd").new()
 inspection_index=load("res://docs/dev/smoothness-optimization-2026-10-14/solid_spatial_index-before.gd").new()
 sight_index=load("res://docs/dev/smoothness-optimization-2026-10-14/solid_spatial_index-before.gd").new()
 body_index=load("res://docs/dev/smoothness-optimization-2026-10-14/solid_spatial_index-before.gd").new()
 inspection_body_index=load("res://docs/dev/smoothness-optimization-2026-10-14/solid_spatial_index-before.gd").new()

func can_place_circle(point: Vector2, radius: float = RADIUS, ignore_actor = null, check_actors: bool = true, include_crate: bool = true) -> bool:
 if not door_body_clear(point): return false
 if ignore_actor in actors and admission_filter.is_valid() and not admission_filter.call(ignore_actor,point,radius): return false
 if ignore_actor != null and ignore_actor.has_method("movement_allowed") and not ignore_actor.movement_allowed(point,radius):
  return false
 if not inside_room(point, radius) and not _staff_exterior(ignore_actor,point,radius):
  return false
 var index = inspection_index if planning_guard_doors else solid_index
 if index.revision != obstacle_revision: index.rebuild(solid_rects(false),obstacle_revision)
 for rect in index.nearby(point,radius):
  if _circle_hits_rect(point, radius, rect): return false
 if include_crate and _circle_hits_rect(point,radius,crate): return false
 if check_actors:
  for actor in actors:
   if actor != ignore_actor and not actor.escaped and ((point-actor.position)/Footprint.ASPECT).length() < radius + RADIUS - 0.01:
    # A capture can restore an occupied home; allow separation without pushing another person.
    if ignore_actor != null and ((ignore_actor.position-actor.position)/Footprint.ASPECT).length() < radius + RADIUS and ((point-actor.position)/Footprint.ASPECT).length_squared() > ((ignore_actor.position-actor.position)/Footprint.ASPECT).length_squared():
     continue
    return false
 return true

