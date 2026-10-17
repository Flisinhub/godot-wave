class_name SecretBossZone3D
extends Area3D

## SecretBossZone3D - Spatial Event Zone for Secret Boss Summoning.
## Requires maintaining exactly ONE stationary ground unit inside the zone for 120 continuous seconds.
## Any violation (0 units, >1 unit, airborne unit, movement > 0.05 m/s, leaving radius)
## triggers an immediate reset to 0.0s.

signal zone_charge_started(unit: Node3D)
signal zone_charge_updated(progress_ratio: float, elapsed_seconds: float)
signal zone_charge_reset(reason: StringName)
signal secret_boss_invoked(boss_scene: PackedScene, spawn_transform: Transform3D)

enum ZoneState { IDLE, CHARGING, TRIGGERED, DISABLED }

@export var required_seconds: float = 120.0
@export var zone_radius: float = 6.0
@export var velocity_threshold: float = 0.05
@export var boss_scene: PackedScene
@export var spawn_marker: Marker3D

var current_state: ZoneState = ZoneState.IDLE
var elapsed_timer: float = 0.0
var tracked_unit: Node3D = null
var last_recorded_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	collision_layer = 0
	# Mask includes allies (2) and enemies (4) layers by default
	collision_mask = 2 | 4
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(_body: Node3D) -> void:
	# Physics process handles rigorous per-frame invariant checking
	pass


func _on_body_exited(_body: Node3D) -> void:
	pass


func _physics_process(delta: float) -> void:
	evaluate_zone(delta, get_overlapping_bodies())


func evaluate_zone(delta: float, bodies: Array) -> void:
	if current_state == ZoneState.TRIGGERED or current_state == ZoneState.DISABLED:
		return

	var ground_candidates: Array[Node3D] = []

	for body in bodies:
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue

		# Check for air tag, property, or group
		var is_air: bool = false
		if body.is_in_group("air_units") or body.get("is_air") == true:
			is_air = true
		if not is_air and body.get("unit_tags") != null:
			var tags = body.get("unit_tags")
			if tags is Array and (tags.has("AIR") or tags.has("FLYING")):
				is_air = true

		if is_air:
			_trigger_immediate_reset(&"AIR_UNIT_ENTERED")
			return

		# Alive check if health property exists
		var hp: float = 1.0
		if "current_health" in body:
			hp = body.current_health
		elif "current_hp" in body:
			hp = body.current_hp
		if hp <= 0.0:
			continue

		ground_candidates.append(body)

	# Invariant 1: Exactly one ground unit
	if ground_candidates.size() == 0:
		if current_state == ZoneState.CHARGING:
			_trigger_immediate_reset(&"ZERO_UNITS")
		return
	elif ground_candidates.size() > 1:
		_trigger_immediate_reset(&"MULTIPLE_UNITS")
		return

	var candidate: Node3D = ground_candidates[0]

	# Invariant 2: Candidate consistency
	if current_state == ZoneState.CHARGING and tracked_unit != candidate:
		_trigger_immediate_reset(&"UNIT_SUBSTITUTED")
		return

	# Invariant 3: Stationarity evaluation
	var vel: Vector3 = Vector3.ZERO
	if "velocity" in candidate:
		vel = candidate.velocity
	elif candidate.has_method("get_velocity"):
		vel = candidate.get_velocity()
	var horizontal_vel: Vector2 = Vector2(vel.x, vel.z)

	# Radius boundary check relative to zone center
	var horizontal_dist_from_center: float = Vector2(
		candidate.global_position.x - global_position.x,
		candidate.global_position.z - global_position.z
	).length()

	if horizontal_dist_from_center > zone_radius:
		_trigger_immediate_reset(&"OUTSIDE_RADIUS")
		return

	if current_state == ZoneState.IDLE:
		if horizontal_vel.length() <= velocity_threshold:
			tracked_unit = candidate
			last_recorded_position = candidate.global_position
			elapsed_timer = 0.0
			current_state = ZoneState.CHARGING
			zone_charge_started.emit(tracked_unit)
	elif current_state == ZoneState.CHARGING:
		var displacement: float = candidate.global_position.distance_to(last_recorded_position)
		if horizontal_vel.length() > velocity_threshold or (delta > 0.0 and displacement > (velocity_threshold * delta * 2.0 + 0.01)):
			_trigger_immediate_reset(&"UNIT_MOVED")
			return

		elapsed_timer += delta
		last_recorded_position = candidate.global_position
		zone_charge_updated.emit(clampf(elapsed_timer / required_seconds, 0.0, 1.0), elapsed_timer)

		if elapsed_timer >= required_seconds:
			_invoke_boss()


func _trigger_immediate_reset(reason: StringName) -> void:
	if current_state == ZoneState.CHARGING:
		elapsed_timer = 0.0
		tracked_unit = null
		current_state = ZoneState.IDLE
		zone_charge_reset.emit(reason)


func _invoke_boss() -> void:
	current_state = ZoneState.TRIGGERED
	elapsed_timer = required_seconds
	var spawn_xform: Transform3D = global_transform if spawn_marker == null else spawn_marker.global_transform
	secret_boss_invoked.emit(boss_scene, spawn_xform)

	var boss_instance: Node3D = null
	if boss_scene:
		boss_instance = boss_scene.instantiate() as Node3D
	else:
		var boss_script = load("res://entities/enemies/boss_omega_ultralisk_3d.gd")
		if boss_script:
			boss_instance = boss_script.new()

	if boss_instance:
		if get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(boss_instance)
		else:
			add_child(boss_instance)
		boss_instance.global_transform = spawn_xform


func reset_zone() -> void:
	current_state = ZoneState.IDLE
	elapsed_timer = 0.0
	tracked_unit = null


func get_elapsed_timer() -> float:
	return elapsed_timer


func get_progress_ratio() -> float:
	return clampf(elapsed_timer / required_seconds, 0.0, 1.0)
