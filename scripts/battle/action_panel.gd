class_name ActionPanel
extends PanelContainer
## The player's command panel: Attack, Abilities, End Turn and the ability list.
##
## Pure view. It owns the buttons and the main-rows / ability-list swap, and
## reports what the player pressed through signals; it knows nothing about
## BattleManager. [BattleScene] decides what each request means and feeds the
## ability list back through [method open_abilities].

## The Attack button was pressed. The target is chosen in the arena, not here.
signal attack_requested
## The End Turn button was pressed.
signal end_turn_requested
## The Abilities button was pressed; answer with [method open_abilities].
signal abilities_requested
## An ability button from the list was pressed.
signal ability_selected(ability_id: String, ability_name: String)

@onready var attack_btn: Button = $ActionsVBox/Buttons/AttackBtn
@onready var abilities_btn: Button = $ActionsVBox/Buttons/AbilitiesBtn
@onready var end_turn_btn: Button = $ActionsVBox/EndTurnRow/EndTurnBtn
@onready var _main_rows: Array[Control] = [$ActionsVBox/Buttons, $ActionsVBox/EndTurnRow]
@onready var _ability_sub_panel: VBoxContainer = $ActionsVBox/AbilitySubPanel
@onready var _ability_buttons: HBoxContainer = $ActionsVBox/AbilitySubPanel/AbilityButtonsContainer
@onready var _ability_back_btn: Button = $ActionsVBox/AbilitySubPanel/AbilityBackBtn


func _ready() -> void:
	attack_btn.pressed.connect(attack_requested.emit)
	end_turn_btn.pressed.connect(end_turn_requested.emit)
	abilities_btn.pressed.connect(abilities_requested.emit)
	_ability_back_btn.pressed.connect(close_abilities)
	_ability_sub_panel.visibility_changed.connect(_on_ability_list_visibility_changed)


## Shows or hides the panel without removing it from the layout, so the party
## status and log next to it do not jump on enemy turns. Hiding also closes the
## ability list.
func show_panel(shown: bool) -> void:
	modulate.a = 1.0 if shown else 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
	if not shown:
		close_abilities()


## Enables or disables the three main buttons together.
func set_enabled(enabled: bool) -> void:
	attack_btn.disabled = not enabled
	abilities_btn.disabled = not enabled
	end_turn_btn.disabled = not enabled


## True while the ability list replaces the main rows.
func is_abilities_open() -> bool:
	return _ability_sub_panel.visible


## Opens the ability list. Each entry is
## [code]{ "id", "name", "cost": int, "can_afford": bool, "can_use": bool, "hint": String }[/code].
func open_abilities(entries: Array) -> void:
	_ability_sub_panel.visible = true
	for c in _ability_buttons.get_children():
		c.queue_free()
	for entry in entries:
		_ability_buttons.add_child(_make_ability_button(entry))


## Closes the ability list and brings the main rows back.
func close_abilities() -> void:
	_ability_sub_panel.visible = false


func _make_ability_button(entry: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = "%s (%d)" % [entry.name, int(entry.cost)]
	btn.tooltip_text = str(entry.hint)
	btn.disabled = not bool(entry.can_use)
	if not bool(entry.can_afford):
		btn.add_theme_color_override("font_color", Palette.TEXT_DISABLED)
	btn.pressed.connect(ability_selected.emit.bind(str(entry.id), str(entry.name)))
	return btn


## The ability list replaces the main rows while open, so the panel keeps
## roughly the same height and the layout fits 1080 px.
func _on_ability_list_visibility_changed() -> void:
	for row in _main_rows:
		row.visible = not _ability_sub_panel.visible
