class_name FloatingTextManager
extends Node3D

## FloatingTextManager - High-Performance 3D Combat Text Renderer for SFE5.
## Displays animated mineral gain indicators ("+5 Minerals"), damage values,
## and RPG "LEVEL UP" notifications in 3D world space.
## Completely zero-allocation in headless CI/CD mode.

static var instance: FloatingTextManager = null


func _init() -> void:
	if instance == null:
		instance = self


func _enter_tree() -> void:
	if instance == null:
		instance = self


## Spawns a billboarded floating text label that rises and fades out.
## Fully guarded for headless DisplayServer execution.
static func spawn_text(parent: Node, world_pos: Vector3, text: String, color: Color = Color.WHITE, duration: float = 0.9) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if parent == null or not is_instance_valid(parent):
		return

	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 22
	label.outline_size = 6
	label.outline_color = Color(0.02, 0.04, 0.06, 0.95)
	label.modulate = color
	label.pixel_size = 0.007
	parent.add_child(label)

	var offset_x: float = randf_range(-0.35, 0.35)
	var offset_z: float = randf_range(-0.35, 0.35)
	label.global_position = world_pos + Vector3(offset_x, 1.2, offset_z)

	var tween: Tween = label.create_tween()
	var target_y: float = label.global_position.y + 1.1
	tween.parallel().tween_property(label, "global_position:y", target_y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)
