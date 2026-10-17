class_name StructureDamageVFX
extends Node3D

## StructureDamageVFX - Pre-attached visual deterioration effects for Terran defensive structures.
## Provides progressive smoke, sparks, and flame emitters triggered by health degradation
## (< 70% light smoke, < 35% heavy smoke, electrical sparks, and fire).
## Listens to SignalBus.structure_damaged and monitors parent structure health.
## 100% headless-safe: prevents GPU particle emissions in headless test runner.

@export var smoke_offset: Vector3 = Vector3(0.0, 1.5, 0.0)
@export var fire_offset: Vector3 = Vector3(0.0, 0.8, 0.0)

var smoke_particles: GPUParticles3D
var sparks_particles: GPUParticles3D
var fire_particles: GPUParticles3D

var _is_headless: bool = false
var _parent_structure: Node = null


func _ready() -> void:
	_is_headless = DisplayServer.get_name() == "headless"
	var p: Node = get_parent()
	while p != null and not (p is StaticBody3D):
		p = p.get_parent()
	_parent_structure = p if p != null else get_parent()
	_create_emitters()
	_connect_signals()

	# Check initial state if already damaged
	if _parent_structure:
		var cur_hp: float = _parent_structure.get("current_health") if "current_health" in _parent_structure else 100.0
		var max_hp: float = _parent_structure.get("max_health") if "max_health" in _parent_structure else 100.0
		update_damage_state(cur_hp, max_hp)


func _create_emitters() -> void:
	# 1. Dark Charcoal Smoke Emitter
	smoke_particles = GPUParticles3D.new()
	smoke_particles.name = "SmokeParticles"
	smoke_particles.emitting = false
	smoke_particles.amount = 16
	smoke_particles.lifetime = 1.4
	smoke_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke_particles.position = smoke_offset
	add_child(smoke_particles)

	# 2. Electrical Sparks Emitter
	sparks_particles = GPUParticles3D.new()
	sparks_particles.name = "SparksParticles"
	sparks_particles.emitting = false
	sparks_particles.amount = 12
	sparks_particles.lifetime = 0.5
	sparks_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparks_particles.position = fire_offset
	add_child(sparks_particles)

	# 3. Structural Fire / Flames Emitter
	fire_particles = GPUParticles3D.new()
	fire_particles.name = "FireParticles"
	fire_particles.emitting = false
	fire_particles.amount = 14
	fire_particles.lifetime = 0.75
	fire_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire_particles.position = fire_offset
	add_child(fire_particles)

	if not _is_headless:
		_setup_particle_materials()


func _setup_particle_materials() -> void:
	# Smoke Process Material
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0.0, 1.0, 0.0)
	smoke_mat.spread = 35.0
	smoke_mat.initial_velocity_min = 0.8
	smoke_mat.initial_velocity_max = 1.8
	smoke_mat.gravity = Vector3(0.0, 0.4, 0.0)
	smoke_mat.color = Color(0.18, 0.18, 0.20, 0.55)
	smoke_mat.scale_min = 0.8
	smoke_mat.scale_max = 2.2
	smoke_particles.process_material = smoke_mat

	var smoke_draw := SphereMesh.new()
	smoke_draw.radius = 0.25
	smoke_draw.height = 0.5
	var smoke_draw_mat := StandardMaterial3D.new()
	smoke_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_draw_mat.albedo_color = Color(0.2, 0.2, 0.22, 0.4)
	smoke_draw.material = smoke_draw_mat
	smoke_particles.draw_pass_1 = smoke_draw

	# Sparks Process Material
	var sparks_mat := ParticleProcessMaterial.new()
	sparks_mat.direction = Vector3(0.0, 1.0, 0.0)
	sparks_mat.spread = 80.0
	sparks_mat.initial_velocity_min = 3.0
	sparks_mat.initial_velocity_max = 6.0
	sparks_mat.gravity = Vector3(0.0, -9.8, 0.0)
	sparks_mat.color = Color(1.0, 0.85, 0.35, 1.0)
	sparks_mat.scale_min = 0.4
	sparks_mat.scale_max = 0.8
	sparks_particles.process_material = sparks_mat

	var sparks_draw := BoxMesh.new()
	sparks_draw.size = Vector3(0.05, 0.05, 0.05)
	var sparks_draw_mat := StandardMaterial3D.new()
	sparks_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparks_draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sparks_draw_mat.albedo_color = Color(1.0, 0.9, 0.4, 1.0)
	sparks_draw.material = sparks_draw_mat
	sparks_particles.draw_pass_1 = sparks_draw

	# Fire Process Material
	var fire_mat := ParticleProcessMaterial.new()
	fire_mat.direction = Vector3(0.0, 1.0, 0.0)
	fire_mat.spread = 25.0
	fire_mat.initial_velocity_min = 1.0
	fire_mat.initial_velocity_max = 2.4
	fire_mat.gravity = Vector3(0.0, 1.2, 0.0)
	fire_mat.color = Color(1.0, 0.45, 0.12, 0.9)
	fire_mat.scale_min = 0.6
	fire_mat.scale_max = 1.4
	fire_particles.process_material = fire_mat

	var fire_draw := SphereMesh.new()
	fire_draw.radius = 0.18
	fire_draw.height = 0.36
	var fire_draw_mat := StandardMaterial3D.new()
	fire_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_draw_mat.albedo_color = Color(1.0, 0.45, 0.12, 0.85)
	fire_draw.material = fire_draw_mat
	fire_particles.draw_pass_1 = fire_draw


func _connect_signals() -> void:
	if not is_inside_tree():
		return
	if Engine.has_singleton("SignalBus"):
		var sb: Node = Engine.get_singleton("SignalBus")
		if sb and sb.has_signal("structure_damaged"):
			sb.connect("structure_damaged", _on_structure_damaged)
	elif ResourceLoader.exists("res://core/signal_bus.gd"):
		var root = get_tree().root if get_tree() else null
		if root and root.has_node("SignalBus"):
			var sb: Node = root.get_node("SignalBus")
			if sb and sb.has_signal("structure_damaged"):
				sb.connect("structure_damaged", _on_structure_damaged)


func _on_structure_damaged(structure: Node, current_hp: float, max_hp: float) -> void:
	if structure == _parent_structure or structure == owner:
		update_damage_state(current_hp, max_hp)


## Evaluates structure health and updates emitter activation states.
func update_damage_state(current_hp: float, max_hp: float) -> void:
	var ratio: float = current_hp / maxf(1.0, max_hp)

	if ratio > 0.70:
		# Pristine or light superficial wear: all emitters dormant
		if smoke_particles:
			smoke_particles.emitting = false
		if sparks_particles:
			sparks_particles.emitting = false
		if fire_particles:
			fire_particles.emitting = false
	elif ratio > 0.35:
		# Moderate damage (< 70%): light rising smoke
		if smoke_particles:
			smoke_particles.emitting = not _is_headless
		if sparks_particles:
			sparks_particles.emitting = false
		if fire_particles:
			fire_particles.emitting = false
	else:
		# Critical damage (< 35%): heavy smoke, electrical sparks, and open fire
		if smoke_particles:
			smoke_particles.emitting = not _is_headless
		if sparks_particles:
			sparks_particles.emitting = not _is_headless
		if fire_particles:
			fire_particles.emitting = not _is_headless


## Returns true if smoke emitter is actively emitting (or flagged active).
func is_smoke_active() -> bool:
	return smoke_particles != null and smoke_particles.emitting


## Returns true if fire emitter is actively emitting (or flagged active).
func is_fire_active() -> bool:
	return fire_particles != null and fire_particles.emitting


## Returns true if sparks emitter is actively emitting (or flagged active).
func is_sparks_active() -> bool:
	return sparks_particles != null and sparks_particles.emitting
