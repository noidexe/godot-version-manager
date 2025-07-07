extends ScrollContainer

var news_item_scene = preload("res://scenes/NewsItem.tscn")

const NEWS_CACHE_FILE = "user://news_cache.bin"
const NEWS_ETAG_FILE = "user://news_etag.bin"
const BASE_URL = "https://godotengine.org"

const  VOID_HTML_ELEMENTS = ["area", "base", "br", "col", "command", "embed", "hr",
		"img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr"]

onready var feed_vbox = $"Feed"
onready var loading_text = $"Feed/Loading"

var refreshing = false

func _ready():
# warning-ignore:return_value_discarded
	get_tree().connect("screen_resized", self, "_on_screen_resized")
	_refresh_news()
	# Check for news every 5 minutes
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 5 * 60 # 5 minutes
	timer.connect("timeout", self, "_refresh_news")
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
	
	$req.request(BASE_URL + "/blog/", ["User-Agent: %s" % Globals.user_agent], true, HTTPClient.METHOD_HEAD)
	var head_response = yield($req,"request_completed")
	for header in head_response[2]:
		# No ETag being returned by the server as of 2023/02/15
		# Using Last-Modified instead
		if header.begins_with("Last-Modified:"):
			up_to_date = header == _get_news_etag()
			new_etag = header
			break
	
	if not up_to_date:
		
		$req.request("https://raw.githubusercontent.com/godotengine/godot-website/master/_data/authors.yml", ["User-Agent: %s" % Globals.user_agent])
		var author_response = yield($req,"request_completed")
		var author_data = author_response[3]
		var avatars = _parse_author_avatars(author_data)
		
		$req.request(BASE_URL + "/rss.json", ["User-Agent: %s" % Globals.user_agent])
		var response = yield($req,"request_completed")
		var news = _get_news(parse_json(response[3].get_string_from_utf8()), avatars)
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
		var news_item = news_item_scene.instance()
		feed_vbox.add_child(news_item)
		news_item.set_info(item)


func _get_news_cache() -> Array:
	var ret = []
	var file : File = File.new()
	if not file.file_exists(NEWS_CACHE_FILE):
		push_warning("News cache not found")
	else:
		var err = file.open(NEWS_CACHE_FILE, File.READ)
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
	var file = File.new()
	file.open(NEWS_CACHE_FILE, File.WRITE)
	file.store_var(news)
	file.close()


func _get_news_etag() -> String:
	var ret : String = ""
	var file : File = File.new()
	if not file.file_exists(NEWS_ETAG_FILE):
		push_warning("News etag not found")
	else:
		var err = file.open(NEWS_ETAG_FILE, File.READ)
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
	var file = File.new()
	file.open(NEWS_ETAG_FILE, File.WRITE)
	file.store_var(etag)
	file.close()

# which will be further parsed by _parse_news_item()
func _get_news(data, avatars) -> Array:
	var parsed_news = []
	
	if typeof(data) != TYPE_DICTIONARY:
		push_error("News data must be of type Dictionary")
		return parsed_news
	
	if not data.has("items"):
		push_error("Invalid news data")
		return parsed_news
	
	for post in data["items"]:
		if typeof(post) != TYPE_DICTIONARY:
			push_warning("Invalid news post, continuing..")
			continue

		var parsed_item = {}
		parsed_item["image"] = post.get("image", "")
		parsed_item["contents"] = _replace_html_entities( post.get("description", "") )
		parsed_item["title"] = _replace_html_entities( post.get("title", "") )
		parsed_item["author"] = post.get("dc:creator", "")
		parsed_item["avatar"] = BASE_URL + avatars.get(parsed_item["author"], "/assets/images/authors/default_avatar.svg")
		
		# Godot does not support RFC 2822 Date Parsing only ISO 8601 thus this is a small fix to remove some of the weird text from it
		var date = post.get("pubDate", "").split(" ")
		if date.size():
			date.remove(date.size() - 1)
		if date.size():
			date.remove(date.size() - 1)
		parsed_item["date"] = " ".join(date)
		parsed_item["link"] = post.get("link", "")
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


static func _replace_html_entities(string : String) -> String:
	# TODO: replace with more comprehensive implementation if necessary
	return string.replace("&#39;", "'").replace("&amp;", "&").replace("&quot;", '"')
