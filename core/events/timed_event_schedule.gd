class_name TimedEventSchedule
extends RefCounted

## TimedEventSchedule - SFE5 Deterministic Timed Events Architecture (Tasks 8.1 - 8.8).
## Coordinates match timeline, scheduled hive attacks (every 300s),
## orbital drop pods (every 45s after 120s peace phase),
## and Nydus crater awakenings across 12 fixed points.

signal drop_pod_due(pod_index: int, game_time: float)
signal scheduled_attack_warning(wave_index: int, leader_data: Dictionary, seconds_left: float)
signal scheduled_attack_due(wave_index: int, leader_data: Dictionary)
signal wave_13_completed()
signal nydus_due(crater_index: int, crater_position: Vector3, nydus_tier: Dictionary)

const DROP_POD_PEACE_TIME: float = 120.0
const DROP_POD_INTERVAL: float = 45.0
const SCHEDULED_ATTACK_INTERVAL: float = 300.0
const WAVE_13_BOSS_DIVISOR: float = 3.0

# 12 Fixed strategic crater positions across the battlefield (Task 8.2)
const CRATER_POSITIONS: Array[Vector3] = [
	Vector3(12.0, 0.0, 8.0),    # Crater 0: Eastern Trench
	Vector3(22.0, 0.0, -4.0),   # Crater 1: South-East Basin
	Vector3(-8.0, 0.0, 18.0),   # Crater 2: Northern Plateau
	Vector3(28.0, 0.0, 24.0),   # Crater 3: North-Eastern Ridge
	Vector3(6.0, 0.0, 32.0),    # Crater 4: High Perch
	Vector3(-24.0, 0.0, 12.0),  # Crater 5: Western Gateway
	Vector3(16.0, 0.0, -18.0),  # Crater 6: Sunken Ravine
	Vector3(34.0, 0.0, -8.0),   # Crater 7: Crimson Dunes
	Vector3(-6.0, 0.0, -22.0),  # Crater 8: Sulfur Crater
	Vector3(2.0, 0.0, -36.0),   # Crater 9: Southern Badlands
	Vector3(26.0, 0.0, -28.0),  # Crater 10: Hive Approach
	Vector3(-18.0, 0.0, -12.0)  # Crater 11: Shadow Hollow
]

# Canonical SFE5 wave leader sequence (Task 8.4)
const SCHEDULED_WAVE_LEADERS: Array[Dictionary] = [
	{
		"wave": 1,
		"leader_id": &"infested_general",
		"leader_name": "Infested General",
		"leader_count": 1,
		"hp": 2500.0,
		"armor": 5.0,
		"damage": 35.0,
		"escort_type": &"zergling",
		"escort_count": 8
	},
	{
		"wave": 2,
		"leader_id": &"rageling",
		"leader_name": "Rageling",
		"leader_count": 3,
		"hp": 1800.0,
		"armor": 4.0,
		"damage": 40.0,
		"escort_type": &"roach",
		"escort_count": 6
	},
	{
		"wave": 3,
		"leader_id": &"hellbringer",
		"leader_name": "Hellbringer",
		"leader_count": 5,
		"hp": 2400.0,
		"armor": 8.0,
		"damage": 55.0,
		"escort_type": &"hydralisk",
		"escort_count": 8
	},
	{
		"wave": 4,
		"leader_id": &"brood_emperor",
		"leader_name": "Brood Emperor",
		"leader_count": 7,
		"hp": 3200.0,
		"armor": 10.0,
		"damage": 70.0,
		"escort_type": &"baneling",
		"escort_count": 12
	},
	{
		"wave": 5,
		"leader_id": &"hybrid_viper",
		"leader_name": "Hybrid Viper",
		"leader_count": 9,
		"hp": 4500.0,
		"armor": 12.0,
		"damage": 85.0,
		"escort_type": &"mutalisk",
		"escort_count": 10
	},
	{
		"wave": 6,
		"leader_id": &"hybrid_lenkus",
		"leader_name": "Hybrid Lenkus",
		"leader_count": 11,
		"hp": 6000.0,
		"armor": 15.0,
		"damage": 110.0,
		"escort_type": &"ultralisk",
		"escort_count": 6
	},
	{
		"wave": 7,
		"leader_id": &"ferocious_brutes",
		"leader_name": "Ferocious Brutes",
		"leader_count": 13,
		"hp": 7500.0,
		"armor": 18.0,
		"damage": 135.0,
		"escort_type": &"aberration",
		"escort_count": 8
	}
]

var match_seed: int = 123456
var elapsed_time: float = 0.0

var next_drop_pod_time: float = DROP_POD_PEACE_TIME
var drop_pod_count: int = 0

var next_scheduled_attack_time: float = SCHEDULED_ATTACK_INTERVAL
var current_scheduled_wave: int = 1
var is_wave_13_cleared: bool = false
var boss_summon_speed_multiplier: float = 1.0

var protoss_phase_active: bool = false
var spawner_level: int = 1

# Warning thresholds for scheduled attacks in seconds
var warning_checkpoints: Array[float] = [60.0, 30.0, 10.0]
var triggered_warnings: Dictionary = {} # wave_index -> Array[float]

var _rng: RandomNumberGenerator


func _init(p_seed: int = 123456) -> void:
	match_seed = p_seed
	_rng = RandomNumberGenerator.new()
	_rng.seed = match_seed
	_reset_timeline()


func _reset_timeline() -> void:
	elapsed_time = 0.0
	next_drop_pod_time = DROP_POD_PEACE_TIME
	drop_pod_count = 0
	next_scheduled_attack_time = SCHEDULED_ATTACK_INTERVAL
	current_scheduled_wave = 1
	is_wave_13_cleared = false
	boss_summon_speed_multiplier = 1.0
	triggered_warnings.clear()


## Advances the clock by delta seconds and processes time-dependent events.
## Returns an array of triggered event descriptors for telemetry and tests.
func advance_time(delta: float) -> Array[Dictionary]:
	if delta <= 0.0:
		return []

	var events_triggered: Array[Dictionary] = []
	var previous_time: float = elapsed_time
	elapsed_time += delta

	# 1. Drop Pods (Task 8.1)
	while elapsed_time >= next_drop_pod_time:
		drop_pod_count += 1
		var pod_event := {
			"type": "drop_pod",
			"pod_index": drop_pod_count,
			"timestamp": next_drop_pod_time
		}
		events_triggered.append(pod_event)
		drop_pod_due.emit(drop_pod_count, next_drop_pod_time)
		next_drop_pod_time += DROP_POD_INTERVAL

	# 2. Scheduled Hive Attacks Warnings & Spawns (Tasks 8.3, 8.4, 8.6)
	var time_until_attack: float = next_scheduled_attack_time - elapsed_time
	var leader_data: Dictionary = get_scheduled_leader(current_scheduled_wave)

	if not triggered_warnings.has(current_scheduled_wave):
		triggered_warnings[current_scheduled_wave] = []

	var warnings_sent: Array = triggered_warnings[current_scheduled_wave]
	for wp in warning_checkpoints:
		if time_until_attack <= wp and not warnings_sent.has(wp):
			warnings_sent.append(wp)
			var warn_event := {
				"type": "scheduled_attack_warning",
				"wave": current_scheduled_wave,
				"leader": leader_data["leader_name"],
				"seconds_left": wp
			}
			events_triggered.append(warn_event)
			scheduled_attack_warning.emit(current_scheduled_wave, leader_data, wp)

	while elapsed_time >= next_scheduled_attack_time:
		var attack_event := {
			"type": "scheduled_attack",
			"wave": current_scheduled_wave,
			"leader_data": leader_data,
			"timestamp": next_scheduled_attack_time
		}
		events_triggered.append(attack_event)
		scheduled_attack_due.emit(current_scheduled_wave, leader_data)

		current_scheduled_wave += 1
		next_scheduled_attack_time += SCHEDULED_ATTACK_INTERVAL
		leader_data = get_scheduled_leader(current_scheduled_wave)

	return events_triggered


## Retrieves wave leader specifications for wave_num (Task 8.4).
## Supports canonical waves 1-7 and scales procedurally for waves 8-13+.
func get_scheduled_leader(wave_num: int) -> Dictionary:
	var base_index: int = clampi(wave_num - 1, 0, SCHEDULED_WAVE_LEADERS.size() - 1)
	var template: Dictionary = SCHEDULED_WAVE_LEADERS[base_index].duplicate()
	template["wave"] = wave_num

	# Procedural scaling beyond wave 7
	if wave_num > SCHEDULED_WAVE_LEADERS.size():
		var extra: int = wave_num - SCHEDULED_WAVE_LEADERS.size()
		template["leader_count"] = 13 + (extra * 2)
		template["hp"] = 7500.0 + (float(extra) * 2000.0)
		template["armor"] = 18.0 + (float(extra) * 3.0)
		template["damage"] = 135.0 + (float(extra) * 25.0)
		template["escort_count"] = 8 + (extra * 2)
		template["leader_name"] = "Elite Wave %d Commander" % wave_num

	return template


## Marks a scheduled attack wave cleared. Once Wave 13 is cleared,
## boss summon duration is divided by 3 (Task 8.5).
func mark_wave_cleared(wave_num: int) -> void:
	if wave_num >= 13 and not is_wave_13_cleared:
		is_wave_13_cleared = true
		boss_summon_speed_multiplier = WAVE_13_BOSS_DIVISOR
		wave_13_completed.emit()


## Resolves Nydus Worm power tier based on spawner progression (Task 8.2).
func get_nydus_tier(p_spawner_level: int = -1) -> Dictionary:
	var level: int = p_spawner_level if p_spawner_level >= 0 else spawner_level
	if level <= 2:
		return {
			"tier_id": &"minor_nydus",
			"tier_name": "Minor Nydus",
			"hp": 3500.0,
			"armor": 10.0,
			"bile_damage": 50.0,
			"minions_per_spawn": 3,
			"reward": 1500
		}
	elif level <= 4:
		return {
			"tier_id": &"standard_nydus",
			"tier_name": "Nydus Worm",
			"hp": 6000.0,
			"armor": 15.0,
			"bile_damage": 75.0,
			"minions_per_spawn": 4,
			"reward": 2500
		}
	elif level <= 6:
		return {
			"tier_id": &"greater_nydus",
			"tier_name": "Greater Nydus",
			"hp": 9000.0,
			"armor": 20.0,
			"bile_damage": 100.0,
			"minions_per_spawn": 5,
			"reward": 4000
		}
	else:
		return {
			"tier_id": &"ultra_nydus",
			"tier_name": "Ultra Nydus",
			"hp": 14000.0,
			"armor": 25.0,
			"bile_damage": 135.0,
			"minions_per_spawn": 6,
			"reward": 6500
		}


## Retrieves fixed crater position by index (0..11) (Task 8.2).
func get_crater_position(index: int) -> Vector3:
	var clamped_idx: int = posmod(index, CRATER_POSITIONS.size())
	return CRATER_POSITIONS[clamped_idx]


## Determines a pseudo-random crater for Nydus emergence deterministically by seed and step.
func pick_deterministic_crater(step_index: int) -> int:
	var temp_rng := RandomNumberGenerator.new()
	temp_rng.seed = match_seed + (step_index * 1337)
	return temp_rng.randi_range(0, CRATER_POSITIONS.size() - 1)
