extends Button

export var add_popup : NodePath

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Add_pressed():
	var popup = get_node(add_popup) as Popup
	popup.popup_centered()
	pass # Replace with function body.
