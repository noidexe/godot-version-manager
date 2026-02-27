extends ItemList

# Shows a slightly different icon for alpha, beta, rc, etc. Will be replaced by
# official icons when https://github.com/godotengine/godot-proposals/issues/541
# is approved
var icons = {
	"tools" : preload("res://icons/master.res"),
	"dev" : preload("res://icons/master.res"),
	"alpha" : preload("res://icons/alpha.res"),
	"beta" : preload("res://icons/beta.res"),
	"rc" : preload("res://icons/rc.res"),
	"stable" : preload("res://icons/stable.res")
}

# TODO: Move the config to Globals.gd and centralize config
# manipulation
var config : Dictionary
export var context_menu : NodePath

var version_regex : RegEx

func _ready():
	version_regex = RegEx.new()
# warning-ignore:return_value_discarded
	version_regex.compile("v[0-9].+_")
	_reload()


func _reload():
	config = Globals.read_config()
	if "ui" in config:
		$"%CloseOnLaunch".pressed = config.ui.get("close_on_launch", false)
	_update_list()


func _update_list():
	clear()
	for version in config.versions:
		add_item(_get_name(version), _get_correct_icon(version.name, version.arguments))


func _get_name(version):
	var ret = version.name
	if "--path" in version.arguments:
		var version_number = "  [ %s ]"
		var regex_match = version_regex.search(version.path)
		if regex_match is RegExMatch:
			ret += version_number % regex_match.get_string().rstrip("_")
		else:
			ret += version_number % "custom ver."
	return ret

func _get_icon_path_from_project(path_to_project : String):
	# This should be easier loading project.godot as a ConfigFile
	# Unfortunately some identifiers like Vector4 break parsing
	# It would probably work if we migrate GVM to Godot 4
	
	var ret = ""
	var file := File.new()
	var err := file.open(path_to_project, File.READ)
	if err != OK:
		printerr("Error loading project.godot at " + path_to_project)
		return ret
	
	var in_section = false # true if we reached [application]
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line == "[application]":
			in_section = true
			continue
		# we don't do any further checks if we're not in the correct section
		# it's a waste of time and we could find the wrong config/icon if defined somewhere else
		if in_section:
			if line.begins_with("[") and line.ends_with("]"):
				# we are entering another section and we left [application]
				# we don't want to keep searching. There's no icon defined
				break
			elif line.begins_with("config/icon="):
				ret = line.get_slice("=", 1).lstrip('"').rstrip('"').trim_prefix("res://")
				break
	file.close()
	return ret

func _get_correct_icon(v_name : String, v_args : String):
	# Handle Godot projects
	if "--path" in v_args:
		var args = _args_string_to_array(v_args)
		var project_path : String = args[ args.find("--path") + 1 ]
		if OS.has_feature("Windows"):
			# Strip \ and " from left and right
			project_path = project_path.lstrip("\\\"").rstrip("\\\"") + "\\"
		else:
			# Strip " from left, and strip / and " from right
			project_path = project_path.lstrip("\"").rstrip("/\"") + "/"
		
		return _load_icon_from_file(project_path + _get_icon_path_from_project(project_path + "project.godot"))
	# Handle Godot versions
	if "godot" in v_name.to_lower():
		for test in ["tools", "dev", "alpha", "beta", "rc", "stable"]:
			if test in v_name:
				return icons[test]
	# Handle custom app with icon in app_icons folder
	var dir = Directory.new()
	if not dir.dir_exists(Globals.APP_ICONS_PATH):
		dir.make_dir(Globals.APP_ICONS_PATH)
	var icon_path := ""
	for ext in ["png", "webp", "jpg"]:
		var candidate = Globals.APP_ICONS_PATH.plus_file("%s.%s" % [v_name, ext])
		if dir.file_exists(candidate):
			icon_path = candidate
			break
	# If found try loading the icon
	if icon_path:
		return _load_icon_from_file(icon_path, preload("res://icons/external_tool.png"))
	# If nothing worked return a generic app icon
	return preload("res://icons/external_tool.png")


func _on_Installed_item_activated(index):
	var pid :int
	var path : String =  config.versions[index].path
	var is_game_project = "--path" in config.versions[index].arguments
	var is_godot = "godot" in path.to_lower()
	var args : PoolStringArray = _args_string_to_array(config.versions[index].arguments)
	if is_game_project:
		args.append("-e")
	elif is_godot:
		args.append("-p")
	if OS.has_feature("OSX"):
		var osx_args := PoolStringArray([ProjectSettings.globalize_path(path), "--args"])
		osx_args.append_array(args)
		pid = OS.execute("open", osx_args, false)
	else:
		pid = OS.execute(ProjectSettings.globalize_path(path), args, false)
	print( "Running \"%s\" with pid %s" % [ path, pid ] )
	if $"%CloseOnLaunch".pressed:
		print("Close on launch enabled. Quitting.." )
		get_tree().quit(0)

func _args_string_to_array( args : String ) -> PoolStringArray:
	var ret = PoolStringArray()
	var quoting = false
	var tmp = String()
	for c in args:
		if c == " " and not quoting:
			ret.append(tmp)
			tmp = String()
		elif c == "\"":
			tmp += c
			if not quoting:
				quoting = true
			else:
				quoting = false
				#no quotes needed
				ret.append(tmp.rstrip("\"").lstrip("\""))
				tmp = String()
		else:
			tmp += c
	if not tmp.empty():
		ret.append(tmp)
	return ret

func _on_version_added():
	_reload()


func _on_ContextMenu_id_pressed(id):
	if not is_anything_selected():
		return
	var item = get_selected_items()[0]
	match id:
		0:
			_edit(item)
		1:
			_move(item, -1)
		2:
			_move(item, 1)
		3:
			_delete(item)
	


func _delete(idx):
	config.versions.remove(idx)
	Globals.write_config(config)
	_reload()


func _move(idx : int, offset: int):
	var to_move = config.versions[idx]
	config.versions.remove(idx)
	var new_idx = clamp(idx + offset, 0, config.versions.size() )
	config.versions.insert(new_idx, to_move)
	Globals.write_config(config)
	_reload()

func _edit(idx):
	$"%AddNew".edit(idx)

func _on_Installed_item_rmb_selected(_index, at_position):
	var menu = get_node(context_menu) as PopupMenu
	# The top_left is at the beginning of the container
	# So we need to add the rect_position of the parent node to 
	# Compensate
	menu.set_position(rect_global_position + at_position + Vector2(0, 20))
	menu.popup()


func _on_CloseOnLaunch_toggled(button_pressed):
	Globals.update_ui_flag("close_on_launch", button_pressed)
	pass # Replace with function body.


func can_drop_data(position, _data):
	return get_item_at_position(position) != -1
	
func get_drag_data(position):
	var item_id := get_item_at_position(position)
	set_drag_preview(_create_preview(item_id))
	return item_id
	
func drop_data(position, data):
	var old_pos : int = data
	var new_pos : int = get_item_at_position(position)
	_move(old_pos, new_pos - old_pos)

func _create_preview( item_id : int ) -> HBoxContainer:
	assert(item_id >= 0 and item_id < get_item_count())
	var ret = PanelContainer.new()
	var hbox = HBoxContainer.new()
	var label = Label.new()
	var icon = TextureRect.new()
	hbox.add_child(icon)
	hbox.add_child(label)
	ret.add_child(hbox)
	label.text = get_item_text(item_id)
	icon.texture = get_item_icon(item_id)
	icon.rect_min_size = Vector2(64,64)
	icon.expand = true
	var dark_mode = Globals.read_config()["ui"]["darkmode"]
	ret.add_stylebox_override("panel", preload("res://theme/item_drag.stylebox") if not dark_mode else preload("res://theme/item_drag_dark.stylebox"))
	return ret

func _gui_input(event):
	if event is InputEventKey:
		var e = event as InputEventKey
		if e.pressed and e.physical_scancode == KEY_DELETE:
			for id in get_selected_items():
				_delete(id)


func _load_icon_from_file(path: String, default : Texture = preload("res://icon.png")) -> Texture: 
	var file = File.new()
	if file.open(path,File.READ) != OK:
		return preload("res://icon.png")

	var buffer = file.get_buffer(file.get_len())
	file.close()
	
	var icon_image = Image.new()
	var err = ERR_BUG
	# loading svgs at runtime is not supported on Godot 3
	match path.get_extension():
		"png":
			err = icon_image.load_png_from_buffer(buffer)
		"webp":
			err = icon_image.load_webp_from_buffer(buffer)
		"jpg":
			err = icon_image.load_jpg_from_buffer(buffer)

	if err:
		return default

	var icon_texture = ImageTexture.new()
	icon_texture.create_from_image(icon_image)
	return icon_texture
