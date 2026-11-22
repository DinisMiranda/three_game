extends SceneTree
## Regenerates assets/ui/triad_theme.tres from TriadThemeBuilder.
## Run: godot --headless --path . -s res://scripts/ui/build_triad_theme.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	var theme := TriadThemeBuilder.build()
	var err := ResourceSaver.save(theme, TriadThemeBuilder.THEME_PATH)
	print("triad theme saved: ", TriadThemeBuilder.THEME_PATH, " err=", err)


func _process(_delta: float) -> bool:
	return true
