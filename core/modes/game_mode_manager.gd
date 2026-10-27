class_name GameModeManager
extends RefCounted

## GameModeManager - SFE5 Mode System & Feature Flags (Tasks 11.1 - 11.7).
## Enforces mode-specific mutators: Classic, Hardcore, Nightmare, Torment, Split Income, 10-Player, Mutation, and Debug.

const ModeData = preload("res://core/data/mode_data.gd")

signal mode_applied(mode_id: StringName, mode_title: String)
signal nightmare_level_updated(level: int, wave_in_cycle: int)
signal debug_command_executed(cmd: String, args: Array)

# Canonical 10-wave cyclical pattern for Nightmare endgame (Task 11.5)
const NIGHTMARE_CYCLE_TYPES: Array[String] = [
	"Terrestre",
	"Terrestre",
	"Aérea",
	"Terrestre Invisible",
	"Élite",
	"Terrestre",
	"Terrestre",
	"Aérea Invisible",
	"Terrestre",
	"Jefe de Ciclo"
]

var active_mode: ModeData = null
var current_mode_id: StringName = &"classic"

# Feature Flags
var allow_buff_purchase: bool = true
var allow_protoss_phases: bool = true
var allow_bonus_events: bool = true
var allow_standard_heroes: bool = true
var is_split_income: bool = false
var is_hardcore: bool = false
var is_nightmare: bool = false
var is_permadeath: bool = false
var max_players_allowed: int = 6

# Nightmare State (Tasks 11.5, 11.6)
var nightmare_current_wave: int = 1
var nightmare_level: int = 1
var base_coordinates: Vector3 = Vector3(-45.0, 0.0, 45.0)

# Mutation Settings (Task 11.3)
var mutation_enemy_health_mult: float = 1.0
var mutation_enemy_damage_mult: float = 1.0
var mutation_spawner_cadence_mult: float = 1.0
var mutation_mineral_bounty_mult: float = 1.0


func _init(p_mode: ModeData = null) -> void:
	if p_mode != null:
		apply_mode(p_mode)
	else:
		_apply_classic_defaults()


func _apply_classic_defaults() -> void:
	current_mode_id = &"classic"
	allow_buff_purchase = true
	allow_protoss_phases = true
	allow_bonus_events = true
	allow_standard_heroes = true
	is_split_income = false
	is_hardcore = false
	is_nightmare = false
	is_permadeath = false
	max_players_allowed = 6
	base_coordinates = Vector3(-45.0, 0.0, 45.0)


## Configures and applies feature flags based on ModeData resource (Task 11.1).
func apply_mode(mode: ModeData) -> void:
	active_mode = mode
	current_mode_id = mode.id

	# Defaults
	_apply_classic_defaults()
	current_mode_id = mode.id
	is_split_income = mode.split_income
	max_players_allowed = mode.max_players

	match mode.id:
		&"hardcore":
			# Task 11.4: 12 starting elites, no buffs, no Protoss, no bonus events
			is_hardcore = true
			allow_buff_purchase = false
			allow_protoss_phases = false
			allow_bonus_events = false
			allow_standard_heroes = false
		&"nightmare":
			# Task 11.5: Central base, radiation barrier, infinite cycles
			is_nightmare = true
			base_coordinates = Vector3(0.0, 0.0, 0.0)
			nightmare_current_wave = 1
			nightmare_level = 1
		&"torment":
			is_permadeath = true
		&"split_income":
			is_split_income = true
		&"ten_player":
			max_players_allowed = 10
		&"mutation":
			# Handled via custom mutator multipliers
			pass

	mode_applied.emit(current_mode_id, mode.mode_name)


## Returns the 12 initial elite units roster for Hardcore mode (Task 11.4):
## 4 Terran (2 Marine Elite, 2 Marauder Elite),
## 4 Protoss (2 Zealot Elite, 2 Stalker Elite),
## 4 Zerg (2 Zergling Elite, 2 Roach Elite).
func get_hardcore_starting_roster() -> Array[Dictionary]:
	return [
		{"type": &"marine", "race": "terran", "is_elite": true, "count": 2},
		{"type": &"marauder", "race": "terran", "is_elite": true, "count": 2},
		{"type": &"zealot", "race": "protoss", "is_elite": true, "count": 2},
		{"type": &"stalker", "race": "protoss", "is_elite": true, "count": 2},
		{"type": &"zergling", "race": "zerg", "is_elite": true, "count": 2},
		{"type": &"roach", "race": "zerg", "is_elite": true, "count": 2}
	]


## Advances a Nightmare wave and returns the wave composition descriptor (Task 11.5, 11.6).
func advance_nightmare_wave() -> Dictionary:
	nightmare_current_wave += 1
	var wave_in_cycle: int = (nightmare_current_wave - 1) % NIGHTMARE_CYCLE_TYPES.size()
	nightmare_level = 1 + int((nightmare_current_wave - 1) / NIGHTMARE_CYCLE_TYPES.size())

	var type_name: String = NIGHTMARE_CYCLE_TYPES[wave_in_cycle]
	nightmare_level_updated.emit(nightmare_level, wave_in_cycle + 1)

	return {
		"wave_number": nightmare_current_wave,
		"level": nightmare_level,
		"cycle_slot": wave_in_cycle + 1,
		"type": type_name,
		"is_boss_wave": (wave_in_cycle == 9)
	}
