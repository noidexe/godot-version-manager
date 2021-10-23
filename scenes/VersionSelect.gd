extends OptionButton


var download_db : Dictionary
var download_links : Array

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
	download_db = {
		"last_updated" : OS.get_unix_time(),
		"versions" : []
		}
	_find_links(base_url)
	while searches > 0:
		yield(get_tree().create_timer(1.0),"timeout")
	
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
				print("Error %s reading XML" % err)
				break
			if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "a":
				var href = xml.get_named_attribute_value_safe("href")
				if href.ends_with("win64.exe.zip"):
					var entry = {
						"name" : href.trim_suffix("_win64.exe.zip"),
						"path" : partial_path + href
					}
					download_db.versions.append(entry)
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
	var response = yield(req,"request_completed")
	if response[1] == 200:
		_parsexml(response[3], url)
	searches -= 1
	req.queue_free()
	
	

func _update_list():
	clear()
	for entry in download_db.versions:
		add_item(entry.name)


func _on_Refresh_pressed():
	disabled = true
	_refresh()
	while searches > 0: 
		refresh_button.text = "Downloading (%s remaining)" % searches
		yield(get_tree().create_timer(0.2),"timeout")
	refresh_button.text = "Refresh"
	disabled = false
	_update_list()
	pass # Replace with function body.


func _on_Download_pressed():
	if selected != -1:
		download_button.disabled = true
		var filename =  "user://versions/" + download_db.versions[selected].name + "_win64.exe.zip"
		var url = download_db.versions[selected].path
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
		_add_version(download_db.versions[selected].name,filename.rstrip(".zip"))
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
