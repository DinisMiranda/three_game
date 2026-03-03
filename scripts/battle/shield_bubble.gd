extends Control
## Draws a blue semi-transparent bubble (circle) when visible. Used for the Shield effect.

const _BUBBLE_COLOR := Color(0.25, 0.45, 0.95, 0.4)
const _BUBBLE_RADIUS_RATIO := 0.58  # radius as fraction of min(width, height)

func _draw() -> void:
	if not visible:
		return
	var r = minf(size.x, size.y) * _BUBBLE_RADIUS_RATIO
	draw_circle(size / 2.0, r, _BUBBLE_COLOR)
