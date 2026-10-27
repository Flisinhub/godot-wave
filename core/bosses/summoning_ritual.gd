class_name SummoningRitual
extends RefCounted

## SummoningRitual - SFE5 Pinnacle Boss Awakening Ritual Controller (Task 10.2).
## Encapsulates diverse ritual conditions: beacon stepping, structural building,
## zone holding, mass unit assembly, and objective destruction.

signal progress_updated(current: int, total: int, description: String)
signal ritual_fulfilled(boss_id: StringName, spawn_position: Vector3)
signal ritual_aborted(reason: String)

enum RitualType {
	BEACONS,
	STRUCTURE_BUILD,
	HOLD_POSITION,
	OBJECTIVE_DESTRUCTION,
	MASS_UNITS,
	SACRIFICE
}

var ritual_id: StringName = &"ritual"
var boss_id: StringName = &"boss"
var boss_title: String = "Pinnacle Boss"
var ritual_type: RitualType = RitualType.BEACONS

var required_count: int = 3
var current_progress: int = 0
var hold_time_required: float = 0.0
var hold_time_current: float = 0.0

var spawn_location: Vector3 = Vector3.ZERO
var is_completed: bool = false
var is_failed: bool = false
var description: String = ""


func _init(p_boss_id: StringName = &"boss", p_type: RitualType = RitualType.BEACONS, p_count: int = 3, p_spawn: Vector3 = Vector3.ZERO) -> void:
	boss_id = p_boss_id
	ritual_type = p_type
	required_count = p_count
	spawn_location = p_spawn
	current_progress = 0
	is_completed = false
	is_failed = false


## Advances the ritual progress count.
func advance_progress(amount: int = 1) -> bool:
	if is_completed or is_failed:
		return is_completed

	current_progress = mini(current_progress + amount, required_count)
	progress_updated.emit(current_progress, required_count, description)

	if current_progress >= required_count:
		is_completed = true
		ritual_fulfilled.emit(boss_id, spawn_location)
		return true

	return false


## Advances timed hold-position rituals.
func process_hold_time(delta: float, is_unit_in_zone: bool) -> bool:
	if is_completed or is_failed or hold_time_required <= 0.0:
		return is_completed

	if is_unit_in_zone:
		hold_time_current += delta
		var prog: int = int((hold_time_current / hold_time_required) * float(required_count))
		current_progress = mini(prog, required_count)
		progress_updated.emit(current_progress, required_count, "Manteniendo posición...")

		if hold_time_current >= hold_time_required:
			is_completed = true
			ritual_fulfilled.emit(boss_id, spawn_location)
			return true
	else:
		# Decay hold time if abandoned
		hold_time_current = maxf(0.0, hold_time_current - (delta * 0.5))

	return false


## Aborts or fails the ritual.
func fail_ritual(reason: String) -> void:
	if is_completed:
		return
	is_failed = true
	ritual_aborted.emit(reason)


## Resets ritual to initial state.
func reset_ritual() -> void:
	current_progress = 0
	hold_time_current = 0.0
	is_completed = false
	is_failed = false
