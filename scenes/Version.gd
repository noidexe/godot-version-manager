extends HBoxContainer

const api_endpoint = "https://api.github.com/repos/noidexe/godot-version-manager/releases"

const DOWNLOAD_SUFFIXES = {
	"OSX" : "osx.zip",
	"Windows": "win.zip",
	"X11": "x11.zip",
}


# Initialized to the release list page as a fallback in case it fails to 
# get the link to the latest release for some reason
const RELEASES_URL = "https://github.com/noidexe/godot-version-manager/releases/"
var download_url = RELEASES_URL


func _ready():
	$update.hide()
	$tag.text = "Version Tag: " + Globals.version_tag
	
	$req.request(api_endpoint, ["Accept: application/vnd.github.v3+json", "User-Agent: %s" % Globals.user_agent])


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
	var last_version_tag : String = last_tag.get("tag_name", Globals.version_tag)
	
	# The update button SHOULD always appear if the local version tag doesn't
	# match tag for the latest official release, even if it is a lower version
	if last_version_tag == Globals.version_tag:
		$tag.text = "Version Tag: " + Globals.version_tag + " (up to date)"
	else:
		$update.hint_tooltip = last_tag.get("name", "") # Show title of new release as tooltip
		
		var assets = last_tag.get("assets", [])
		var suffix = DOWNLOAD_SUFFIXES.get(OS.get_name(), "none")
		for asset in assets:
			var url : String = asset.get("browser_download_url", "")
			if url.ends_with(suffix):
				download_url = url
				break
		#download_url = last_tag.get("html_url", download_url)
		$update.show()


func _on_update_pressed():
	var error = OS.shell_open(download_url)
	if error != OK:
		printerr("Error opening browser. Error Code: %s" % error )


func _on_LogoContainer_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		var error = OS.shell_open(RELEASES_URL)
		if error != OK:
			printerr("Error opening browser. Error Code: %s" % error )
	pass # Replace with function body.
