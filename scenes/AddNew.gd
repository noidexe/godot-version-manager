extends Popup

export var select_dialog : NodePath

onready var line_edit_path = $Margin/VBox/path/LineEdit
onready var line_edit_name = $Margin/VBox/name/LineEdit
onready var line_edit_arguments = $Margin/VBox/arguments/LineEdit
onready var add_button = $Margin/VBox/Add

signal version_added()

func _ready():
	_validate()

# Selection of binary to add
func _on_Select_pressed():
	var popup = get_node(select_dialog) as FileDialog
	popup.popup()
	line_edit_path.text = yield(popup,"file_selected")
	if line_edit_name.text == "":
		line_edit_name.text = line_edit_path.text.get_file()
	_validate()

# Validate name and path input
func _validate(_unused = ""):
	add_button.disabled = line_edit_name.text == "" or not line_edit_path.text.is_abs_path()

# Create a entry and add it to the list of 
# installed versions
func _on_Add_pressed():
	var entry = {
		"name": line_edit_name.text,
		"path" :line_edit_path.text,
		"arguments" :line_edit_arguments.text
	}
	
	# Read the config
	var config: Dictionary = Globals.read_config()
	
	# Modify config file
	config.versions.append(entry)
	
	# Write out contents
	Globals.write_config(config)
	
	emit_signal("version_added")
	hide()

# Initialization
func _on_AddNew_about_to_show():
	line_edit_name.text = ""
	line_edit_arguments.text = ""
	line_edit_path.text = ""
