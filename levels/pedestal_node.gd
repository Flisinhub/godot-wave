class_name PedestalNode
extends Area3D

## PedestalNode - Interactive spatial pedestal for the 8-pedestal puzzle.
## Emits pedestal_stepped when an allied hero or unit enters the area.
## Features independent StandardMaterial3D, floating Label3D, and golden oracle hints.

signal pedestal_stepped()

@export var pedestal_id: int = 0
@export var is_active: bool = false

@onready var visual_mesh: MeshInstance3D = get_node_or_null("VisualMesh")
var status_label: Label3D = null
var _hint_active: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Allies & Heroes layer
	body_entered.connect(_on_body_entered)

	if visual_mesh == null:
		visual_mesh = get_node_or_null("VisualMesh")

	# Independent StandardMaterial3D so pedestals don't share material states
	var mat := StandardMaterial3D.new()
	if visual_mesh:
		visual_mesh.material_override = mat

	# Floating 3D status label
	status_label = get_node_or_null("StatusLabel") as Label3D
	if status_label == null:
		status_label = Label3D.new()
		status_label.name = "StatusLabel"
		status_label.position = Vector3(0, 1.8, 0)
		status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		status_label.font_size = 28
		status_label.outline_size = 4
		add_child(status_label)

	_update_visuals()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("allies") or body.is_in_group("heroes"):
		pedestal_stepped.emit()


func set_active_state(active: bool) -> void:
	is_active = active
	_hint_active = false
	_update_visuals()


func _update_visuals() -> void:
	if visual_mesh and visual_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = visual_mesh.material_override as StandardMaterial3D
		if is_active:
			# Emerald Green Glow
			mat.albedo_color = Color(0.15, 1.0, 0.35)
			mat.emission_enabled = true
			mat.emission = Color(0.15, 1.0, 0.35)
			mat.emission_energy_multiplier = 3.0
		else:
			# Dim Dark Blue
			mat.albedo_color = Color(0.15, 0.22, 0.32)
			mat.emission_enabled = false
			mat.emission_energy_multiplier = 0.0

	if status_label:
		status_label.text = "[%d] %s" % [pedestal_id, "ON" if is_active else "OFF"]
		status_label.modulate = Color(0.2, 1.0, 0.4) if is_active else Color(0.5, 0.7, 0.9)


## Flashes with a bright golden glow to indicate oracle hints (Task 9.8).
func flash_hint(duration: float = 3.0) -> void:
	_hint_active = true
	if visual_mesh and visual_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = visual_mesh.material_override as StandardMaterial3D
		mat.albedo_color = Color(1.0, 0.84, 0.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.84, 0.0)
		mat.emission_energy_multiplier = 4.0

	if status_label:
		status_label.text = "[%d] ★ PISTA ★" % pedestal_id
		status_label.modulate = Color(1.0, 0.9, 0.2)

	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(duration)
		timer.timeout.connect(func():
			if is_instance_valid(self) and _hint_active:
				_hint_active = false
				_update_visuals()
		)

