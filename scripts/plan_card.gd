extends PanelContainer
signal moved(source: int, destination: int)
signal dropped(data, boundary: int)
var index = 0
var robot_id = 0
var editable = true
var accepts: Callable
var caption = ""
var drop_boundary = -1

func _get_drag_data(_at: Vector2):
	if not editable: return null
	var preview = PanelContainer.new()
	preview.add_theme_stylebox_override("panel", get_theme_stylebox("panel"))
	var label = Label.new()
	label.text = caption if not caption.is_empty() else "Переместить шаг %d" % (index + 1)
	label.add_theme_font_override("font", get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 16)
	preview.add_child(label)
	set_drag_preview(preview)
	return {"kind":"plan_step", "robot":robot_id, "index":index}

func _can_drop_data(at: Vector2, data) -> bool:
	var boundary = index if at.y < size.y / 2 else index + 1
	var valid = accepts.is_valid() and accepts.call(data, boundary)
	drop_boundary = boundary if valid else -1
	queue_redraw()
	return valid

func _drop_data(at: Vector2, data) -> void:
	var boundary = index if at.y < size.y / 2 else index + 1
	if accepts.is_valid() and accepts.call(data, boundary): dropped.emit(data, boundary)
	drop_boundary = -1
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		drop_boundary = -1
		queue_redraw()

func _draw() -> void:
	if drop_boundary >= 0:
		var y = 2.0 if drop_boundary == index else size.y - 2.0
		draw_line(Vector2(2,y),Vector2(size.x-2,y),Color("87d4ff"),4)

# Only forward the header; parameter fields retain normal typing and selection.
func wire_drag_targets(node: Node = self) -> void:
	for child in node.get_children():
		if child is Control:
			child.set_drag_forwarding(_get_drag_data, _forward_can.bind(child), _forward_drop.bind(child))
		wire_drag_targets(child)

func _forward_can(at: Vector2, data, source: Control) -> bool:
	return _can_drop_data(get_global_transform_with_canvas().affine_inverse() * (source.get_global_transform_with_canvas() * at), data)

func _forward_drop(at: Vector2, data, source: Control) -> void:
	_drop_data(get_global_transform_with_canvas().affine_inverse() * (source.get_global_transform_with_canvas() * at), data)
