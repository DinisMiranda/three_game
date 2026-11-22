extends CanvasLayer
## Reusable fade-through-black for scene changes (autoload "SceneFader",
## registered as scenes/ui/scene_fader.tscn so the timings are inspector data).
##
## [method change_scene] fades to black, swaps the scene with
## [code]change_scene_to_file[/code], then fades back in. [method fade_through]
## does the same around a callable, for in-place swaps such as the battle's
## "next floor". While a fade runs the overlay swallows mouse input and further
## requests are refused, so double clicks cannot start two transitions.
##
## No class_name on purpose: a class_name equal to the autoload name would hide
## the singleton. Tests load this script by path.

## Lifecycle of one transition.
enum State { IDLE, FADING_OUT, FADING_IN }

## Fade-to-black length in seconds.
@export_range(0.0, 3.0, 0.01) var fade_out_duration: float = 0.4
## Fade-from-black length in seconds, after the new scene is in.
@export_range(0.0, 3.0, 0.01) var fade_in_duration: float = 0.45
## Overlay colour (alpha is driven by the fade).
@export var fade_color: Color = Color.BLACK

var _state: State = State.IDLE
var _rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_rect()


## Current transition state.
func get_state() -> State:
	return _state


## True while a fade is running.
func is_busy() -> bool:
	return _state != State.IDLE


## Clamps a configured duration to a safe tween length (never negative).
static func clamp_duration(seconds: float) -> float:
	return maxf(0.0, seconds)


## Fades out, changes to the scene at [param path], fades in. Returns false
## (and does nothing) when [param path] is empty, a fade is already running or
## the fader is not in the tree. Not a coroutine: callers need not await it.
func change_scene(path: String) -> bool:
	if path.is_empty() or is_busy() or not is_inside_tree():
		return false
	_run(func () -> void:
		var err: Error = get_tree().change_scene_to_file(path)
		if err != OK:
			push_error("SceneFader: could not change scene to %s (error %d)" % [path, err])
	)
	return true


## Fades out, calls [param swap] while the screen is black, fades in. Returns
## false (and does not call [param swap]) when busy, not in the tree or the
## callable is invalid; the caller then performs the swap itself.
func fade_through(swap: Callable) -> bool:
	if not swap.is_valid() or is_busy() or not is_inside_tree():
		return false
	_run(swap)
	return true


func _run(swap: Callable) -> void:
	_ensure_rect()
	_state = State.FADING_OUT
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var out_tw := create_tween()
	out_tw.tween_property(_rect, "modulate:a", 1.0, clamp_duration(fade_out_duration)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await out_tw.finished
	swap.call()
	# change_scene_to_file swaps at the end of the frame; wait one frame so the
	# new scene has run _ready() before it is revealed.
	await get_tree().process_frame
	_state = State.FADING_IN
	var in_tw := create_tween()
	in_tw.tween_property(_rect, "modulate:a", 0.0, clamp_duration(fade_in_duration)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await in_tw.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state = State.IDLE


func _ensure_rect() -> void:
	if _rect != null:
		return
	_rect = get_node_or_null("Overlay") as ColorRect
	if _rect == null:
		_rect = ColorRect.new()
		_rect.name = "Overlay"
		add_child(_rect)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = fade_color
	_rect.modulate = Color(1, 1, 1, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
