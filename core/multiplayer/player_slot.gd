class_name PlayerSlot
extends RefCounted

## PlayerSlot - SFE5 Multiplayer Player Abstraction (Task 13.2).
## Manages network identity, selected hero, mineral wallet, supply allocation, and ready state.

var peer_id: int = 1
var player_name: String = "Player"
var hero_id: StringName = &"marine"
var minerals: int = 12000
var supply_used: int = 1
var player_color: Color = Color(0.2, 0.6, 1.0)
var is_ready: bool = false
var is_host: bool = false
var ping_ms: int = 0


func _init(p_id: int = 1, p_name: String = "Player", p_is_host: bool = false) -> void:
	peer_id = p_id
	player_name = p_name
	is_host = p_is_host
	is_ready = p_is_host


func to_dictionary() -> Dictionary:
	return {
		"peer_id": peer_id,
		"player_name": player_name,
		"hero_id": str(hero_id),
		"minerals": minerals,
		"supply_used": supply_used,
		"color": player_color.to_html(false),
		"is_ready": is_ready,
		"is_host": is_host,
		"ping_ms": ping_ms
	}


func from_dictionary(dict: Dictionary) -> void:
	peer_id = int(dict.get("peer_id", 1))
	player_name = str(dict.get("player_name", "Player"))
	hero_id = StringName(dict.get("hero_id", "marine"))
	minerals = int(dict.get("minerals", 12000))
	supply_used = int(dict.get("supply_used", 1))
	if dict.has("color"):
		player_color = Color.from_string(str(dict["color"]), Color(0.2, 0.6, 1.0))
	is_ready = bool(dict.get("is_ready", false))
	is_host = bool(dict.get("is_host", false))
	ping_ms = int(dict.get("ping_ms", 0))
