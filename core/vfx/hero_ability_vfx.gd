class_name HeroAbilityVFX
extends RefCounted

## HeroAbilityVFX - Comprehensive Real-Time 3D Ability VFX System for SFE5
## Manages particle systems (GPUParticles3D / CPUParticles3D) and dedicated emissive shaders
## for all Hero active and ultimate abilities across Raynor, Tychus, Nova, Zeratul, Tassadar, Stetmann, and Harbinger.
## Strict headless safety: fully guarded against running GPU rendering passes or leaking nodes in CI/CD.

const SHADER_PSIONIC_STORM := preload("res://assets/shaders/vfx/psionic_storm.gdshader")
const SHADER_PLASMA_SHIELD := preload("res://assets/shaders/vfx/plasma_shield.gdshader")
const SHADER_TACTICAL_CLOAK := preload("res://assets/shaders/vfx/tactical_cloak.gdshader")
const SHADER_LASER_BEAM := preload("res://assets/shaders/vfx/laser_beam.gdshader")
const SHADER_ENERGY_MATRIX := preload("res://assets/shaders/vfx/energy_matrix.gdshader")
const SHADER_SINGULARITY_VORTEX := preload("res://assets/shaders/vfx/singularity_vortex.gdshader")
const SHADER_PSIONIC_BLADE_ARC := preload("res://assets/shaders/vfx/psionic_blade_arc.gdshader")


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


# ==============================================================================
# 1. TASSADAR: Psionic Storm & Plasma Shield
# ==============================================================================

## Spawns Psionic Storm: vortex of swirling electric psionic lightning arcs, radius 5.2m, emission 3.5.
static func spawn_psionic_storm(parent: Node, center: Vector3, radius: float = 5.2) -> Node3D:
	if is_headless() or parent == null:
		return null

	var storm_root := Node3D.new()
	storm_root.name = "VFX_PsionicStorm"
	parent.add_child(storm_root)
	storm_root.global_position = center + Vector3(0, 0.35, 0)

	# 1. Swirling Electrical Disc Mesh
	var storm_mesh := MeshInstance3D.new()
	storm_mesh.name = "StormDisc"
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	var storm_mat := ShaderMaterial.new()
	storm_mat.shader = SHADER_PSIONIC_STORM
	storm_mat.set_shader_parameter("emission_energy", 3.5)
	storm_mesh.mesh = quad
	storm_mesh.material_override = storm_mat
	storm_root.add_child(storm_mesh)

	# 2. Swirling Electric Lightning Particles (GPUParticles3D)
	var particles := GPUParticles3D.new()
	particles.name = "LightningParticles"
	particles.amount = 36
	particles.lifetime = 1.4
	particles.explosiveness = 0.1
	particles.randomness = 0.5

	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	proc_mat.emission_ring_radius = radius * 0.85
	proc_mat.emission_ring_height = 0.8
	proc_mat.direction = Vector3(0, 1, 0)
	proc_mat.spread = 45.0
	proc_mat.gravity = Vector3(0, 1.5, 0)
	proc_mat.initial_velocity_min = 1.2
	proc_mat.initial_velocity_max = 3.0
	proc_mat.color = Color(0.4, 0.7, 1.0, 0.9)
	proc_mat.scale_min = 0.6
	proc_mat.scale_max = 1.4
	particles.process_material = proc_mat

	var draw_mesh := SphereMesh.new()
	draw_mesh.radius = 0.08
	draw_mesh.height = 0.16
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw_mat.albedo_color = Color(0.5, 0.85, 1.0, 0.95)
	draw_mesh.material = draw_mat
	particles.draw_pass_1 = draw_mesh
	storm_root.add_child(particles)
	particles.emitting = true

	# Lifetime & cleanup
	var tw: Tween = storm_root.create_tween()
	tw.tween_interval(2.5)
	tw.parallel().tween_property(storm_mesh, "scale", Vector3(1.1, 1.1, 1.1), 0.5)
	tw.parallel().tween_property(storm_mat, "shader_parameter/emission_energy", 0.0, 0.5)
	tw.tween_callback(storm_root.queue_free)

	return storm_root


## Spawns Plasma Shield: luminous hexagonal energy dome, emission 2.8.
static func spawn_plasma_shield(target: Node3D, duration: float = 3.5) -> Node3D:
	if is_headless() or target == null:
		return null

	var shield_dome := MeshInstance3D.new()
	shield_dome.name = "VFX_PlasmaShieldDome"
	var sphere := SphereMesh.new()
	sphere.radius = 1.25
	sphere.height = 2.5
	sphere.radial_segments = 24
	sphere.rings = 16

	var shield_mat := ShaderMaterial.new()
	shield_mat.shader = SHADER_PLASMA_SHIELD
	shield_mat.set_shader_parameter("emission_energy", 2.8)
	shield_dome.mesh = sphere
	shield_dome.material_override = shield_mat
	target.add_child(shield_dome)
	shield_dome.position = Vector3(0, 1.1, 0)
	shield_dome.scale = Vector3(0.2, 0.2, 0.2)

	# Initial activation expansion
	var tw: Tween = shield_dome.create_tween()
	tw.tween_property(shield_dome, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration - 0.5)
	tw.tween_property(shield_mat, "shader_parameter/emission_energy", 0.0, 0.3)
	tw.parallel().tween_property(shield_dome, "scale", Vector3(1.3, 1.3, 1.3), 0.3)
	tw.tween_callback(shield_dome.queue_free)

	return shield_dome


# ==============================================================================
# 2. NOVA: Snipe & Tactical Cloak
# ==============================================================================

## Spawns Snipe: instant high-intensity concentrated laser beam tracer with ion particle wake.
static func spawn_snipe(parent: Node, from_pos: Vector3, to_pos: Vector3) -> Node3D:
	if is_headless() or parent == null:
		return null

	var snipe_root := Node3D.new()
	snipe_root.name = "VFX_SnipeBeam"
	parent.add_child(snipe_root)

	var dist: float = from_pos.distance_to(to_pos)
	if dist < 0.1:
		snipe_root.queue_free()
		return null

	# Laser beam cylinder mesh
	var beam := MeshInstance3D.new()
	beam.name = "LaserTracer"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = dist
	cyl.radial_segments = 8
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = SHADER_LASER_BEAM
	beam_mat.set_shader_parameter("emission_energy", 5.0)
	beam_mat.set_shader_parameter("beam_color", Color(0.15, 0.85, 1.0, 1.0))
	beam.mesh = cyl
	beam.material_override = beam_mat
	snipe_root.add_child(beam)

	# Orient beam along trajectory
	beam.global_position = (from_pos + to_pos) * 0.5
	beam.look_at(to_pos, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

	# Ion particle wake trailing along line
	var wake := GPUParticles3D.new()
	wake.name = "IonWake"
	wake.amount = 28
	wake.lifetime = 0.4
	wake.one_shot = true
	wake.explosiveness = 0.8

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(0.06, dist * 0.5, 0.06)
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 15.0
	p_mat.initial_velocity_min = 2.0
	p_mat.initial_velocity_max = 5.0
	p_mat.color = Color(0.3, 0.9, 1.0, 0.95)
	p_mat.scale_min = 0.4
	p_mat.scale_max = 0.8
	wake.process_material = p_mat

	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.05
	p_mesh.height = 0.1
	var draw_m := StandardMaterial3D.new()
	draw_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_m.albedo_color = Color(0.4, 0.95, 1.0, 0.9)
	p_mesh.material = draw_m
	wake.draw_pass_1 = p_mesh
	snipe_root.add_child(wake)
	wake.global_position = beam.global_position
	wake.global_transform.basis = beam.global_transform.basis
	wake.emitting = true

	# Impact flash at target
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	var f_mat := StandardMaterial3D.new()
	f_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	f_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	f_mat.albedo_color = Color(0.6, 0.95, 1.0, 0.95)
	flash.mesh = sphere
	flash.material_override = f_mat
	snipe_root.add_child(flash)
	flash.global_position = to_pos

	var tw: Tween = snipe_root.create_tween()
	tw.parallel().tween_property(beam_mat, "shader_parameter/emission_energy", 0.0, 0.28)
	tw.parallel().tween_property(flash, "scale", Vector3(1.8, 1.8, 1.8), 0.25)
	tw.parallel().tween_property(f_mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_interval(0.15)
	tw.tween_callback(snipe_root.queue_free)

	return snipe_root


## Applies Tactical Cloak: refractive stealth shimmer, alpha transparency fade, particle distortion.
static func apply_tactical_cloak(hero: Node3D, duration: float = 15.0) -> Node3D:
	if is_headless() or hero == null:
		return null

	var cloak_root := Node3D.new()
	cloak_root.name = "VFX_TacticalCloak"
	hero.add_child(cloak_root)

	# Refractive shimmer distortion puff at activation
	var shimmer_puff := GPUParticles3D.new()
	shimmer_puff.name = "ShimmerPuff"
	shimmer_puff.amount = 24
	shimmer_puff.lifetime = 0.6
	shimmer_puff.one_shot = true
	shimmer_puff.explosiveness = 1.0

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 0.8
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 180.0
	p_mat.initial_velocity_min = 1.5
	p_mat.initial_velocity_max = 3.5
	p_mat.color = Color(0.4, 0.85, 1.0, 0.8)
	shimmer_puff.process_material = p_mat

	var draw_m := SphereMesh.new()
	draw_m.radius = 0.06
	draw_m.height = 0.12
	var s_mat := StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s_mat.albedo_color = Color(0.35, 0.9, 1.0, 0.8)
	draw_m.material = s_mat
	shimmer_puff.draw_pass_1 = draw_m
	cloak_root.add_child(shimmer_puff)
	shimmer_puff.position = Vector3(0, 1.0, 0)
	shimmer_puff.emitting = true

	# Apply stealth shader to hero's body mesh
	var body: MeshInstance3D = hero.get_node_or_null("VisualRoot/BodyMesh") as MeshInstance3D
	var original_mat: Material = body.material_override if body else null

	if body:
		var cloak_shader_mat := ShaderMaterial.new()
		cloak_shader_mat.shader = SHADER_TACTICAL_CLOAK
		cloak_shader_mat.set_shader_parameter("stealth_alpha", 0.18)
		body.material_override = cloak_shader_mat

		var tw: Tween = cloak_root.create_tween()
		tw.tween_interval(duration)
		tw.tween_callback(func():
			if is_instance_valid(body):
				body.material_override = original_mat
			if is_instance_valid(cloak_root):
				cloak_root.queue_free()
		)

	return cloak_root


# ==============================================================================
# 3. JIM RAYNOR: Stimpack, Penetrating Round & Orbital Bombardment
# ==============================================================================

## Spawns Stimpack: chemical bio-injector green vapor venting from armor exhaust and weapon muzzle sparks.
static func spawn_stimpack(hero: Node3D) -> Node3D:
	if is_headless() or hero == null:
		return null

	var stim_root := Node3D.new()
	stim_root.name = "VFX_Stimpack"
	hero.add_child(stim_root)
	stim_root.position = Vector3(0, 1.2, 0)

	# 1. Chemical bio-injector green exhaust vapor plumes (from armor thrusters/backpack)
	var vapor := GPUParticles3D.new()
	vapor.name = "ChemicalVapor"
	vapor.amount = 26
	vapor.lifetime = 0.7
	vapor.one_shot = true
	vapor.explosiveness = 0.85

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(0.4, 0.2, 0.3)
	p_mat.direction = Vector3(0, 1, -0.6)
	p_mat.spread = 35.0
	p_mat.initial_velocity_min = 3.0
	p_mat.initial_velocity_max = 5.5
	p_mat.gravity = Vector3(0, 2.0, 0)
	p_mat.color = Color(0.2, 0.95, 0.3, 0.9)
	p_mat.scale_min = 0.6
	p_mat.scale_max = 1.3
	vapor.process_material = p_mat

	var draw_m := SphereMesh.new()
	draw_m.radius = 0.08
	draw_m.height = 0.16
	var d_mat := StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	d_mat.albedo_color = Color(0.25, 0.98, 0.35, 0.9)
	draw_m.material = d_mat
	vapor.draw_pass_1 = draw_m
	stim_root.add_child(vapor)
	vapor.emitting = true

	# 2. Armor adrenaline shock ring at base
	var ring := MeshInstance3D.new()
	ring.name = "ShockRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.85
	var r_mat := StandardMaterial3D.new()
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r_mat.albedo_color = Color(0.25, 1.0, 0.4, 0.9)
	ring.mesh = torus
	ring.material_override = r_mat
	stim_root.add_child(ring)
	ring.position = Vector3(0, -0.9, 0)

	var tw: Tween = stim_root.create_tween()
	tw.parallel().tween_property(ring, "scale", Vector3(1.8, 1.8, 1.8), 0.35)
	tw.parallel().tween_property(r_mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_interval(0.4)
	tw.tween_callback(stim_root.queue_free)

	return stim_root


## Spawns Penetrating Round: supersonic kinetic rail-slug with shockwave ring and plasma vapor trail.
static func spawn_penetrating_round(parent: Node, from_pos: Vector3, dir: Vector3, distance: float = 12.0) -> Node3D:
	if is_headless() or parent == null:
		return null

	var slug_root := Node3D.new()
	slug_root.name = "VFX_PenetratingRound"
	parent.add_child(slug_root)

	var target_pos: Vector3 = from_pos + dir.normalized() * distance

	# 1. Supersonic Rail-Slug Tracer Cylinder
	var tracer := MeshInstance3D.new()
	tracer.name = "RailSlug"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = distance
	cyl.radial_segments = 6
	var s_mat := StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s_mat.albedo_color = Color(0.3, 0.8, 1.0, 0.95)
	tracer.mesh = cyl
	tracer.material_override = s_mat
	slug_root.add_child(tracer)
	tracer.global_position = (from_pos + target_pos) * 0.5
	tracer.look_at(target_pos, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

	# 2. Supersonic Expanding Shockwave Ring
	var ring := MeshInstance3D.new()
	ring.name = "ShockwaveRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.65
	var r_mat := StandardMaterial3D.new()
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r_mat.albedo_color = Color(0.7, 0.9, 1.0, 0.9)
	ring.mesh = torus
	ring.material_override = r_mat
	slug_root.add_child(ring)
	ring.global_position = from_pos + dir * 2.0
	ring.look_at(target_pos, Vector3.UP)

	# 3. Plasma Vapor Trail Particles
	var trail := GPUParticles3D.new()
	trail.name = "PlasmaVaporTrail"
	trail.amount = 30
	trail.lifetime = 0.5
	trail.one_shot = true
	trail.explosiveness = 0.9

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(0.08, distance * 0.5, 0.08)
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.initial_velocity_min = 1.0
	p_mat.initial_velocity_max = 3.0
	p_mat.color = Color(0.4, 0.85, 1.0, 0.9)
	trail.process_material = p_mat

	var draw_m := SphereMesh.new()
	draw_m.radius = 0.06
	draw_m.height = 0.12
	var d_mat := StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.albedo_color = Color(0.4, 0.9, 1.0, 0.85)
	draw_m.material = d_mat
	trail.draw_pass_1 = draw_m
	slug_root.add_child(trail)
	trail.global_position = tracer.global_position
	trail.global_transform.basis = tracer.global_transform.basis
	trail.emitting = true

	var tw: Tween = slug_root.create_tween()
	tw.parallel().tween_property(s_mat, "albedo_color:a", 0.0, 0.28)
	tw.parallel().tween_property(ring, "scale", Vector3(2.5, 2.5, 2.5), 0.28)
	tw.parallel().tween_property(r_mat, "albedo_color:a", 0.0, 0.28)
	tw.tween_interval(0.2)
	tw.tween_callback(slug_root.queue_free)

	return slug_root


## Spawns Hyperion Orbital Bombardment: cascading vertical celestial laser strikes with ground shockwaves.
static func spawn_orbital_bombardment(parent: Node, center: Vector3, radius: float = 8.0, duration: float = 2.5) -> Node3D:
	if is_headless() or parent == null:
		return null

	var orbital_root := Node3D.new()
	orbital_root.name = "VFX_OrbitalBombardment"
	parent.add_child(orbital_root)
	orbital_root.global_position = center

	# Sequence of 5 concentrated strikes
	var tw: Tween = orbital_root.create_tween()
	for i in range(5):
		var delay: float = (duration / 5.0) * float(i)
		tw.parallel().tween_callback(func():
			if not is_instance_valid(orbital_root):
				return
			var offset := Vector3(randf_range(-radius * 0.6, radius * 0.6), 0, randf_range(-radius * 0.6, radius * 0.6))
			var strike_pos: Vector3 = center + offset

			# Vertical descending laser beam
			var beam := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.35
			cyl.bottom_radius = 0.35
			cyl.height = 35.0
			var b_mat := StandardMaterial3D.new()
			b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			b_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			b_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.95)
			beam.mesh = cyl
			beam.material_override = b_mat
			orbital_root.add_child(beam)
			beam.global_position = strike_pos + Vector3(0, 17.5, 0)

			# Ground impact blast
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 1.2
			torus.outer_radius = 1.8
			var r_mat := StandardMaterial3D.new()
			r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			r_mat.albedo_color = Color(0.4, 0.85, 1.0, 0.95)
			ring.mesh = torus
			ring.material_override = r_mat
			orbital_root.add_child(ring)
			ring.global_position = strike_pos + Vector3(0, 0.2, 0)

			var sub_tw: Tween = beam.create_tween()
			sub_tw.parallel().tween_property(b_mat, "albedo_color:a", 0.0, 0.35)
			sub_tw.parallel().tween_property(ring, "scale", Vector3(2.2, 2.2, 2.2), 0.4)
			sub_tw.parallel().tween_property(r_mat, "albedo_color:a", 0.0, 0.4)
			sub_tw.tween_callback(beam.queue_free)
			sub_tw.tween_callback(ring.queue_free)
		).set_delay(delay)

	tw.tween_interval(duration + 0.6)
	tw.tween_callback(orbital_root.queue_free)

	return orbital_root


# ==============================================================================
# 4. ZERATUL: Blink & Shadow Cleave
# ==============================================================================

## Spawns Blink: dark Void dimensional rift collapse, particle suction wake, green afterimage.
static func spawn_blink(parent: Node, from_pos: Vector3, to_pos: Vector3) -> void:
	if is_headless() or parent == null:
		return

	# 1. Dark Void Implosion / Suction Wake at Origin (Departure)
	var origin_rift := MeshInstance3D.new()
	origin_rift.name = "VoidRift_Origin"
	var sphere_org := SphereMesh.new()
	sphere_org.radius = 0.7
	sphere_org.height = 1.4
	var org_mat := StandardMaterial3D.new()
	org_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	org_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	org_mat.albedo_color = Color(0.1, 0.4, 0.2, 0.95)
	origin_rift.mesh = sphere_org
	origin_rift.material_override = org_mat
	parent.add_child(origin_rift)
	origin_rift.global_position = from_pos + Vector3(0, 0.9, 0)

	var tw_org: Tween = origin_rift.create_tween()
	tw_org.parallel().tween_property(origin_rift, "scale", Vector3(0.1, 0.1, 0.1), 0.25)
	tw_org.parallel().tween_property(org_mat, "albedo_color:a", 0.0, 0.25)
	tw_org.tween_callback(origin_rift.queue_free)

	# 2. Emerald Void Plasma Flash & Afterimage at Destination (Arrival)
	var dest_flash := MeshInstance3D.new()
	dest_flash.name = "VoidRift_Dest"
	var sphere_dst := SphereMesh.new()
	sphere_dst.radius = 0.8
	sphere_dst.height = 1.6
	var dst_mat := StandardMaterial3D.new()
	dst_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dst_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dst_mat.albedo_color = Color(0.2, 0.98, 0.45, 0.95)
	dest_flash.mesh = sphere_dst
	dest_flash.material_override = dst_mat
	parent.add_child(dest_flash)
	dest_flash.global_position = to_pos + Vector3(0, 0.9, 0)
	dest_flash.scale = Vector3(0.3, 0.3, 0.3)

	var tw_dst: Tween = dest_flash.create_tween()
	tw_dst.parallel().tween_property(dest_flash, "scale", Vector3(1.7, 1.7, 1.7), 0.28)
	tw_dst.parallel().tween_property(dst_mat, "albedo_color:a", 0.0, 0.28)
	tw_dst.tween_callback(dest_flash.queue_free)


## Spawns Shadow Cleave: 360° sweeping emerald psionic blade crescent arc with slice decals.
static func spawn_shadow_cleave(parent: Node, center: Vector3, radius: float = 3.8) -> Node3D:
	if is_headless() or parent == null:
		return null

	var cleave_root := Node3D.new()
	cleave_root.name = "VFX_ShadowCleave"
	parent.add_child(cleave_root)
	cleave_root.global_position = center + Vector3(0, 0.75, 0)

	# 1. Emerald Psionic Blade Crescent Arc Mesh
	var arc_mesh := MeshInstance3D.new()
	arc_mesh.name = "EmeraldBladeArc"
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.2, radius * 2.2)
	quad.orientation = PlaneMesh.FACE_Y
	var arc_mat := ShaderMaterial.new()
	arc_mat.shader = SHADER_PSIONIC_BLADE_ARC
	arc_mat.set_shader_parameter("emission_energy", 3.2)
	arc_mesh.mesh = quad
	arc_mesh.material_override = arc_mat
	cleave_root.add_child(arc_mesh)

	# 2. Expanding emerald slice decal ring
	var ring := MeshInstance3D.new()
	ring.name = "BladeDecalRing"
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.75
	torus.outer_radius = radius
	var r_mat := StandardMaterial3D.new()
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r_mat.albedo_color = Color(0.25, 1.0, 0.45, 0.95)
	ring.mesh = torus
	ring.material_override = r_mat
	cleave_root.add_child(ring)

	var tw: Tween = cleave_root.create_tween()
	tw.parallel().tween_property(cleave_root, "scale", Vector3(1.3, 1.3, 1.3), 0.28)
	tw.parallel().tween_property(r_mat, "albedo_color:a", 0.0, 0.28)
	tw.parallel().tween_property(arc_mat, "shader_parameter/emission_energy", 0.0, 0.28)
	tw.tween_callback(cleave_root.queue_free)

	return cleave_root


# ==============================================================================
# 5. EGON STETMANN (MEDIC): Nano-Repair Beam & Defensive Matrix
# ==============================================================================

## Spawns Nano-Repair Beam: continuous dual-stream cyan restorative plasma beam with target node tracking.
static func spawn_heal_beam(parent: Node, source: Node3D, target: Node3D, duration: float = 1.0) -> Node3D:
	if is_headless() or parent == null:
		return null

	var from_p: Vector3 = source.global_position + Vector3(0, 1.1, 0) if source and is_instance_valid(source) else Vector3.ZERO
	var to_p: Vector3 = target.global_position + Vector3(0, 0.9, 0) if target and is_instance_valid(target) else Vector3(0, 0, 5)

	var beam_root := Node3D.new()
	beam_root.name = "VFX_NanoRepairBeam"
	parent.add_child(beam_root)

	var dist: float = from_p.distance_to(to_p)
	if dist < 0.1:
		beam_root.queue_free()
		return null

	# Dual-stream cyan beam cylinders
	var cyl1 := CylinderMesh.new()
	cyl1.top_radius = 0.06
	cyl1.bottom_radius = 0.06
	cyl1.height = dist
	var mat1 := StandardMaterial3D.new()
	mat1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat1.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat1.albedo_color = Color(0.2, 0.95, 0.75, 0.95)
	var stream1 := MeshInstance3D.new()
	stream1.mesh = cyl1
	stream1.material_override = mat1
	beam_root.add_child(stream1)
	stream1.global_position = (from_p + to_p) * 0.5
	stream1.look_at(to_p, Vector3.UP)
	stream1.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

	# Restorative Nanite cross particles flowing along stream
	var nanites := GPUParticles3D.new()
	nanites.name = "RestorativeNanites"
	nanites.amount = 20
	nanites.lifetime = 0.5
	nanites.explosiveness = 0.2

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(0.08, dist * 0.45, 0.08)
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.initial_velocity_min = 2.0
	p_mat.initial_velocity_max = 4.0
	p_mat.color = Color(0.25, 1.0, 0.8, 0.9)
	nanites.process_material = p_mat

	var draw_m := SphereMesh.new()
	draw_m.radius = 0.04
	draw_m.height = 0.08
	var d_mat := StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.albedo_color = Color(0.3, 1.0, 0.85, 0.9)
	draw_m.material = d_mat
	nanites.draw_pass_1 = draw_m
	beam_root.add_child(nanites)
	nanites.global_position = stream1.global_position
	nanites.global_transform.basis = stream1.global_transform.basis
	nanites.emitting = true

	var tw: Tween = beam_root.create_tween()
	tw.tween_interval(duration * 0.8)
	tw.parallel().tween_property(mat1, "albedo_color:a", 0.0, duration * 0.2)
	tw.tween_callback(beam_root.queue_free)

	return beam_root


## Spawns Defensive Matrix: revolving protective hexagonal energy matrix.
static func spawn_defensive_matrix(target: Node3D, duration: float = 7.0) -> Node3D:
	if is_headless() or target == null:
		return null

	var matrix_dome := MeshInstance3D.new()
	matrix_dome.name = "VFX_DefensiveMatrixDome"
	var sphere := SphereMesh.new()
	sphere.radius = 1.3
	sphere.height = 2.6
	sphere.radial_segments = 24
	sphere.rings = 16

	var matrix_mat := ShaderMaterial.new()
	matrix_mat.shader = SHADER_ENERGY_MATRIX
	matrix_mat.set_shader_parameter("emission_energy", 2.8)
	matrix_dome.mesh = sphere
	matrix_dome.material_override = matrix_mat
	target.add_child(matrix_dome)
	matrix_dome.position = Vector3(0, 1.1, 0)

	var tw: Tween = matrix_dome.create_tween()
	tw.tween_interval(duration - 0.5)
	tw.tween_property(matrix_mat, "shader_parameter/emission_energy", 0.0, 0.5)
	tw.parallel().tween_property(matrix_dome, "scale", Vector3(1.2, 1.2, 1.2), 0.5)
	tw.tween_callback(matrix_dome.queue_free)

	return matrix_dome


# ==============================================================================
# 6. TYCHUS: Overkill & Shredder Grenade
# ==============================================================================

## Spawns Overkill: continuous twin-Gatling barrel flash, thermal heat distortion, ejected cartridge sparks.
static func spawn_overkill(hero: Node3D, duration: float = 6.0) -> Node3D:
	if is_headless() or hero == null:
		return null

	var overkill_root := Node3D.new()
	overkill_root.name = "VFX_Overkill"
	hero.add_child(overkill_root)

	# Ejected cartridge sparks (GPUParticles3D spraying brass casings)
	var brass := GPUParticles3D.new()
	brass.name = "EjectedCartridges"
	brass.amount = 32
	brass.lifetime = 0.5
	brass.explosiveness = 0.1

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(0.2, 0.2, 0.2)
	p_mat.direction = Vector3(0.8, 0.6, -0.4)
	p_mat.spread = 25.0
	p_mat.initial_velocity_min = 3.5
	p_mat.initial_velocity_max = 6.0
	p_mat.gravity = Vector3(0, -9.8, 0)
	p_mat.color = Color(1.0, 0.8, 0.3, 0.95)
	brass.process_material = p_mat

	var draw_m := CylinderMesh.new()
	draw_m.top_radius = 0.02
	draw_m.bottom_radius = 0.02
	draw_m.height = 0.08
	var d_mat := StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.albedo_color = Color(1.0, 0.85, 0.35, 0.95)
	draw_m.material = d_mat
	brass.draw_pass_1 = draw_m
	overkill_root.add_child(brass)
	brass.position = Vector3(0.35, 1.1, -0.2)
	brass.emitting = true

	# Thermal heat glow on barrels
	var heat_glow := MeshInstance3D.new()
	heat_glow.name = "BarrelHeatGlow"
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	var g_mat := StandardMaterial3D.new()
	g_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	g_mat.albedo_color = Color(1.0, 0.45, 0.1, 0.8)
	heat_glow.mesh = sphere
	heat_glow.material_override = g_mat
	overkill_root.add_child(heat_glow)
	heat_glow.position = Vector3(0.15, 1.0, -0.7)

	var tw: Tween = overkill_root.create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(overkill_root.queue_free)

	return overkill_root


## Spawns Shredder Grenade: explosion with shrapnel debris and shockwave.
static func spawn_shredder_grenade(parent: Node, center: Vector3, radius: float = 4.5) -> Node3D:
	if is_headless() or parent == null:
		return null

	var nade_root := Node3D.new()
	nade_root.name = "VFX_ShredderGrenade"
	parent.add_child(nade_root)
	nade_root.global_position = center + Vector3(0, 0.4, 0)

	# 1. Shrapnel Blast Sphere
	var blast := MeshInstance3D.new()
	blast.name = "BlastSphere"
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.5
	sphere.height = radius
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	b_mat.albedo_color = Color(1.0, 0.55, 0.15, 0.95)
	blast.mesh = sphere
	blast.material_override = b_mat
	nade_root.add_child(blast)

	# 2. Debris Shrapnel Sparks
	var shrapnel := GPUParticles3D.new()
	shrapnel.name = "ShrapnelSparks"
	shrapnel.amount = 30
	shrapnel.lifetime = 0.45
	shrapnel.one_shot = true
	shrapnel.explosiveness = 1.0

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 0.5
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 180.0
	p_mat.initial_velocity_min = 6.0
	p_mat.initial_velocity_max = 12.0
	p_mat.gravity = Vector3(0, -12.0, 0)
	p_mat.color = Color(1.0, 0.75, 0.25, 0.95)
	shrapnel.process_material = p_mat

	var draw_m := SphereMesh.new()
	draw_m.radius = 0.05
	draw_m.height = 0.1
	var d_mat := StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.albedo_color = Color(1.0, 0.8, 0.3, 0.9)
	draw_m.material = d_mat
	shrapnel.draw_pass_1 = draw_m
	nade_root.add_child(shrapnel)
	shrapnel.emitting = true

	var tw: Tween = nade_root.create_tween()
	tw.parallel().tween_property(blast, "scale", Vector3(1.6, 1.6, 1.6), 0.3)
	tw.parallel().tween_property(b_mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_interval(0.2)
	tw.tween_callback(nade_root.queue_free)

	return nade_root


# ==============================================================================
# 7. SECRET HARBINGER: Celestial Singularity & Dimensional Beam
# ==============================================================================

## Spawns Celestial Singularity: gravity vortex pulling entities, cosmic gold/purple accretion disk.
static func spawn_celestial_singularity(parent: Node, center: Vector3, radius: float = 6.0, duration: float = 2.0) -> Node3D:
	if is_headless() or parent == null:
		return null

	var sing_root := Node3D.new()
	sing_root.name = "VFX_CelestialSingularity"
	parent.add_child(sing_root)
	sing_root.global_position = center + Vector3(0, 0.45, 0)

	# 1. Cosmic Gold/Purple Accretion Disk Mesh
	var disk := MeshInstance3D.new()
	disk.name = "AccretionDisk"
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	var disk_mat := ShaderMaterial.new()
	disk_mat.shader = SHADER_SINGULARITY_VORTEX
	disk_mat.set_shader_parameter("emission_energy", 3.8)
	disk.mesh = quad
	disk.material_override = disk_mat
	sing_root.add_child(disk)

	# 2. Event Horizon Gravitational Suction Particles (inward radial pull)
	var suction := GPUParticles3D.new()
	suction.name = "GravitySuction"
	suction.amount = 40
	suction.lifetime = 0.8
	suction.explosiveness = 0.1

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = radius * 0.95
	p_mat.gravity = Vector3.ZERO
	p_mat.radial_accel_min = -12.0
	p_mat.radial_accel_max = -8.0
	p_mat.color = Color(1.0, 0.85, 0.3, 0.95)
	suction.process_material = p_mat

	var draw_m := SphereMesh.new()
	draw_m.radius = 0.07
	draw_m.height = 0.14
	var d_mat := StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	d_mat.albedo_color = Color(0.9, 0.35, 1.0, 0.9)
	draw_m.material = d_mat
	suction.draw_pass_1 = draw_m
	sing_root.add_child(suction)
	suction.emitting = true

	# Implosion animation at end
	var tw: Tween = sing_root.create_tween()
	tw.tween_interval(duration)
	tw.parallel().tween_property(disk, "scale", Vector3(0.05, 0.05, 0.05), 0.25)
	tw.parallel().tween_property(disk_mat, "shader_parameter/emission_energy", 0.0, 0.25)
	tw.tween_callback(sing_root.queue_free)

	return sing_root


## Spawns Dimensional Beam: concentrated prismatic tachyon laser beam.
static func spawn_dimensional_beam(parent: Node, from_pos: Vector3, to_pos: Vector3) -> Node3D:
	if is_headless() or parent == null:
		return null

	var beam_root := Node3D.new()
	beam_root.name = "VFX_DimensionalBeam"
	parent.add_child(beam_root)

	var dist: float = from_pos.distance_to(to_pos)
	if dist < 0.1:
		beam_root.queue_free()
		return null

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = dist
	var b_mat := ShaderMaterial.new()
	b_mat.shader = SHADER_LASER_BEAM
	b_mat.set_shader_parameter("beam_color", Color(0.85, 0.35, 1.0, 1.0))
	b_mat.set_shader_parameter("core_color", Color(1.0, 0.9, 0.4, 1.0))
	b_mat.set_shader_parameter("emission_energy", 4.5)
	var beam := MeshInstance3D.new()
	beam.mesh = cyl
	beam.material_override = b_mat
	beam_root.add_child(beam)
	beam.global_position = (from_pos + to_pos) * 0.5
	beam.look_at(to_pos, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

	var tw: Tween = beam_root.create_tween()
	tw.parallel().tween_property(b_mat, "shader_parameter/emission_energy", 0.0, 0.3)
	tw.tween_callback(beam_root.queue_free)

	return beam_root
