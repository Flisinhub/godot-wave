class_name AcidSplash3D
extends Node3D

## AcidSplash3D - Brief ephemeral acid burst particle effect on swarm death.

func _ready() -> void:
	scale = Vector3(0.5, 0.5, 0.5)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.95, 0.25, 0.9)

	for child in get_children():
		if child is MeshInstance3D:
			child.material_override = mat

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.8, 1.8, 1.8), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
