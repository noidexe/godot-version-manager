extends HBoxContainer


# Path to the Main Node to edit its theme
onready var main_node = $"../../../../.."
# When it starts up sets to true so the setting doesn't save itself before
# anything was done
var initialized = false

# Custom Styles from some nodes, not darkmode friendly but a work around
onready var install_style: StyleBoxFlat = $"%Installed".get("custom_styles/bg")
onready var logo_panel_style: StyleBoxFlat = $"../../LogoContainer/Panel".get("custom_styles/panel")


func _ready():
	var config = Globals.read_config()
	# adds the darkmode setting if not existing
	if not "darkmode" in config["ui"]:
		config["ui"]["darkmode"] = false
		Globals.write_config(config)
	
	# sets the button to its state and enable it so it doesn't click it on itself
	$CheckButton.pressed = config.ui.get("darkmode", false)
	$CheckButton.disabled = false

	mode_handler($CheckButton.pressed)


# Toggles between dark and main theme
func mode_handler(dark: bool):
	match dark:
		true:
			main_node.set_theme(load("res://theme/dark_mode.theme"))
			# Tweaks the custom override styles that has been set to dark
			$"%Installed".set("custom_styles/bg", get_dark_installed_style())
			$"../../LogoContainer/Panel".set("custom_styles/panel", get_dark_logo_panel_style())
		false:
			main_node.set_theme(load("res://theme/main.theme"))
			# Tweaks the custom override styles to normal
			$"%Installed".set("custom_styles/bg", install_style)
			$"../../LogoContainer/Panel".set("custom_styles/panel", logo_panel_style)


# new style for installedlist
func get_dark_installed_style() -> StyleBoxFlat:
	var new_installed_style = StyleBoxFlat.new()
	new_installed_style.set_bg_color(Color(0.09, 0.09, 0.09, 1.0))
	new_installed_style.border_width_bottom = 1
	new_installed_style.border_width_top = 1
	new_installed_style.border_width_left = 1
	new_installed_style.border_width_right = 1
	new_installed_style.border_color = Color("#ffffff")
	new_installed_style.corner_radius_bottom_left = 10
	new_installed_style.corner_radius_bottom_right = 10
	new_installed_style.corner_radius_top_left = 10
	new_installed_style.corner_radius_top_right = 10
	new_installed_style.content_margin_left = 20
	new_installed_style.content_margin_right = 20
	new_installed_style.content_margin_top = 30
	new_installed_style.content_margin_bottom = 20
	
	return new_installed_style


func get_dark_logo_panel_style() -> StyleBoxFlat:
	var new_logo_panel_style = StyleBoxFlat.new()
	new_logo_panel_style.set_bg_color(Color(0.09, 0.09, 0.09, 1.0))
	new_logo_panel_style.border_color = Color("#ffffff")
	new_logo_panel_style.corner_radius_bottom_left = 2
	new_logo_panel_style.corner_radius_bottom_right = 2
	new_logo_panel_style.corner_radius_top_left = 2
	new_logo_panel_style.corner_radius_top_right = 2
	return new_logo_panel_style


func _on_CheckButton_toggled(button_pressed):
	mode_handler(button_pressed)
	$Timer.start(10)


# Is a little cooldown so if someone spams the toggler
# the file doesn't write everytime
func _on_Timer_timeout():
	if not initialized:
		initialized = true
		return
	var config = Globals.read_config()
	if config["ui"]["darkmode"] == $CheckButton.pressed:
		return
	config["ui"]["darkmode"] = $CheckButton.pressed
	Globals.write_config(config)
