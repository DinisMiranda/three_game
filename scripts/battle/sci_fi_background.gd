extends Control
## Sci-fi battle background: dark gradient + subtle grid (Red Rising / Sun Eater / Dungeon Crawler Carl vibe).

func _draw() -> void:
	# Dark gradient: near-black to deep blue-black
	var size = get_size()
	var from_color = Color(0.02, 0.02, 0.06, 1)
	var to_color = Color(0.06, 0.06, 0.12, 1)
	for i in 20:
		var t = float(i) / 20.0
		var c = from_color.lerp(to_color, t)
		var y = size.y * (t + 0.02)
		var h = size.y / 20.0 + 2
		draw_rect(Rect2(0, y, size.x, h), c)
	# Subtle grid
	var grid_color = Color(0.12, 0.15, 0.22, 0.4)
	var step = 48
	var x = 0
	while x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color)
		x += step
	var y = 0
	while y <= size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color)
		y += step
	# Thin accent line along bottom (HUD feel)
	draw_rect(Rect2(0, size.y - 2, size.x, 2), Color(0.0, 0.9, 1.0, 0.25))
