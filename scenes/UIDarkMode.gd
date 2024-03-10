extends HBoxContainer


func _ready():
	var config = Globals.read_config()
	if not "darkmode" in config["ui"]:
		config["ui"]["darkmode"] = false
		Globals.write_config(config)
	
	$CheckButton.pressed = config.ui.get("darkmode", false)
	$CheckButton.disabled = false
	
	toggle_ui_mode()


# Toggles between Whitemode and Darkmode
func toggle_ui_mode():
	var config = Globals.read_config()
	match config.ui.get("darkmode", $CheckButton.pressed):
		true:
			print("Darkmode activated")
		false:
			print("Whitemode activated")
