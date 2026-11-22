class_name PartyStatusPanel
extends VBoxContainer
## The "Party status" list: one row per hero with name, HP bar and numbers,
## energy bar and numbers.
##
## Colours, tags and the "current/max" format come from [BattleFeel], the same
## as the arena slots, so HP (cyan, orange/red when low) and energy (yellow)
## read the same everywhere.


## Rebuilds the rows from [param party] (Array of [BattlerStats], in party order).
func refresh(party: Array, feel: BattleFeel) -> void:
	for c in get_children():
		c.queue_free()
	for i in party.size():
		add_child(_make_row(party[i], i, feel))


func _make_row(s: BattlerStats, hero_index: int, f: BattleFeel) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_l := Label.new()
	name_l.text = s.display_name + ":"
	name_l.custom_minimum_size.x = 80
	name_l.add_theme_color_override("font_color", HeroRoster.get_role_color(hero_index))
	row.add_child(name_l)
	row.add_child(_make_bar(s.current_hp, s.max_hp, f.get_hp_color(s.current_hp, s.max_hp), 12, 3.0))
	row.add_child(_make_label(BattleFeel.format_bar_value(s.current_hp, s.max_hp), f.hp_text_color, 58))
	row.add_child(_make_label(f.energy_tag, f.energy_text_color, 0))
	row.add_child(_make_bar(s.current_energy, s.max_energy, f.energy_color, 9, 2.0))
	row.add_child(_make_label(BattleFeel.format_bar_value(s.current_energy, s.max_energy), f.energy_text_color, 58))
	return row


## One bar of a row. [param stretch] shares the free width. The trough comes
## from the Theme (ProgressBar/background); the fill colour is per value.
func _make_bar(value: int, maximum: int, fill_color: Color, height: int, stretch: float) -> ProgressBar:
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = fill_color
	bar_fill.set_corner_radius_all(2)
	var bar := ProgressBar.new()
	bar.max_value = float(maxi(1, maximum))
	bar.value = float(value)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_stretch_ratio = stretch
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, height)
	bar.add_theme_stylebox_override("fill", bar_fill)
	return bar


## A small right-aligned number or tag label.
func _make_label(text: String, color: Color, min_width: int) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = min_width
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.theme_type_variation = &"MonoLabel"
	l.add_theme_color_override("font_color", color)
	return l
