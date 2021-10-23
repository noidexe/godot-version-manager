extends OptionButton


var download_db : Dictionary
var filtered_db_view :  Array
var download_links : Array

var alpha_included = false
var beta_included = false
var rc_included = false

var base_url = "https://downloads.tuxfamily.org/godotengine/"
var searches = 0

onready var refresh_button = $"../Refresh"
onready var download_button = $"../Download"

signal refresh_finished()
signal version_added()

# Called when the node enters the scene tree for the first time.
func _ready():
	_reload()
	pass # Replace with function body.


func _reload():
	var file = File.new()
	if file.file_exists("user://download_db.json"):
		file.open("user://download_db.json",File.READ)
		download_db = parse_json(file.get_as_text())
		file.close()
		_update_list()

func _refresh():
	download_links = []
	download_db = {
		"last_updated" : OS.get_unix_time(),
		"versions" : []
		}
	_find_links(base_url)
	while searches > 0:
		yield(get_tree().create_timer(1.0),"timeout")
	
	
	download_links.sort()
	for link in download_links:
		var entry = {
			"name" : link.get_file().trim_suffix("_win64.exe.zip"),
			"path" : link
		}
		download_db.versions.append(entry)
	
	var file = File.new()
	file.open("user://download_db.json", File.WRITE)
	file.store_line(to_json(download_db))
	file.close()
	emit_signal("refresh_finished")

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
			if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "a":
				var href = xml.get_named_attribute_value_safe("href")
				if href.ends_with("win64.exe.zip"):
					download_links.append(partial_path + href)
				elif (
					href.begins_with("alpha")
					or href.begins_with("beta")
					or href.begins_with("rc")
					or ( href.ends_with("/") and href[0].is_valid_integer() and href[1] == ".")
					):
					_find_links(partial_path + href)
	else:
		print("Error %s getting download info" % error)


#func _find_links(url:String):
#	searches += 1
#	while($req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED):
#		yield($req,"request_completed")
#	$req.request(url, [], false)
#	var response = yield($req,"request_completed")
#	if response[1] == 200:
#		_parsexml(response[3], url)
#	searches -= 1
	
func _find_links(url:String):
	while searches > 4: #four connections max
		yield(get_tree().create_timer(0.1),"timeout")
	searches += 1
	var req = HTTPRequest.new()
	add_child(req)
	req.request(url, [], false)
	refresh_button.text = "Scraping%s %s" % [ [".", "..", "..."][randi() % 3] ,url.rsplit("/",true,2)[1] ]
	var response = yield(req,"request_completed")
	if response[1] == 200:
		_parsexml(response[3], url)
	searches -= 1
	req.queue_free()
	
	

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
	while searches > 0: 
		refresh_button.text = "Scraping %s urls%s" % [ searches, [".", "..", "..."][randi() % 3] ]
		yield(get_tree().create_timer(0.2),"timeout")
	refresh_button.text = "Refresh"
	disabled = false
	_update_list()
	


func _on_Download_pressed():
	if selected != -1:
		var _selection = filtered_db_view[selected]
		download_button.disabled = true
		var filename =  "user://versions/" + _selection.name + "_win64.exe.zip"
		var url = _selection.path
		var req = HTTPRequest.new()
		add_child(req)
		req.download_file = filename
		req.request(url)
		while req.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:	
			download_button.text = "Downloading... %d%% %d/%d" % [100.0 * req.get_downloaded_bytes() / req.get_body_size(), req.get_downloaded_bytes() / 1024, req.get_body_size() / 1024]
			yield(get_tree().create_timer(1.0),"timeout")
		#yield(req,"request_completed")
		download_button.text = "Extracting.."
		yield(get_tree(),"idle_frame")
		var output = []
		#OS.execute(ProjectSettings.globalize_path("res://bin/7za.exe"), ["x", "-y", "-o" + ProjectSettings.globalize_path("user://versions/"), ProjectSettings.globalize_path(filename)], true, output) 
		OS.execute(ProjectSettings.globalize_path("powershell.exe"), ["-command", "\"Expand-Archive '%s' '%s'\"" % [ ProjectSettings.globalize_path(filename), ProjectSettings.globalize_path("user://versions/") ] ], true, output) 
		print(output)
		download_button.disabled = false
		download_button.text = "Download"
		_add_version(_selection.name,filename.rstrip(".zip"))
	pass # Replace with function body.

func _add_version(v_name : String, path: String):
	var entry = {
		"name": v_name,
		"path" : ProjectSettings.globalize_path(path), 
		"arguments" : ""
	}
	var file = File.new()
	file.open("user://config.json",File.READ)
	var config = parse_json(file.get_as_text())
	config.versions.append(entry)
	file.close()
	file.open("user://config.json",File.WRITE)
	file.store_line(to_json(config))
	file.close()
	emit_signal("version_added")


func _on_Alpha_toggled(button_pressed):
	alpha_included = button_pressed
	_update_list()
	pass # Replace with function body.


func _on_Beta_toggled(button_pressed):
	beta_included = button_pressed
	_update_list()
	pass # Replace with function body.


func _on_RC_toggled(button_pressed):
	rc_included = button_pressed
	_update_list()
	pass # Replace with function body.
