extends Control

## Schematic art only; no infrastructure or rover state is implied.

const EDGE := Color("66738f")
const BLUE := Color("91cfff")


func _ready() -> void:
	custom_minimum_size = Vector2(0, 260)
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("101521"))
	for row in range(5):
		var points := PackedVector2Array()
		for step in range(33):
			var x := w * float(step) / 32.0
			var y := h * (0.63 + float(row) * 0.075) + sin(float(step) * 0.38 + row * 0.8) * (8.0 + row * 2.0)
			points.append(Vector2(x, y))
		draw_polyline(points, Color(EDGE, 0.45), 1.0, true)
	var habitat := Rect2(Vector2(w * 0.22, h * 0.35), Vector2(138, 58))
	draw_rect(habitat, Color("171c2b"))
	draw_rect(habitat, BLUE, false, 2.0)
	draw_line(habitat.position + Vector2(15, 0), habitat.position + Vector2(35, -20), BLUE, 2.0)
	draw_line(habitat.position + Vector2(35, -20), habitat.position + Vector2(103, -20), BLUE, 2.0)
	draw_line(habitat.position + Vector2(103, -20), habitat.position + Vector2(123, 0), BLUE, 2.0)
	var solar := Vector2(w * 0.74, h * 0.34)
	draw_colored_polygon(PackedVector2Array([solar + Vector2(-66, -15), solar + Vector2(66, -15), solar + Vector2(51, 20), solar + Vector2(-81, 20)]), Color("171c2b"))
	for column in range(5):
		var offset := -64.0 + column * 30.0
		draw_line(solar + Vector2(offset, -15), solar + Vector2(offset - 15, 20), BLUE, 1.0)
	draw_line(solar + Vector2(-74, 2), solar + Vector2(59, 2), BLUE, 1.0)
	draw_line(solar + Vector2(-66, -15), solar + Vector2(66, -15), BLUE, 2.0)
	draw_line(solar + Vector2(-81, 20), solar + Vector2(51, 20), BLUE, 2.0)
	var rover := Vector2(w * 0.66, h * 0.72)
	draw_rect(Rect2(rover - Vector2(27, 12), Vector2(54, 22)), Color("171c2b"))
	draw_rect(Rect2(rover - Vector2(27, 12), Vector2(54, 22)), BLUE, false, 2.0)
	draw_circle(rover + Vector2(-17, 14), 5.0, Color("f1f3fa"))
	draw_circle(rover + Vector2(17, 14), 5.0, Color("f1f3fa"))
	draw_line(rover + Vector2(5, -12), rover + Vector2(10, -29), BLUE, 2.0)
	draw_circle(rover + Vector2(10, -29), 4.0, Color("b7a2ff"))
