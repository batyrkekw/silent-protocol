extends PanelContainer
## Explicit insertion boundary: including an empty program and empty branches.
signal received(data, boundary: int)
var boundary = 0
var accepts: Callable
var highlighted = false
var chosen = false

func _can_drop_data(_at: Vector2, data) -> bool:
	highlighted = accepts.is_valid() and accepts.call(data, boundary)
	queue_redraw()
	return highlighted

func _drop_data(_at: Vector2, data) -> void:
	if accepts.call(data, boundary): received.emit(data, boundary)
	highlighted = false
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		highlighted = false
		queue_redraw()

func _draw() -> void:
	var color = Color("87d4ff") if highlighted else Color("54779a")
	if highlighted:
		draw_style_box(_outline(color), Rect2(Vector2.ZERO, size))
	elif chosen:
		draw_line(Vector2(2, 3), Vector2(size.x - 2, 3), color, 2)

func _outline(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color, .15)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
