extends RefCounted
## Original robot silhouettes inspired by museum art.
static func render(canvas: CanvasItem, p: Vector2, id: int, scale: float = 1.0) -> void:
	var accents = [Color("62daca"), Color("cf9cff"), Color("f4ba73")]
	var color = accents[id]
	canvas.draw_set_transform(p, 0, Vector2.ONE * scale)
	canvas.draw_circle(Vector2(0, 5), 14, Color(0.02, 0.04, 0.09, 0.22))
	match id:
		0:
			# LISA: a framed face, quiet eyes and the hint of an asymmetric smile.
			canvas.draw_arc(Vector2(0, -16), 8, 0, TAU, 32, color, 1.5, true)
			canvas.draw_circle(Vector2(0, -3), 11, Color("20364d"))
			canvas.draw_rect(Rect2(-11, -3, 22, 13), Color("20364d"))
			canvas.draw_arc(Vector2(0, -3), 11, PI, TAU, 24, Color("90b9c4"), 1.5, true)
			canvas.draw_circle(Vector2(0, 10), 5, color)
			canvas.draw_rect(Rect2(-9, -6, 18, 6), Color("050a13"))
			canvas.draw_line(Vector2(-7, -3), Vector2(-2, -3), color, 2)
			canvas.draw_line(Vector2(2, -3), Vector2(7, -3), color, 2)
			canvas.draw_polyline(PackedVector2Array([Vector2(-5,3), Vector2(-1,5), Vector2(3,4), Vector2(5,2)]), color, 1.4, true)
		1:
			# NIKE: wings and a faceted, forward-leaning body.
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0,-15),Vector2(13,9),Vector2(0,5),Vector2(-13,9)]), Color("352947"))
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-9,-4),Vector2(-18,7),Vector2(-10,12)]), color)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(9,-4),Vector2(18,7),Vector2(10,12)]), color)
			canvas.draw_line(Vector2(0,-14),Vector2(10,5),Color("dfc9fa"),1.5,true)
			canvas.draw_rect(Rect2(-8,-3,16,5),Color("080c19"))
			canvas.draw_line(Vector2(-6,-1),Vector2(6,-1),color,2)
			canvas.draw_circle(Vector2(0,9),3,Color("b9a4e1"))
		2:
			# SPHINX: angular ceremonial mask, amber eyes and striped side plates.
			canvas.draw_rect(Rect2(-16,-7,6,20),Color("243345"))
			canvas.draw_rect(Rect2(10,-7,6,20),Color("243345"))
			canvas.draw_rect(Rect2(-11,-13,22,24),Color("263f55"))
			canvas.draw_line(Vector2(-10,-13),Vector2(10,-13),Color("b7c4d2"),2)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-12,-10),Vector2(-7,-17),Vector2(7,-17),Vector2(12,-10),Vector2(6,8),Vector2(-6,8)]), Color("a7844e"))
			canvas.draw_line(Vector2(-8,-5),Vector2(-2,-3),Color("102137"),3,true)
			canvas.draw_line(Vector2(2,-3),Vector2(8,-5),Color("102137"),3,true)
			canvas.draw_circle(Vector2(-5,-4),1.6,color)
			canvas.draw_circle(Vector2(5,-4),1.6,color)
			for y in [-5,0,5]:
				canvas.draw_line(Vector2(-16,y),Vector2(-11,y),color,1)
				canvas.draw_line(Vector2(11,y),Vector2(16,y),color,1)
			canvas.draw_circle(Vector2(0,5),3,color)
			canvas.draw_line(Vector2(-15,10),Vector2(-11,10),color,2)
			canvas.draw_line(Vector2(11,10),Vector2(15,10),color,2)
	canvas.draw_set_transform(Vector2.ZERO)
