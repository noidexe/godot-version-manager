extends OptionButton

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

# Raw list of download_urls to be sorted and used to generate donwload_db
var download_links : Array

# Used to regenerate filtered_db_view
var alpha_included = false
var beta_included = false
var rc_included = false

# base_url used for scraping
var base_url = "https://downloads.tuxfamily.org/godotengine/"

var requests = 0 # Number of concurrent http requests running
const MAX_REQUESTS = 4

onready var refresh_button = $"../Refresh"
onready var download_button = $"../Download"

signal refresh_finished()
signal version_added()

func _ready():
	_reload()

# Deserializes json version of download_db and
# calls _update_list to update display of options
func _reload():
	var file = File.new()
	if file.file_exists("user://download_db.json"):
		file.open("user://download_db.json",File.READ)
		download_db = parse_json(file.get_as_text())
		file.close()
		_update_list()

# Scrapes downloads website and regenerates
# downloads_db
func _refresh():
	download_links = []
	download_db = {
		"last_updated" : OS.get_unix_time(),
		"versions" : []
		}
	_find_links(base_url)
	
	# Wait for _find_links to finish
	while requests > 0:
		yield(get_tree().create_timer(1.0),"timeout")
	
	# Build download_db
	download_links.sort()
	download_links.invert()
	for link in download_links:
		var entry = {
			"name" : link.get_file().trim_suffix("_win64.exe.zip"),
			"path" : link
		}
		download_db.versions.append(entry)
	
	# Store download_db as json
	var file = File.new()
	file.open("user://download_db.json", File.WRITE)
	file.store_line(to_json(download_db))
	file.close()
	
	emit_signal("refresh_finished")

# Analyzes a directory listing returned by lighthttpd in search of two things:
# - download links to Godot versions
# - folder links to analyze recursively
func _parsexml(buffer : PoolByteArray, partial_path):
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
				
				# TODO: make it configurable to support other platforms
				if href.ends_with("win64.exe.zip"):
					download_links.append(partial_path + href)

				# if it is a folder that may contain downloads, recursively parse it
				elif href.ends_with("/") and (
					href.begins_with("alpha")
					or href.begins_with("beta")
					or href.begins_with("rc")
					or (href[0].is_valid_integer() and href[1] == ".") # x.x.x/ etc..
					):
					_find_links(partial_path + href)
	else:
		print("Error %s getting download info" % error)

# Gets called recursively. Fetches the next page containing a diretory
# listing from the download page and sends it to _parsexml for analysis
func _find_links(url:String):
	while requests > MAX_REQUESTS:
		yield(get_tree().create_timer(0.1),"timeout")
	requests += 1
	
	var req = HTTPRequest.new()
	add_child(req)
	req.request(url)
	
	refresh_button.text = "Scraping%s %s" % [ [".", "..", "..."][randi() % 3] ,url.rsplit("/",true,2)[1] ]
	
	var response = yield(req,"request_completed")
	if response[1] == 200:
		_parsexml(response[3], url)
	
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
	disabled = true
	_refresh()
	while requests > 0: 
		refresh_button.text = "Scraping %s urls%s" % [ requests, [".", "..", "..."][randi() % 3] ]
		yield(get_tree().create_timer(0.2),"timeout")
	refresh_button.text = "Refresh"
	disabled = false

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
	var filename =  "user://versions/" + _selection.name + "_win64.exe.zip"
	var url = _selection.path
	
	var req = HTTPRequest.new()
	add_child(req)
	req.download_file = filename
	req.request(url)
	
	while req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:	
		download_button.text = "Downloading... %d%% %d/%d" % [100.0 * req.get_downloaded_bytes() / req.get_body_size(), req.get_downloaded_bytes() / 1024, req.get_body_size() / 1024]
		yield(get_tree().create_timer(1.0),"timeout")
	
	download_button.text = "Extracting.."
	yield(get_tree(),"idle_frame")
	
	# TODO: Make this configurable for all platforms. Use tar on unix based systems
	#OS.execute(ProjectSettings.globalize_path("res://bin/7za.exe"), ["x", "-y", "-o" + ProjectSettings.globalize_path("user://versions/"), ProjectSettings.globalize_path(filename)], true, output) 
	var output = []
	OS.execute(ProjectSettings.globalize_path("powershell.exe"), ["-command", "\"Expand-Archive '%s' '%s'\"" % [ ProjectSettings.globalize_path(filename), ProjectSettings.globalize_path("user://versions/") ] ], true, output) 
	print(output)
	
	download_button.disabled = false
	download_button.text = "Download"

	_add_version(_selection.name,filename.rstrip(".zip"))

# Adds a downloaded version of Godot to the list of 
# installed versions
func _add_version(v_name : String, path: String):
	var entry = {
		"name": v_name,
		"path" : ProjectSettings.globalize_path(path), 
		"arguments" : ""
	}
	
	var file = File.new()
	
	# Read in the config
	file.open("user://config.json",File.READ)
	var config = parse_json(file.get_as_text())
	file.close()
	
	# Modify the config
	config.versions.append(entry)
	
	# Write out changes
	file.open("user://config.json",File.WRITE)
	file.store_line(to_json(config))
	file.close()
	
	emit_signal("version_added")


func _on_Alpha_toggled(button_pressed):
	alpha_included = button_pressed
	_update_list()

func _on_Beta_toggled(button_pressed):
	beta_included = button_pressed
	_update_list()

func _on_RC_toggled(button_pressed):
	rc_included = button_pressed
	_update_list()

func _on_VersionSelect_refresh_finished():
	_update_list()
