class_name BossOmegaUltralisk3D
extends CharacterBody3D

## BossOmegaUltralisk3D - Secret Boss Entity spawned by SecretBossZone3D.
## Features massive durability, flat armor mitigation, cleaving melee strikes,
## an AoE Seismic Stomp ability, and a 2-Phase Enrage state below 50% HP.

signal boss_phase_changed(phase_number: int)
signal boss_ability_used(ability_name: StringName)
signal boss_died()

@export var max_health: float = 5000.0
@export var flat_armor: float = 15.0
@export var move_speed: float = 4.8
@export var attack_damage: float = 65.0
@export var cleave_radius: float = 4.5
@export var attack_cooldown: float = 1.2
@export var stomp_cooldown: float = 8.0
@export var stomp_damage: float = 120.0
@export var stomp_radius: float = 7.0
@export var kill_reward: int = 1500

var current_health: float = 5000.0
var current_phase: int = 1
var is_enraged: bool = false
var current_target: Node3D = null

var _attack_timer: float = 0.0
var _stomp_timer: float = 4.0
var _target_search_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	add_to_group("secret_boss")

	current_health = max_health
	_setup_visual_proxy()
	_find_best_target()


func _setup_visual_proxy() -> void:
	if has_node("VisualRoot"):
		return

	# Programmatic visual representation for standalone runtime & headless test compatibility
	var root := Node3D.new()
	root.name = "VisualRoot"
	add_child(root)

	if DisplayServer.get_name() != "headless":
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "BodyMesh"
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(3.5, 3.0, 4.5)
		mesh_instance.mesh = box_mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.08, 0.12) # Deep crimson
		mat.metallic = 0.4
		mat.roughness = 0.6
		mesh_instance.material_override = mat
		root.add_child(mesh_instance)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_attack_timer = max(0.0, _attack_timer - delta)
	_stomp_timer = max(0.0, _stomp_timer - delta)

	# Periodic target acquisition
	_target_search_timer -= delta
	if _target_search_timer <= 0.0:
		_target_search_timer = 0.5
		_find_best_target()

	# Ability: Seismic Stomp
	if _stomp_timer <= 0.0 and is_instance_valid(current_target):
		var dist_to_target: float = global_position.distance_to(current_target.global_position)
		if dist_to_target <= stomp_radius:
			_perform_seismic_stomp()
			return

	if not is_instance_valid(current_target):
		_stop_movement(delta)
		return

	var dist: float = global_position.distance_to(current_target.global_position)
	if dist <= cleave_radius:
		_stop_movement(delta)
		_look_at_target(current_target.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_perform_cleave_attack()
	else:
		_navigate_towards(current_target.global_position, delta)


func _navigate_towards(target_pos: Vector3, delta: float) -> void:
	var dir: Vector3 = (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_look_at_target(target_pos, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


func _stop_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 6.0)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 6.0)
	move_and_slide()


func _look_at_target(target_pos: Vector3, delta: float) -> void:
	var dir: Vector3 = (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		var target_angle_y: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle_y, delta * 8.0)


func _perform_cleave_attack() -> void:
	boss_ability_used.emit(&"cleave_strike")

	# Cleave damage to all allies in front sector
	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and ally is Node3D:
			var d: float = global_position.distance_to(ally.global_position)
			if d <= cleave_radius:
				if ally.has_method("take_damage"):
					ally.take_damage(attack_damage)


func _perform_seismic_stomp() -> void:
	_stomp_timer = stomp_cooldown
	boss_ability_used.emit(&"seismic_stomp")

	# AoE spell damage to all nearby allies
	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and ally is Node3D:
			var d: float = global_position.distance_to(ally.global_position)
			if d <= stomp_radius:
				if ally.has_method("take_damage"):
					ally.take_damage(stomp_damage)


func take_damage(amount: float) -> void:
	# Flat armor applies to incoming damage
	var mitigated: float = max(1.0, amount - flat_armor)
	current_health = max(0.0, current_health - mitigated)

	# Phase 2 Enrage transition at 50% HP
	if not is_enraged and current_health <= max_health * 0.5:
		_enter_enrage_phase()

	if current_health <= 0.0:
		die()


func _enter_enrage_phase() -> void:
	is_enraged = true
	current_phase = 2
	move_speed *= 1.3
	attack_damage *= 1.25
	attack_cooldown *= 0.75
	boss_phase_changed.emit(2)


func _find_best_target() -> void:
	# Priority 1: Heroes
	var heroes: Array[Node] = get_tree().get_nodes_in_group("heroes")
	var nearest: Node3D = null
	var min_dist: float = 25.0

	for h in heroes:
		if is_instance_valid(h) and h is Node3D:
			var d: float = global_position.distance_to(h.global_position)
			if d < min_dist:
				min_dist = d
				nearest = h as Node3D

	if nearest:
		current_target = nearest
		return

	# Priority 2: General allies
	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	min_dist = INF
	for a in allies:
		if is_instance_valid(a) and a is Node3D:
			var d: float = global_position.distance_to(a.global_position)
			if d < min_dist:
				min_dist = d
				nearest = a as Node3D

	current_target = nearest


func die() -> void:
	boss_died.emit()
	if SignalBus.has_signal("enemy_died"):
		SignalBus.enemy_died.emit(self, kill_reward)
	queue_free()
