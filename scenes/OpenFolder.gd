extends Button

func _on_OpenFolder_pressed():
	OS.shell_open(ProjectSettings.globalize_path("user://versions/"))
