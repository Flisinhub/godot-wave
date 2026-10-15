class_name BaseUnit3D
extends CharacterBody3D

## BaseUnit3D - Standard RTS Unit with Navigation, Visual Decoupling & Micromanagement Support

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
	
	# Configure navigation agent for responsive RTS movement
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = 0.5
		nav_agent.path_max_distance = 3.0


func _physics_process(delta: float) -> void:
	# Gravity handling
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if not nav_agent or nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
		move_and_slide()
		return

	var current_pos: Vector3 = global_position
	var next_path_pos: Vector3 = nav_agent.get_next_path_position()
	var move_dir: Vector3 = (next_path_pos - current_pos)
	move_dir.y = 0.0

	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		
		# Smoothly rotate on Y axis towards move direction
		var target_angle_y: float = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle_y, delta * 12.0)
		
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)

	move_and_slide()


func move_to(target_pos: Vector3) -> void:
	if nav_agent:
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
