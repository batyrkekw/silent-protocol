extends Button
## A reusable command in the permanent toolbox. Clicking and dragging both insert it.
signal drag_started
var command_type = "forward"
var allowed: Callable

func _get_drag_data(_at: Vector2):
	if disabled or not allowed.call(): return null
	drag_started.emit()
	var preview = PanelContainer.new()
	preview.add_theme_stylebox_override("panel", get_theme_stylebox("normal"))
	var caption = Label.new()
	caption.text = text
	caption.add_theme_font_override("font", get_theme_font("font"))
	caption.add_theme_font_size_override("font_size", 17)
	preview.add_child(caption)
	set_drag_preview(preview)
	return {"kind":"new_command", "type":command_type}
