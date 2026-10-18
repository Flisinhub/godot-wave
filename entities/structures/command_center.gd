class_name CommandCenter
extends StaticBody3D

## CommandCenter - The central HQ structure of the Terran base.
## Primary objective to protect against enemy waves.

@export var max_health: float = 2000.0
@export var structure_name: String = "Command Center"

@onready var visual_root: Node3D = $VisualRoot
@onready var health_bar: HealthBar3D = $HealthBar3D

var current_health: float = 2000.0


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null


func _ready() -> void:
	add_to_group("structures")
	current_health = max_health
	if health_bar:
		health_bar.setup(current_health, max_health)
	_setup_glb_visuals()


func _setup_glb_visuals() -> void:
	if visual_root == null:
		return
	var fortress_mesh_node: MeshInstance3D = visual_root.get_node_or_null("FortressMesh") as MeshInstance3D
	if fortress_mesh_node and (fortress_mesh_node.mesh == null or fortress_mesh_node.mesh is BoxMesh):
		var upgraded_mesh: Mesh = load("res://assets/models/structures/command_center_mesh.tres") as Mesh
		if upgraded_mesh:
			fortress_mesh_node.mesh = upgraded_mesh


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
