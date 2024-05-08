extends PanelContainer

var news_item_scene = preload("res://scenes/NewsItem.tscn")

const NEWS_CACHE_FILE = "user://news_cache.bin"
const NEWS_ETAG_FILE = "user://news_etag.bin"
const BASE_URL = "https://godotengine.org"

const  VOID_HTML_ELEMENTS = ["area", "base", "br", "col", "command", "embed", "hr",
		"img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr"]

@onready var feed_vbox = $"Scroll/Feed"
@onready var loading_text = $"Scroll/Feed/Loading"
@onready var req = $"Scroll/req"

var refreshing = false

func _ready():
# warning-ignore:return_value_discarded
	get_window().size_changed.connect(_on_screen_resized)
	_refresh_news()
	# Check for news every 5 minutes
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 5 * 60 # 5 minutes
	timer.connect("timeout", Callable(self, "_refresh_news"))
	timer.start()
	

# Updates display of news
func _refresh_news():
	if refreshing:
		return
	refreshing = true
	loading_text.show()
	_update_news_feed(_get_news_cache())
	
	var up_to_date := false
	var new_etag := "" 
	
	req.request(BASE_URL + "/blog/", ["User-Agent: %s" % Globals.user_agent], HTTPClient.METHOD_HEAD)
	var head_response = await req.request_completed
	for header in head_response[2]:
		# No ETag being returned by the server as of 2023/02/15
		# Using Last-Modified instead
		if header.begins_with("Last-Modified:"):
			up_to_date = header == _get_news_etag()
			new_etag = header
			break
	
	if not up_to_date:
		
		req.request("https://raw.githubusercontent.com/godotengine/godot-website/master/_data/authors.yml", ["User-Agent: %s" % Globals.user_agent])
		var author_response = await req.request_completed
		var author_data = author_response[3]
		var avatars = _parse_author_avatars(author_data)
		
		req.request(BASE_URL + "/rss.json", ["User-Agent: %s" % Globals.user_agent])
		var response = await req.request_completed
		var data = JSON.parse_string(response[3].get_string_from_utf8())
		var news = _get_news(data, avatars)
		_save_news_cache(news)
		_save_news_etag(new_etag)
		_update_news_feed(news)
	
	loading_text.hide()
	refreshing = false


# Generates text bases on an array of dictionaries containing strings to 
# interpolate
func _update_news_feed(feed : Array):
	var old_news = feed_vbox.get_children()
	for i in range(2,old_news.size()):
		old_news[i].queue_free()
	for item in feed:
		var news_item = news_item_scene.instantiate()
		feed_vbox.add_child(news_item)
		news_item.set_info(item)


func _get_news_cache() -> Array:
	var ret = []
	var file
	if not FileAccess.file_exists(NEWS_CACHE_FILE):
		push_warning("News cache not found")
	else:
		file = FileAccess.open(NEWS_CACHE_FILE, FileAccess.READ)
		var err = FileAccess.get_open_error()
		if err != OK:
			push_error("Error opening file")
		else:
			var data = file.get_var()
			if typeof(data) == TYPE_ARRAY:
				ret = data
			else:
				push_error("News cache format invalid")
			file.close()
	return ret


func _save_news_cache(news : Array):
	var file
	file = FileAccess.open(NEWS_CACHE_FILE, FileAccess.WRITE)
	file.store_var(news)
	file.close()


func _get_news_etag() -> String:
	var ret : String = ""
	var file
	if not FileAccess.file_exists(NEWS_ETAG_FILE):
		push_warning("News etag not found")
	else:
		file = FileAccess.open(NEWS_ETAG_FILE, FileAccess.READ)
		var err = FileAccess.get_open_error()
		if err != OK:
			push_error("Error opening file")
		else:
			var data = file.get_var()
			if typeof(data) == TYPE_STRING:
				ret = data
			else:
				push_error("News etag format invalid")
			file.close()
	return ret


func _save_news_etag(etag : String):
	var file = FileAccess.open(NEWS_ETAG_FILE, FileAccess.WRITE)
	file.store_var(etag)
	file.close()

# which will be further parsed by _parse_news_item()
func _get_news(data, avatars) -> Array:
	var parsed_news = []

	for post in data["items"]:
		var parsed_item = {}
		parsed_item["image"] = post["image"]
		parsed_item["contents"] = post["description"].replace("&#39;", "'").replace("&amp;", "&") # manually parse some html entieties. Parsing them all would probably be overkill
		parsed_item["title"] = post["title"]
		parsed_item["author"] = post["dc:creator"]
		parsed_item["avatar"] = BASE_URL + avatars[post["dc:creator"]]
		
		# Godot does not support RFC 2822 Date Parsing only ISO 8601 thus this is a small fix to remove some of the weird text from it
		var date = post["pubDate"].split(" ")
		date.remove_at(date.size() - 1)
		date.remove_at(date.size() - 1)
		parsed_item["date"] = " ".join(date)
		parsed_item["link"] = post["link"]
		parsed_news.append(parsed_item)
	return parsed_news

# parses YAML data from the Author list 
func _parse_author_avatars(raw_data): 
	var data = raw_data.get_string_from_utf8().split("\n")
	var avatars: Dictionary = {}
	var author = ""
	for idx in range(0, data.size()):
		if data[idx].begins_with("- name: "): 
			author = data[idx].trim_prefix("- name: ")
			# yaml strings can be wrapped in single, double or no quotes
			if author.begins_with('"') and author.ends_with('"'):
				author = author.trim_prefix('"').trim_suffix('"')
			elif author.begins_with("'") and author.ends_with("'"):
				author = author.trim_prefix("'").trim_suffix("'")
		elif data[idx].begins_with("  image: "):
			avatars[author] = data[idx].trim_prefix("  image: ")
			author = ""
	return avatars

func _on_screen_resized():
	visible = get_viewport_rect().size.x > 1100
