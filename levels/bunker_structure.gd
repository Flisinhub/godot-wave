class_name BunkerStructure
extends StaticBody3D

## BunkerStructure - Fortified infantry shelter providing 25% passive structural mitigation.
## Implements Requirement R2 / M6 perimeter defensive integration.

@export var max_health: float = 750.0
@export var structure_name: String = "Terran Bunker"

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var health_bar: Node = get_node_or_null("HealthBar3D")

var current_health: float = 750.0


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null


func _ready() -> void:
	add_to_group("structures")
	add_to_group("bunkers")
	current_health = max_health
	if health_bar and health_bar.has_method("setup"):
		health_bar.setup(current_health, max_health)
	_setup_visuals()


func _setup_visuals() -> void:
	if visual_root:
		var default_mesh_inst: MeshInstance3D = visual_root.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if default_mesh_inst and (default_mesh_inst.mesh == null or default_mesh_inst.mesh is BoxMesh):
			var upgraded_mesh: Mesh = load("res://assets/models/structures/bunker_structure_mesh.tres") as Mesh
			if upgraded_mesh:
				default_mesh_inst.mesh = upgraded_mesh
				default_mesh_inst.transform = Transform3D.IDENTITY
		var bunker_mesh_node: MeshInstance3D = visual_root.get_node_or_null("BunkerMesh") as MeshInstance3D
		if bunker_mesh_node and (bunker_mesh_node.mesh == null or bunker_mesh_node.mesh is BoxMesh):
			var upgraded_mesh: Mesh = load("res://assets/models/structures/bunker_structure_mesh.tres") as Mesh
			if upgraded_mesh:
				bunker_mesh_node.mesh = upgraded_mesh


func take_damage(amount: float) -> void:
	current_health = max(0.0, current_health - amount)
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)
	var bus := _get_signal_bus()
	if bus and bus.has_signal("structure_damaged"):
		bus.structure_damaged.emit(self, current_health, max_health)
	if current_health <= 0.0:
		destroy()


func destroy() -> void:
	var bus := _get_signal_bus()
	if bus and bus.has_signal("structure_destroyed"):
		bus.structure_destroyed.emit(self)
	queue_free()
