class_name BaseEnemy3D
extends CharacterBody3D

## BaseEnemy3D - Swarm enemy unit with autonomous target finding, wall-breaching, and RVO avoidance.

@export var enemy_data: EnemyData

@onready var visual_root: Node3D = $VisualRoot
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_bar: HealthBar3D = $HealthBar3D
@onready var body_mesh: MeshInstance3D = $VisualRoot/BodyMesh
@onready var accent_mesh: MeshInstance3D = $VisualRoot/SpinesMesh

var current_health: float = 35.0
var max_health: float = 35.0
var move_speed: float = 7.2
var attack_damage: float = 5.0
var attack_range: float = 1.6
var attack_cooldown: float = 0.5
var kill_reward: int = 5

var current_target: Node3D = null
var _target_search_timer: float = 0.0
var _attack_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var acid_splash_scene: PackedScene = preload("res://entities/enemies/acid_splash_3d.tscn")


func _ready() -> void:
	add_to_group("enemies")
	
	if enemy_data:
		max_health = enemy_data.max_health
		current_health = max_health
		move_speed = enemy_data.move_speed
		attack_damage = enemy_data.attack_damage
		attack_range = enemy_data.attack_range
		attack_cooldown = enemy_data.attack_cooldown
		kill_reward = enemy_data.kill_reward
		
		if visual_root:
			visual_root.scale = enemy_data.mesh_scale
		
		_apply_enemy_materials()

	if health_bar:
		health_bar.setup(current_health, max_health)

	if nav_agent:
		nav_agent.path_desired_distance = 0.6
		nav_agent.target_desired_distance = 0.5
		nav_agent.path_max_distance = 4.0
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.45
		nav_agent.max_speed = move_speed
		nav_agent.velocity_computed.connect(_on_navigation_agent_3d_velocity_computed)

	_find_best_target()


func _apply_enemy_materials() -> void:
	if not enemy_data:
		return
		
	if body_mesh:
		var mat_body: StandardMaterial3D = StandardMaterial3D.new()
		mat_body.albedo_color = enemy_data.body_color
		mat_body.metallic = 0.2
		mat_body.roughness = 0.7
		body_mesh.material_override = mat_body
		
	if accent_mesh:
		var mat_accent: StandardMaterial3D = StandardMaterial3D.new()
		mat_accent.albedo_color = enemy_data.accent_color
		mat_accent.emission_enabled = true
		mat_accent.emission = enemy_data.accent_color
		mat_accent.emission_energy_multiplier = 2.0
		accent_mesh.material_override = mat_accent


func _physics_process(delta: float) -> void:
	# Gravity handling
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_attack_timer = max(0.0, _attack_timer - delta)
	
	# Periodic target search
	_target_search_timer -= delta
	if _target_search_timer <= 0.0:
		_target_search_timer = 0.25
		_find_best_target()

	if not is_instance_valid(current_target):
		_stop_movement(delta)
		return

	var dist_to_target: float = global_position.distance_to(current_target.global_position)
	
	# Check if within attack range of target
	if dist_to_target <= attack_range + 0.5:
		_stop_movement(delta)
		_look_at_target(current_target.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_perform_attack(current_target)
		return

	# Check if blocked by a nearby defensive wall or gate
	var blocking_structure: Node3D = _get_nearby_blocking_structure()
	if blocking_structure:
		_stop_movement(delta)
		_look_at_target(blocking_structure.global_position, delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_perform_attack(blocking_structure)
		return

	# Navigate towards target
	if nav_agent:
		nav_agent.target_position = current_target.global_position
		
		if not nav_agent.is_navigation_finished():
			var next_pos: Vector3 = nav_agent.get_next_path_position()
			var move_dir: Vector3 = (next_pos - global_position)
			move_dir.y = 0.0
			
			if move_dir.length_squared() > 0.001:
				move_dir = move_dir.normalized()
				var intended_velocity: Vector3 = move_dir * move_speed
				nav_agent.set_velocity(intended_velocity)
			else:
				nav_agent.set_velocity(Vector3.ZERO)
		else:
			_stop_movement(delta)


func _look_at_target(target_pos: Vector3, delta: float) -> void:
	var dir: Vector3 = (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		var target_angle_y: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle_y, delta * 14.0)


func _stop_movement(delta: float) -> void:
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(Vector3.ZERO)
	velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 8.0)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 8.0)
	move_and_slide()


func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	if not is_instance_valid(self):
		return
	if safe_velocity.length_squared() > 0.01:
		var target_angle_y: float = atan2(-safe_velocity.x, -safe_velocity.z)
		rotation.y = lerp_angle(rotation.y, target_angle_y, get_physics_process_delta_time() * 12.0)
	
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()


func _perform_attack(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
		
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
	
	# Attack lunge animation
	if visual_root:
		var original_z: float = visual_root.position.z
		var tween: Tween = create_tween()
		tween.tween_property(visual_root, "position:z", original_z - 0.4, 0.08)
		tween.tween_property(visual_root, "position:z", original_z, 0.12)


func _find_best_target() -> void:
	# Priority 1: Nearest living ally within 10 meters
	var allies: Array[Node] = get_tree().get_nodes_in_group("allies")
	var nearest_ally: Node3D = null
	var min_ally_dist: float = 10.0
	
	for node in allies:
		if node is Node3D and is_instance_valid(node):
			var dist: float = global_position.distance_to(node.global_position)
			if dist < min_ally_dist:
				min_ally_dist = dist
				nearest_ally = node as Node3D

	if nearest_ally:
		current_target = nearest_ally
		return

	# Priority 2: Command Center or closest base structure
	var structures: Array[Node] = get_tree().get_nodes_in_group("structures")
	var nearest_structure: Node3D = null
	var min_struct_dist: float = INF
	
	# Look for CommandCenter first if within broad awareness
	for node in structures:
		if node is CommandCenter and is_instance_valid(node):
			nearest_structure = node as Node3D
			break

	if not nearest_structure:
		for node in structures:
			if node is Node3D and is_instance_valid(node):
				var dist: float = global_position.distance_to(node.global_position)
				if dist < min_struct_dist:
					min_struct_dist = dist
					nearest_structure = node as Node3D

	current_target = nearest_structure


func _get_nearby_blocking_structure() -> Node3D:
	var structures: Array[Node] = get_tree().get_nodes_in_group("structures")
	for node in structures:
		if node is Node3D and is_instance_valid(node):
			var dist: float = global_position.distance_to(node.global_position)
			if dist < 2.5:
				return node as Node3D
	return null


func apply_slow(ratio: float, duration: float = 2.0) -> void:
	var orig_speed := move_speed
	move_speed = maxf(0.5, move_speed * (1.0 - ratio))
	if is_inside_tree():
		var timer := get_tree().create_timer(duration)
		timer.timeout.connect(func():
			if is_instance_valid(self):
				move_speed = orig_speed
		)


func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	if health_bar:
		health_bar.update_health(current_health, max_health)
	if current_health <= 0.0:
		die()


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var t := get_tree()
	if t and t.root and t.root.has_node("SignalBus"):
		return t.root.get_node("SignalBus")
	return null


func die() -> void:
	if acid_splash_scene:
		var splash: Node3D = acid_splash_scene.instantiate() as Node3D
		if get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(splash)
			splash.global_position = global_position + Vector3(0.0, 0.4, 0.0)

	var bus := _get_signal_bus()
	if bus and bus.has_signal("enemy_died"):
		bus.enemy_died.emit(self, kill_reward)
	queue_free()
