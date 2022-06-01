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


func _ready():
	_reload()


func _reload():
	config = Globals.read_config()
	_update_list()


func _update_list():
	clear()
	for version in config.versions:
		add_item(version.name, _get_correct_icon(version.name))


func _get_correct_icon(v_name : String):
	for test in ["tool", "alpha", "beta", "rc", "stable"]:
		if test in v_name:
			return icons[test]
	return preload("res://icon.png")


func _on_Installed_item_activated(index):
	var path : String =  config.versions[index].path
	var args : PoolStringArray = config.versions[index].arguments.split(" ")
	args.append("-p")
	if OS.has_feature("OSX"):
		var osx_args := PoolStringArray([ProjectSettings.globalize_path(path), "--args"])
		osx_args.append_array(args)
		OS.execute("open", osx_args, false)
	else:
		OS.execute(ProjectSettings.globalize_path(path), args, false)


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


func _on_Installed_item_rmb_selected(_index, at_position):
	var menu = get_node(context_menu) as PopupMenu
	# The top_left is at the beginning of the container
	# So we need to add the rect_position of the parent node to 
	# Compensate
	menu.set_position(rect_position + at_position)
	menu.popup()
