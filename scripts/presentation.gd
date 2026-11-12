extends RefCounted
## Visual interpolation never pushes another robot or changes its path.
static func robot_cell(robot: Dictionary, alpha: float) -> Vector2:
 if not robot.path.is_empty() and not robot.blocked:
  var t = clampf((robot.move_clock + alpha) / float(robot.move_period),0,1)
  return Vector2(robot.pos).lerp(Vector2(robot.path[0]),t)
 return Vector2(robot.pos)

static func layout(robots: Array, tile: Vector2, alpha: float) -> Array:
 var result: Array = []
 for r in robots:
  result.append({"position":(robot_cell(r,alpha)+Vector2(0.5,0.5))*tile,"scale":minf(.70,minf(tile.x,tile.y)/35.0)})
 return result
