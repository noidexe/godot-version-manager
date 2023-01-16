extends ScrollContainer

var news_item_scene = preload("res://scenes/NewsItem.tscn")

const NEWS_CACHE_FILE = "user://news_cache.bin"
const BASE_URL = "https://godotengine.org"

const  VOID_HTML_ELEMENTS = ["area", "base", "br", "col", "command", "embed", "hr",
		"img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr"]

onready var feed_vbox = $"Feed"
onready var loading_text = $"Feed/Loading"

func _ready():
	get_tree().connect("screen_resized", self, "_on_screen_resized")
	_refresh_news()


# Updates display of news
func _refresh_news():
	loading_text.show()
	_update_news_feed(_get_news_cache())
	
	$req.request(BASE_URL + "/blog/")
	var response = yield($req,"request_completed")
	
	loading_text.hide()
	var news = _get_news(response[3])
	_save_news_cache(news)
	_update_news_feed(news)


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


# Analyzes html for <div class="news-item"> elements
# which will be further parsed by _parse_news_item()
func _get_news(buffer) -> Array:

	var xml = XMLParser.new()
	var error = xml.open_buffer(buffer)

	if error == OK:
		while(true):
			var err = xml.read()

			if err != OK:
				if err != ERR_FILE_EOF:
					print("Error %s reading XML" % err)
				break

			# Look for <div class="posts"> element
			if xml.get_node_type() == XMLParser.NODE_ELEMENT and xml.get_node_name() == "div":
				var class_attr = xml.get_named_attribute_value_safe("class")
				# Take note of the offsets from <div class="posts"> to </div>
				# to further analyze
				if "posts" in class_attr:
					var tag_open_offset = xml.get_node_offset()
					_skip_section_handle_void_elements(xml)
					var tag_close_offset = xml.get_node_offset()
					return _parse_posts(buffer, tag_open_offset, tag_close_offset)
	else:
		print("Error %s getting download info" % error)
	# return an empty array by default
	return []



func _parse_posts(buffer, begin_ofs, end_ofs):
	var parsed_news = []
	
	var xml = XMLParser.new()
	var error = xml.open_buffer(buffer)
	if error != OK:
		printerr("Error parsing news item. Error code: %s" % error)
	xml.seek(begin_ofs) # automatically does xml.read()
	while(xml.get_node_offset() != end_ofs):
		if xml.get_node_type() == XMLParser.NODE_ELEMENT:
			match xml.get_node_name():
				"a":
					var tag_open_offset = xml.get_node_offset()
					_skip_section_handle_void_elements(xml)
					var tag_close_offset = xml.get_node_offset()
					parsed_news.append(_parse_news_item(buffer, tag_open_offset, tag_close_offset))
		xml.read()
	return parsed_news


# Extract the necesary info for each news item
func _parse_news_item(buffer, begin_ofs, end_ofs):
	var parsed_item = {}
	var xml = XMLParser.new()
	var error = xml.open_buffer(buffer)
	if error != OK:
		printerr("Error parsing news item. Error code: %s" % error)
	xml.seek(begin_ofs) # automatically does xml.read()
	
	# We iterate over every node in the range specified by
	# begin_ofs and end_ofs fetching the info we care about
	# strip_edges is needed since text nodes seem to contain
	# every character as it is in the html, including
	# tabulation and leading spaces
	while(xml.get_node_offset() != end_ofs):
		if xml.get_node_type() == XMLParser.NODE_ELEMENT:
			match xml.get_node_name():
				"a":
					parsed_item["link"] = BASE_URL + xml.get_named_attribute_value_safe("href")
				"img":
					if "avatar" in xml.get_named_attribute_value_safe("class"):
						parsed_item["avatar"] = BASE_URL + xml.get_named_attribute_value_safe("src")
				"div":
					if "thumbnail" in xml.get_named_attribute_value_safe("class"):
						var image_style = xml.get_named_attribute_value_safe("style")
						var url_start = image_style.find("'") + 1
						var url_end = image_style.find_last("'")
						var image_url = image_style.substr(url_start,url_end - url_start)
						parsed_item["image"] = BASE_URL + image_url
				"h3":
					xml.read()
					parsed_item["title"] = xml.get_node_data().strip_edges() if xml.get_node_type() == XMLParser.NODE_TEXT else ""
				"h4":
					if "author" in xml.get_named_attribute_value_safe("class"):
						xml.read()
						parsed_item["author"] = xml.get_node_data().strip_edges() if xml.get_node_type() == XMLParser.NODE_TEXT else ""
				"span":
					if "date" in xml.get_named_attribute_value_safe("class"):
						xml.read()
						parsed_item["date"] = xml.get_node_data().strip_edges().lstrip("&nbsp;-&nbsp;") if xml.get_node_type() == XMLParser.NODE_TEXT else ""
					if "by" in xml.get_named_attribute_value_safe("class"):
						xml.read()
						parsed_item["author"] = xml.get_node_data().strip_edges() if xml.get_node_type() == XMLParser.NODE_TEXT else ""
				"p":
					if "excerpt" in xml.get_named_attribute_value_safe("class"):
						xml.read()
						parsed_item["contents"] = xml.get_node_data().strip_edges() if xml.get_node_type() == XMLParser.NODE_TEXT else ""
		xml.read()
		
	# Return the dictionary with the news entry once we are done
	return parsed_item
	
func _on_screen_resized():
	visible = get_viewport_rect().size.x > 1046
		


# This is line by line a gdscript implementation of XMLParser
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
