class_name BattleFx
extends Node
## Presentation-only combat effects for the battle scene: attacker lunge,
## hit-stop, screen shake, hit flash, floating combat text, death slump,
## pacing waits and the battle speed multiplier.
##
## Implements Phase 1A of docs/design/portfolio-plan.md ("Combat feel and
## pacing"). It never reads or changes battle rules; BattleScene resolves the
## action with BattleManager and hands the results here as "hits".
##
## Speed rule: every tween this node creates goes through
## [method create_battle_tween] (which carries the speed multiplier), and every
## duration it hands to another node or a timer is pre-scaled with
## [method scaled]. Engine.time_scale is never touched, so menus run at 1x.
##
## A hit is a Dictionary built by BattleScene:
## [code]{ "slot": BattlerSlot, "damage": int, "kind": String, "downed": bool }[/code]
## where [code]kind[/code] is a BattleManager hit kind and [code]downed[/code]
## is true when the target is dead after the action.

## Emitted when the battle speed changes (e.g. so the toggle can relabel).
signal speed_changed(multiplier: float)

## Index into BattleFeel.speed_multipliers. Static so the choice survives
## floor changes and scene reloads for the rest of the session. There is no
## persistent settings store yet, so it resets when the game restarts.
static var _speed_index: int = 0

## Tuning data. Assign before the node enters the tree, or inject in tests.
@export var feel: BattleFeel

var _shake_targets: Array[Control] = []
var _shake_origins: Array[Vector2] = []
var _shake_strength: float = 0.0
var _shake_tween: Tween
var _text_layer: Node
var _rng := RandomNumberGenerator.new()
## Rest position of each attacker's sprite while it is mid-lunge.
var _lunge_rest: Dictionary = {}  # BattlerSlot -> Vector2


func _ready() -> void:
	if feel == null:
		feel = BattleFeel.new()


## Wires the nodes that effects act on: [param shake_targets] are moved by the
## screen shake (free-positioned Controls, not container children);
## [param text_layer] receives floating combat text.
func configure(shake_targets: Array[Control], text_layer: Node) -> void:
	_stop_shake()
	_shake_targets = shake_targets
	_text_layer = text_layer


# --- Speed -------------------------------------------------------------------

## Returns [param seconds] scaled for playback at [param speed] (2x halves it).
## Negative durations clamp to 0; a non-positive speed leaves time unscaled.
static func scale_duration(seconds: float, speed: float) -> float:
	var clamped := maxf(0.0, seconds)
	if speed <= 0.0:
		return clamped
	return clamped / speed


## Returns the active battle speed multiplier (1.0, 2.0, ...).
func get_speed_multiplier() -> float:
	return _get_feel().get_speed_multiplier(_speed_index)


## Returns the index of the active speed in BattleFeel.speed_multipliers.
func get_speed_index() -> int:
	return _speed_index


## Selects a speed by index (wraps around the list) and emits speed_changed.
func set_speed_index(index: int) -> void:
	var count: int = maxi(1, _get_feel().speed_multipliers.size())
	_speed_index = posmod(index, count)
	speed_changed.emit(get_speed_multiplier())


## Advances to the next speed in the list and returns the new multiplier.
func cycle_speed() -> float:
	set_speed_index(_speed_index + 1)
	return get_speed_multiplier()


## Returns a short label for the speed toggle, e.g. "1x" or "2x".
func get_speed_label() -> String:
	var m := get_speed_multiplier()
	if is_equal_approx(m, roundf(m)):
		return "%dx" % roundi(m)
	return "%.1fx" % m


## Returns [param seconds] (a 1x duration) scaled by the active speed.
func scaled(seconds: float) -> float:
	return scale_duration(seconds, get_speed_multiplier())


## Creates a tween bound to this node that plays at the active battle speed.
## Durations passed to it should be 1x values.
func create_battle_tween() -> Tween:
	var tw := create_tween()
	tw.set_speed_scale(get_speed_multiplier())
	return tw


## Waits [param seconds] (a 1x duration) at the active battle speed.
func wait(seconds: float) -> void:
	var t := scaled(seconds)
	if t <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(t).timeout


## Waits the post-action pause from BattleFeel.
func wait_after_action() -> void:
	await wait(_get_feel().post_action_wait)


# --- Turn intro --------------------------------------------------------------

## Plays the enemy-turn cue (slot flash plus the full-screen red flash) and
## returns after BattleFeel.enemy_intro_wait.
func play_enemy_turn_intro(enemy_slot: BattlerSlot, screen_flash: CanvasItem) -> void:
	var f := _get_feel()
	if enemy_slot:
		enemy_slot.play_enemy_turn_flash(get_speed_multiplier())
	if screen_flash:
		screen_flash.visible = true
		screen_flash.modulate.a = 0.0
		var tw := create_battle_tween()
		tw.tween_property(screen_flash, "modulate:a", 1.0, f.enemy_flash_in_duration)
		tw.tween_property(screen_flash, "modulate:a", 0.0, f.enemy_flash_out_duration)
		tw.finished.connect(func() -> void: screen_flash.visible = false)
	await wait(f.enemy_intro_wait)


# --- Attack ------------------------------------------------------------------

## Starts the attacker's attack frames and lunges its sprite toward
## [param target] (or straight ahead when there is no target). Returns at the
## moment of impact, with the sprite held at the lunge apex; follow with
## [method play_impact], which brings it back.
func play_lunge(attacker: BattlerSlot, target: BattlerSlot) -> void:
	if attacker == null or not attacker.is_inside_tree():
		return
	var f := _get_feel()
	attacker.play_attack_animation(scaled(f.attack_anim_duration))
	var body := attacker.get_sprite()
	if body == null:
		return
	var rest: Vector2 = _lunge_rest.get(attacker, body.position)
	_lunge_rest[attacker] = rest
	var offset := lunge_offset(attacker, target, f.lunge_distance_px)
	var tw := create_battle_tween()
	tw.tween_property(body, "position", rest + offset, f.lunge_out_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


## Returns the lunge offset (px) from [param attacker] toward [param target].
## Without a target, party slots lunge right and enemy slots lunge left.
static func lunge_offset(attacker: BattlerSlot, target: BattlerSlot, distance: float) -> Vector2:
	var fallback := Vector2.RIGHT if attacker.is_party else Vector2.LEFT
	if target == null or target == attacker:
		return fallback * distance
	var delta := target.get_combat_text_position() - attacker.get_combat_text_position()
	if delta.length_squared() < 1.0:
		return fallback * distance
	return delta.normalized() * distance


## Presents the resolved [param hits] of one action: hit flash, hit-stop,
## screen shake (stronger on crit), floating text, death slump for downed
## targets, then brings [param attacker] back from its lunge and waits the
## post-action pause. [param attacker] may be null (no lunge to undo) and
## [param hits] may be empty (non-damaging ability).
func play_impact(attacker: BattlerSlot, hits: Array[Dictionary]) -> void:
	var f := _get_feel()
	var has_impact := false
	var has_damage := false
	var has_crit := false
	for hit in hits:
		var damage: int = int(hit.get("damage", 0))
		var kind: String = str(hit.get("kind", "hit"))
		has_damage = has_damage or damage > 0
		has_crit = has_crit or kind == "crit"
		has_impact = has_impact or damage > 0 or kind == "absorb"

	var stop := f.get_hit_stop_seconds() if has_impact else 0.0
	for hit in hits:
		var slot: BattlerSlot = hit.get("slot")
		if slot and int(hit.get("damage", 0)) > 0:
			slot.play_hit_flash(f.hit_flash_color, scaled(f.hit_flash_in_duration),
				scaled(stop), scaled(f.hit_flash_out_duration))
	# Hit-stop: the attacker holds at the lunge apex and the target holds white.
	await wait(stop)
	if not is_inside_tree():
		return

	if has_damage:
		var shake_params := f.get_shake(has_crit)
		shake(shake_params.x, shake_params.y)
	var death_tween: Tween
	var texts_per_slot: Dictionary = {}  # BattlerSlot -> int, staggers multi-hit numbers
	for hit in hits:
		var slot: BattlerSlot = hit.get("slot")
		if slot == null:
			continue
		var kind: String = str(hit.get("kind", "hit"))
		var downed: bool = bool(hit.get("downed", false))
		# A follow-up "miss" on a target the same action already killed is noise.
		if not (downed and kind == "miss" and texts_per_slot.has(slot)):
			var stack: int = int(texts_per_slot.get(slot, 0))
			spawn_combat_text(slot, int(hit.get("damage", 0)), kind, stack)
			texts_per_slot[slot] = stack + 1
		if downed:
			var tw := play_death(slot, f.hit_flash_out_duration)
			if tw:
				death_tween = tw

	await _play_lunge_return(attacker)
	if death_tween and death_tween.is_valid() and death_tween.is_running():
		await death_tween.finished
	await wait_after_action()


## Shakes the configured targets with [param strength_px] amplitude, decaying
## to zero over [param duration] seconds (1x). Restarts any shake in progress.
func shake(strength_px: float, duration: float) -> void:
	_stop_shake()
	if _shake_targets.is_empty() or strength_px <= 0.0 or duration <= 0.0:
		return
	_shake_strength = strength_px
	_shake_origins.clear()
	for target in _shake_targets:
		_shake_origins.append(target.position if is_instance_valid(target) else Vector2.ZERO)
	_shake_tween = create_battle_tween()
	_shake_tween.tween_method(_apply_shake, 1.0, 0.0, duration)
	_shake_tween.finished.connect(_stop_shake)


## Spawns the floating number or status label for one hit above [param slot].
## [param stack] lifts repeated numbers on the same slot so they do not overlap.
func spawn_combat_text(slot: BattlerSlot, damage: int, kind: String, stack: int = 0) -> void:
	if _text_layer == null or slot == null:
		return
	var f := _get_feel()
	var style := f.get_combat_text_style(kind, damage)
	if style.is_empty():
		return
	var anchor := slot.get_combat_text_position() + Vector2(0.0, -f.multi_hit_text_offset_px * stack)
	FloatingCombatText.spawn(_text_layer, anchor, style.text, style.color,
		int(style.font_size), get_speed_multiplier())


# --- Death -------------------------------------------------------------------

## Fades, dims and slumps a downed [param slot] after [param delay] seconds (1x).
## Idempotent: returns null if the slot is already downed.
func play_death(slot: BattlerSlot, delay: float = 0.0) -> Tween:
	if slot == null or slot.is_downed():
		return null
	slot.mark_downed()
	var f := _get_feel()
	var body := slot.get_sprite()
	var root := slot.get_body()
	if root == null and body == null:
		return null
	var tw := create_battle_tween()
	tw.set_parallel(true)
	if root:
		tw.tween_property(root, "modulate", f.death_modulate, f.death_duration) \
			.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if body:
		body.pivot_offset = Vector2(body.size.x * 0.5, body.size.y)
		tw.tween_property(body, "scale", f.death_scale, f.death_duration) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(body, "position:y", body.position.y + f.death_slump_px, f.death_duration) \
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw


# --- Internals ---------------------------------------------------------------

func _play_lunge_return(attacker: BattlerSlot) -> void:
	if attacker == null or not _lunge_rest.has(attacker):
		return
	var rest: Vector2 = _lunge_rest[attacker]
	_lunge_rest.erase(attacker)
	if not is_instance_valid(attacker) or attacker.get_sprite() == null:
		return
	var tw := create_battle_tween()
	tw.tween_property(attacker.get_sprite(), "position", rest, _get_feel().lunge_back_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _apply_shake(decay: float) -> void:
	var amplitude := _shake_strength * decay
	for i in _shake_targets.size():
		var target := _shake_targets[i]
		if not is_instance_valid(target):
			continue
		var jitter := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		target.position = _shake_origins[i] + jitter * amplitude


func _stop_shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	for i in mini(_shake_targets.size(), _shake_origins.size()):
		if is_instance_valid(_shake_targets[i]):
			_shake_targets[i].position = _shake_origins[i]
	_shake_origins.clear()


func _get_feel() -> BattleFeel:
	if feel == null:
		feel = BattleFeel.new()
	return feel
