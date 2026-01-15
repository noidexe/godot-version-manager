extends Node

const CONFIG_FILE_PATH: String = "user://config.json"
const DOWNLOAD_DB_FILE_PATH: String = "user://download_db.json"
const APP_ICONS_PATH: String = "user://app_icons"
const GITHUB_AUTH_BEARER_TOKEN_PATH: String = "user://github_auth_bearer_token.txt"

const DOWNLOAD_DB_VERSION = 1
const DEFAULT_CONFIG : Dictionary = { "ui":{"alpha": false, "beta": false, "rc": false}, "versions" : [] }

# Update before commiting
# Use semver
# Add '-devel' for versions not intended for release
# Remove '-devel' when commiting a build to be tagged as release
# Remember to update version in export settings before exporting
const version_tag = "v1.17.4-devel"
var user_agent : String
var github_auth_bearer_token: String = ""

func _ready():
	user_agent = "Godot Version Manager/%s (%s) Godot/%s" % [version_tag.lstrip("v"), OS.get_name(), Engine.get_version_info().string ] 
	var file = File.new()
	if file.file_exists(GITHUB_AUTH_BEARER_TOKEN_PATH):
		file.open(GITHUB_AUTH_BEARER_TOKEN_PATH, File.READ)
		github_auth_bearer_token = file.get_as_text()

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
	file.store_string(JSON.print(config, "\t"))
	file.close()

# Update the ui_flag
func update_ui_flag(flag: String, value): #switch: bool):
	var config = read_config()

	if not "ui" in config:
		# There should be a better way to define this
		config["ui"] = {"alpha": false, "beta": false, "rc": false, "dev": false, "scale": 1.0 }

	config.ui[flag] = value
	write_config(config)


# Read the download db from file
func read_download_db() -> Dictionary:
	var file = File.new()
	var download_db
	
	
	if file.file_exists(DOWNLOAD_DB_FILE_PATH):
		file.open(DOWNLOAD_DB_FILE_PATH, File.READ)
		download_db = parse_json(file.get_as_text())
	
	# TODO: more advanced validation and sanitization
	if not _is_download_db_valid(download_db):
		download_db = { "version" : DOWNLOAD_DB_VERSION }
	if not download_db.has("versions"):
		download_db["versions"] = []
	if not download_db.has("last_updated"):
		download_db["last_updated"] = 0
	if not download_db.has("cache"):
		download_db["cache"] = {}
		download_db["cache"]["download_links"] = {}
	file.close()
	return download_db

func write_download_db(download_db):
	var file = File.new()
	file.open(DOWNLOAD_DB_FILE_PATH, File.WRITE)
	file.store_line(to_json(download_db))
	file.close()

func delete_download_db():
	var err = OS.move_to_trash(ProjectSettings.globalize_path(DOWNLOAD_DB_FILE_PATH))
	if err != OK:
		print_debug(err)

func _is_download_db_valid(db) -> bool:
	# Check basic format
	if typeof(db) != TYPE_DICTIONARY:
		return false
	# Check db version
	if not db.has("version"):
		return false
	if db.version != DOWNLOAD_DB_VERSION:
		return false
	# Basic extended checks
	# if there is a versions entry it should be an array
	if db.has("versions") and typeof(db.versions) != TYPE_ARRAY:
		return false
	# if there is a cache entry it should be a dictionary
	if db.has("cache") and typeof(db.cache) != TYPE_DICTIONARY:
		return false
	return true
