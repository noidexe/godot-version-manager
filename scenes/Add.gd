extends Button

export var add_popup : NodePath

func _on_Add_pressed():
	var popup = get_node(add_popup) as Popup
	popup.popup_centered()
