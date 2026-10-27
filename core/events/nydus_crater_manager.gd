class_name NydusCraterManager
extends RefCounted

## NydusCraterManager - SFE5 Nydus Worm Strategic Crater Network (Task 8.2).
## Controls 12 fixed crater positions across the battlefield.
## Emerges during Protoss phases with tier power scaling with spawner progression.

signal crater_tremor_started(crater_index: int, position: Vector3, delay: float)
signal nydus_emerged(crater_index: int, position: Vector3, nydus_data: Dictionary)
signal nydus_crater_cleared(crater_index: int, reward: int)

const TimedEventSchedule = preload("res://core/events/timed_event_schedule.gd")

var schedule: TimedEventSchedule
var is_active: bool = false
var active_nydus_craters: Dictionary = {} # crater_index -> Dictionary
var pending_tremors: Array[Dictionary] = []

var tremor_warning_time: float = 3.5


func _init(p_schedule: TimedEventSchedule = null) -> void:
	schedule = p_schedule if p_schedule else TimedEventSchedule.new()


## Activates Nydus crater network (triggered upon reaching Protoss Phase 1).
func activate_network() -> void:
	is_active = true


## Deactivates network if paused or suppressed.
func deactivate_network() -> void:
	is_active = false


## Triggers an emergence sequence at a specific crater index or pseudo-randomly.
func trigger_crater_awakening(crater_index: int, spawner_level: int = 1) -> bool:
	if not is_active:
		return false

	var idx: int = posmod(crater_index, TimedEventSchedule.CRATER_POSITIONS.size())
	if active_nydus_craters.has(idx):
		return false # Crater already occupied by live Nydus

	var pos: Vector3 = schedule.get_crater_position(idx)
	var tier_data: Dictionary = schedule.get_nydus_tier(spawner_level)

	var tremor := {
		"crater_index": idx,
		"position": pos,
		"time_left": tremor_warning_time,
		"tier_data": tier_data
	}
	pending_tremors.append(tremor)
	crater_tremor_started.emit(idx, pos, tremor_warning_time)
	return true


## Updates tremor countdowns and emerges Nydus worms.
func process_craters(delta: float) -> Array[Dictionary]:
	var emerged_list: Array[Dictionary] = []
	var remaining_tremors: Array[Dictionary] = []

	for tremor in pending_tremors:
		tremor["time_left"] -= delta
		if tremor["time_left"] <= 0.0:
			var idx: int = tremor["crater_index"]
			var pos: Vector3 = tremor["position"]
			var tier: Dictionary = tremor["tier_data"]

			active_nydus_craters[idx] = tier
			emerged_list.append(tremor)
			nydus_emerged.emit(idx, pos, tier)
		else:
			remaining_tremors.append(tremor)

	pending_tremors = remaining_tremors
	return emerged_list


## Reports destruction of a Nydus worm at crater_index.
func report_nydus_destroyed(crater_index: int) -> int:
	if active_nydus_craters.has(crater_index):
		var tier: Dictionary = active_nydus_craters[crater_index]
		var reward: int = tier.get("reward", 1500)
		active_nydus_craters.erase(crater_index)
		nydus_crater_cleared.emit(crater_index, reward)
		return reward
	return 0


## Checks if a crater is currently active.
func is_crater_occupied(crater_index: int) -> bool:
	return active_nydus_craters.has(crater_index)
