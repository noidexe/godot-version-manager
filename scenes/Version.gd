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
	


func _on_request_completed(_result, response_code : int, _headers, body : PackedByteArray):
	if response_code != 200:
		printerr("Error %s downloading release list from Github" % response_code)
		printerr(body.get_string_from_utf8())
		return

	var test_json_conv = JSON.new()
	test_json_conv.parse(body.get_string_from_utf8())
	var json = test_json_conv.get_data()
	if typeof(json) != TYPE_ARRAY:
		printerr("Wrong response format in release list")
		return
	if json.is_empty() or typeof(json[0]) != TYPE_DICTIONARY:
		printerr("Invalid data received when requesting release list")

	var last_tag : Dictionary = json[0]
	var last_version_tag : String = last_tag.get("tag_name", Globals.version_tag)
	
	# The update button SHOULD always appear if the local version tag doesn't
	# match tag for the latest official release, even if it is a lower version
	if last_version_tag == Globals.version_tag:
		$tag.text = "Version Tag: " + Globals.version_tag + " (up to date)"
	else:
		$update.text = "Update to " + last_version_tag
		$update.tooltip_text = last_tag.get("name", "") # Show title of new release as tooltip
		
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
	if OS.has_feature("macos"):
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
			await version_select.refresh_finished
		else:
			$update.text = "Waiting for download.."
			await version_select.download_finished
	
	var dir_path = "user://updates"
	var file_path = dir_path + download_url.get_file()
	
	# Make sure dir exist
	
	DirAccess.make_dir_absolute(dir_path)
	
	# Downlad file
	var req = HTTPRequest.new()
	add_child(req)
	req.download_file = file_path
	req.request(download_url, ["User-Agent: %s" % Globals.user_agent])
	
	var divisor : float = 1024 * 1024
	
	while req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:	
		$update.text = "%d%% [%.2f/%.2fMB]" % [100.0 * req.get_downloaded_bytes() / req.get_body_size(), req.get_downloaded_bytes() / divisor, req.get_body_size() / divisor]
		await get_tree().create_timer(1.0).timeout
	
	$update.text = "Extracting.."
	await get_tree().idle_frame
	
	var output = []
	var exit_code : int
	
	# TODO: Improve, remove repetition
	if OS.has_feature("windows"):
		exit_code = OS.execute("powershell.exe", ["-command", "\"Expand-Archive '%s' '%s'\" -Force" % [ ProjectSettings.globalize_path(file_path), ProjectSettings.globalize_path(dir_path) ] ], output) 
		print(output.pop_front())
		print("Powershell.exe executed with exit code: %s" % exit_code)
		exit_code = OS.execute("powershell.exe", ["-command", "\"Remove-Item '%s'\" -Force" % ProjectSettings.globalize_path(file_path) ], output) 
		print(output.pop_front())
		print("Powershell.exe executed with exit code: %s" % exit_code)
		# Only for release builds. Avoid renaming the Godot Editor executable
		if OS.has_feature("release"):
			var current_version_path = OS.get_executable_path()
			var current_version_name = current_version_path.get_file()
			var dir
			print("Opening %s.. " % current_version_path.get_base_dir() )
			dir = DirAccess.open(current_version_path.get_base_dir())
			print("Renaming %s into %s.." % [current_version_name, current_version_name + ".old"])
			print( dir.rename(current_version_name, current_version_name + ".old") )
			print("Copying new version from %s to %s" % [dir_path + "/gvm.exe", current_version_path])
			print( dir.copy(dir_path + "/gvm.exe", current_version_path) )
			print("Opening new version with pid: %s" % OS.create_process(current_version_path, []))
			get_tree().quit()
			
	elif OS.has_feature("linux"):
		exit_code = OS.execute("unzip", ["-o", "%s" % ProjectSettings.globalize_path(file_path), "-d", "%s" % ProjectSettings.globalize_path(dir_path)], output)
		print(output.pop_front())
		print("unzip executed with exit code: %s" % exit_code)
		exit_code = OS.execute("rm", ["%s" % ProjectSettings.globalize_path(file_path)], output)
		print(output.pop_front())
		print("rm executed with exit code: %s" % exit_code)
		exit_code = OS.execute("chmod", ["+x", "%s" % ProjectSettings.globalize_path(dir_path + "/gvm.x86_64") ], output )
		print(output.pop_front())
		print("chmod executed with exit code: %s" % exit_code)
		if OS.has_feature("release"):
			var dir
			var current_version_path = OS.get_executable_path()
			var current_version_name = current_version_path.get_file()
			print("Opening %s.. " % current_version_path.get_base_dir() )
			dir = DirAccess.open(current_version_path.get_base_dir())
			print("Renaming %s into %s.." % [current_version_name, current_version_name + ".old"])
			dir.rename(current_version_name, current_version_name + ".old")
			print("Copying new version from %s to %s" % [dir_path + "/gvm.x86_64", current_version_path])
			dir.copy(dir_path + "/gvm.x86_64", current_version_path)
			exit_code = OS.execute("chmod", ["+x", "%s" % current_version_path], output )
			print("chmod executed with exit code: %s" % exit_code)
			print("Opening new version with pid: %s" % OS.create_process(current_version_path, []))
			get_tree().quit()
	
	$update.text = "Restart to update"
	$update.disabled = true


func _on_LogoContainer_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var error = OS.shell_open("https://github.com/noidexe/godot-version-manager/graphs/contributors")
		if error != OK:
			printerr("Error opening browser. Error Code: %s" % error )
	pass # Replace with function body.
