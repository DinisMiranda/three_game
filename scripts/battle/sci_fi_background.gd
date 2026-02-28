extends Control
## Draws the sci-fi battle background: dark gradient + grid + bottom accent line.
## No logic; only _draw(). Attached to the root Control that covers the full viewport.

func _draw() -> void:
	var size = get_size()

	# Dark gradient top-to-bottom: near-black -> deep blue-black (20 bands)
	var from_color = Color(0.02, 0.02, 0.06, 1)
	var to_color = Color(0.06, 0.06, 0.12, 1)
	for i in 20:
		var t = float(i) / 20.0
		var c = from_color.lerp(to_color, t)
		var y = size.y * (t + 0.02)
		var h = size.y / 20.0 + 2
		draw_rect(Rect2(0, y, size.x, h), c)

	# Subtle grid (48px step) for a tech/HUD feel
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

	# Thin cyan line along bottom (HUD accent)
	draw_rect(Rect2(0, size.y - 2, size.x, 2), Color(0.0, 0.9, 1.0, 0.25))
