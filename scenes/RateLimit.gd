extends Label

var total : int = -1
var remaining: int = -1
var reset_time: int = -1
var retry_after: int = -1
var invalid_credentials : bool = false

onready var time_zone : int = Time.get_time_zone_from_system().bias

const text_template_normal = "Requests Remaining: %s/%s"
const text_template_exceeded = "Requests Exceeded. Try again %s"

signal rate_exceeded()

func _ready():
	hint_tooltip = (
"""
This shows how many Github API requests you have remaining.
You can get more by creating a personal access token at:
https://github.com/settings/personal-access-tokens/new
and saving it at:
%s
""" % ProjectSettings.globalize_path(Globals.GITHUB_AUTH_BEARER_TOKEN_PATH)
)

func update_info( headers : PoolStringArray):
	total = -1
	remaining = -1
	reset_time = -1
	retry_after = -1
	for header in headers:
		if "X-RateLimit-Limit:" in header:
			total = _get_value(header)
		elif "X-RateLimit-Remaining:" in header:
			remaining = _get_value(header)
			if remaining == 0:
				emit_signal("rate_exceeded")
		elif "Retry-After:" in header:
			retry_after = _get_value(header)
			print(retry_after)
		elif "X-RateLimit-Reset:" in header:
			reset_time = _get_value(header)
	_update_display()


func _get_value( string : String ) -> int:
	return int(string.split(":")[1])

func _update_display():
	var txt_reset_time : String
	if retry_after != -1:
		txt_reset_time = "in %ss" % retry_after
	else:
		txt_reset_time = "at " + _get_time_for_timezone(reset_time)
	if remaining == 0:
		text = text_template_exceeded % (retry_after if retry_after != -1 else txt_reset_time)
	else:
		text = text_template_normal % [remaining, total]
	if invalid_credentials:
		text += " ## INVALID OR EXPIRED TOKEN! ##"

func _get_time_for_timezone(time : int)-> String:
	var offset_seconds = time_zone * 60
	return Time.get_time_string_from_unix_time(time + offset_seconds)
