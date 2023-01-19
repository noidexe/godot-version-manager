extends Reference
class_name HTMLObject

const  VOID_HTML_ELEMENTS = ["area", "base", "br", "col", "command", "embed", "hr",
		"img", "input", "keygen", "link", "meta", "param", "source", "track", "wbr"]
const CacheDict = {
	"class" : {},
	"name" : {},
	"id" : {}
}

class HTMLNode:
	var parent : HTMLNode = null setget _set_parent, _get_parent
	var _parent_weakref : WeakRef
	var children := HTMLNodeList.new()
	var name : String= ""
	var type : int = -1
	var value : String= ""
	var attributes := {}
	
	func _set_parent( node : HTMLNode ):
		_parent_weakref = weakref(node)
	
	func _get_parent():
		if _parent_weakref != null and _parent_weakref.get_ref() != null:
			return _parent_weakref.get_ref()
		else:
			return HTMLNullNode.new()

class HTMLNullNode extends HTMLNode:
	func _init():
		name = "[NULL NODE]"

class HTMLNodeList:
	var list : Array = []
	var current : int
	
	func _iter_init(arg):
		current = 0
		return current < list.size()
	
	func _iter_next(arg):
		current += 1
		return current < list.size()
	
	func _iter_get(arg):
		return list[current]
	
	func append( node : HTMLNode):
		list.append(node)

	func idx( i : int ) -> HTMLNode:
		return list[i]
	
	func first() -> HTMLNode:
		if list.empty():
			push_error("Attempting to return first node in empty HTMLNodeList")
			return HTMLNullNode.new()
		else:
			return list.front()
	
	func last() -> HTMLNode:
		if list.empty():
			push_error("Attempting to return last node in empty HTMLNodeList")
			return HTMLNullNode.new()
		else:
			return list.back()

	func append_list ( node_list : HTMLNodeList ) -> void:
		list.append_array( node_list.list )


	func with_parent( parent : HTMLNode) -> HTMLNodeList:
		var ret := HTMLNodeList.new()
		for node in list:
			if node.parent == parent:
				ret.append(node)
		return ret


	func with_parent_name( parent_name : String ) -> HTMLNodeList:
		var ret := HTMLNodeList.new()
		for node in list:
			if node.parent.name == parent_name:
				ret.append(node)
		return ret


	func with_name( name : String ) -> HTMLNodeList:
		var ret := HTMLNodeList.new()
		for node in list:
			if node.name == name:
				ret.append(node)
		return ret


	func of_class( node_class : String ) -> HTMLNodeList:
		var ret := HTMLNodeList.new()
		for node in list:
			if node.attributes.get("class") == node_class:
				ret.append(node)
		return ret


	func with_id (id : String ) -> HTMLNodeList:
		var ret := HTMLNodeList.new()
		for node in list:
			if node.attributes.get("id") == id:
				ret.append(node)
		return ret

var root = null
var grouped_by : Dictionary


func load_from_buffer( buffer : PoolByteArray) -> int: # -> Error
	return load_from_text(buffer.get_string_from_utf8())

func load_from_text( file : String) -> int: # -> Error 
	file = _sanitize_cdata(file)
	
	root = null
	grouped_by = CacheDict.duplicate(true)
	
	var err = ERR_BUG
	var xml = XMLParser.new()
	err = xml.open_buffer(file.to_utf8())
	if err == OK:
		err = _parse(xml)
	return err

func _sanitize_cdata( file : String ):
	var re = RegEx.new()
	re.compile("<script.?>")
	file = re.sub(file, "<script>\n// <![CDATA[", true)
	re.compile("</script>")
	file = re.sub(file, "// ]]>\n</script>", true)
	re.compile("<style.?>")
	file = re.sub(file, "<style>\n// <![CDATA[", true)
	re.compile("</style>")
	file = re.sub(file, "// ]]>\n</style>", true)
	
	return file
	

func _parse(xml : XMLParser) -> int: # -> Error
	var err = ERR_BUG
	var stack = []
	
	while(true):
		err = xml.read()
		if err != OK:
			root = stack.pop_front()
			break
		#GET TYPE
		var type = xml.get_node_type()
		match type:
			XMLParser.NODE_ELEMENT:
				var node = HTMLNode.new()
				node.type = type
				node.name = xml.get_node_name()
				if not grouped_by.name.has(node.name):
					grouped_by.name[node.name] = HTMLNodeList.new()
				grouped_by.name[node.name].append(node)
				
				for i in xml.get_attribute_count():
					var attr_name = xml.get_attribute_name(i)
					var attr_value = xml.get_attribute_value(i)
					node.attributes[ attr_name ] = attr_value
					if attr_name in ["class", "id"]:
						if not grouped_by[attr_name].has(attr_value):
							grouped_by[attr_name][attr_value] = HTMLNodeList.new()
						grouped_by[attr_name][attr_value].append(node)

				# Add as child of parent
				if not stack.empty():
					node.parent = stack.back()
					node.parent.children.append(node)
				
				# void elements don't have a matching close tag and can't have contents
				if not (node.name in VOID_HTML_ELEMENTS or xml.is_empty()):
					stack.append(node)
			XMLParser.NODE_ELEMENT_END:
				assert(stack.back().name == xml.get_node_name())
				var node = stack.pop_back()
				if stack.empty():
					root = node
					break
			XMLParser.NODE_TEXT:
				var node = HTMLNode.new()
				node.type = type
				node.name = "#text"
				node.value = xml.get_node_data()
				
				# Add as child of parent
				if not stack.empty():
					node.parent = stack.back()
					node.parent.children.append(node)
			_:
				pass

	return err


func with_name( name : String ) -> HTMLNodeList:
	return grouped_by.name.get(name, HTMLNodeList.new())


func of_class( node_class : String ) -> HTMLNodeList:
	return grouped_by.class.get(node_class, HTMLNodeList.new())


func with_id (id : String ) -> HTMLNodeList:
	return grouped_by.id.get(id, HTMLNodeList.new())
