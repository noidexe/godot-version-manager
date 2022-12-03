extends VBoxContainer


var url = "https://example.com"

const BASE_DIR = "user://images/"

onready var title = $title
onready var author = $author
onready var thumb = $body/thumb_container/thumb
onready var contents = $body/contents

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var error = OS.shell_open(url)
		if error != OK:
			printerr("Error opening browser. Error Code: %s" % error )

func set_info(info : Dictionary):
	url = info.link
	hint_tooltip = url
	title.text = info.title
	author.text = "%s - %s" % [info.author, info.date]
	contents.text = info.contents
	_load_image(info.image)

func _load_image(_url):
	var local_path = BASE_DIR + _url.get_file()
	var dir = Directory.new()
	if not dir.dir_exists(BASE_DIR):
		dir.make_dir(BASE_DIR)
	if not dir.file_exists(local_path):
		$req.download_file = local_path
		$req.request(_url)
		var response = yield($req,"request_completed")
		if not response[1] == 200:
			printerr("Could not find or download image")
			return
	var img = Image.new()
	img.load(local_path)
	var tex = ImageTexture.new()
	tex.create_from_image(img)
	thumb.texture = tex
