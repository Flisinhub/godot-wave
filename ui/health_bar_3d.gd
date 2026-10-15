class_name HealthBar3D
extends Node3D

## HealthBar3D - Lightweight billboard health bar using dual QuadMeshes.
## Automatically stays hidden at full health and displays with dynamic colors on damage.

@export var bar_width: float = 1.2
@export var bar_height: float = 0.14
@export var hide_at_full_health: bool = true

@onready var bg_mesh: MeshInstance3D = $Background
@onready var fill_pivot: Node3D = $FillPivot
@onready var fill_mesh: MeshInstance3D = $FillPivot/Fill

var _mat_fill: StandardMaterial3D


func _ready() -> void:
	_setup_materials()
	if hide_at_full_health:
		visible = false


func _setup_materials() -> void:
	_mat_fill = StandardMaterial3D.new()
	_mat_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_fill.no_depth_test = true
	_mat_fill.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat_fill.albedo_color = Color(0.2, 0.95, 0.25)
	
	if fill_mesh:
		fill_mesh.material_override = _mat_fill

	if bg_mesh:
		var mat_bg: StandardMaterial3D = StandardMaterial3D.new()
		mat_bg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_bg.no_depth_test = true
		mat_bg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat_bg.albedo_color = Color(0.08, 0.08, 0.1, 0.85)
		bg_mesh.material_override = mat_bg


func setup(current_hp: float, max_hp: float) -> void:
	update_health(current_hp, max_hp)


func update_health(current_hp: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		return

	var pct: float = clamp(current_hp / max_hp, 0.0, 1.0)
	
	if hide_at_full_health and is_equal_approx(pct, 1.0):
		visible = false
		return
	
	visible = true

	if fill_pivot:
		fill_pivot.scale.x = pct

	if _mat_fill:
		if pct > 0.6:
			_mat_fill.albedo_color = Color(0.2, 0.95, 0.25)
		elif pct > 0.3:
			_mat_fill.albedo_color = Color(0.95, 0.85, 0.15)
		else:
			_mat_fill.albedo_color = Color(0.95, 0.2, 0.15)
