class_name BaseUnit3D
extends CharacterBody3D

## BaseUnit3D - Standard RTS Unit with Navigation, RVO Avoidance & Micromanagement Support

@export var unit_data: UnitData

@onready var visual_root: Node3D = $VisualRoot
@onready var selection_ring: MeshInstance3D = $VisualRoot/SelectionRing
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var current_health: float = 45.0
var max_health: float = 45.0
var move_speed: float = 5.0
var is_selected: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group("allies")
	
	if unit_data:
		max_health = unit_data.max_health
		current_health = max_health
		move_speed = unit_data.move_speed
	
	if selection_ring:
		selection_ring.visible = false
	
	# Configure navigation agent for responsive RTS movement and RVO local avoidance
	if nav_agent:
		nav_agent.path_desired_distance = 0.6
		nav_agent.target_desired_distance = 0.5
		nav_agent.path_max_distance = 4.0
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 0.45
		nav_agent.max_speed = move_speed
		nav_agent.velocity_computed.connect(_on_navigation_agent_3d_velocity_computed)


func _physics_process(delta: float) -> void:
	# Gravity handling
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if not nav_agent or nav_agent.is_navigation_finished():
		if nav_agent and nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector3.ZERO)
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 8.0)
		move_and_slide()
		return

	var current_pos: Vector3 = global_position
	var next_path_pos: Vector3 = nav_agent.get_next_path_position()
	var move_dir: Vector3 = (next_path_pos - current_pos)
	move_dir.y = 0.0

	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		var intended_velocity: Vector3 = move_dir * move_speed
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(intended_velocity)
		else:
			_apply_movement_velocity(intended_velocity, delta)
	else:
		if nav_agent.avoidance_enabled:
			nav_agent.set_velocity(Vector3.ZERO)
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 8.0)
		move_and_slide()


func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	if not is_instance_valid(self):
		return
	_apply_movement_velocity(safe_velocity, get_physics_process_delta_time())


func _apply_movement_velocity(vel: Vector3, delta: float) -> void:
	if vel.length_squared() > 0.01:
		var target_angle_y: float = atan2(-vel.x, -vel.z)
		rotation.y = lerp_angle(rotation.y, target_angle_y, delta * 12.0)
	
	velocity.x = vel.x
	velocity.z = vel.z
	move_and_slide()


func move_to(target_pos: Vector3) -> void:
	if nav_agent:
		target_pos.y = 0.0
		nav_agent.target_position = target_pos


func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = selected


func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	SignalBus.unit_health_changed.emit(self, current_health, max_health)
	if current_health <= 0.0:
		die()


func die() -> void:
	SignalBus.unit_died.emit(self)
	queue_free()
