class_name ArmoryTerminal
extends StaticBody3D

## ArmoryTerminal - Physical 3D Armory Base Station with Proximity Detection.
## Implements Feature 4 of SFE5 Phase 2 (Milestone M2).
## Provides a 4.0m interaction zone for Hero units, [E] prompt, and dual UI integration.

signal terminal_opened
signal terminal_closed
signal terminal_interaction_available(terminal: Node, available: bool)

const INTERACTION_RADIUS: float = 4.0

@export var interaction_radius: float = INTERACTION_RADIUS
@export var structure_name: String = "Armory Terminal"
@export var max_health: float = 1500.0

var current_health: float = 1500.0
var hero_in_range: bool = false
var is_terminal_open: bool = false
var _is_flow_field_registered: bool = false

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var interaction_zone: Area3D = get_node_or_null("InteractionZone")
@onready var prompt_root: Node3D = get_node_or_null("PromptRoot")


func _ready() -> void:
	add_to_group("structures")
	add_to_group("interactables")
	add_to_group("armory")

	current_health = max_health

	if interaction_zone == null:
		interaction_zone = get_node_or_null("InteractionArea") as Area3D

	if interaction_zone != null:
		if not interaction_zone.body_entered.is_connected(_on_body_entered):
			interaction_zone.body_entered.connect(_on_body_entered)
		if not interaction_zone.body_exited.is_connected(_on_body_exited):
			interaction_zone.body_exited.connect(_on_body_exited)
	elif is_inside_tree():
		# Create dynamic interaction zone if scene node was omitted
		_create_runtime_interaction_zone()

	if prompt_root != null:
		prompt_root.visible = false

	_register_flow_field_obstacle()


func _exit_tree() -> void:
	_unregister_flow_field_obstacle()


func _create_runtime_interaction_zone() -> void:
	var area: Area3D = Area3D.new()
	area.name = "InteractionZone"
	area.collision_layer = 0
	area.collision_mask = 2 # Detect allied / hero units on layer 2
	var col: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = interaction_radius
	cyl.height = 2.5
	col.shape = cyl
	col.position = Vector3(0.0, 1.25, 0.0)
	area.add_child(col)
	add_child(area)
	interaction_zone = area
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_E and hero_in_range:
			toggle_terminal()
			var vp: Viewport = get_viewport()
			if vp:
				vp.set_input_as_handled()


func toggle_terminal() -> void:
	if is_terminal_open:
		close_terminal()
	else:
		open_terminal()


func open_terminal() -> void:
	is_terminal_open = true
	terminal_opened.emit()


func close_terminal() -> void:
	is_terminal_open = false
	terminal_closed.emit()


func _on_body_entered(body: Node3D) -> void:
	if _is_hero_body(body):
		hero_in_range = true
		if prompt_root != null:
			prompt_root.visible = true
		terminal_interaction_available.emit(self, true)
		_notify_signal_bus_interaction(true)


func _on_body_exited(body: Node3D) -> void:
	if _is_hero_body(body):
		hero_in_range = false
		if prompt_root != null:
			prompt_root.visible = false
		if is_terminal_open:
			close_terminal()
		terminal_interaction_available.emit(self, false)
		_notify_signal_bus_interaction(false)


func _is_hero_body(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if body.is_in_group("heroes") or body.is_in_group("allies"):
		return true
	if body.get("is_hero") == true:
		return true
	var script: Variant = body.get_script()
	if script and "HeroUnit3D" in str(script):
		return true
	return false


func _notify_signal_bus_interaction(available: bool) -> void:
	var sb: Node = _get_signal_bus()
	if sb:
		if not sb.has_user_signal("terminal_interaction_available") and not sb.has_signal("terminal_interaction_available"):
			sb.add_user_signal("terminal_interaction_available", [
				{"name": "terminal", "type": TYPE_OBJECT},
				{"name": "available", "type": TYPE_BOOL}
			])
		sb.emit_signal("terminal_interaction_available", self, available)


func _register_flow_field_obstacle() -> void:
	var flow_field: Variant = _get_flow_field()
	if flow_field != null and flow_field.has_method("register_obstacle"):
		var pos: Vector3 = global_position
		var half_w: float = 1.4
		var world_min: Vector2 = Vector2(pos.x - half_w, pos.z - half_w)
		var world_max: Vector2 = Vector2(pos.x + half_w, pos.z + half_w)
		flow_field.register_obstacle(self, world_min, world_max, true, 255)
		_is_flow_field_registered = true


func _unregister_flow_field_obstacle() -> void:
	if _is_flow_field_registered:
		var flow_field: Variant = _get_flow_field()
		if flow_field != null and flow_field.has_method("unregister_obstacle"):
			flow_field.unregister_obstacle(self)
		_is_flow_field_registered = false


func _get_flow_field() -> Variant:
	if not is_inside_tree():
		return null
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene:
		var swarm_sim: Node = tree.current_scene.get_node_or_null("SwarmSimulation")
		if swarm_sim and "flow_field" in swarm_sim:
			return swarm_sim.get("flow_field")
	return null


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree and tree.root and tree.root.has_node("SignalBus"):
			return tree.root.get_node("SignalBus")
	return null
