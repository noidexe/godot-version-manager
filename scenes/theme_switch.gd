extends OptionButton

const EXCLUDED_DIRECTORY_NAME := "scripts"

var _themes: PackedStringArray

func _ready() -> void:
	var dir := DirAccess.open("res://themes")
	_themes = dir.get_directories()
	_themes.remove_at(_themes.find(EXCLUDED_DIRECTORY_NAME))
	
	clear()
	for t in _themes:
		add_item(t)
	var config = Globals.read_config()
	var active_theme_id = _themes.find(config.theme)
	select(active_theme_id)


func _on_item_selected(index: int) -> void:
	Globals.update_theme(_themes[index])
