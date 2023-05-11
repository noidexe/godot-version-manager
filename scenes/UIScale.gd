extends Control

var host_device_dpi := 96.0
var stretch_mode := SceneTree.STRETCH_MODE_DISABLED
var stretch_aspect := SceneTree.STRETCH_ASPECT_IGNORE
onready var target_device_dpi := OS.get_screen_dpi()
onready var base_window_size := Vector2(
	ProjectSettings.get_setting("display/window/size/width"),
	ProjectSettings.get_setting("display/window/size/height"))

func _ready():
	var shrink = target_device_dpi / host_device_dpi
	var config = Globals.read_config()
	if "ui" in config:
		shrink = config.ui.get("scale", shrink )
	$SpinBox.value = shrink
	

func _rescale_ui(scale: float):
	get_tree().set_screen_stretch(stretch_mode, stretch_aspect, Vector2.ZERO, scale)
	OS.window_size = base_window_size * scale
	OS.center_window()


func _on_SpinBox_value_changed(value):
	_rescale_ui(value)
	Globals.update_ui_flag("scale", value)
