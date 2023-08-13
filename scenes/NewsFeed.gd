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
		$req.request(BASE_URL + "/blog/", ["User-Agent: %s" % Globals.user_agent])
		var response = yield($req,"request_completed")
		var news = _get_news(response[3])
	
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



# Analyzes html for <div class="news-item"> elements
# which will be further parsed by _parse_news_item()
func _get_news(buffer) -> Array:
	var parsed_news = []
	
	var html = HTMLObject.new()
	html.load_from_buffer(buffer)
	
	var posts : HTMLObject.HTMLNodeList = html.of_class("posts").children.all_with_name("a")
	for post in posts:
		post = post as HTMLObject.HTMLNode
		var parsed_item = {}
		# LINK
		parsed_item["link"] = BASE_URL + post.attributes.get("href")
		
		# IMAGE
		var divs : HTMLObject.HTMLNodeList = post.children.with_name("article").children.all_with_name("div")
		var image_style = divs.of_class("thumbnail").attributes.get("style")
		var url_start = image_style.find("'") + 1
		var url_end = image_style.find_last("'")
		var image_url = image_style.substr(url_start,url_end - url_start)
		parsed_item["image"] = BASE_URL + image_url
		
		var content : HTMLObject.HTMLNode = divs.of_class("content")
		# CONTENTS
		parsed_item["contents"] = content.children.with_name("p").first_child.value.strip_edges()
		
		# TITLE
		parsed_item["title"] = content.children.with_name("h3").first_child.value.strip_edges()
		var info : HTMLObject.HTMLNodeList = content.children.of_class("info").children
		
		# AVATAR, AUTHOR, DATE
		for node in info:
			node = node as HTMLObject.HTMLNode
			match node.attributes.get("class"):
				"avatar":
					parsed_item["avatar"] = BASE_URL + node.attributes.get("src")
				"by":
					parsed_item["author"] = node.first_child.value.strip_edges()
				"date":
					parsed_item["date"] = node.first_child.value.strip_edges().lstrip("&nbsp;-&nbsp;")

		parsed_news.append(parsed_item)
	return parsed_news


func _on_screen_resized():
	visible = get_viewport_rect().size.x > 1100
		


# This is line by line a gdscript implementation of XMLParser::_skip_section
# the only difference is that void html elements do not increase
# tagcount
func _skip_section_handle_void_elements(xml : XMLParser ):
	if xml.is_empty():
		return
	
	var tagcount : int = 1
	
	while tagcount and xml.read() == OK:
		if (
				xml.get_node_type() == XMLParser.NODE_ELEMENT and
				!xml.is_empty() and
				!xml.get_node_name() in VOID_HTML_ELEMENTS
		):
			tagcount += 1
		elif xml.get_node_type() == XMLParser.NODE_ELEMENT_END:
			tagcount -= 1
