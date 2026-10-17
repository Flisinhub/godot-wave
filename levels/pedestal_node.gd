class_name PedestalNode
extends Area3D

## PedestalNode - Interactive spatial pedestal for the 8-pedestal puzzle.
## Emits pedestal_stepped when an allied hero or unit enters the area.

signal pedestal_stepped()

@export var pedestal_id: int = 0
@export var is_active: bool = false

@onready var visual_mesh: MeshInstance3D = get_node_or_null("VisualMesh")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Allies & Heroes layer
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("allies") or body.is_in_group("heroes"):
		pedestal_stepped.emit()


func set_active_state(active: bool) -> void:
	is_active = active
	if visual_mesh and visual_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = visual_mesh.material_override as StandardMaterial3D
		mat.emission_enabled = active
