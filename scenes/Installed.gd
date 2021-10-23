extends ItemList

var icons = {
	"tool" : preload("res://icons/master.res"),
	"alpha" : preload("res://icons/alpha.res"),
	"beta" : preload("res://icons/beta.res"),
	"rc" : preload("res://icons/rc.res"),
	"stable" : preload("res://icons/stable.res")
}

var config : Dictionary = { "versions" : [] }
export var context_menu : NodePath
# Called when the node enters the scene tree for the first time.
func _ready():
	_reload()
	pass # Replace with function body.


func _reload():
	var file = File.new()
	if not file.file_exists("user://config.json"):
		_save()
	file.open("user://config.json",File.READ)
	var content = file.get_as_text()
	config = parse_json(content)
	file.close()
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
	OS.execute(ProjectSettings.globalize_path(path), args, false)


func _on_version_added():
	_reload()
	pass # Replace with function body.


func _on_ContextMenu_id_pressed(id):
	if id == 0 and is_anything_selected():
		_delete(get_selected_items()[0])
		
func _delete(idx):
	config.versions.remove(idx)
	_save()
	_reload()


func _on_Installed_item_rmb_selected(_index, at_position):
	var menu = get_node(context_menu) as PopupMenu
	menu.rect_position = at_position
	menu.popup()
	pass # Replace with function body.

func _save():
	var file = File.new()
	file.open("user://config.json",File.WRITE)
	file.store_line(to_json(config))
	file.close()
