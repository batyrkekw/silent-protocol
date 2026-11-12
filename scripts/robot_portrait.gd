extends Control
const Art = preload("res://scripts/robot_art.gd")
var robot_id = 0:
	set(value):
		robot_id = value
		queue_redraw()
func _draw() -> void:
	Art.render(self, size * 0.5 + Vector2(0, 3), robot_id, 1.25)
