extends OptionButton
# Handles the following:
# - Refreshing version list
# - Displaying available versions based on selected flags (beta, alpha, RC).
# - Downloading a specific version
# - Updating the list of linstalled versions
# Will be refactored in the future

# Contains info to download and extract the correct version
# depending on the detected platform
const platforms = {
	"X11": {
		"suffixes": ["_x11.64.zip", "_linux.64.zip"],
		"extraction-command" : [
			"unzip",
			[
				"{zip_path}",
				"-d",
				"{dest_folder}"
			],
		]
	},
	"OSX": {
		"suffixes": ["_osx.universal.zip"],
		"extraction-command" : [
			"unzip",
			[
				"{zip_path}",
				"-d",
				"{dest_folder}"
			],
		]
	},
	"Windows": {
		"suffixes": ["_win64.exe.zip"],
		"extraction-command" : [
			"powershell.exe",
			[
				"-command",
				"\"Expand-Archive '{filename}' '{dest_dir}'\"",
			]
		]
	}
}

# Currently detected platform (Windows, OSX, Linux, etc)
var current_platform

# base_url used for scraping
const base_url = "https://downloads.tuxfamily.org/godotengine/"

# Maximum concurrent HTTP requests when refreshing version list
const MAX_REQUESTS = 6

# Number of concurrent http requests running
var requests = 0

# download_db contains a list of names and download paths, 
# and gets serialized to JSON in the user data folder
# download_db  = {
# 	"last_updated" : <unix timestamp>
# 	"versions" : [
# 		{
# 			"name":"Godot_v#.#",
# 			"path":"https://path/to/exe.zip"
# 		},
# 		...
# 	]
# }
var download_db : Dictionary 

# Filtered version of download_db excluding alphas, betas, or rcs depending
# on settings
var filtered_db_view :  Array

# Used to regenerate filtered_db_view
var alpha_included = false
var beta_included = false
var rc_included = false

onready var refresh_button = $"../Refresh"
onready var download_button = $"../Download"

# Emitted when the download_db has been updated
signal refresh_finished()

# Emitted when a version is added to the list of installed versions
signal version_added() 


func _ready():
	# DETECT PLATFORM
	if OS.has_feature("Windows"):
		current_platform = "Windows"
	elif OS.has_feature("OSX"):
		current_platform = "OSX"
	elif OS.has_feature("X11"):
		current_platform = "X11"
		
	# RELOAD
	_reload()
	
	# RESTORE UI FLAGS
	var config = Globals.read_config()
	if "ui" in config:
		$"../Alpha".pressed = config.ui.alpha
		$"../Beta".pressed = config.ui.beta
		$"../RC".pressed = config.ui.rc


# Deserializes json version of download_db and
# calls _update_list to update display of options
func _reload():
	download_db = Globals.read_download_db()
	_update_list()


# Uses natural order sort to sort based on semver
func _version_sort(a : String, b: String):
	# Get the name of the file from the url
	# Otherwise the full url will cause naturalnocasemp_to 
	# sort incorrectly
	var a_split = a.split("/")
	var b_split = b.split("/")
	a = a_split[a_split.size()-1]
	b = b_split[b_split.size()-1]
	
	return a.naturalnocasecmp_to(b) < 0


# Scrapes downloads website and regenerates
# downloads_db
func _refresh():
	var _download_links = []
	var _download_db = {
		"last_updated" : OS.get_unix_time(),
		"versions" : []
		}
	_find_links(base_url, _download_links)
	
	# Wait for _find_links to finish
	while requests > 0:
		yield(get_tree().create_timer(1.0),"timeout")
	
	# Build download_db
	_download_links.sort_custom(self, "_version_sort")
	
	_download_links.invert()
	for link in _download_links:
		var suffixes = platforms[current_platform].suffixes
		var _entry_name = link.get_file()
		for suffix in suffixes:
			_entry_name = _entry_name.trim_suffix(suffix)
		var entry = {
			"name" : _entry_name,
			"path" : link
		}
		_download_db.versions.append(entry)
	
	# Store download_db as json
	Globals.write_download_db(_download_db)
	
	emit_signal("refresh_finished", _download_db)


# Analyzes a directory listing returned by lighthttpd in search of two things:
# - download links to Godot versions
# - folder links to analyze recursively
# output_array stores the results
func _parsexml(buffer : PoolByteArray, partial_path : String, output_array : Array):
	var xml = XMLParser.new()
	var error = xml.open_buffer(buffer)
	if error == OK:
		while(true):
			var err = xml.read()
			
			if err != OK:
				if err != ERR_FILE_EOF:
					print("Error %s reading XML" % err)
				break
			
			# look for <a> tags
			if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "a":
				
				var href = xml.get_named_attribute_value_safe("href")
				
				# if it is a folder that may contain downloads, recursively parse it
				if href.ends_with("/") and (
					href.begins_with("alpha")
					or href.begins_with("beta")
					or href.begins_with("rc")
					or (href[0].is_valid_integer() and href[1] == ".") # x.x.x/ etc..
					):
					_find_links(partial_path + href, output_array)
				else:
					# Handle linux having a different suffix on 4.x
					var suffixes = platforms[current_platform].suffixes
					for suffix in suffixes:
						if href.ends_with(suffix):
							output_array.append(partial_path + href)

				
	else:
		print("Error %s getting download info" % error)


# Gets called recursively. Fetches the next page containing a diretory
# listing from the download page and sends it to _parsexml for analysis
# output_array is passed to _parsexml to store the results
func _find_links(url:String, output_array : Array):
	while requests > MAX_REQUESTS:
		yield(get_tree().create_timer(0.1),"timeout")
	requests += 1
	
	var req = HTTPRequest.new()
	add_child(req)
	req.request(url)
	
	refresh_button.text = "Scraping%s %s" % [ [".", "..", "..."][randi() % 3] ,url.rsplit("/",true,2)[1] ]
	
	var response = yield(req,"request_completed")
	if response[1] == 200:
		_parsexml(response[3], url, output_array)
	else:
		printerr("Error scraping link. Response code: %s" % response[1])
	
	req.queue_free()
	requests -= 1


# Recreates the drop-down menu for download options
func _update_list():
	clear()
	filtered_db_view = []
	
	for entry in download_db.versions:
		if (
			"stable" in entry.name
			or (rc_included and "rc" in entry.name)
			or (beta_included and "beta" in entry.name)
			or (alpha_included and "alpha" in entry.name) 
			):
			filtered_db_view.append(entry)

	for entry in filtered_db_view:
		add_item(entry.name)


func _on_Refresh_pressed():
	#disabled = true
	_refresh()
	while requests > 0: 
		refresh_button.text = "Scraping %s urls%s" % [ requests, [".", "..", "..."][randi() % 3] ]
		yield(get_tree().create_timer(0.2),"timeout")
	refresh_button.text = "Refresh"
	#disabled = false


# Downloads and installs the selected version
func _on_Download_pressed():
	if selected == -1:
		return false
		
	# Make sure the directory exists
	var dir = Directory.new()
	dir.make_dir("user://versions/")
	
	var _selection = filtered_db_view[selected]
	download_button.disabled = true
	
	# TODO: make it work with other platforms
	var filename =  "user://versions/" + _selection.path.get_file()
	var url = _selection.path
	
	var req = HTTPRequest.new()
	add_child(req)
	req.download_file = filename
	req.request(url, [], false)
	
	var divisor : float = 1024 * 1024
	
	while req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:	
		download_button.text = "Downloading... %d%% [%.2f/%.2fMB]" % [100.0 * req.get_downloaded_bytes() / req.get_body_size(), req.get_downloaded_bytes() / divisor, req.get_body_size() / divisor]
		yield(get_tree().create_timer(1.0),"timeout")
	
	download_button.text = "Extracting.."
	yield(get_tree(),"idle_frame")
	
	var output = []
	var exit_code : int
	if OS.has_feature("Windows"):
		exit_code = OS.execute("powershell.exe", ["-command", "\"Expand-Archive '%s' '%s'\" -Force" % [ ProjectSettings.globalize_path(filename), ProjectSettings.globalize_path("user://versions/") ] ], true, output) 
		print(output.pop_front())
		print("Powershell.exe executed with exit code: %s" % exit_code)
		_add_version(_selection.name,filename.rstrip(".zip"))
	elif OS.has_feature("X11"):
		exit_code = OS.execute("unzip", ["-o", "%s" % ProjectSettings.globalize_path(filename), "-d", "%s" % ProjectSettings.globalize_path("user://versions/")], true, output)
		print(output.pop_front())
		print("unzip executed with exit code: %s" % exit_code)
		exit_code = OS.execute("chmod", ["+x", "%s" % ProjectSettings.globalize_path(filename).rstrip(".zip") ], true, output )
		print(output.pop_front())
		print("chmod executed with exit code: %s" % exit_code)
		_add_version(_selection.name,filename.rstrip(".zip"))
	elif OS.has_feature("OSX"):
		exit_code = OS.execute("unzip", ["%s" % ProjectSettings.globalize_path(filename), "-d", "%s" % ProjectSettings.globalize_path("user://versions/")], true, output)
		print(output.pop_front())
		print("unzip executed with exit code: %s" % exit_code)
		var app_full_path = ProjectSettings.globalize_path("user://versions/") + _selection.name + ".app"
		exit_code = OS.execute("mv", [ProjectSettings.globalize_path("user://versions/Godot.app"), app_full_path], true, output)
		print(output.pop_front())
		print("mv run with exit code: %s" % exit_code)
		_add_version(_selection.name, "user://versions/" + _selection.name + ".app")
	
	download_button.disabled = false
	download_button.text = "Download"


# Adds a downloaded version of Godot to the list of 
# installed versions
func _add_version(v_name : String, path: String):
	var entry = {
		"name": v_name,
		"path" : ProjectSettings.globalize_path(path), 
		"arguments" : ""
	}
	
	# Read in the config
	var config = Globals.read_config()
	
	# Modify the config
	config.versions.append(entry)
	
	# Write out changes
	Globals.write_config(config)
	
	emit_signal("version_added")


func _on_Alpha_toggled(button_pressed):
	alpha_included = button_pressed
	Globals.update_ui_flag("alpha", button_pressed)
	_update_list()


func _on_Beta_toggled(button_pressed):
	beta_included = button_pressed
	Globals.update_ui_flag("beta", button_pressed)
	_update_list()


func _on_RC_toggled(button_pressed):
	rc_included = button_pressed
	Globals.update_ui_flag("rc", button_pressed)
	_update_list()


func _on_VersionSelect_refresh_finished(new_download_db : Dictionary):
	download_db = new_download_db
	_update_list()
