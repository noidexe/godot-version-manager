extends Button

func _on_OpenFolder_pressed():
	var dir = Directory.new()
	if not dir.dir_exists("user://versions/"):
		var err = dir.make_dir("user://versions/")
		print_debug(err)
	var path = ProjectSettings.globalize_path("user://versions/")
	if OS.has_feature("OSX"):
		path = "file://" + path
	var err = OS.shell_open(path)
	if err != OK:
		print_debug(err)
