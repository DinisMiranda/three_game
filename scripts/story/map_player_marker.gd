extends Control
## Squad position marker on the tactical map.

func _draw() -> void:
	var c := size * 0.5
	var pts := PackedVector2Array([
		c + Vector2(0, -size.y * 0.45),
		c + Vector2(size.x * 0.38, size.y * 0.2),
		c + Vector2(0, size.y * 0.12),
		c + Vector2(-size.x * 0.38, size.y * 0.2),
	])
	draw_colored_polygon(pts, Color(0.0, 0.95, 1.0, 0.95))
	draw_polyline(pts, Color(1, 1, 1, 0.9), 2.0, true)
