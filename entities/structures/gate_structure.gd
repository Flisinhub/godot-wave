class_name GateStructure
extends StaticBody3D

## GateStructure - Heavy blast door that opens for allies and blocks paths when closed.
## Supports manual toggle/locking and automatic proximity detection.

enum GateState { CLOSED, OPEN }

@export var initial_state: GateState = GateState.CLOSED
@export var auto_open_for_allies: bool = true
@export var door_travel_distance: float = 3.6
@export var slide_speed: float = 8.0
@export var max_health: float = 800.0

@onready var visual_root: Node3D = $VisualRoot
@onready var door_visual: Node3D = $VisualRoot/DoorSlidingPart
@onready var door_collision: CollisionShape3D = $DoorCollisionShape
@onready var status_light_mesh: MeshInstance3D = $VisualRoot/StatusLight
@onready var proximity_area: Area3D = $ProximityArea
@onready var health_bar: HealthBar3D = $HealthBar3D

var current_state: GateState = GateState.CLOSED
var current_health: float = 800.0
var is_locked_by_player: bool = false

var _door_closed_y: float = 1.7
var _door_open_y: float = -1.9
var _target_door_y: float = 1.7
var _nearby_allies: Array[Node3D] = []

# Materials for status light
var _mat_closed: StandardMaterial3D
var _mat_open: StandardMaterial3D
var _mat_locked: StandardMaterial3D


func _ready() -> void:
	add_to_group("structures")
	add_to_group("gates")
	current_health = max_health
	if health_bar:
		health_bar.setup(current_health, max_health)

	_door_closed_y = door_visual.position.y
	_door_open_y = _door_closed_y - door_travel_distance
	
	_setup_materials()
	
	if proximity_area:
		proximity_area.body_entered.connect(_on_proximity_body_entered)
		proximity_area.body_exited.connect(_on_proximity_body_exited)

	if initial_state == GateState.OPEN:
		open_gate(false)
	else:
		close_gate(false)


func _setup_materials() -> void:
	_mat_closed = StandardMaterial3D.new()
	_mat_closed.albedo_color = Color(1.0, 0.1, 0.1)
	_mat_closed.emission_enabled = true
	_mat_closed.emission = Color(1.0, 0.15, 0.15)
	_mat_closed.emission_energy_multiplier = 2.0
	
	_mat_open = StandardMaterial3D.new()
	_mat_open.albedo_color = Color(0.1, 0.9, 0.3)
	_mat_open.emission_enabled = true
	_mat_open.emission = Color(0.1, 1.0, 0.35)
	_mat_open.emission_energy_multiplier = 2.0

	_mat_locked = StandardMaterial3D.new()
	_mat_locked.albedo_color = Color(1.0, 0.65, 0.05)
	_mat_locked.emission_enabled = true
	_mat_locked.emission = Color(1.0, 0.65, 0.1)
	_mat_locked.emission_energy_multiplier = 2.5


func _process(delta: float) -> void:
	# Clean up any freed nodes from nearby allies list
	_clean_nearby_allies()
	
	# Smoothly animate the physical door height
	if door_visual:
		if not is_equal_approx(door_visual.position.y, _target_door_y):
			door_visual.position.y = move_toward(door_visual.position.y, _target_door_y, slide_speed * delta)
			
			# If door is lowered almost fully, disable collision so units move freely
			if door_collision:
				var is_mostly_open: bool = (door_visual.position.y <= _door_open_y + 0.3)
				door_collision.disabled = is_mostly_open


func toggle_gate() -> void:
	if not is_locked_by_player:
		# Player manually locks gate in opposite state
		is_locked_by_player = true
		if current_state == GateState.CLOSED:
			open_gate(true)
		else:
			close_gate(true)
	else:
		# Unlock manual override and restore automatic behavior
		is_locked_by_player = false
		if auto_open_for_allies and not _nearby_allies.is_empty():
			open_gate(false)
		else:
			close_gate(false)
	
	_update_status_light()


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree := get_tree()
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null


func open_gate(_manual: bool = false) -> void:
	current_state = GateState.OPEN
	_target_door_y = _door_open_y
	_update_status_light()
	var bus := _get_signal_bus()
	if bus and bus.has_signal("gate_state_changed"):
		bus.gate_state_changed.emit(self, true)


func close_gate(_manual: bool = false) -> void:
	current_state = GateState.CLOSED
	_target_door_y = _door_closed_y
	if door_collision:
		door_collision.disabled = false
	_update_status_light()
	var bus := _get_signal_bus()
	if bus and bus.has_signal("gate_state_changed"):
		bus.gate_state_changed.emit(self, false)


func _update_status_light() -> void:
	if not status_light_mesh:
		return
	if is_locked_by_player and _mat_locked:
		status_light_mesh.material_override = _mat_locked
	elif current_state == GateState.OPEN and _mat_open:
		status_light_mesh.material_override = _mat_open
	elif current_state == GateState.CLOSED and _mat_closed:
		status_light_mesh.material_override = _mat_closed


func _on_proximity_body_entered(body: Node3D) -> void:
	if body.is_in_group("allies"):
		if not _nearby_allies.has(body):
			_nearby_allies.append(body)
		if not is_locked_by_player and auto_open_for_allies and current_state == GateState.CLOSED:
			open_gate(false)


func _on_proximity_body_exited(body: Node3D) -> void:
	if body.is_in_group("allies"):
		_nearby_allies.erase(body)
		if not is_locked_by_player and auto_open_for_allies and _nearby_allies.is_empty():
			close_gate(false)


func _clean_nearby_allies() -> void:
	for i in range(_nearby_allies.size() - 1, -1, -1):
		if not is_instance_valid(_nearby_allies[i]):
			_nearby_allies.remove_at(i)
	
	if not is_locked_by_player and auto_open_for_allies and _nearby_allies.is_empty() and current_state == GateState.OPEN:
		close_gate(false)


func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	if health_bar:
		health_bar.update_health(current_health, max_health)
	var bus := _get_signal_bus()
	if bus and bus.has_signal("structure_damaged"):
		bus.structure_damaged.emit(self, current_health, max_health)
	if current_health <= 0.0:
		if bus and bus.has_signal("structure_destroyed"):
			bus.structure_destroyed.emit(self)
		queue_free()
