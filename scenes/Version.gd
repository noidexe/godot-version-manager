extends HBoxContainer

const api_endpoint = "https://api.github.com/repos/noidexe/godot-version-manager/releases"
const version_tag = "v1.4"  # REMEMBER TO UPDATE!

var download_url = "https://github.com/noidexe/godot-version-manager/releases/"

# Called when the node enters the scene tree for the first time.
func _ready():
	$update.hide()
	$tag.text = "Version Tag: " + version_tag
	
	$req.request(api_endpoint, ["Accept: application/vnd.github.v3+json"])

func _on_request_completed(_result, response_code : int, _headers, body : PoolByteArray):
	if response_code != 200:
		printerr("Error %s downloaded release list from Github" % response_code)
		return
	var json = parse_json(body.get_string_from_utf8())
	if typeof(json) != TYPE_ARRAY:
		printerr("Wrong response format in release list")
		return
	if json.empty() or typeof(json[0]) != TYPE_DICTIONARY:
		printerr("Invalid data received when requesting release list")
	var last_tag : Dictionary = json[0]
	
	var last_version_tag : String = last_tag.get("tag_name", version_tag)
	
	if last_version_tag != version_tag:
		$update.hint_tooltip = last_tag.get("name", "")
		download_url = last_tag.get("html_url", download_url)
		$update.show()
	else:
		$tag.text = "Version Tag: " + version_tag + " (up to date)"

func _on_update_pressed():
	OS.shell_open(download_url)
