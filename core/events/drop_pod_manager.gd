class_name DropPodManager
extends RefCounted

## DropPodManager - SFE5 Orbital Drop Pod Hazard (Task 8.1).
## Periodically targets player units caught outside the base perimeter after 120s peace time.
## Dispatches telegraph alerts, kinetic landing impact damage, and assault unit drops.

signal drop_pod_warned(target_position: Vector3, delay: float)
signal drop_pod_landed(target_position: Vector3, units_spawned: Array[Dictionary])
signal drop_pod_impact_damage(target_position: Vector3, radius: float, damage: float)

@export var base_origin: Vector3 = Vector3(-45.0, 0.0, 45.0)
@export var base_perimeter_radius: float = 28.0
@export var impact_radius: float = 4.5
@export var impact_damage: float = 75.0
@export var warning_delay: float = 2.5

var active_strikes: Array[Dictionary] = []


func _init(p_origin: Vector3 = Vector3(-45.0, 0.0, 45.0), p_radius: float = 28.0) -> void:
	base_origin = p_origin
	base_perimeter_radius = p_radius


## Checks if a 3D position is outside the defensive perimeter of the base.
func is_outside_base(position: Vector3) -> bool:
	var dist: float = position.distance_to(base_origin)
	return dist > base_perimeter_radius


## Filters a list of allied units or positions to find valid candidates outside base.
func find_valid_targets(allied_units: Array) -> Array:
	var valid: Array = []
	for unit in allied_units:
		if is_instance_valid(unit) and unit is Node3D:
			if is_outside_base(unit.global_position):
				valid.append(unit)
	return valid


## Evaluates targets and schedules a drop pod strike on a target outside the base.
## Returns true if a strike was scheduled, false if all units are safely inside base.
func request_strike(candidate_positions: Array[Vector3], rng: RandomNumberGenerator = null) -> bool:
	var valid_positions: Array[Vector3] = []
	for pos in candidate_positions:
		if is_outside_base(pos):
			valid_positions.append(pos)

	if valid_positions.is_empty():
		return false

	var target_pos: Vector3
	if rng:
		var idx: int = rng.randi_range(0, valid_positions.size() - 1)
		target_pos = valid_positions[idx]
	else:
		target_pos = valid_positions[0]

	schedule_strike(target_pos)
	return true


## Schedules an imminent drop pod strike with telegraph delay.
func schedule_strike(target_position: Vector3) -> void:
	var strike := {
		"position": target_position,
		"time_remaining": warning_delay,
		"impact_radius": impact_radius,
		"impact_damage": impact_damage
	}
	active_strikes.append(strike)
	drop_pod_warned.emit(target_position, warning_delay)


## Advances active strikes countdown and triggers landings.
func process_strikes(delta: float, targets_to_damage: Array = []) -> Array[Dictionary]:
	var landed: Array[Dictionary] = []
	var remaining: Array[Dictionary] = []

	for strike in active_strikes:
		strike["time_remaining"] -= delta
		if strike["time_remaining"] <= 0.0:
			landed.append(strike)
			_execute_landing(strike, targets_to_damage)
		else:
			remaining.append(strike)

	active_strikes = remaining
	return landed


func _execute_landing(strike: Dictionary, potential_targets: Array) -> void:
	var pos: Vector3 = strike["position"]
	var rad: float = strike["impact_radius"]
	var dmg: float = strike["impact_damage"]

	# 1. Kinetic impact signal
	drop_pod_impact_damage.emit(pos, rad, dmg)

	# 2. Damage affected units within impact radius
	for target in potential_targets:
		if is_instance_valid(target) and target is Node3D:
			if pos.distance_to(target.global_position) <= rad:
				if target.has_method("take_damage"):
					target.take_damage(dmg)

	# 3. Squad deployment payload
	var payload: Array[Dictionary] = [
		{"type": &"zergling", "count": 4, "offset": Vector3(1.5, 0.0, 0.0)},
		{"type": &"roach", "count": 2, "offset": Vector3(-1.5, 0.0, 0.0)}
	]
	drop_pod_landed.emit(pos, payload)
