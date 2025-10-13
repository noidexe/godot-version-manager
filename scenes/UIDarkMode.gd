extends HBoxContainer


enum Mode { LIGHT, DARK }


# Path to the Main Node to edit its theme
export var main_node_path : NodePath
onready var main_node : Control

# Custom Styles from some nodes, not darkmode friendly but a work around
onready var install_style: StyleBoxFlat = $"%Installed".get("custom_styles/bg")
onready var logo_panel_style: StyleBoxFlat = $"%LogoContainer/Panel".get("custom_styles/panel")

var installed_style_dark : StyleBoxFlat = preload("res://theme/installed_dark.tres")
var logo_panel_style_dark : StyleBoxFlat = preload("res://theme/logo_panel_dark.tres")



func _ready():
	main_node = get_node_or_null(main_node_path)
	assert(is_instance_valid(main_node))
	$OptionButton.clear()
	$OptionButton.add_item("Light", Mode.LIGHT)
	$OptionButton.add_item("Dark", Mode.DARK)
	# Hack to fix minimum size being incorrect
	$OptionButton.get_popup().rect_min_size = $OptionButton.get_minimum_size() * Vector2(2,2.75)
	
	var config = Globals.read_config()
	# adds the darkmode setting if not existing
	if not "darkmode" in config["ui"]:
		config["ui"]["darkmode"] = false
		Globals.write_config(config)
	
	# sets the button to its state and enable it so it doesn't click it on itself
	var darkmode_enabled = config.ui.get("darkmode", false)
	$OptionButton.select(Mode.DARK if darkmode_enabled else Mode.LIGHT)
	$OptionButton.disabled = false
	
	mode_handler(darkmode_enabled)


# Toggles between dark and main theme
func mode_handler(dark: bool):
	match dark:
		true:
			main_node.set_theme(load("res://theme/dark_mode.tres"))
			# Tweaks the custom override styles that has been set to dark
			$"%Installed".set("custom_styles/bg", installed_style_dark)
			$"%LogoContainer/Panel".set("custom_styles/panel", logo_panel_style_dark)
		false:
			main_node.set_theme(load("res://theme/light_mode.tres"))
			# Tweaks the custom override styles to normal
			$"%Installed".set("custom_styles/bg", install_style)
			$"%LogoContainer/Panel".set("custom_styles/panel", logo_panel_style)
	_update_config(dark)


func _update_config(darkmode_selected):
	Globals.update_ui_flag("darkmode", darkmode_selected)
	var settings_override : ConfigFile = ConfigFile.new()
	settings_override.set_value("application", "boot_splash/bg_color", Color( 0.0784314, 0.0784314, 0.0784314, 1 ) if darkmode_selected else Color.white)
	var save_path : String = ProjectSettings.get_setting("application/config/project_settings_override")
	settings_override.save(save_path)


func _on_OptionButton_item_selected(index):
	var darkmode_selected = $OptionButton.get_item_id(index) == Mode.DARK
	mode_handler(darkmode_selected)
