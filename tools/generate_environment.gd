extends SceneTree

# Procedural Environment & Atmospheric Asset Generator for Special Forces Elite 5 (SFE5)
# Generates authentic Planet Char volcanic environment assets:
# 1. PBR Volcanic Basalt Ground Material & Shader
# 2. Glowing Magma Fissure Shader, Material & Jagged Chasm Meshes
# 3. Organic Zerg Creep / Biomass Shader, Material & Infestation Pool Meshes
# 4. Terran Industrial Base Enclave Deck Shader, Material & Foundation Mesh
# 5. Volcanic Basalt Rock Formations & Crag Meshes

const GROUND_MAT_PATH := "res://assets/materials/environment/char_basalt_ground_pbr.tres"
const LAVA_MAT_PATH := "res://assets/materials/environment/lava_fissure_material.tres"
const CREEP_MAT_PATH := "res://assets/materials/environment/zerg_creep_material.tres"
const DECK_MAT_PATH := "res://assets/materials/environment/terran_base_deck_material.tres"
const ROCK_MAT_PATH := "res://assets/materials/environment/char_rock_crust.tres"

const LAVA_MESH_PATH := "res://assets/models/environment/lava_fissures_mesh.tres"
const CREEP_MESH_PATH := "res://assets/models/environment/zerg_creep_pools_mesh.tres"
const DECK_MESH_PATH := "res://assets/models/environment/terran_base_deck_mesh.tres"
const BOULDERS_MESH_PATH := "res://assets/models/environment/volcanic_boulders_mesh.tres"

var mat_ground: ShaderMaterial
var mat_lava: ShaderMaterial
var mat_creep: ShaderMaterial
var mat_deck: ShaderMaterial
var mat_rock: StandardMaterial3D


func _init() -> void:
	print("[EnvironmentGenerator] Synthesizing Planet Char volcanic atmosphere...")
	_ensure_directories()
	_create_and_save_materials()
	
	_build_lava_fissures_mesh()
	_build_zerg_creep_pools_mesh()
	_build_terran_base_deck_mesh()
	_build_volcanic_boulders_mesh()
	
	print("[EnvironmentGenerator] All Planet Char materials and meshes generated successfully!")
	quit(0)


func _ensure_directories() -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets/materials/environment"):
		dir.make_dir_recursive("assets/materials/environment")
	if not dir.dir_exists("assets/models/environment"):
		dir.make_dir_recursive("assets/models/environment")


func _create_and_save_materials() -> void:
	# 1. Ground Basalt Material
	mat_ground = ShaderMaterial.new()
	mat_ground.shader = load("res://assets/shaders/char_terrain.gdshader")
	ResourceSaver.save(mat_ground, GROUND_MAT_PATH)
	print("[EnvironmentGenerator] Saved Ground Material: ", GROUND_MAT_PATH)
	
	# 2. Emissive Magma Fissure Material
	mat_lava = ShaderMaterial.new()
	mat_lava.shader = load("res://assets/shaders/lava_fissure.gdshader")
	mat_lava.set_shader_parameter("emission_energy", 4.5)
	mat_lava.set_shader_parameter("flow_speed", 0.08)
	mat_lava.set_shader_parameter("pulse_speed", 1.8)
	ResourceSaver.save(mat_lava, LAVA_MAT_PATH)
	print("[EnvironmentGenerator] Saved Lava Material: ", LAVA_MAT_PATH)
	
	# 3. Zerg Creep Material
	mat_creep = ShaderMaterial.new()
	mat_creep.shader = load("res://assets/shaders/zerg_creep.gdshader")
	mat_creep.set_shader_parameter("vein_emission_energy", 2.6)
	mat_creep.set_shader_parameter("gloss_roughness", 0.20)
	mat_creep.set_shader_parameter("clearcoat", 0.85)
	mat_creep.set_shader_parameter("pulse_speed", 2.2)
	ResourceSaver.save(mat_creep, CREEP_MAT_PATH)
	print("[EnvironmentGenerator] Saved Creep Material: ", CREEP_MAT_PATH)
	
	# 4. Terran Industrial Base Deck Material
	mat_deck = ShaderMaterial.new()
	mat_deck.shader = load("res://assets/shaders/terran_base_deck.gdshader")
	mat_deck.set_shader_parameter("conduit_emission_energy", 2.5)
	ResourceSaver.save(mat_deck, DECK_MAT_PATH)
	print("[EnvironmentGenerator] Saved Base Deck Material: ", DECK_MAT_PATH)
	
	# 5. Basalt Rock Crust Material
	mat_rock = StandardMaterial3D.new()
	mat_rock.albedo_color = Color(0.12, 0.10, 0.11, 1.0)
	mat_rock.roughness = 0.88
	mat_rock.metallic = 0.10
	ResourceSaver.save(mat_rock, ROCK_MAT_PATH)
	print("[EnvironmentGenerator] Saved Rock Crust Material: ", ROCK_MAT_PATH)


# ==============================================================================
# 1. EMISSIVE MAGMA FISSURES MESH
# ==============================================================================

func _build_lava_fissures_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Fissure 1: West Canyon Diagonal Chasm (cuts from NW spawners towards West perimeter)
	var path_west: Array[Vector3] = [
		Vector3(-22.0, 0.008, -32.0),
		Vector3(-18.5, 0.008, -26.0),
		Vector3(-14.0, 0.008, -20.0),
		Vector3(-11.0, 0.008, -14.0),
		Vector3(-8.0, 0.008, -8.0),
		Vector3(-5.5, 0.008, -3.0),
		Vector3(-2.5, 0.008, 0.5)
	]
	var widths_west: Array[float] = [1.8, 2.4, 3.2, 2.6, 2.8, 2.2, 1.6]
	_add_ribbon_fissure(st, path_west, widths_west)
	
	# Fissure 2: East Canyon Diagonal Chasm (cuts from NE spawners towards East perimeter)
	var path_east: Array[Vector3] = [
		Vector3(20.0, 0.008, -32.0),
		Vector3(17.0, 0.008, -25.0),
		Vector3(14.5, 0.008, -18.0),
		Vector3(11.0, 0.008, -12.0),
		Vector3(8.5, 0.008, -7.0),
		Vector3(5.0, 0.008, -2.5),
		Vector3(2.5, 0.008, 0.5)
	]
	var widths_east: Array[float] = [1.6, 2.5, 3.0, 2.8, 2.4, 2.0, 1.5]
	_add_ribbon_fissure(st, path_east, widths_east)
	
	# Fissure 3: North Transverse Trench (connects across no-man's-land)
	var path_north: Array[Vector3] = [
		Vector3(-15.0, 0.008, -21.0),
		Vector3(-9.0, 0.008, -22.5),
		Vector3(-3.0, 0.008, -21.0),
		Vector3(3.0, 0.008, -22.0),
		Vector3(9.0, 0.008, -20.5),
		Vector3(15.0, 0.008, -22.0)
	]
	var widths_north: Array[float] = [1.4, 2.2, 2.6, 2.4, 2.2, 1.5]
	_add_ribbon_fissure(st, path_north, widths_north)
	
	# Fissure 4: Hell's Gate Caldera Ring Fissure (around Nydus rift at -26, -10)
	var center_hell := Vector3(-26.0, 0.008, -10.0)
	_add_circular_chasm(st, center_hell, 4.5, 6.2, 16)
	
	# Fissure 5: Secret Boss Tributary Fissure (near 26, -10)
	var path_secret: Array[Vector3] = [
		Vector3(26.0, 0.008, -16.0),
		Vector3(24.5, 0.008, -10.0),
		Vector3(28.0, 0.008, -5.0)
	]
	var widths_secret: Array[float] = [1.5, 2.2, 1.6]
	_add_ribbon_fissure(st, path_secret, widths_secret)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_lava)
	st.commit(mesh)
	
	ResourceSaver.save(mesh, LAVA_MESH_PATH)
	print("[EnvironmentGenerator] Saved Lava Fissures Mesh: ", LAVA_MESH_PATH)


func _add_ribbon_fissure(st: SurfaceTool, points: Array[Vector3], widths: Array[float]) -> void:
	if points.size() < 2:
		return
	
	var total_dist: float = 0.0
	for i in range(points.size() - 1):
		var p0 := points[i]
		var p1 := points[i + 1]
		var dir := (p1 - p0).normalized()
		var perp := Vector3(-dir.z, 0.0, dir.x)
		
		var w0 := widths[i] * 0.5
		var w1 := widths[i + 1] * 0.5
		
		var left0 := p0 - perp * w0
		var right0 := p0 + perp * w0
		var left1 := p1 - perp * w1
		var right1 := p1 + perp * w1
		
		var segment_len := p0.distance_to(p1)
		var v_start := total_dist * 0.2
		var v_end := (total_dist + segment_len) * 0.2
		total_dist += segment_len
		
		# Quad with proper UV mapping for flow
		st.set_color(Color.WHITE)
		st.set_normal(Vector3.UP)
		
		st.set_uv(Vector2(0.0, v_start))
		st.add_vertex(left0)
		st.set_uv(Vector2(1.0, v_start))
		st.add_vertex(right0)
		st.set_uv(Vector2(1.0, v_end))
		st.add_vertex(right1)
		
		st.set_uv(Vector2(0.0, v_start))
		st.add_vertex(left0)
		st.set_uv(Vector2(1.0, v_end))
		st.add_vertex(right1)
		st.set_uv(Vector2(0.0, v_end))
		st.add_vertex(left1)


func _add_circular_chasm(st: SurfaceTool, center: Vector3, inner_rad: float, outer_rad: float, segments: int) -> void:
	for i in range(segments):
		var a0 := float(i) * TAU / float(segments)
		var a1 := float(i + 1) * TAU / float(segments)
		
		var in0 := center + Vector3(cos(a0) * inner_rad, 0.0, sin(a0) * inner_rad)
		var out0 := center + Vector3(cos(a0) * outer_rad, 0.0, sin(a0) * outer_rad)
		var in1 := center + Vector3(cos(a1) * inner_rad, 0.0, sin(a1) * inner_rad)
		var out1 := center + Vector3(cos(a1) * outer_rad, 0.0, sin(a1) * outer_rad)
		
		var u0 := float(i) / float(segments)
		var u1 := float(i + 1) / float(segments)
		
		st.set_color(Color.WHITE)
		st.set_normal(Vector3.UP)
		
		st.set_uv(Vector2(u0, 0.0))
		st.add_vertex(in0)
		st.set_uv(Vector2(u0, 1.0))
		st.add_vertex(out0)
		st.set_uv(Vector2(u1, 1.0))
		st.add_vertex(out1)
		
		st.set_uv(Vector2(u0, 0.0))
		st.add_vertex(in0)
		st.set_uv(Vector2(u1, 1.0))
		st.add_vertex(out1)
		st.set_uv(Vector2(u1, 0.0))
		st.add_vertex(in1)


# ==============================================================================
# 2. ORGANIC ZERG CREEP POOLS MESH
# ==============================================================================

func _build_zerg_creep_pools_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Pool 1: Central Hive Spawner Infestation (0, -34)
	_add_organic_creep_disk(st, Vector3(0.0, 0.012, -34.0), 9.0, 18, 0.35)
	
	# Pool 2: West Spawner Infestation (-7, -34)
	_add_organic_creep_disk(st, Vector3(-7.0, 0.012, -34.0), 6.5, 14, 0.28)
	
	# Pool 3: East Spawner Infestation (7, -34)
	_add_organic_creep_disk(st, Vector3(7.0, 0.012, -34.0), 6.5, 14, 0.28)
	
	# Pool 4: Hell's Gate Nydus Zone (-26, -10)
	_add_organic_creep_disk(st, Vector3(-26.0, 0.012, -10.0), 8.0, 16, 0.30)
	
	# Pool 5: Secret Boss Zone (26, -10)
	_add_organic_creep_disk(st, Vector3(26.0, 0.012, -10.0), 7.0, 16, 0.25)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_creep)
	st.commit(mesh)
	
	ResourceSaver.save(mesh, CREEP_MESH_PATH)
	print("[EnvironmentGenerator] Saved Creep Pools Mesh: ", CREEP_MESH_PATH)


func _add_organic_creep_disk(st: SurfaceTool, center: Vector3, base_radius: float, segments: int, lobe_distortion: float) -> void:
	# Center point
	var c_uv := Vector2(0.5, 0.5)
	
	for i in range(segments):
		var a0 := float(i) * TAU / float(segments)
		var a1 := float(i + 1) * TAU / float(segments)
		
		# Organic lobed radius variation using harmonic frequencies
		var r0 := base_radius * (1.0 + sin(a0 * 3.0) * lobe_distortion + cos(a0 * 5.0) * (lobe_distortion * 0.4))
		var r1 := base_radius * (1.0 + sin(a1 * 3.0) * lobe_distortion + cos(a1 * 5.0) * (lobe_distortion * 0.4))
		
		var p0 := center + Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
		var p1 := center + Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)
		
		var uv0 := c_uv + Vector2(cos(a0) * (r0 / base_radius) * 0.5, sin(a0) * (r0 / base_radius) * 0.5)
		var uv1 := c_uv + Vector2(cos(a1) * (r1 / base_radius) * 0.5, sin(a1) * (r1 / base_radius) * 0.5)
		
		st.set_color(Color.WHITE)
		st.set_normal(Vector3.UP)
		
		st.set_uv(c_uv)
		st.add_vertex(center)
		st.set_uv(uv0)
		st.add_vertex(p0)
		st.set_uv(uv1)
		st.add_vertex(p1)


# ==============================================================================
# 3. TERRAN INDUSTRIAL BASE DECK MESH
# ==============================================================================

func _build_terran_base_deck_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Base Enclave interior bounds: X in [-17.5, 17.5], Z in [4.5, 23.5]
	var min_x := -17.5
	var max_x := 17.5
	var min_z := 4.5
	var max_z := 23.5
	var y_pos := 0.006
	
	var steps_x := 8
	var steps_z := 5
	var dx := (max_x - min_x) / float(steps_x)
	var dz := (max_z - min_z) / float(steps_z)
	
	for ix in range(steps_x):
		for iz in range(steps_z):
			var x0 := min_x + float(ix) * dx
			var x1 := min_x + float(ix + 1) * dx
			var z0 := min_z + float(iz) * dz
			var z1 := min_z + float(iz + 1) * dz
			
			var p0 := Vector3(x0, y_pos, z0)
			var p1 := Vector3(x1, y_pos, z0)
			var p2 := Vector3(x1, y_pos, z1)
			var p3 := Vector3(x0, y_pos, z1)
			
			var u0 := float(ix) / float(steps_x)
			var u1 := float(ix + 1) / float(steps_x)
			var v0 := float(iz) / float(steps_z)
			var v1 := float(iz + 1) / float(steps_z)
			
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.UP)
			
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p0)
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p1)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p2)
			
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p0)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p2)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p3)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_deck)
	st.commit(mesh)
	
	ResourceSaver.save(mesh, DECK_MESH_PATH)
	print("[EnvironmentGenerator] Saved Base Deck Mesh: ", DECK_MESH_PATH)


# ==============================================================================
# 4. VOLCANIC BASALT BOULDERS & CRAGS MESH
# ==============================================================================

func _build_volcanic_boulders_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Strategic perimeter boulder clusters around battlefield perimeter (outside unit flow)
	var boulder_spots: Array[Vector3] = [
		# West edge crags
		Vector3(-32.0, 0.0, -28.0),
		Vector3(-35.0, 0.0, -18.0),
		Vector3(-34.0, 0.0, 0.0),
		Vector3(-32.0, 0.0, 15.0),
		# East edge crags
		Vector3(32.0, 0.0, -28.0),
		Vector3(35.0, 0.0, -18.0),
		Vector3(34.0, 0.0, 0.0),
		Vector3(32.0, 0.0, 15.0),
		# North spawn ridge
		Vector3(-18.0, 0.0, -36.0),
		Vector3(18.0, 0.0, -36.0),
		Vector3(-28.0, 0.0, -35.0),
		Vector3(28.0, 0.0, -35.0)
	]
	
	for i in range(boulder_spots.size()):
		var center := boulder_spots[i]
		var scale_factor := 1.8 + float(i % 3) * 0.7
		_add_craggy_boulder(st, center, scale_factor)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_rock)
	st.commit(mesh)
	
	ResourceSaver.save(mesh, BOULDERS_MESH_PATH)
	print("[EnvironmentGenerator] Saved Volcanic Boulders Mesh: ", BOULDERS_MESH_PATH)


func _add_craggy_boulder(st: SurfaceTool, center: Vector3, radius: float) -> void:
	# Octagonal tapered craggy monolith
	var sides := 7
	var h := radius * 1.5
	var base_r := radius
	var top_r := radius * 0.35
	
	for i in range(sides):
		var a0 := float(i) * TAU / float(sides)
		var a1 := float(i + 1) * TAU / float(sides)
		
		# Jitter radii for craggy rock relief
		var jr0 := base_r * (0.85 + 0.3 * sin(a0 * 2.0))
		var jr1 := base_r * (0.85 + 0.3 * sin(a1 * 2.0))
		var jtr0 := top_r * (0.85 + 0.3 * cos(a0 * 3.0))
		var jtr1 := top_r * (0.85 + 0.3 * cos(a1 * 3.0))
		
		var b0 := center + Vector3(cos(a0) * jr0, 0.0, sin(a0) * jr0)
		var b1 := center + Vector3(cos(a1) * jr1, 0.0, sin(a1) * jr1)
		var t0 := center + Vector3(cos(a0) * jtr0, h, sin(a0) * jtr0)
		var t1 := center + Vector3(cos(a1) * jtr1, h, sin(a1) * jtr1)
		var top_center := center + Vector3(0.0, h * 1.15, 0.0)
		
		st.set_color(Color(0.12, 0.10, 0.11))
		
		# Side facet
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(b0)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(b1)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(t1)
		
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(b0)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(t1)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(t0)
		
		# Top cap
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(top_center)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(t0)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(t1)
