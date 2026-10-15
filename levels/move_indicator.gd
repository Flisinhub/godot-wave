class_name MoveIndicator
extends Node3D

## MoveIndicator - Brief visual feedback circle at right-click target location.
## Supports green for movement and red for hostile target attack orders.

@export var indicator_color: Color = Color(0.1, 1.0, 0.35, 0.9)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func set_color(color: Color) -> void:
	indicator_color = color
	if mesh_instance and mesh_instance.material_override is StandardMaterial3D:
		(mesh_instance.material_override as StandardMaterial3D).albedo_color = color


func _ready() -> void:
	scale = Vector3(0.6, 0.6, 0.6)
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = indicator_color
	mesh_instance.material_override = mat

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
