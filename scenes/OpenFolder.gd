extends Button

func _on_OpenFolder_pressed():
	var err
	if not DirAccess.dir_exists_absolute("user://versions/"):
		err = DirAccess.make_dir_absolute("user://versions/")
		print_debug(err)
	var path = ProjectSettings.globalize_path("user://versions/")
	if OS.has_feature("macos"):
		path = "file://" + path
	err = OS.shell_open(path)
	if err != OK:
		print_debug(err)
