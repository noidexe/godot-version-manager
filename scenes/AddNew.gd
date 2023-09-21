extends Popup

export var select_dialog : NodePath
export var modal_blur : NodePath


onready var line_edit_path : LineEdit = $Margin/VBox/path/LineEdit
onready var line_edit_name : LineEdit = $Margin/VBox/name/LineEdit
onready var line_edit_arguments : LineEdit = $Margin/VBox/arguments/LineEdit
onready var add_button : Button = $Margin/VBox/Add

onready var installed : ItemList = get_node("%Installed")
onready var version_popup = get_node("%AddVersionSelect").get_popup()


signal version_added()

var edited_entry : int = -1  # -1 adding new
var available_versions : Dictionary

var is_mac = OS.has_feature("OSX")

func _ready():
	(get_node(modal_blur) as ColorRect).hide()
	_validate()
	var err = get_tree().connect("files_dropped", self, "_on_files_dropped")
	assert(err == OK)
	err = version_popup.connect("index_pressed", self, "_on_version_selected")
	assert(err == OK)

# Selection of binary to add
func _on_Select_pressed():
	var popup := get_node(select_dialog) as FileDialog
	popup.current_dir = ProjectSettings.globalize_path("user://versions")
	popup.mode = FileDialog.MODE_OPEN_DIR if is_mac else FileDialog.MODE_OPEN_FILE
	popup.popup()	
	line_edit_path.text = yield(popup,"dir_selected" if is_mac else "file_selected")
	if line_edit_name.text == "":
		line_edit_name.text = line_edit_path.text.get_file()
	_validate()

# Validate name and path input
func _validate(_unused = ""):
	add_button.disabled = true
	if line_edit_name.text == "":
		print_debug("Name cannot be empty")
		return
	if not line_edit_path.text.is_abs_path():
		print_debug("Path must be absolute")
		return
	if is_mac and not line_edit_path.text.ends_with(".app"):
		print_debug("Folder must end in .app")
		return
	add_button.disabled = false

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
	(get_node(modal_blur) as ColorRect).show()
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
	_populate_version_list()


func edit(config_idx):
	print("Editing %s" % config_idx)
	edited_entry = config_idx
	popup_centered()


func _on_AddNew_popup_hide():
	(get_node(modal_blur) as ColorRect).hide()
	# Reset edited entry to default vaule
	edited_entry = -1


func _on_Close_pressed():
	hide()
	pass # Replace with function body.


func _on_files_dropped(files : PoolStringArray, _screen ):
	if files.empty():
		return
	var dir = Directory.new()
	var path : String = files[0]
	
	if dir.dir_exists(path):
		var project_path = path.plus_file("project.godot")
		if dir.file_exists(project_path):
			path = project_path
		else:
			return
	
	popup_centered()
	if path.get_file() == "project.godot":
		line_edit_arguments.text = '--path %s' % path.get_base_dir()
		line_edit_name.text = path.get_base_dir().get_file()
	else:
		line_edit_path.text = path
		line_edit_name.text = path.get_file().trim_suffix("." + path.get_extension())
	_validate()
	pass


func _populate_version_list():
	var index = 0
	version_popup.clear()
	for version in installed.config.versions:
		if version["arguments"].find("--path") == -1:
			version_popup.add_item(version["name"])
			available_versions[index] = version["path"]
			index += 1


func _on_version_selected(index:int):
	line_edit_path.text = available_versions[index]
	_validate()
