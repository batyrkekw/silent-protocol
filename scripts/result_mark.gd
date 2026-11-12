extends Control
var progress = 0.0
var result = "running"
var clock = 0.0
var full_window = false
var animation: Tween
func set_result(value: String) -> void:
 if result == value: return
 result = value
 if animation and animation.is_valid(): animation.kill()
 progress = 0
 modulate.a = 1
 if full_window:
  visible = value in ["won","lost"]
  if not visible: return
 animation = create_tween()
 animation.tween_property(self,"progress",1.0,0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 if full_window:
  animation.tween_interval(1.1)
  animation.tween_property(self,"modulate:a",0.0,0.35)
  animation.tween_callback(hide)
func _process(delta: float) -> void:
 clock += delta
 queue_redraw()
func _draw() -> void:
 var p = size/2
 var scale = minf(size.x,size.y)/145.0 if full_window else 1.0
 var color = Color("73d8bb") if result == "won" else Color("ef8297")
 if full_window: draw_rect(Rect2(Vector2.ZERO,size),Color("080f1d",.96))
 draw_set_transform(p,0,Vector2.ONE*scale)
 if result not in ["won","lost"]:
  draw_arc(Vector2.ZERO,22,clock*2,clock*2+4.4,48,Color("83b8f5"),3,true)
  draw_set_transform(Vector2.ZERO)
  return
 draw_circle(Vector2.ZERO,32,Color(color,0.08))
 draw_arc(Vector2.ZERO,28,-PI/2,-PI/2+TAU*progress,64,Color(color,0.4),2,true)
 var points = [Vector2(-14,0),Vector2(-3,11),Vector2(17,-12)] if result == "won" else [Vector2(-12,-12),Vector2(12,12)]
 draw_line(points[0],points[0].lerp(points[1],clampf(progress*2,0,1)),color,4,true)
 if result == "won": draw_line(points[1],points[1].lerp(points[2],clampf(progress*2-1,0,1)),color,4,true)
 else: draw_line(Vector2(12,-12),Vector2(12,-12).lerp(Vector2(-12,12),clampf(progress*2-1,0,1)),color,4,true)
 draw_set_transform(Vector2.ZERO)
