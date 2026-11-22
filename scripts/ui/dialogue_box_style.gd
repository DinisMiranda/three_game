class_name DialogueBoxStyle
extends RefCounted
## Shared look of the story dialogue boxes (briefing, epilogue, debrief).
##
## The panel uses the Theme's panel style (own copy, so the speaker pulse can
## animate its border without touching the shared Theme). The speaker name is a
## Roboto Mono "SpeakerTag" label above the Exo 2 "DialogueBody" text
## (art-direction §2: mono is accent only).


## Gives [param panel] its own copy of the themed panel style and returns it.
## Call after the panel is in the tree so the Theme resolves.
static func style_panel(panel: PanelContainer) -> StyleBoxFlat:
	var base := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var s: StyleBoxFlat = base.duplicate() if base != null else TriadThemeBuilder.make_panel_box()
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", s)
	return s


## Styles [param text_label] as dialogue body and puts a speaker tag above it.
## The label is moved into a new VBox in its current parent; its node stays
## the same object, so existing references and the typewriter keep working.
static func attach_speaker_tag(text_label: Label) -> Label:
	text_label.theme_type_variation = &"DialogueBody"
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var parent := text_label.get_parent()
	var index := text_label.get_index()
	var box := VBoxContainer.new()
	box.name = "DialogueVBox"
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = text_label.size_flags_horizontal
	box.size_flags_vertical = text_label.size_flags_vertical
	parent.remove_child(text_label)
	parent.add_child(box)
	parent.move_child(box, index)
	var tag := Label.new()
	tag.name = "SpeakerTag"
	tag.theme_type_variation = &"SpeakerTag"
	box.add_child(tag)
	box.add_child(text_label)
	return tag


## Body text for one line: the quote only (the speaker goes in the tag).
static func format_line(text: String) -> String:
	return "\"%s\"" % text


## Speaker tag text, e.g. "NOVA".
static func format_speaker(speaker_name: String) -> String:
	return speaker_name.to_upper()
