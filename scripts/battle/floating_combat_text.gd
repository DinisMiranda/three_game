class_name FloatingCombatText
extends Label
## Short-lived damage / status number that floats above a battler.
## Style (text, colour, size) is chosen by BattleFeel.get_combat_text_style().

const DURATION := 1.05
const RISE_PX := 72.0
const FONT_SIZE := 26
const _OUTLINE_COLOR := Color(0.02, 0.02, 0.06, 0.95)
const _OUTLINE_SIZE := 4
const _POP_START_SCALE := Vector2(0.65, 0.65)
const _FADE_IN := 0.08
const _POP_DURATION := 0.12


## Spawns a label under [param parent] at [param anchor] and animates it.
## [param font_size] sets the text size (crits use a bigger one);
## [param speed_scale] plays the animation faster (battle speed toggle).
static func spawn(parent: Node, anchor: Vector2, message: String, color: Color,
		font_size: int = FONT_SIZE, speed_scale: float = 1.0) -> FloatingCombatText:
	var lbl := FloatingCombatText.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", _OUTLINE_COLOR)
	lbl.add_theme_constant_override("outline_size", _OUTLINE_SIZE)
	lbl.z_index = 50
	parent.add_child(lbl)
	lbl._animate(anchor, speed_scale)
	return lbl


func _animate(start_pos: Vector2, speed_scale: float) -> void:
	# Centre on the anchor so bigger crit text still sits over the target.
	size = get_combined_minimum_size()
	pivot_offset = size * 0.5
	position = start_pos - Vector2(size.x * 0.5, 0.0)
	modulate = Color(1, 1, 1, 0)
	scale = _POP_START_SCALE
	var tw := create_tween()
	tw.set_speed_scale(maxf(0.01, speed_scale))
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, _FADE_IN)
	tw.tween_property(self, "scale", Vector2.ONE, _POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(self, "position:y", position.y - RISE_PX, DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, DURATION * 0.55).set_delay(DURATION * 0.45)
	await tw.finished
	queue_free()
