class_name HellsGateZone3D
extends Area3D

## HellsGateZone3D - Spatial Event Zone for Hell's Gate Nydus Unsealing.
## Requires the simultaneous presence of at least 6 living hero units at the activation point.
## Commences a 3.0s ritual synchronization channel; if any hero leaves or dies, the ritual aborts.
## Upon completion, unseals the Hell's Gate Nydus boss entity.

signal ritual_channel_started()
signal ritual_channel_progress(progress_ratio: float)
signal ritual_channel_cancelled()
signal hells_gate_opened(nydus_boss: Node3D)

@export var required_heroes: int = 6
@export var channel_duration: float = 3.0
@export var nydus_boss_scene: PackedScene
@export var rift_spawn_point: Marker3D

var is_unsealed: bool = false
var channel_timer: float = 0.0
var active_heroes: Array[Node3D] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Allies / heroes physics layer


func _physics_process(delta: float) -> void:
	evaluate_zone(delta, get_overlapping_bodies())


func evaluate_zone(delta: float, bodies: Array) -> void:
	if is_unsealed:
		return

	active_heroes.clear()

	for body in bodies:
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			continue

		var is_hero: bool = false
		if body.is_in_group("heroes") or body.get("is_hero") == true or body.get("HEROIC") == true:
			is_hero = true
		elif body.get("unit_tags") != null:
			var tags = body.get("unit_tags")
			if tags is Array and tags.has("HEROIC"):
				is_hero = true

		if is_hero:
			var hp: float = 1.0
			if "current_health" in body:
				hp = body.current_health
			elif "current_hp" in body:
				hp = body.current_hp

			if hp > 0.0 and not active_heroes.has(body):
				active_heroes.append(body)

	if active_heroes.size() >= required_heroes:
		if channel_timer == 0.0:
			ritual_channel_started.emit()
		channel_timer += delta
		ritual_channel_progress.emit(clampf(channel_timer / channel_duration, 0.0, 1.0))

		if channel_timer >= channel_duration:
			_unseal_hells_gate()
	else:
		if channel_timer > 0.0:
			channel_timer = 0.0
			ritual_channel_cancelled.emit()


func _unseal_hells_gate() -> void:
	is_unsealed = true
	var spawn_pos: Vector3 = global_position if rift_spawn_point == null else rift_spawn_point.global_position

	var nydus_instance: Node3D = null
	if nydus_boss_scene:
		nydus_instance = nydus_boss_scene.instantiate() as Node3D
	else:
		var nydus_script = load("res://entities/enemies/boss_nydus_3d.gd")
		if nydus_script:
			nydus_instance = nydus_script.new()

	if nydus_instance:
		if get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(nydus_instance)
		else:
			add_child(nydus_instance)
		nydus_instance.global_position = spawn_pos

	hells_gate_opened.emit(nydus_instance)


func reset_gate() -> void:
	is_unsealed = false
	channel_timer = 0.0
	active_heroes.clear()


func get_active_hero_count() -> int:
	return active_heroes.size()


func get_channel_progress() -> float:
	return clampf(channel_timer / channel_duration, 0.0, 1.0)
