extends Control
## Draws the sci-fi battle background: dark gradient + grid + bottom accent line.
## No logic; only _draw(). Attached to the root Control that covers the full viewport.

func _draw() -> void:
	var draw_size := get_size()

	# Dark gradient top-to-bottom: near-black -> deep blue-black (20 bands)
	var from_color = Color(0.02, 0.02, 0.06, 1)
	var to_color = Color(0.06, 0.06, 0.12, 1)
	for i in 20:
		var t = float(i) / 20.0
		var c = from_color.lerp(to_color, t)
		var band_y: float = draw_size.y * (t + 0.02)
		var h: float = draw_size.y / 20.0 + 2
		draw_rect(Rect2(0, band_y, draw_size.x, h), c)

	# Subtle grid (48px step) for a tech/HUD feel
	var grid_color = Color(0.12, 0.15, 0.22, 0.4)
	var step = 48
	var x = 0
	while x <= draw_size.x:
		draw_line(Vector2(x, 0), Vector2(x, draw_size.y), grid_color)
		x += step
	var grid_y = 0
	while grid_y <= draw_size.y:
		draw_line(Vector2(0, grid_y), Vector2(draw_size.x, grid_y), grid_color)
		grid_y += step

	# Thin cyan line along bottom (HUD accent)
	draw_rect(Rect2(0, draw_size.y - 2, draw_size.x, 2), Color(0.0, 0.9, 1.0, 0.25))
