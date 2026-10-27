class_name GameSettings
extends RefCounted

## GameSettings - SFE5 User Preferences & Audio/Video Settings (Task 12.6).
## Stored as clean JSON in user://sfe5_settings.json for player editing and persistence.

const SETTINGS_PATH: String = "user://sfe5_settings.json"

var master_volume: float = 0.8
var sfx_volume: float = 0.8
var music_volume: float = 0.7
var voice_volume: float = 0.9

var camera_zoom_speed: float = 1.0
var edge_scroll_enabled: bool = true
var edge_scroll_margin: int = 24
var show_damage_numbers: bool = true
var developer_console_enabled: bool = true


func _init() -> void:
	load_settings()


func to_dictionary() -> Dictionary:
	return {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"voice_volume": voice_volume,
		"camera_zoom_speed": camera_zoom_speed,
		"edge_scroll_enabled": edge_scroll_enabled,
		"edge_scroll_margin": edge_scroll_margin,
		"show_damage_numbers": show_damage_numbers,
		"developer_console_enabled": developer_console_enabled
	}


func from_dictionary(dict: Dictionary) -> void:
	master_volume = float(dict.get("master_volume", 0.8))
	sfx_volume = float(dict.get("sfx_volume", 0.8))
	music_volume = float(dict.get("music_volume", 0.7))
	voice_volume = float(dict.get("voice_volume", 0.9))
	camera_zoom_speed = float(dict.get("camera_zoom_speed", 1.0))
	edge_scroll_enabled = bool(dict.get("edge_scroll_enabled", true))
	edge_scroll_margin = int(dict.get("edge_scroll_margin", 24))
	show_damage_numbers = bool(dict.get("show_damage_numbers", true))
	developer_console_enabled = bool(dict.get("developer_console_enabled", true))


func save_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if not file:
		return false
	var json_str: String = JSON.stringify(to_dictionary(), "\t")
	file.store_string(json_str)
	file.flush()
	file.close()
	return true


func load_settings() -> bool:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return false
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return false
	var json_str: String = file.get_as_text()
	file.close()

	var test_json := JSON.new()
	var err: Error = test_json.parse(json_str)
	if err == OK and test_json.data is Dictionary:
		from_dictionary(test_json.data)
		return true
	return false


func reset_to_defaults() -> void:
	master_volume = 0.8
	sfx_volume = 0.8
	music_volume = 0.7
	voice_volume = 0.9
	camera_zoom_speed = 1.0
	edge_scroll_enabled = true
	edge_scroll_margin = 24
	show_damage_numbers = true
	developer_console_enabled = true
	save_settings()
