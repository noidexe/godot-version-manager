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
		"suffixes": ["_x11.64.zip", "_linux.64.zip", "_linux.x86_64.zip"],
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
		"suffixes": ["_osx.universal.zip", "_macos.universal.zip"],
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
#	"directories" : {
#		"1.1/beta/" : "Mon 31 Feb 1942"
#	},
#	"links" : {
#		"http://asdfasdfasdf/" : true  # Dict as Set
#	}

# }
var download_db : Dictionary 

# Filtered version of download_db excluding alphas, betas, or rcs depending
# on settings
var filtered_db_view :  Array

# Used to regenerate filtered_db_view
var stable_included = true
var alpha_included = false
var beta_included = false
var rc_included = false

export var refresh_button_path : NodePath 
export var download_button_path : NodePath
export var stable_button_path : NodePath
export var alpha_button_path : NodePath
export var beta_button_path : NodePath
export var rc_button_path : NodePath

onready var refresh_button = get_node(refresh_button_path)
onready var download_button = get_node(download_button_path)
onready var stable_button = get_node(stable_button_path)
onready var alpha_button = get_node(alpha_button_path)
onready var beta_button = get_node(beta_button_path)
onready var rc_button = get_node(rc_button_path)

# Emitted when the download_db has been updated
signal refresh_finished()

# Emitted when a version is added to the list of installed versions
signal version_added() 


func _ready():
	# VALIDATE BUTTON PATHS ( Will use scene unique names when 3.5 reaches stable)
	for button in [refresh_button, download_button, stable_button, alpha_button, beta_button, rc_button]:
		assert(button != null, "Make sure all button_paths are properly assigned in the inspector")
	
	
	
	# DETECT PLATFORM
	if OS.has_feature("Windows"):
		current_platform = "Windows"
	elif OS.has_feature("OSX"):
		current_platform = "OSX"
	elif OS.has_feature("X11"):
		current_platform = "X11"
		
	
	# RESTORE UI FLAGS
	var config = Globals.read_config()
	if "ui" in config:
		stable_button.pressed = config.ui.get("stable", stable_button.pressed )
		alpha_button.pressed = config.ui.get("alpha", alpha_button.pressed )
		beta_button.pressed = config.ui.get("beta", beta_button.pressed )
		rc_button.pressed = config.ui.get("rc", rc_button.pressed )
	
	# RELOAD
	_reload()

	yield(get_tree(),"idle_frame")
	_on_autoupdate_timeout()



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
func _refresh( is_full : bool = false ):
	if is_full:
		Globals.delete_download_db()
	_reload() # in case download_db.json was modified on disk
	var new_db = download_db.duplicate(true)
	_find_links(base_url, new_db)
	
	# Check for missing downloads on already cached dirs
	var dir_cache = download_db.cache.directories.keys()
	var links_cache = download_db.cache.download_links.keys()
	for dir in dir_cache:
		var found = false
		for link in links_cache:
			if dir in link:
				found = true
				break
		if !found:
			_find_links(dir, new_db)


	# Wait for _find_links to finish
	while requests > 0:
		yield(get_tree().create_timer(1.0),"timeout")
	
	# Build download_db
	var _download_links = new_db.cache.download_links.keys()
	var _versions = []
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
		_versions.append(entry)
	
	new_db.versions = _versions
	
	# Store download_db as json
	Globals.write_download_db(new_db)
	
	emit_signal("refresh_finished", new_db)

func _is_version_directory( href: String) -> bool:
	return ( 
		href.begins_with("alpha") or
		href.begins_with("beta") or
		href.begins_with("rc") or
		href.begins_with("20200815") or # Handle 2.1.7 rc odd naming scheme
		(href[0].is_valid_integer() and href[1] == ".") # x.x.x/ etc..
		)

func _is_dir_changed( path : String, mtime) -> bool:
	return download_db.cache.directories.get(path, "") != mtime

# Analyzes a directory listing returned by lighthttpd in search of two things:
# - download links to Godot versions
# - folder links to analyze recursively
func _parsexml(buffer : PoolByteArray, partial_path : String, db: Dictionary):
	var html := HTMLObject.new()
	var err = html.load_from_buffer(buffer)
	if err != OK:
		push_error("Error parsing xml in path: %s" % partial_path)
		return

	var list : = html.all_with_name("tr").all_with_parent_name("tbody")

	for tr in list:
		var href = ""
		var mtime = ""
		var is_directory = false
		for td in tr.children:
			match td.attributes.get("class"):
				"n":
					href = td.first_child.attributes.href
				"m":
					mtime = td.first_child.value
				"t":
					is_directory = td.first_child.value == "Directory"
		
		var full_path = partial_path + href
		
		# Handle directories
		if is_directory:
			if _is_version_directory( href) and _is_dir_changed(full_path, mtime ):
				db.cache.directories[full_path] = mtime
				_find_links(full_path, db)
		# Handle files
		else:
			var suffixes = platforms[current_platform].suffixes
			for suffix in suffixes:
				if href.ends_with(suffix):
					db.cache.download_links[full_path] = true


# Gets called recursively. Fetches the next page containing a diretory
# listing from the download page and sends it to _parsexml for analysis
# output_array is passed to _parsexml to store the results
func _find_links(url:String, db : Dictionary):
	while requests > MAX_REQUESTS:
		yield(get_tree().create_timer(0.1),"timeout")
	requests += 1
	
	var req = HTTPRequest.new()
	add_child(req)
	req.request(url)
	
	refresh_button.text = "Scraping%s %s" % [ [".", "..", "..."][randi() % 3] ,url.rsplit("/",true,2)[1] ]
	
	var response = yield(req,"request_completed")
	if response[1] == 200:
		_parsexml(response[3], url, db)
		
	else:
		printerr("Error scraping link. Response code: %s" % response[1])
	
	req.queue_free()
	requests -= 1


# Recreates the drop-down menu for download options
func _update_list():
	if not download_db.has("versions"):
		return
	
	clear()
	filtered_db_view = []
	
	for entry in download_db.versions:
		if (
			(stable_included and "stable" in entry.name)
			or (rc_included and "rc" in entry.name)
			or (beta_included and "beta" in entry.name)
			or (alpha_included and "alpha" in entry.name) 
			):
			filtered_db_view.append(entry)

	for entry in filtered_db_view:
		add_item(entry.name)


func _unhandled_key_input(event):
	if refresh_button.disabled:
		return
	if event is InputEventKey and event.physical_scancode == KEY_SHIFT:
		if event.pressed:
			var warning = preload("res://theme/warning_button.tres")
			(refresh_button as Button).add_stylebox_override("normal", warning)
			(refresh_button as Button).add_stylebox_override("focus", warning)
			(refresh_button as Button).add_stylebox_override("hover", warning)
			refresh_button.text = "Full Refresh"
		else:
			(refresh_button as Button).remove_stylebox_override("normal")
			(refresh_button as Button).remove_stylebox_override("focus")
			(refresh_button as Button).remove_stylebox_override("hover")
			refresh_button.text = "Refresh"

func _on_Refresh_pressed():
	if refresh_button.disabled:
		return
	$autoupdate.stop()
	#disabled = true
	refresh_button.disabled = true
	var is_full = Input.is_key_pressed(KEY_SHIFT)
	_refresh( is_full )
	while requests > 0: 
		refresh_button.text = "Scraping %s urls%s" % [ requests, [".", "..", "..."][randi() % 3] ]
		yield(get_tree().create_timer(0.2),"timeout")
	refresh_button.text = "Refresh"
	refresh_button.disabled = false
	$autoupdate.start()
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
		exit_code = OS.execute("powershell.exe", ["-command", "\"Remove-Item '%s'\" -Force" % ProjectSettings.globalize_path(filename) ], true, output) 
		print(output.pop_front())
		print("Powershell.exe executed with exit code: %s" % exit_code)
		_add_version(_selection.name,filename.rstrip(".zip"))
	elif OS.has_feature("X11"):
		exit_code = OS.execute("unzip", ["-o", "%s" % ProjectSettings.globalize_path(filename), "-d", "%s" % ProjectSettings.globalize_path("user://versions/")], true, output)
		print(output.pop_front())
		print("unzip executed with exit code: %s" % exit_code)
		exit_code = OS.execute("rm", ["%s" % ProjectSettings.globalize_path(filename)], true, output)
		print(output.pop_front())
		print("rm executed with exit code: %s" % exit_code)
		exit_code = OS.execute("chmod", ["+x", "%s" % ProjectSettings.globalize_path(filename).rstrip(".zip") ], true, output )
		print(output.pop_front())
		print("chmod executed with exit code: %s" % exit_code)
		_add_version(_selection.name,filename.rstrip(".zip"))
	elif OS.has_feature("OSX"):
		exit_code = OS.execute("unzip", ["%s" % ProjectSettings.globalize_path(filename), "-d", "%s" % ProjectSettings.globalize_path("user://versions/")], true, output)
		print(output.pop_front())
		print("unzip executed with exit code: %s" % exit_code)
		exit_code = OS.execute("rm", ["%s" % ProjectSettings.globalize_path(filename)], true, output)
		print(output.pop_front())
		print("rm executed with exit code: %s" % exit_code)
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

func _on_Stable_toggled(button_pressed):
	stable_included = button_pressed
	Globals.update_ui_flag("stable", button_pressed)
	_update_list()



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


func _on_autoupdate_timeout():
	_on_Refresh_pressed()
