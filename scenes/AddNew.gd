extends Popup


export var select_dialog : NodePath

signal version_added()

# Called when the node enters the scene tree for the first time.
func _ready():
	_validate()
	pass


func _on_Select_pressed():
	var popup = get_node(select_dialog) as FileDialog
	popup.popup()
	$Margin/VBox/path/LineEdit.text = yield(popup,"file_selected")
	if $Margin/VBox/name/LineEdit.text == "":
		$Margin/VBox/name/LineEdit.text = $Margin/VBox/path/LineEdit.text.get_file()
	_validate()

func _validate(_unused = ""):
	$Margin/VBox/Add.disabled = $Margin/VBox/name/LineEdit.text == "" or not $Margin/VBox/path/LineEdit.text.is_abs_path()
	pass

func _on_Add_pressed():
	var entry = {
		"name": $Margin/VBox/name/LineEdit.text,
		"path" :$Margin/VBox/path/LineEdit.text,
		"arguments" :$Margin/VBox/arguments/LineEdit.text
	}
	var file = File.new()
	file.open("user://config.json",File.READ)
	var config = parse_json(file.get_as_text())
	config.versions.append(entry)
	file.close()
	file.open("user://config.json",File.WRITE)
	file.store_line(to_json(config))
	file.close()
	emit_signal("version_added")
	hide()


func _on_AddNew_about_to_show():
	$Margin/VBox/name/LineEdit.text = ""
	$Margin/VBox/arguments/LineEdit.text = ""
	$Margin/VBox/path/LineEdit.text = ""
