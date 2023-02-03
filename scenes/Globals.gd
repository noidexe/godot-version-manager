extends Node

const CONFIG_FILE_PATH: String = "user://config.json"
const DOWNLOAD_DB_FILE_PATH: String = "user://download_db.json"

const DEFAULT_CONFIG : Dictionary = { "ui":{"alpha": false, "beta": false, "rc": false}, "versions" : [] }

# Read the config from file
func read_config() -> Dictionary:
	var file = File.new()
	
	# Initialise config file if it doesn't exist
	if not file.file_exists(CONFIG_FILE_PATH):
		write_config(DEFAULT_CONFIG)

	file.open(CONFIG_FILE_PATH,File.READ)
	var config = parse_json(file.get_as_text())
	file.close()
	return config


# Write config to file
func write_config(config: Dictionary):
	var file = File.new()

	file.open(CONFIG_FILE_PATH,File.WRITE)
	file.store_line(to_json(config))
	file.close()

# Update the ui_flag
func update_ui_flag(flag: String, switch: bool):
	var config = read_config()

	if not "ui" in config:
		# There should be a better way to define this
		config["ui"] = {"alpha": false, "beta": false, "rc": false}

	config.ui[flag] = switch
	write_config(config)

# Read the download db from file
func read_download_db() -> Dictionary:
	var file = File.new()
	var download_db
	
	
	if file.file_exists(DOWNLOAD_DB_FILE_PATH):
		file.open(DOWNLOAD_DB_FILE_PATH, File.READ)
		download_db = parse_json(file.get_as_text())
	if typeof(download_db) != TYPE_DICTIONARY:
		download_db = {}
	if not download_db.has("versions"):
		download_db["versions"] = []
	if not download_db.has("last_updated"):
		download_db["last_updated"] = 0
	if not download_db.has("cache"):
		download_db["cache"] = {}
		download_db["cache"]["directories"] = {}
		download_db["cache"]["download_links"] = {}
	file.close()
	return download_db

func write_download_db(download_db):
	var file = File.new()
	file.open(DOWNLOAD_DB_FILE_PATH, File.WRITE)
	file.store_line(to_json(download_db))
	file.close()
