extends Button

func _on_OpenFolder_pressed():
# warning-ignore:return_value_discarded
	OS.shell_open(ProjectSettings.globalize_path("user://versions/"))
