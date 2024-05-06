extends Control

@export var select_dialog : NodePath
@export var modal_blur : NodePath


@onready var line_edit_name : LineEdit = %NameLineEdit
@onready var line_edit_path : LineEdit = %PathLineEdit
@onready var line_edit_arguments : TextEdit = %ArgumentsTextEdit
@onready var add_button : Button = %AddButton

@onready var installed : ItemList = get_node("%Installed")
@onready var version_popup = get_node("%AddVersionSelect").get_popup()


signal version_added()

var edited_entry : int = -1  # -1 adding new
var available_versions : Dictionary

var is_mac = OS.has_feature("macos")

func _ready():
	get_viewport().transparent_bg = true
	(get_node(modal_blur) as ColorRect).hide()
	_validate()
	var err = get_parent().get_window().files_dropped.connect(_on_files_dropped)
	assert(err == OK)
	err = version_popup.connect("index_pressed", Callable(self, "_on_version_selected"))
	assert(err == OK)

# Selection of binary to add
func _on_Select_pressed():
	var file_popup := get_node(select_dialog) as FileDialog
	file_popup.current_dir = ProjectSettings.globalize_path("user://versions")
	file_popup.file_mode = FileDialog.FILE_MODE_OPEN_DIR if is_mac else FileDialog.FILE_MODE_OPEN_FILE
	file_popup.popup()
	file_popup.popup_centered_ratio()
	await file_popup.visibility_changed
	if is_mac:
		line_edit_path.text = await file_popup.dir_selected
	else:
		line_edit_path.text = await file_popup.file_selected
	if line_edit_name.text == "":
		line_edit_name.text = line_edit_path.text.get_file()
	_validate()
	line_edit_path.caret_column = line_edit_path.text.length()

# Validate name and path input
func _validate(_unused = ""):
	add_button.disabled = true
	if line_edit_name.text == "":
		print_debug("Name cannot be empty")
		return
	if not line_edit_path.text.is_absolute_path():
		print_debug("Path3D must be absolute")
		return
	if is_mac and not line_edit_path.text.ends_with(".app"):
		print_debug("Folder must end in super.app")
		return
	
	add_button.disabled = false

# Create a entry and add it to the list of 
# installed versions
func _on_Add_pressed():
	var entry = {
		"name": line_edit_name.text,
		"path" :line_edit_path.text,
		"arguments" :line_edit_arguments.text.replace("\n", " "),
		"arguments_raw": line_edit_arguments.text
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
	add_button.disabled = true
	if edited_entry == -1:
		line_edit_name.text = ""
		line_edit_arguments.text = ""
		line_edit_path.text = ""
		add_button.text = "Add"
	else:
		var config: Dictionary = Globals.read_config()
		var entry = config.versions[edited_entry]
		line_edit_name.text = entry.name
		line_edit_path.text = entry.path
		line_edit_path.caret_column = line_edit_path.text.length()
		line_edit_arguments.text = entry.arguments_raw
		add_button.text = "Save"
	_populate_version_list()


func edit(config_idx):
	print("Editing %s" % config_idx)
	edited_entry = config_idx
	visible = true


func _args_pretty_print(args_text: String) -> String:
	var lines: PackedStringArray = []
	
	# ==================================================
	# Split arguments
	# ==================================================
	
	## Matches separate command line "arguments" - which is either quoted text
	## or non-whitespace characters sequence.
	## Example arguments:
	##   --path
	##   "C://path/to/my/awesome project 3000"
	##   -key="value"
	##   /nextKey:${theValue}
	var r_argument = RegEx.new()
	r_argument.compile('([^\\s"]*\\"[^\\"]*\\")+|\\S+')
	var arguments: PackedStringArray = r_argument.search_all(args_text).map(func(rg_match: RegExMatch):
		return rg_match.get_string())
	
	# ==================================================
	# Create key - value pairs of arguments
	# ==================================================
	
	## Matches key.
	## When talking about command line interfaces they are often called: option,
	## key, flag and start with single od double dash ('-', '--') or forward
	## slash ('/').
	## Examples
	##   --key
	##   -h
	##   /Arg
	var r_key := RegEx.new()
	r_key.compile('^[-/]\\S*')
	var was_last_added := false
	var is_last := false
	for i in arguments.size():
		if i == 0:
			continue
		if i == arguments.size() - 1:
			is_last = true
		
		# Current argument is a key.
		if r_key.search(arguments[i]) != null:
			# Key with value.
			if arguments[i].contains('=') or arguments[i].contains(':'):
				if not was_last_added:
					lines.append(arguments[i-1])
				lines.append(arguments[i])
				was_last_added = true
			# Key after key.
			elif r_key.search(arguments[i-1]) != null:
				if not was_last_added:
					lines.append(arguments[i-1])
				was_last_added = false
			# Key after value.
			else:
				if not was_last_added:
					lines.append(arguments[i-1])
				if is_last:
					lines.append(arguments[i])
				was_last_added = false
		
		# Current argument is a value.
		else:
			# Value after key.
			if r_key.search(arguments[i-1]) != null:
				if not was_last_added:
					lines.append(str(arguments[i-1], ' ', arguments[i]))
				else:
					lines.append(arguments[i])
				was_last_added = true
			# Value after value.
			else:
				if not was_last_added:
					lines.append(arguments[i-1])
				lines.append(arguments[i])
				was_last_added = true
	
	return "\n".join(lines)


func _on_AddNew_popup_hide():
	(get_node(modal_blur) as ColorRect).hide()
	# Reset edited entry to default vaule
	edited_entry = -1


func _on_Close_pressed():
	hide()


func _on_files_dropped(files : PackedStringArray ):
	show()
	if files.is_empty():
		return
	
	var path : String = files[0]
	
	if DirAccess.dir_exists_absolute(path):
		var project_path = path.path_join("project.godot")
		if FileAccess.file_exists(project_path):
			path = project_path
		else:
			return
	
	if path.get_file() == "project.godot":
		line_edit_arguments.text = '--path "%s"' % path.get_base_dir()
		line_edit_name.text = path.get_base_dir().get_file()
	else:
		line_edit_path.text = path
		line_edit_name.text = path.get_file().trim_suffix("." + path.get_extension())
	_validate()


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


func _on_prettify_button_pressed() -> void:
	line_edit_arguments.text = \
		_args_pretty_print(line_edit_arguments.text)
	_validate()


func _on_visibility_changed() -> void:
	if visible:
		_on_AddNew_about_to_show()
	else:
		_on_AddNew_popup_hide()
