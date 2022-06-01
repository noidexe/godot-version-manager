extends HBoxContainer

const api_endpoint = "https://api.github.com/repos/noidexe/godot-version-manager/releases"

# Update before commiting
# Use semver
# Add '-devel' for versions not intended for release
# Remove '-devel' when commiting a build to be tagged as release
# Remember to update version in export settings before exporting
const version_tag = "v1.5"

# Initialized to the release list page as a fallback in case it fails to 
# get the link to the latest release for some reason
var download_url = "https://github.com/noidexe/godot-version-manager/releases/"


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
	
	# The update button SHOULD always appear if the local version tag doesn't
	# match tag for the latest official release, even if it is a lower version
	if last_version_tag == version_tag:
		$tag.text = "Version Tag: " + version_tag + " (up to date)"
	else:
		$update.hint_tooltip = last_tag.get("name", "") # Show title of new release as tooltip
		download_url = last_tag.get("html_url", download_url)
		$update.show()


func _on_update_pressed():
	OS.shell_open(download_url)
