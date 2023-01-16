extends Popup

export var select_dialog : NodePath

onready var line_edit_path = $Margin/VBox/path/LineEdit
onready var line_edit_name = $Margin/VBox/name/LineEdit
onready var line_edit_arguments = $Margin/VBox/arguments/LineEdit
onready var add_button = $Margin/VBox/Add

signal version_added()

var edited_entry : int = -1  # -1 adding new

func _ready():
	_validate()

# Selection of binary to add
func _on_Select_pressed():
	var popup := get_node(select_dialog) as FileDialog
	popup.current_dir = ProjectSettings.globalize_path("user://versions")
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
	if edited_entry == -1:
		config.versions.append(entry)
	else:
		config.versions[edited_entry] = entry
	
	# Write out contents
	Globals.write_config(config)
	
	emit_signal("version_added")
	hide()

# Initialization
func _on_AddNew_about_to_show():
	if edited_entry == -1:
		line_edit_name.text = ""
		line_edit_arguments.text = ""
		line_edit_path.text = ""
		$Margin/VBox/Add.text = "Add"
	else:
		var config: Dictionary = Globals.read_config()
		var entry = config.versions[edited_entry]
		line_edit_name.text = entry.name
		line_edit_arguments.text = entry.arguments
		line_edit_path.text = entry.path
		$Margin/VBox/Add.text = "Save"

func edit(config_idx):
	print("Editing %s" % config_idx)
	edited_entry = config_idx
	popup_centered()


func _on_AddNew_popup_hide():
	# Reset edited entry to default vaule
	edited_entry = -1
