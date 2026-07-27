class_name FloatingCombatText
extends Label
## Short-lived damage / status number that floats above a battler.

const DURATION := 1.05
const RISE_PX := 72.0


static func spawn(parent: Node, anchor: Vector2, message: String, color: Color) -> void:
	var lbl := FloatingCombatText.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06, 0.95))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 50
	parent.add_child(lbl)
	lbl._animate(anchor)


func _animate(start_pos: Vector2) -> void:
	position = start_pos - Vector2(24, 0)
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.65, 0.65)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "position:y", position.y - RISE_PX, DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, DURATION * 0.55).set_delay(DURATION * 0.45)
	await tw.finished
	queue_free()
