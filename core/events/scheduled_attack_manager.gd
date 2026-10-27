class_name ScheduledAttackManager
extends RefCounted

## ScheduledAttackManager - SFE5 Scheduled Hive Assaults (Tasks 8.3, 8.4, 8.5, 8.6).
## Dispatches assault waves every 300 seconds from Hive to Player Base.
## Tracks wave leader progressions and unlocks the 3x boss summon accelerator upon wave 13 victory.

signal attack_warning_received(wave_index: int, leader_name: String, time_remaining: float, attack_direction: Vector3)
signal wave_attack_dispatched(wave_index: int, leader_data: Dictionary, spawn_origin: Vector3, destination: Vector3)
signal wave_leader_eliminated(wave_index: int, leader_name: String)
signal hive_pressure_accelerated(boss_speed_multiplier: float)

const TimedEventSchedule = preload("res://core/events/timed_event_schedule.gd")

var schedule: TimedEventSchedule
var hive_origin: Vector3 = Vector3(45.0, 0.0, -45.0)
var base_destination: Vector3 = Vector3(-45.0, 0.0, 45.0)

var active_leaders_alive: Dictionary = {} # wave_index -> int (count remaining)


func _init(p_schedule: TimedEventSchedule = null, p_hive: Vector3 = Vector3(45.0, 0.0, -45.0), p_base: Vector3 = Vector3(-45.0, 0.0, 45.0)) -> void:
	schedule = p_schedule if p_schedule else TimedEventSchedule.new()
	hive_origin = p_hive
	base_destination = p_base
	_connect_schedule_signals()


func _connect_schedule_signals() -> void:
	if not schedule.scheduled_attack_warning.is_connected(_on_attack_warning):
		schedule.scheduled_attack_warning.connect(_on_attack_warning)
	if not schedule.scheduled_attack_due.is_connected(_on_attack_due):
		schedule.scheduled_attack_due.connect(_on_attack_due)
	if not schedule.wave_13_completed.is_connected(_on_wave_13_completed):
		schedule.wave_13_completed.connect(_on_wave_13_completed)


## Calculates normalized direction vector from base towards the approaching hive attack.
func get_attack_direction() -> Vector3:
	return (hive_origin - base_destination).normalized()


func _on_attack_warning(wave_index: int, leader_data: Dictionary, seconds_left: float) -> void:
	var dir: Vector3 = get_attack_direction()
	var leader_name: String = leader_data.get("leader_name", "Unknown Leader")
	attack_warning_received.emit(wave_index, leader_name, seconds_left, dir)


func _on_attack_due(wave_index: int, leader_data: Dictionary) -> void:
	var leader_count: int = leader_data.get("leader_count", 1)
	active_leaders_alive[wave_index] = leader_count
	wave_attack_dispatched.emit(wave_index, leader_data, hive_origin, base_destination)


## Reports that a wave leader was slain by players.
func report_leader_kill(wave_index: int) -> void:
	if not active_leaders_alive.has(wave_index):
		return

	active_leaders_alive[wave_index] -= 1
	var leader_data: Dictionary = schedule.get_scheduled_leader(wave_index)
	var leader_name: String = leader_data.get("leader_name", "Leader")

	if active_leaders_alive[wave_index] <= 0:
		active_leaders_alive.erase(wave_index)
		wave_leader_eliminated.emit(wave_index, leader_name)
		schedule.mark_wave_cleared(wave_index)


func _on_wave_13_completed() -> void:
	hive_pressure_accelerated.emit(schedule.boss_summon_speed_multiplier)


## Returns time remaining until next scheduled attack.
func get_time_to_next_attack() -> float:
	return maxf(0.0, schedule.next_scheduled_attack_time - schedule.elapsed_time)
