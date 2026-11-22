class_name TriadThemeBuilder
extends RefCounted
## Builds the project-wide Theme (assets/ui/triad_theme.tres) from Palette
## tokens and the typography table in docs/design/art-direction.md §2-3.
##
## This script is the source of truth for the theme. After changing it,
## regenerate the resource with:
## [codeblock]
## godot --headless --path . -s res://scripts/ui/build_triad_theme.gd
## [/codeblock]
##
## Type variations (set [member Control.theme_type_variation] on a node):
## - Labels: TitleLabel (64 Bold), HeadingLabel (32 SemiBold),
##   SubheadingLabel (22 SemiBold), CaptionLabel (14, secondary),
##   KickerLabel / MonoLabel / SpeakerTag (Roboto Mono accents),
##   HudLabel / HudHeading (2 px black outline, for text over the battle art),
##   DialogueBody (dialogue text).
## - Buttons: CompactButton (tight margins, 18).
## - Panels: ActivePanel (cyan glow, current actor only), LogPanel,
##   HistoryPanel, PlatePanel (small dark label plate), BarPanel (top/bottom bars).

const THEME_PATH := "res://assets/ui/triad_theme.tres"
const EXO2_PATH := "res://assets/fonts/Exo2.ttf"
const MONO_PATH := "res://assets/fonts/RobotoMono.ttf"

## Typography sizes @1080p (art-direction §2).
const SIZE_TITLE := 64
const SIZE_HEADING := 32
const SIZE_SUBHEADING := 22
const SIZE_BODY := 18
const SIZE_CAPTION := 14

const WEIGHT_REGULAR := 400
const WEIGHT_SEMIBOLD := 600
const WEIGHT_BOLD := 700

const RADIUS := 4


## Returns a new Theme built from the Palette tokens.
static func build() -> Theme:
	var t := Theme.new()
	var regular := make_exo2(WEIGHT_REGULAR)
	var semibold := make_exo2(WEIGHT_SEMIBOLD)
	var bold := make_exo2(WEIGHT_BOLD)
	var mono: Font = load(MONO_PATH) as Font
	t.default_font = regular
	t.default_font_size = SIZE_BODY

	_build_labels(t, semibold, bold, mono)
	_build_buttons(t, semibold)
	_build_panels(t)
	_build_bars(t, mono)
	_build_inputs(t)
	return t


## Exo 2 (variable font) at a fixed weight.
static func make_exo2(weight: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load(EXO2_PATH) as Font
	var wght: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {wght: weight}
	return fv


## A StyleBoxFlat with the shared radius and the given fill, border and margins.
static func make_box(fill: Color, border: Color = Color.TRANSPARENT, border_px: int = 0,
		margin_h: float = 0.0, margin_v: float = 0.0, radius: int = RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_px)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


## Shared panel: panel_fill, 1 px line_cyan, radius 4, margins 16/12, shadow.
static func make_panel_box() -> StyleBoxFlat:
	var s := make_box(Palette.PANEL_FILL, Palette.LINE_CYAN, 1, 16, 12)
	s.shadow_color = Palette.SHADOW
	s.shadow_size = 6
	return s


## Focus ring: no fill, 2 px select_amber, expanded 2 px.
static func make_focus_box() -> StyleBoxFlat:
	var s := make_box(Color.TRANSPARENT, Palette.SELECT_AMBER, 2)
	s.draw_center = false
	s.set_expand_margin_all(2)
	return s


static func _build_labels(t: Theme, semibold: Font, bold: Font, mono: Font) -> void:
	t.set_color("font_color", "Label", Palette.TEXT_PRIMARY)
	t.set_color("font_outline_color", "Label", Palette.OUTLINE)
	t.set_color("font_shadow_color", "Label", Color.TRANSPARENT)

	_label_variation(t, "TitleLabel", bold, SIZE_TITLE, Palette.TEXT_PRIMARY)
	_label_variation(t, "HeadingLabel", semibold, SIZE_HEADING, Palette.TEXT_PRIMARY)
	_label_variation(t, "SubheadingLabel", semibold, SIZE_SUBHEADING, Palette.TEXT_PRIMARY)
	_label_variation(t, "CaptionLabel", null, SIZE_CAPTION, Palette.TEXT_SECONDARY)
	_label_variation(t, "KickerLabel", mono, SIZE_CAPTION, Palette.ACCENT_CYAN)
	_label_variation(t, "MonoLabel", mono, SIZE_CAPTION, Palette.TEXT_PRIMARY)
	_label_variation(t, "SpeakerTag", mono, SIZE_BODY, Palette.ACCENT_CYAN)
	_label_variation(t, "DialogueBody", null, SIZE_SUBHEADING, Palette.TEXT_PRIMARY)
	_label_variation(t, "HudLabel", null, SIZE_BODY, Palette.TEXT_PRIMARY)
	t.set_constant("outline_size", "HudLabel", 2)
	_label_variation(t, "HudHeading", semibold, SIZE_SUBHEADING, Palette.TEXT_PRIMARY)
	t.set_constant("outline_size", "HudHeading", 2)

	t.set_color("default_color", "RichTextLabel", Palette.TEXT_PRIMARY)
	t.set_font_size("normal_font_size", "RichTextLabel", SIZE_BODY)
	t.set_font("mono_font", "RichTextLabel", mono)
	t.set_font("bold_font", "RichTextLabel", semibold)

	t.set_color("font_color", "TooltipLabel", Palette.TEXT_PRIMARY)
	t.set_font_size("font_size", "TooltipLabel", SIZE_CAPTION)
	t.set_stylebox("panel", "TooltipPanel", make_box(Palette.BG_DEEP, Palette.LINE_CYAN, 1, 10, 6))


static func _label_variation(t: Theme, type_name: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(type_name, "Label")
	if font != null:
		t.set_font("font", type_name, font)
	t.set_font_size("font_size", type_name, size)
	t.set_color("font_color", type_name, color)


static func _build_buttons(t: Theme, semibold: Font) -> void:
	for type_name: String in ["Button", "CompactButton"]:
		var mh := 20.0 if type_name == "Button" else 10.0
		var mv := 10.0 if type_name == "Button" else 4.0
		var normal := make_box(Palette.PANEL_RAISED, Palette.LINE_CYAN, 1, mh, mv)
		var hover := make_box(Palette.PANEL_HOVER, Palette.ACCENT_CYAN, 1, mh, mv)
		var pressed := make_box(Palette.BG_DEEP, Palette.ACCENT_CYAN, 2, mh, mv)
		var disabled := make_box(Palette.with_alpha(Palette.PANEL_RAISED, 0.5),
			Palette.with_alpha(Palette.TEXT_DISABLED, 0.4), 1, mh, mv)
		t.set_stylebox("normal", type_name, normal)
		t.set_stylebox("hover", type_name, hover)
		t.set_stylebox("pressed", type_name, pressed)
		t.set_stylebox("hover_pressed", type_name, pressed)
		t.set_stylebox("disabled", type_name, disabled)
		t.set_stylebox("focus", type_name, make_focus_box())
		t.set_color("font_color", type_name, Palette.TEXT_PRIMARY)
		t.set_color("font_hover_color", type_name, Palette.TEXT_PRIMARY)
		t.set_color("font_focus_color", type_name, Palette.TEXT_PRIMARY)
		t.set_color("font_pressed_color", type_name, Palette.ACCENT_CYAN)
		t.set_color("font_hover_pressed_color", type_name, Palette.ACCENT_CYAN)
		t.set_color("font_disabled_color", type_name, Palette.TEXT_DISABLED)
	t.set_font("font", "Button", semibold)
	t.set_font_size("font_size", "Button", SIZE_SUBHEADING)
	t.set_type_variation("CompactButton", "Button")
	t.set_font_size("font_size", "CompactButton", SIZE_BODY)


static func _build_panels(t: Theme) -> void:
	var panel := make_panel_box()
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var active := make_panel_box()
	active.shadow_color = Palette.with_alpha(Palette.LINE_CYAN, 0.25)
	active.shadow_size = 8
	t.set_type_variation("ActivePanel", "PanelContainer")
	t.set_stylebox("panel", "ActivePanel", active)

	var bar := make_panel_box()
	bar.content_margin_left = 28
	bar.content_margin_right = 28
	t.set_type_variation("BarPanel", "PanelContainer")
	t.set_stylebox("panel", "BarPanel", bar)

	var log_box := make_box(Palette.with_alpha(Palette.BG_DEEP, 0.98), Palette.LINE_CYAN, 1, 16, 8)
	t.set_type_variation("LogPanel", "PanelContainer")
	t.set_stylebox("panel", "LogPanel", log_box)
	var history := log_box.duplicate() as StyleBoxFlat
	history.shadow_color = Palette.SHADOW
	history.shadow_size = 12
	t.set_type_variation("HistoryPanel", "PanelContainer")
	t.set_stylebox("panel", "HistoryPanel", history)

	var plate := make_box(Palette.with_alpha(Palette.BG_DEEP, 0.85), Palette.LINE_CYAN, 1, 8, 2, 2)
	t.set_type_variation("PlatePanel", "PanelContainer")
	t.set_stylebox("panel", "PlatePanel", plate)


static func _build_bars(t: Theme, mono: Font) -> void:
	t.set_stylebox("background", "ProgressBar", make_box(Palette.BG_DEEP, Color.TRANSPARENT, 0, 0, 0, 2))
	t.set_stylebox("fill", "ProgressBar", make_box(Palette.ACCENT_CYAN, Color.TRANSPARENT, 0, 0, 0, 2))
	t.set_font("font", "ProgressBar", mono)
	t.set_font_size("font_size", "ProgressBar", SIZE_CAPTION)
	t.set_color("font_color", "ProgressBar", Palette.TEXT_PRIMARY)
	t.set_color("font_outline_color", "ProgressBar", Palette.OUTLINE)

	var slider := make_box(Palette.BG_DEEP, Palette.LINE_CYAN, 1, 0, 3, 2)
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", make_box(Palette.ACCENT_CYAN, Color.TRANSPARENT, 0, 0, 3, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", make_box(Palette.ACCENT_CYAN, Color.TRANSPARENT, 0, 0, 3, 2))
	t.set_stylebox("focus", "HSlider", make_focus_box())

	for type_name: String in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", type_name, make_box(Palette.BG_DEEP, Color.TRANSPARENT, 0, 4, 4, 2))
		t.set_stylebox("scroll_focus", type_name, make_box(Palette.BG_DEEP, Color.TRANSPARENT, 0, 4, 4, 2))
		t.set_stylebox("grabber", type_name, make_box(Palette.PANEL_HOVER, Color.TRANSPARENT, 0, 4, 4, 2))
		t.set_stylebox("grabber_highlight", type_name, make_box(Palette.LINE_CYAN, Color.TRANSPARENT, 0, 4, 4, 2))
		t.set_stylebox("grabber_pressed", type_name, make_box(Palette.ACCENT_CYAN, Color.TRANSPARENT, 0, 4, 4, 2))


static func _build_inputs(t: Theme) -> void:
	t.set_stylebox("normal", "LineEdit", make_box(Palette.PANEL_RAISED, Palette.LINE_CYAN, 1, 12, 8))
	t.set_stylebox("focus", "LineEdit", make_focus_box())
	t.set_stylebox("read_only", "LineEdit", make_box(Palette.with_alpha(Palette.PANEL_RAISED, 0.5),
		Palette.with_alpha(Palette.TEXT_DISABLED, 0.4), 1, 12, 8))
	t.set_color("font_color", "LineEdit", Palette.TEXT_PRIMARY)
	t.set_color("font_placeholder_color", "LineEdit", Palette.TEXT_SECONDARY)
	t.set_color("font_uneditable_color", "LineEdit", Palette.TEXT_DISABLED)
	t.set_color("caret_color", "LineEdit", Palette.ACCENT_CYAN)
	t.set_color("selection_color", "LineEdit", Palette.with_alpha(Palette.ACCENT_CYAN, 0.3))
