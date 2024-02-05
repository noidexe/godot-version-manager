extends Control

var host_device_dpi := 96.0
var stretch_mode := Window.CONTENT_SCALE_MODE_DISABLED
var stretch_aspect := Window.CONTENT_SCALE_ASPECT_IGNORE
@onready var target_device_dpi := DisplayServer.screen_get_dpi()
@onready var base_window_size := Vector2(
	ProjectSettings.get_setting("display/window/size/viewport_width"),
	ProjectSettings.get_setting("display/window/size/viewport_height"))

func _ready():
	# wait a couple of frames to avoid showing a black background during resize
	# AFAIK it's not possible to know when the splash is gone
	for i in 2:
		await get_tree().process_frame
	var shrink = target_device_dpi / host_device_dpi
	var config = Globals.read_config()
	if "ui" in config:
		shrink = config.ui.get("scale", shrink )
	$SpinBox.value = shrink


func _rescale_ui(p_scale: float):
	get_window().content_scale_mode = stretch_mode
	get_window().content_scale_aspect = stretch_aspect
	get_window().content_scale_factor = p_scale
	get_window().size = base_window_size * p_scale
	get_window().move_to_center()


func _on_SpinBox_value_changed(value):
	_rescale_ui(value)
	Globals.update_ui_flag("scale", value)
