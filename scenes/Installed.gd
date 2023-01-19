extends ItemList

# Shows a slightly different icon for alpha, beta, rc, etc. Will be replaced by
# official icons when https://github.com/godotengine/godot-proposals/issues/541
# is approved
var icons = {
	"tool" : preload("res://icons/master.res"),
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

func _get_correct_icon(v_name : String, v_args : String):
	if "--path" in v_args:
		var args = v_args.split(" ")
		var path : String = args[ args.find("--path") + 1 ]
		path = path.lstrip("\\\"").rstrip("\\\"") + "\\icon.png"
		
		var file = File.new()
		if file.open(path,File.READ) != OK:
			return preload("res://icon.png")

		var buffer = file.get_buffer(file.get_len())
		file.close()
		
		var icon_image = Image.new()
		if icon_image.load_png_from_buffer(buffer) != OK:
			return preload("res://icon.png")

		var icon_texture = ImageTexture.new()
		icon_texture.create_from_image(icon_image)
		return icon_texture
	for test in ["tool", "alpha", "beta", "rc", "stable"]:
		if test in v_name:
			return icons[test]
	return preload("res://icon.png")


func _on_Installed_item_activated(index):
	var pid :int
	var path : String =  config.versions[index].path
	var is_game_project = "--path" in config.versions[index].arguments
	var args : PoolStringArray = config.versions[index].arguments.split(" ")
	args.append("-e" if is_game_project else "-p")
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
		

func _on_version_added():
	_reload()


func _on_ContextMenu_id_pressed(id):
	if not is_anything_selected():
		return
	var item = get_selected_items()[0]
	match id:
		0:
			_delete(item)
		1:
			_move(item, -1)
		2:
			_move(item, 1)
		3:
			_edit(item)
	


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
	menu.set_position(rect_position + at_position)
	menu.popup()


func _on_CloseOnLaunch_toggled(button_pressed):
	Globals.update_ui_flag("close_on_launch", button_pressed)
	pass # Replace with function body.
