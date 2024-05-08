@tool
extends Node

@export var theme: Theme:
	set(p_theme):
		theme = p_theme
		if p_theme != null:
			theme_colors = load(str(theme.resource_path, "/../colors.tres"))
		else:
			theme_colors = null

@export var trigger_update: bool = false:
	set(v):
		update_colors()

@export var theme_colors: ThemeColors:
	set(c):
		if theme_colors != null:
			theme_colors.changed.disconnect(update_colors)
		if c != null:
			c.changed.connect(update_colors)
		
		theme_colors = c
		
		if c != null:
			update_colors()
		else:
			theme = null

func update_colors():
	var number_of_built_in_object_properties := 9
	var colors = theme_colors.get_property_list().slice(
		number_of_built_in_object_properties,
		theme_colors.get_property_list().size()
	).map(func(property):
		var theme_properties = []
		var theme_color = theme_colors[property.name]
		for p in theme_color.theme_properties:
			var type = (p as String).get_slice("_", 0)
			theme_properties.append({
				"type": type,
				"property": (p as String).trim_prefix(str(type, "_"))
			})
		return { 
			"color": theme_color.color,
			"theme_properties": theme_properties
		}
	)
	for color in colors:
		for theme_property in color.theme_properties:
			theme.set_color(
				theme_property.property,
				theme_property.type,
				color.color
			)
	
	ResourceSaver.save(theme, theme.resource_path)
