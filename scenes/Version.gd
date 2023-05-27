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
		$update.text = "Update to " + last_version_tag
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
	# Autoupdate currently not supported on OSX
	if OS.has_feature("OSX"):
		var error = OS.shell_open(download_url)
		if error != OK:
			printerr("Error opening browser. Error Code: %s" % error )
		return
	
	$update.disabled = true
	
	# Wait till there are no version refresh or downloads pending..
	var version_select = $"%VersionSelect"
	while version_select.is_refreshing or version_select.is_downloading:
		if version_select.is_refreshing:
			$update.text = "Waiting for refresh.."
			yield(version_select,"refresh_finished")
		else:
			$update.text = "Waiting for download.."
			yield(version_select,"download_finished")
	
	var dir_path = "user://updates"
	var file_path = dir_path + download_url.get_file()
	
	# Make sure dir exist
	var dir = Directory.new()
	dir.make_dir(dir_path)
	
	# Downlad file
	var req = HTTPRequest.new()
	add_child(req)
	req.download_file = file_path
	req.request(download_url, ["User-Agent: %s" % Globals.user_agent], false)
	
	var divisor : float = 1024 * 1024
	
	while req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:	
		$update.text = "%d%% [%.2f/%.2fMB]" % [100.0 * req.get_downloaded_bytes() / req.get_body_size(), req.get_downloaded_bytes() / divisor, req.get_body_size() / divisor]
		yield(get_tree().create_timer(1.0),"timeout")
	
	$update.text = "Extracting.."
	yield(get_tree(),"idle_frame")
	
	var output = []
	var exit_code : int
	
	# TODO: Improve, remove repetition
	if OS.has_feature("Windows"):
		exit_code = OS.execute("powershell.exe", ["-command", "\"Expand-Archive '%s' '%s'\" -Force" % [ ProjectSettings.globalize_path(file_path), ProjectSettings.globalize_path(dir_path) ] ], true, output) 
		print(output.pop_front())
		print("Powershell.exe executed with exit code: %s" % exit_code)
		exit_code = OS.execute("powershell.exe", ["-command", "\"Remove-Item '%s'\" -Force" % ProjectSettings.globalize_path(file_path) ], true, output) 
		print(output.pop_front())
		print("Powershell.exe executed with exit code: %s" % exit_code)
		# Only for release builds. Avoid renaming the Godot Editor executable
		if OS.has_feature("release"):
			var current_version_path = OS.get_executable_path()
			var current_version_name = current_version_path.get_file()
			print("Opening %s.. " % current_version_path.get_base_dir() )
			print( dir.open(current_version_path.get_base_dir()) )
			print("Renaming %s into %s.." % [current_version_name, current_version_name + ".old"])
			print( dir.rename(current_version_name, current_version_name + ".old") )
			print("Copying new version from %s to %s" % [dir_path + "/gvm.exe", current_version_path])
			print( dir.copy(dir_path + "/gvm.exe", current_version_path) )
			print("Opening new version with pid: %s" % OS.execute(current_version_path, [], false))
			get_tree().quit()
			
	elif OS.has_feature("X11"):
		exit_code = OS.execute("unzip", ["-o", "%s" % ProjectSettings.globalize_path(file_path), "-d", "%s" % ProjectSettings.globalize_path(dir_path)], true, output)
		print(output.pop_front())
		print("unzip executed with exit code: %s" % exit_code)
		exit_code = OS.execute("rm", ["%s" % ProjectSettings.globalize_path(file_path)], true, output)
		print(output.pop_front())
		print("rm executed with exit code: %s" % exit_code)
		exit_code = OS.execute("chmod", ["+x", "%s" % ProjectSettings.globalize_path(dir_path + "/gvm.x86_64") ], true, output )
		print(output.pop_front())
		print("chmod executed with exit code: %s" % exit_code)
		if OS.has_feature("release"):
			var current_version_path = OS.get_executable_path()
			var current_version_name = current_version_path.get_file()
			print("Opening %s.. " % current_version_path.get_base_dir() )
			dir.open(current_version_path.get_base_dir())
			print("Renaming %s into %s.." % [current_version_name, current_version_name + ".old"])
			dir.rename(current_version_name, current_version_name + ".old")
			print("Copying new version from %s to %s" % [dir_path + "/gvm.x86_64", current_version_path])
			dir.copy(dir_path + "/gvm.x86_64", current_version_path)
			exit_code = OS.execute("chmod", ["+x", "%s" % current_version_path], true, output )
			print("chmod executed with exit code: %s" % exit_code)
			print("Opening new version with pid: %s" % OS.execute(current_version_path, [], false))
			get_tree().quit()
	
	$update.text = "Restart to update"
	$update.disabled = true


func _on_LogoContainer_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		var error = OS.shell_open(RELEASES_URL)
		if error != OK:
			printerr("Error opening browser. Error Code: %s" % error )
	pass # Replace with function body.
