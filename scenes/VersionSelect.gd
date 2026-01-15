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
		"suffixes": ["_x11.64.zip", "_linux.64.zip", "_linux.x86_64.zip", "_x11_64.zip", "_linux_x86_64.zip"],
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
		"suffixes": ["_osx.universal.zip", "_macos.universal.zip", "_osx64.zip", "_osx.64.zip"],
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
		"suffixes": ["_win64.exe.zip", "_win64.zip"],
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
const base_url = "https://api.github.com/repos/godotengine/godot-builds/releases?per_page=%d&page=%d"

# Number of concurrent http requests running
var requests = 0

#text shown in the refresh button
var refresh_button_text = "Refreshing"

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
var dev_included = false
var mono_included = false

export var refresh_button_path : NodePath 
export var download_button_path : NodePath
export var stable_button_path : NodePath
export var alpha_button_path : NodePath
export var beta_button_path : NodePath
export var rc_button_path : NodePath
export var dev_button_path : NodePath
export var mono_button_path : NodePath
export var rate_limit_path : NodePath

onready var refresh_button = get_node(refresh_button_path)
onready var download_button = get_node(download_button_path)
onready var stable_button = get_node(stable_button_path)
onready var alpha_button = get_node(alpha_button_path)
onready var beta_button = get_node(beta_button_path)
onready var rc_button = get_node(rc_button_path)
onready var dev_button = get_node(dev_button_path)
onready var mono_button = get_node(mono_button_path)
onready var rate_limit = get_node(rate_limit_path)

signal refresh_started()
# Emitted when the download_db has been updated
signal refresh_finished()
var is_refreshing := false

signal download_started()
signal download_finished()
var is_downloading := false

# Emitted when a version is added to the list of installed versions
signal version_added() 


func _ready():
	# VALIDATE BUTTON PATHS ( Will use scene unique names when 3.5 reaches stable)
	for button in [refresh_button, download_button, stable_button, alpha_button, beta_button, rc_button, dev_button, mono_button, rate_limit]:
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
		dev_button.pressed = config.ui.get("dev", dev_button.pressed )
		mono_button.pressed = config.ui.get("mono", mono_button.pressed )
		
	
	# RELOAD
	_reload()

	yield(get_tree(),"idle_frame")
	_on_autoupdate_timeout()



# Deserializes json version of download_db and
# calls _update_list to update display of options
func _reload():
	download_db = Globals.read_download_db()
	_update_list()

const TAGS = {
	"dev" : "a",
	"alpha" : "b",
	"beta" : "c",
	"rc" : "d",
	"stable" : "e",
}
# Uses natural order sort to sort based on semver
func _version_sort(a : String, b: String):
	# Get the name of the file from the url
	# Otherwise the full url will cause naturalnocasemp_to 
	# sort incorrectly
	var a_split = a.split("/")
	var b_split = b.split("/")
	a = a_split[a_split.size()-1]
	b = b_split[b_split.size()-1]
	for tag in TAGS:
		a = a.replace(tag, TAGS[tag])
		b = b.replace(tag, TAGS[tag])
	return a.naturalnocasecmp_to(b) < 0


# Scrapes downloads website and regenerates
# downloads_db
func _refresh( is_full : bool = false ):
	emit_signal("refresh_started")
	is_refreshing = true
	if is_full:
		Globals.delete_download_db()
	_reload() # in case download_db.json was modified on disk
	
	# if last_updated is 0 it's a fresh db and we need a full refresh
	if download_db.get("last_updated", 0) <= 0:
		is_full = true
	
	var new_db = download_db.duplicate(true)
	_scrape_github(new_db, is_full)

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
	new_db["last_updated"] = OS.get_unix_time()
	
	# Store download_db as json
	Globals.write_download_db(new_db)
	
	is_refreshing = false
	emit_signal("refresh_finished", new_db)

func _is_version_directory( href: String) -> bool:
	return ( 
		href.begins_with("mono") or
		href.begins_with("alpha") or
		href.begins_with("beta") or
		href.begins_with("rc") or
		href.begins_with("dev") or # New in 4.x
		href.begins_with("20200815") or # Handle 2.1.7 rc odd naming scheme
		(href[0].is_valid_integer() and href[1] == ".") # x.x.x/ etc..
		)


func _is_link_mono_version( href: String) -> bool:
	# "/mono/" should be somewhere in the url
	if not "/mono/" in href:
		return false
	var split = href.split("/")
	# this should never happen but let's check anyways
	if split.size() < 2:
		return false
	# return whether the containing folder is named mono
	return split[-2] == "mono"


func _scrape_github_url(page: int, per_page: int, url: String):
	var req = HTTPRequest.new()
	add_child(req)

	var headers = ["User-Agent: %s" % Globals.user_agent, "Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2022-11-28"]
	if Globals.github_auth_bearer_token != "":
		headers.append("Authorization: Bearer %s" % Globals.github_auth_bearer_token)
	if url == "": 
		req.request(base_url % [per_page, page], headers )
	else:
		req.request(url, headers )

	var results = []
	var response = yield(req,"request_completed")
	if response[1] == 200:
		results = parse_json(response[3].get_string_from_utf8())
	else:
		printerr("Error scraping link. Response code: %s" % response[1])
		printerr((response[3] as PoolByteArray).get_string_from_utf8())
		
		# Reset auth_bearer_token if we got a 401. Proably expired
		if response[1] == 401:
			rate_limit.invalid_credentials = true
		# Make sure we still return data in the expected format
		results = [{ "assets" : [] }]
	rate_limit.update_info(response[2])
	req.queue_free()
	return [results, response[2], response[1]]

func _process_github(results, db: Dictionary):
	for entry in results:
		# var mtime = entry["created_at"]
		for asset in entry["assets"]:
			var full_path = asset["browser_download_url"]
			var suffixes = platforms[current_platform].suffixes
			for suffix in suffixes:
				if full_path.ends_with(suffix):
					db.cache.download_links[full_path] = true

func _get_next_github_url(string : String):
	var next : String
	var links : PoolStringArray = string.trim_prefix("Link:").split(",")
	for link in links:
		var data = link.split(";")
		if data.size() == 2 and 'rel="next"' in data[1]:
			next = data[0].lstrip(" <").rstrip(">")
	return next
	
func _scrape_github(db: Dictionary, is_full: bool):
	requests += 1

	var page = 0;
	var returns
	if is_full:
		var next_url = ""
		while true:
			page += 1
			refresh_button_text = "Collecting Releases Page %s" % page
			returns = yield(_scrape_github_url(page, 100, next_url), "completed")
			if returns[2] == 401:
				Globals.github_auth_bearer_token = ""
				printerr("Error with Authentication Token, reseting to unauthenticated requests")
				returns = yield(_scrape_github_url(page, 100, next_url), "completed")
			
			_process_github(returns[0], db)
			var nextLinkFound = false
			for header in returns[1]:
				if header.begins_with("Link:"):
					next_url = _get_next_github_url(header)
					break
			if next_url == "":
				break
	else: 
		# we cant use the "offical" releases/lastest API endpoint from github here
		# because it does not include pre-releases and thus we need to
		# fallback to the releases list with but limit it to 1 release on page 1
		refresh_button_text = "Checking for new Releases"
		returns = yield(_scrape_github_url(1, 1, ""), "completed")
		if returns[2] == 401:
			printerr("Error with Authentication Token, reseting to unauthenticated requests")
			Globals.github_auth_bearer_token = ""
			returns = yield(_scrape_github_url(1, 1, ""), "completed")

		var path = ""
		for asset in returns[0][0]["assets"]:
			var full_path = asset["browser_download_url"]
			var suffixes = platforms[current_platform].suffixes
			for suffix in suffixes:
				if full_path.ends_with(suffix):
					path = full_path
					break;
		if !db.cache.download_links.has(path):
			refresh_button_text = "Collecting Latest Releases"
			# we only want to fetch 10 releases here from page 1 to reduce network traffic if we found a release that was missing
			returns = yield(_scrape_github_url(1, 10, ""), "completed")
			_process_github(returns[0], db)
	requests -= 1

# Recreates the drop-down menu for download options
func _update_list():
	if not download_db.has("versions"):
		return
	
	clear()
	filtered_db_view = []
	
	for entry in download_db.versions:
		# Little hack to filter OLD.Godot_v3.6.2-stable*
		# Maybe a blacklist feature would make sense
		if (entry.name as String).begins_with("OLD."):
			continue
		# if mono entry should include "mono" and vice versa
		if mono_included != ("mono" in entry.name):
			continue

		if (
			(stable_included and "stable" in entry.name)
			or (rc_included and "rc" in entry.name)
			or (beta_included and "beta" in entry.name)
			or (alpha_included and "alpha" in entry.name)
			or (dev_included and "dev" in entry.name) 
			):
			filtered_db_view.append(entry)

	for entry in filtered_db_view:
		add_item(entry.name)


func _unhandled_key_input(event):
	if refresh_button.disabled:
		return
	if event is InputEventKey and event.physical_scancode == KEY_SHIFT:
		_set_full_refresh_mode(event.pressed)

func _set_full_refresh_mode(enabled : bool):
	if enabled:
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
		refresh_button.text = "%s %s" % [ refresh_button_text, [".", "..", "..."][randi() % 3] ]
		yield(get_tree().create_timer(0.2),"timeout")
	refresh_button.text = "Refresh"
	refresh_button.disabled = false
	$autoupdate.start()
	#disabled = false


# Downloads and installs the selected version
func _on_Download_pressed():
	if selected == -1:
		return false
	
	is_downloading = true
	emit_signal("download_started")
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
	req.request(url, ["User-Agent: %s" % Globals.user_agent], false)
	
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
		var run_path = filename.trim_suffix(".zip")
		if "_mono_" in filename:
			run_path += "/" + _selection.path.get_file().trim_suffix(".zip") + ".exe"
		_add_version(_selection.name,run_path)
	elif OS.has_feature("X11"):
		exit_code = OS.execute("unzip", ["-o", "%s" % ProjectSettings.globalize_path(filename), "-d", "%s" % ProjectSettings.globalize_path("user://versions/")], true, output)
		print(output.pop_front())
		print("unzip executed with exit code: %s" % exit_code)
		exit_code = OS.execute("rm", ["%s" % ProjectSettings.globalize_path(filename)], true, output)
		print(output.pop_front())
		print("rm executed with exit code: %s" % exit_code)
		var run_path = filename.trim_suffix(".zip")
		if "_mono_" in filename:
			if "v3." in filename:
				run_path += "/" + _selection.name + "_x11.64"
			elif "v4." in filename:
				run_path += "/" + _selection.name + "_linux.x86_64"
		exit_code = OS.execute("chmod", ["+x", "%s" % ProjectSettings.globalize_path(run_path) ], true, output )
		print(output.pop_front())
		print("chmod executed with exit code: %s" % exit_code)
		_add_version(_selection.name,run_path)
	elif OS.has_feature("OSX"):
		exit_code = OS.execute("unzip", ["%s" % ProjectSettings.globalize_path(filename), "-d", "%s" % ProjectSettings.globalize_path("user://versions/")], true, output)
		print(output.pop_front())
		print("unzip executed with exit code: %s" % exit_code)
		exit_code = OS.execute("rm", ["%s" % ProjectSettings.globalize_path(filename)], true, output)
		print(output.pop_front())
		print("rm executed with exit code: %s" % exit_code)
		var app_full_path = ProjectSettings.globalize_path("user://versions/") + _selection.name + ".app"
		var original_path = "user://versions/Godot_mono.app" if "_mono_" in filename else "user://versions/Godot.app"
		exit_code = OS.execute("mv", [ProjectSettings.globalize_path(original_path), app_full_path], true, output)
		print(output.pop_front())
		print("mv run with exit code: %s" % exit_code)
		_add_version(_selection.name, "user://versions/" + _selection.name + ".app")
	
	download_button.disabled = false
	download_button.text = "Download"
	
	is_downloading = false
	emit_signal("download_finished")

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
	
func _on_Dev_toggled(button_pressed):
	dev_included = button_pressed
	Globals.update_ui_flag("dev", button_pressed)
	_update_list()


func _on_Mono_toggled(button_pressed):
	mono_included = button_pressed
	Globals.update_ui_flag("mono", button_pressed)
	_update_list()


func _on_VersionSelect_refresh_finished(new_download_db : Dictionary):
	_set_full_refresh_mode(false)
	download_db = new_download_db
	_update_list()


func _on_autoupdate_timeout():
	_on_Refresh_pressed()
