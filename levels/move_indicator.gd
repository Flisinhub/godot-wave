class_name MoveIndicator
extends Node3D

## MoveIndicator - Brief visual feedback circle at right-click target location.

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	scale = Vector3(0.6, 0.6, 0.6)
	
	var mat: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
	if not mat:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.1, 1.0, 0.35, 0.9)
		mesh_instance.material_override = mat
	else:
		# Duplicate material to avoid tweening shared resources
		mat = mat.duplicate() as StandardMaterial3D
		mesh_instance.material_override = mat

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
