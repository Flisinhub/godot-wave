extends SceneTree

# Procedural 3D Model, Mesh & GLTF Generator for Special Forces Elite 5 (SFE5)
# Generates authentic StarCraft II inspired assets:
# 1. Terran Marine (marine_body_mesh.tres, c14_gauss_rifle_mesh.tres, marine.glb)
# 2. Jim Raynor (raynor_body_mesh.tres, raynor_rifle_mesh.tres, raynor.glb)
# 3. Zergling (zergling_mesh.tres, zergling.glb)
# 4. Roach (roach_mesh.tres, roach.glb)
# 5. Baneling (baneling_mesh.tres, baneling.glb)
# 6. Hydralisk (hydralisk_mesh.tres, hydralisk.glb)
# 7. Command Center (structures/command_center.glb)
# 8. Bunker (structures/bunker.glb)
# 9. Auto-Turret (auto_turret_mesh.tres, structures/auto_turret.glb)

const MARINE_BODY_PATH := "res://assets/models/marine_body_mesh.tres"
const MARINE_RIFLE_PATH := "res://assets/models/c14_gauss_rifle_mesh.tres"
const RAYNOR_BODY_PATH := "res://assets/models/raynor_body_mesh.tres"
const RAYNOR_RIFLE_PATH := "res://assets/models/raynor_rifle_mesh.tres"
const ZERGLING_MESH_PATH := "res://assets/models/zergling_mesh.tres"
const ROACH_MESH_PATH := "res://assets/models/roach_mesh.tres"
const BANELING_MESH_PATH := "res://assets/models/baneling_mesh.tres"
const HYDRALISK_MESH_PATH := "res://assets/models/hydralisk_mesh.tres"
const AUTO_TURRET_MESH_PATH := "res://assets/models/auto_turret_mesh.tres"
const AUTO_TURRET_STRUCT_PATH := "res://assets/models/structures/auto_turret_mesh.tres"
const CC_MESH_PATH := "res://assets/models/structures/command_center_mesh.tres"
const BUNKER_MESH_PATH := "res://assets/models/structures/bunker_structure_mesh.tres"

var mat_marine_armor: Material
var mat_marine_steel: Material
var mat_marine_visor: Material
var mat_marine_thruster: Material
var mat_raynor_armor: Material
var mat_raynor_brass: Material
var mat_raynor_visor: Material
var mat_zergling: Material
var mat_roach: Material
var mat_baneling: Material
var mat_hydralisk: Material
var mat_auto_turret: Material
var mat_hull: Material
var mat_dark_steel: Material
var mat_blue_glow: Material


func _init() -> void:
	print("[ModelGenerator] Starting authentic 3D model synthesis & GLTF pipeline...")
	_ensure_directories()
	_load_materials()
	
	# 1. Generate & save .tres meshes
	_build_marine_body()
	_build_c14_rifle()
	_build_raynor_body()
	_build_raynor_rifle()
	_build_zergling_mesh()
	_build_roach_mesh()
	_build_baneling_mesh()
	_build_hydralisk_mesh()
	_build_auto_turret_mesh()
	_ensure_structure_meshes()
	
	# 2. Export 9 binary .glb models with AnimationPlayer
	_export_marine_glb()
	_export_raynor_glb()
	_export_zergling_glb()
	_export_roach_glb()
	_export_baneling_glb()
	_export_hydralisk_glb()
	_export_command_center_glb()
	_export_bunker_glb()
	_export_auto_turret_glb()
	
	print("[ModelGenerator] All 9 .glb models and meshes generated and exported successfully!")
	quit(0)


func _ensure_directories() -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets"):
		dir.make_dir("assets")
	if not dir.dir_exists("assets/models"):
		dir.make_dir("assets/models")
	if not dir.dir_exists("assets/models/structures"):
		dir.make_dir_recursive("assets/models/structures")
	if not dir.dir_exists("assets/materials"):
		dir.make_dir("assets/materials")
	if not dir.dir_exists("assets/materials/structures"):
		dir.make_dir_recursive("assets/materials/structures")
	if not dir.dir_exists("assets/shaders"):
		dir.make_dir("assets/shaders")


func _load_materials() -> void:
	mat_marine_armor = _load_or_create_std_mat("res://assets/materials/marine_armor_pbr.tres", Color(0.18, 0.38, 0.72), 0.75, 0.35)
	mat_marine_steel = _load_or_create_std_mat("res://assets/materials/marine_steel_dark.tres", Color(0.15, 0.16, 0.18), 0.85, 0.45)
	mat_marine_visor = _load_or_create_std_mat("res://assets/materials/marine_visor_glow.tres", Color(1.0, 0.75, 0.2), 0.1, 0.2, Color(1.0, 0.65, 0.1), 3.0)
	mat_marine_thruster = _load_or_create_std_mat("res://assets/materials/marine_thruster_glow.tres", Color(0.2, 0.8, 1.0), 0.1, 0.2, Color(0.1, 0.7, 1.0), 4.0)
	
	mat_raynor_armor = _load_or_create_std_mat("res://assets/materials/raynor_armor_pbr.tres", Color(0.12, 0.18, 0.35), 0.8, 0.3)
	mat_raynor_brass = _load_or_create_std_mat("res://assets/materials/raynor_brass_trim.tres", Color(0.85, 0.68, 0.22), 0.9, 0.25)
	mat_raynor_visor = _load_or_create_std_mat("res://assets/materials/raynor_visor_glow.tres", Color(1.0, 0.35, 0.1), 0.1, 0.2, Color(1.0, 0.25, 0.05), 4.5)
	
	if ResourceLoader.exists("res://assets/materials/zergling_material.tres"):
		mat_zergling = load("res://assets/materials/zergling_material.tres")
	else:
		mat_zergling = _load_or_create_std_mat("res://assets/materials/zergling_material.tres", Color(0.24, 0.1, 0.28), 0.1, 0.32)
		
	if ResourceLoader.exists("res://assets/materials/roach_material.tres"):
		mat_roach = load("res://assets/materials/roach_material.tres")
	else:
		mat_roach = _load_or_create_std_mat("res://assets/materials/roach_material.tres", Color(0.3, 0.18, 0.12), 0.05, 0.55)
		
	if ResourceLoader.exists("res://assets/materials/baneling_material.tres"):
		mat_baneling = load("res://assets/materials/baneling_material.tres")
	else:
		mat_baneling = _load_or_create_std_mat("res://assets/materials/baneling_material.tres", Color(0.2, 0.95, 0.15), 0.08, 0.22, Color(0.2, 0.95, 0.15), 4.0)
		
	if ResourceLoader.exists("res://assets/materials/hydralisk_material.tres"):
		mat_hydralisk = load("res://assets/materials/hydralisk_material.tres")
	else:
		mat_hydralisk = _load_or_create_std_mat("res://assets/materials/hydralisk_material.tres", Color(0.35, 0.12, 0.18), 0.05, 0.45, Color(0.1, 1.0, 0.2), 3.5)
		
	mat_auto_turret = _load_or_create_std_mat("res://assets/materials/auto_turret_material.tres", Color(0.24, 0.27, 0.32), 0.85, 0.35)
	mat_hull = _load_or_create_std_mat("res://assets/materials/structures/terran_hull_pbr.tres", Color(0.32, 0.35, 0.40), 0.8, 0.4)
	mat_dark_steel = _load_or_create_std_mat("res://assets/materials/structures/terran_dark_steel.tres", Color(0.18, 0.20, 0.22), 0.85, 0.35)
	mat_blue_glow = _load_or_create_std_mat("res://assets/materials/structures/terran_blue_glow.tres", Color(0.2, 0.6, 1.0), 0.1, 0.2, Color(0.2, 0.6, 1.0), 3.0)


func _load_or_create_std_mat(path: String, albedo: Color, metallic: float, roughness: float, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> Material:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Material:
			return res
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = roughness
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	ResourceSaver.save(m, path)
	return m


# ==============================================================================
# GEOMETRY HELPERS
# ==============================================================================

func _add_box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color = Color.WHITE) -> void:
	var h := size * 0.5
	var v000 := center + Vector3(-h.x, -h.y, -h.z)
	var v001 := center + Vector3(-h.x, -h.y,  h.z)
	var v010 := center + Vector3(-h.x,  h.y, -h.z)
	var v011 := center + Vector3(-h.x,  h.y,  h.z)
	var v100 := center + Vector3( h.x, -h.y, -h.z)
	var v101 := center + Vector3( h.x, -h.y,  h.z)
	var v110 := center + Vector3( h.x,  h.y, -h.z)
	var v111 := center + Vector3( h.x,  h.y,  h.z)
	
	_add_quad(st, v001, v101, v111, v011, Vector3.FORWARD, col)
	_add_quad(st, v100, v000, v010, v110, Vector3.BACK, col)
	_add_quad(st, v011, v111, v110, v010, Vector3.UP, col)
	_add_quad(st, v000, v100, v101, v001, Vector3.DOWN, col)
	_add_quad(st, v101, v100, v110, v111, Vector3.RIGHT, col)
	_add_quad(st, v000, v001, v011, v010, Vector3.LEFT, col)


func _add_quad(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3, norm: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(norm)
	
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p1)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(p2)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(p3)
	
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p1)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(p3)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(p4)


func _add_tapered_box(st: SurfaceTool, center: Vector3, size_bot: Vector3, size_top: Vector3, col: Color = Color.WHITE) -> void:
	var hb := size_bot * 0.5
	var ht := size_top * 0.5
	var y_bot := center.y - (size_bot.y * 0.5)
	var y_top := center.y + (size_top.y * 0.5)
	
	var v000 := Vector3(center.x - hb.x, y_bot, center.z - hb.z)
	var v001 := Vector3(center.x - hb.x, y_bot, center.z + hb.z)
	var v100 := Vector3(center.x + hb.x, y_bot, center.z - hb.z)
	var v101 := Vector3(center.x + hb.x, y_bot, center.z + hb.z)
	
	var v010 := Vector3(center.x - ht.x, y_top, center.z - ht.z)
	var v011 := Vector3(center.x - ht.x, y_top, center.z + ht.z)
	var v110 := Vector3(center.x + ht.x, y_top, center.z - ht.z)
	var v111 := Vector3(center.x + ht.x, y_top, center.z + ht.z)
	
	_add_quad(st, v001, v101, v111, v011, (Vector3.FORWARD + Vector3.UP * 0.2).normalized(), col)
	_add_quad(st, v100, v000, v010, v110, (Vector3.BACK + Vector3.UP * 0.2).normalized(), col)
	_add_quad(st, v011, v111, v110, v010, Vector3.UP, col)
	_add_quad(st, v000, v100, v101, v001, Vector3.DOWN, col)
	_add_quad(st, v101, v100, v110, v111, (Vector3.RIGHT + Vector3.UP * 0.2).normalized(), col)
	_add_quad(st, v000, v001, v011, v010, (Vector3.LEFT + Vector3.UP * 0.2).normalized(), col)


func _add_cylinder(st: SurfaceTool, center: Vector3, radius: float, height: float, segments: int = 8, col: Color = Color.WHITE) -> void:
	var h2 := height * 0.5
	var y_top := center.y + h2
	var y_bot := center.y - h2
	
	for i in range(segments):
		var a1 := (float(i) / segments) * TAU
		var a2 := (float(i + 1) / segments) * TAU
		var x1 := center.x + cos(a1) * radius
		var z1 := center.z + sin(a1) * radius
		var x2 := center.x + cos(a2) * radius
		var z2 := center.z + sin(a2) * radius
		
		var n1 := Vector3(cos(a1), 0, sin(a1))
		var n2 := Vector3(cos(a2), 0, sin(a2))
		var n_mid := ((n1 + n2) * 0.5).normalized()
		
		var p1 := Vector3(x1, y_bot, z1)
		var p2 := Vector3(x2, y_bot, z2)
		var p3 := Vector3(x2, y_top, z2)
		var p4 := Vector3(x1, y_top, z1)
		_add_quad(st, p1, p2, p3, p4, n_mid, col)
		
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(Vector3(center.x, y_top, center.z))
		st.set_uv(Vector2(cos(a1) * 0.5 + 0.5, sin(a1) * 0.5 + 0.5))
		st.add_vertex(p4)
		st.set_uv(Vector2(cos(a2) * 0.5 + 0.5, sin(a2) * 0.5 + 0.5))
		st.add_vertex(p3)
		
		st.set_normal(Vector3.DOWN)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(Vector3(center.x, y_bot, center.z))
		st.set_uv(Vector2(cos(a2) * 0.5 + 0.5, sin(a2) * 0.5 + 0.5))
		st.add_vertex(p2)
		st.set_uv(Vector2(cos(a1) * 0.5 + 0.5, sin(a1) * 0.5 + 0.5))
		st.add_vertex(p1)


func _add_wedge(st: SurfaceTool, tip: Vector3, b1: Vector3, b2: Vector3, b3: Vector3, col: Color = Color.WHITE) -> void:
	st.set_color(col)
	var n1 := (b2 - b1).cross(tip - b1).normalized()
	st.set_normal(n1)
	st.add_vertex(b1)
	st.add_vertex(b2)
	st.add_vertex(tip)
	
	var n2 := (b3 - b2).cross(tip - b2).normalized()
	st.set_normal(n2)
	st.add_vertex(b2)
	st.add_vertex(b3)
	st.add_vertex(tip)
	
	var n3 := (b1 - b3).cross(tip - b3).normalized()
	st.set_normal(n3)
	st.add_vertex(b3)
	st.add_vertex(b1)
	st.add_vertex(tip)
	
	var n_base := (b2 - b1).cross(b3 - b1).normalized()
	st.set_normal(n_base)
	st.add_vertex(b1)
	st.add_vertex(b3)
	st.add_vertex(b2)


func normalize_mesh_ground(mesh: ArrayMesh) -> ArrayMesh:
	var min_y: float = 999999.0
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		if arrays.size() > Mesh.ARRAY_VERTEX:
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for v in verts:
				if v.y < min_y:
					min_y = v.y
	
	if absf(min_y) > 0.0001 and min_y < 999998.0:
		var normalized_mesh := ArrayMesh.new()
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in range(verts.size()):
				verts[i].y -= min_y
			arrays[Mesh.ARRAY_VERTEX] = verts
			normalized_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			normalized_mesh.surface_set_material(s, mesh.surface_get_material(s))
		return normalized_mesh
	return mesh


# ==============================================================================
# 1. MARINE MESHES
# ==============================================================================

func _build_marine_body() -> void:
	var mesh := ArrayMesh.new()
	
	var st_armor := SurfaceTool.new()
	st_armor.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tapered_box(st_armor, Vector3(0, 1.15, -0.02), Vector3(0.54, 0.35, 0.38), Vector3(0.62, 0.35, 0.44))
	_add_box(st_armor, Vector3(0, 0.88, 0.0), Vector3(0.48, 0.22, 0.34))
	_add_tapered_box(st_armor, Vector3(0, 0.68, 0.0), Vector3(0.38, 0.18, 0.30), Vector3(0.46, 0.18, 0.32))
	_add_box(st_armor, Vector3(-0.44, 1.32, 0.0), Vector3(0.28, 0.28, 0.38))
	_add_box(st_armor, Vector3(0.44, 1.32, 0.0), Vector3(0.28, 0.28, 0.38))
	_add_box(st_armor, Vector3(-0.46, 1.44, 0.0), Vector3(0.22, 0.06, 0.34))
	_add_box(st_armor, Vector3(0.46, 1.44, 0.0), Vector3(0.22, 0.06, 0.34))
	_add_box(st_armor, Vector3(-0.38, 1.08, -0.02), Vector3(0.18, 0.24, 0.20))
	_add_box(st_armor, Vector3(0.38, 1.08, -0.02), Vector3(0.18, 0.24, 0.20))
	_add_box(st_armor, Vector3(-0.34, 0.90, -0.18), Vector3(0.16, 0.18, 0.30))
	_add_box(st_armor, Vector3(0.34, 0.90, -0.18), Vector3(0.16, 0.18, 0.30))
	_add_box(st_armor, Vector3(-0.20, 0.48, 0.0), Vector3(0.20, 0.28, 0.24))
	_add_box(st_armor, Vector3(0.20, 0.48, 0.0), Vector3(0.20, 0.28, 0.24))
	_add_box(st_armor, Vector3(-0.20, 0.38, -0.12), Vector3(0.18, 0.14, 0.12))
	_add_box(st_armor, Vector3(0.20, 0.38, -0.12), Vector3(0.18, 0.14, 0.12))
	_add_box(st_armor, Vector3(-0.20, 0.20, -0.02), Vector3(0.22, 0.26, 0.24))
	_add_box(st_armor, Vector3(0.20, 0.20, -0.02), Vector3(0.22, 0.26, 0.24))
	_add_box(st_armor, Vector3(-0.20, 0.06, -0.04), Vector3(0.24, 0.12, 0.36))
	_add_box(st_armor, Vector3(0.20, 0.06, -0.04), Vector3(0.24, 0.12, 0.36))
	_add_box(st_armor, Vector3(0, 1.58, 0.02), Vector3(0.36, 0.32, 0.36))
	_add_box(st_armor, Vector3(0, 1.72, 0.02), Vector3(0.28, 0.08, 0.28))
	st_armor.generate_normals()
	st_armor.generate_tangents()
	st_armor.set_material(mat_marine_armor)
	st_armor.commit(mesh)
	
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_steel, Vector3(0, 1.40, -0.05), Vector3(0.26, 0.12, 0.24))
	_add_box(st_steel, Vector3(0, 1.20, -0.21), Vector3(0.32, 0.14, 0.04))
	_add_box(st_steel, Vector3(0, 1.22, 0.26), Vector3(0.44, 0.44, 0.24))
	_add_cylinder(st_steel, Vector3(-0.18, 1.32, 0.36), 0.08, 0.28, 8)
	_add_cylinder(st_steel, Vector3(0.18, 1.32, 0.36), 0.08, 0.28, 8)
	_add_box(st_steel, Vector3(-0.36, 0.98, -0.05), Vector3(0.14, 0.10, 0.16))
	_add_box(st_steel, Vector3(0.36, 0.98, -0.05), Vector3(0.14, 0.10, 0.16))
	_add_box(st_steel, Vector3(-0.20, 0.34, 0.0), Vector3(0.16, 0.08, 0.18))
	_add_box(st_steel, Vector3(0.20, 0.34, 0.0), Vector3(0.16, 0.08, 0.18))
	_add_box(st_steel, Vector3(-0.30, 0.88, -0.32), Vector3(0.14, 0.12, 0.14))
	_add_box(st_steel, Vector3(0.26, 0.92, -0.36), Vector3(0.14, 0.12, 0.14))
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_marine_steel)
	st_steel.commit(mesh)
	
	var st_visor := SurfaceTool.new()
	st_visor.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_visor, Vector3(0, 1.56, -0.16), Vector3(0.26, 0.12, 0.04))
	st_visor.generate_normals()
	st_visor.generate_tangents()
	st_visor.set_material(mat_marine_visor)
	st_visor.commit(mesh)
	
	var st_thruster := SurfaceTool.new()
	st_thruster.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st_thruster, Vector3(-0.18, 1.18, 0.36), 0.065, 0.04, 8)
	_add_cylinder(st_thruster, Vector3(0.18, 1.18, 0.36), 0.065, 0.04, 8)
	st_thruster.generate_normals()
	st_thruster.generate_tangents()
	st_thruster.set_material(mat_marine_thruster)
	st_thruster.commit(mesh)
	
	mesh = normalize_mesh_ground(mesh)
	ResourceSaver.save(mesh, MARINE_BODY_PATH)
	print("[ModelGenerator] Saved: ", MARINE_BODY_PATH)


func _build_c14_rifle() -> void:
	var mesh := ArrayMesh.new()
	
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_steel, Vector3(0, 0, -0.02), Vector3(0.14, 0.18, 0.46))
	_add_box(st_steel, Vector3(0, 0.02, -0.32), Vector3(0.10, 0.12, 0.24))
	_add_cylinder(st_steel, Vector3(0, 0.04, -0.46), 0.025, 0.08, 8)
	_add_cylinder(st_steel, Vector3(0, -0.02, -0.46), 0.025, 0.08, 8)
	_add_box(st_steel, Vector3(0, 0.12, -0.06), Vector3(0.06, 0.06, 0.32))
	_add_box(st_steel, Vector3(0, -0.02, 0.24), Vector3(0.10, 0.16, 0.16))
	_add_box(st_steel, Vector3(0, -0.14, 0.10), Vector3(0.06, 0.14, 0.08))
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_marine_steel)
	st_steel.commit(mesh)
	
	var st_armor := SurfaceTool.new()
	st_armor.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_armor, Vector3(0, -0.15, -0.08), Vector3(0.12, 0.18, 0.18))
	_add_box(st_armor, Vector3(-0.075, 0.01, -0.04), Vector3(0.02, 0.14, 0.28))
	_add_box(st_armor, Vector3(0.075, 0.01, -0.04), Vector3(0.02, 0.14, 0.28))
	st_armor.generate_normals()
	st_armor.generate_tangents()
	st_armor.set_material(mat_marine_armor)
	st_armor.commit(mesh)
	
	ResourceSaver.save(mesh, MARINE_RIFLE_PATH)
	print("[ModelGenerator] Saved: ", MARINE_RIFLE_PATH)


# ==============================================================================
# 2. RAYNOR MESHES
# ==============================================================================

func _build_raynor_body() -> void:
	var mesh := ArrayMesh.new()
	var s: float = 1.08
	
	var st_armor := SurfaceTool.new()
	st_armor.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tapered_box(st_armor, Vector3(0, 1.16 * s, -0.02 * s), Vector3(0.56, 0.36, 0.40) * s, Vector3(0.66, 0.36, 0.46) * s)
	_add_box(st_armor, Vector3(0, 0.88 * s, 0.0), Vector3(0.50, 0.22, 0.36) * s)
	_add_tapered_box(st_armor, Vector3(0, 0.68 * s, 0.0), Vector3(0.40, 0.18, 0.32) * s, Vector3(0.48, 0.18, 0.34) * s)
	_add_box(st_armor, Vector3(-0.48 * s, 1.34 * s, 0.0), Vector3(0.32, 0.30, 0.42) * s)
	_add_box(st_armor, Vector3(0.48 * s, 1.34 * s, 0.0), Vector3(0.32, 0.30, 0.42) * s)
	_add_box(st_armor, Vector3(-0.42 * s, 1.08 * s, -0.02 * s), Vector3(0.20, 0.24, 0.22) * s)
	_add_box(st_armor, Vector3(0.42 * s, 1.08 * s, -0.02 * s), Vector3(0.20, 0.24, 0.22) * s)
	_add_box(st_armor, Vector3(-0.36 * s, 0.90 * s, -0.18 * s), Vector3(0.18, 0.20, 0.32) * s)
	_add_box(st_armor, Vector3(0.36 * s, 0.90 * s, -0.18 * s), Vector3(0.18, 0.20, 0.32) * s)
	_add_box(st_armor, Vector3(-0.22 * s, 0.48 * s, 0.0), Vector3(0.22, 0.28, 0.26) * s)
	_add_box(st_armor, Vector3(0.22 * s, 0.48 * s, 0.0), Vector3(0.22, 0.28, 0.26) * s)
	_add_box(st_armor, Vector3(-0.22 * s, 0.38 * s, -0.13 * s), Vector3(0.20, 0.14, 0.14) * s)
	_add_box(st_armor, Vector3(0.22 * s, 0.38 * s, -0.13 * s), Vector3(0.20, 0.14, 0.14) * s)
	_add_box(st_armor, Vector3(-0.22 * s, 0.20 * s, -0.02 * s), Vector3(0.24, 0.26, 0.26) * s)
	_add_box(st_armor, Vector3(0.22 * s, 0.20 * s, -0.02 * s), Vector3(0.24, 0.26, 0.26) * s)
	_add_box(st_armor, Vector3(-0.22 * s, 0.06 * s, -0.04 * s), Vector3(0.26, 0.12, 0.38) * s)
	_add_box(st_armor, Vector3(0.22 * s, 0.06 * s, -0.04 * s), Vector3(0.26, 0.12, 0.38) * s)
	_add_box(st_armor, Vector3(0, 1.58 * s, 0.02 * s), Vector3(0.38, 0.34, 0.38) * s)
	_add_box(st_armor, Vector3(0, 1.74 * s, 0.02 * s), Vector3(0.30, 0.08, 0.30) * s)
	st_armor.generate_normals()
	st_armor.generate_tangents()
	st_armor.set_material(mat_raynor_armor)
	st_armor.commit(mesh)
	
	var st_brass := SurfaceTool.new()
	st_brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_brass, Vector3(-0.50 * s, 1.48 * s, 0.0), Vector3(0.24, 0.08, 0.38) * s)
	_add_box(st_brass, Vector3(0.50 * s, 1.48 * s, 0.0), Vector3(0.24, 0.08, 0.38) * s)
	_add_box(st_brass, Vector3(0, 1.30 * s, -0.22 * s), Vector3(0.28, 0.06, 0.06) * s)
	_add_box(st_brass, Vector3(0, 1.22 * s, -0.22 * s), Vector3(0.18, 0.05, 0.06) * s)
	_add_box(st_brass, Vector3(-0.22 * s, 0.38 * s, -0.18 * s), Vector3(0.14, 0.08, 0.04) * s)
	_add_box(st_brass, Vector3(0.22 * s, 0.38 * s, -0.18 * s), Vector3(0.14, 0.08, 0.04) * s)
	st_brass.generate_normals()
	st_brass.generate_tangents()
	st_brass.set_material(mat_raynor_brass)
	st_brass.commit(mesh)
	
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_steel, Vector3(0, 1.24 * s, 0.28 * s), Vector3(0.48, 0.46, 0.26) * s)
	_add_cylinder(st_steel, Vector3(-0.20 * s, 1.34 * s, 0.38 * s), 0.09 * s, 0.32 * s, 8)
	_add_cylinder(st_steel, Vector3(0.20 * s, 1.34 * s, 0.38 * s), 0.09 * s, 0.32 * s, 8)
	_add_box(st_steel, Vector3(-0.32 * s, 0.88 * s, -0.34 * s), Vector3(0.16, 0.14, 0.16) * s)
	_add_box(st_steel, Vector3(0.28 * s, 0.92 * s, -0.38 * s), Vector3(0.16, 0.14, 0.16) * s)
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_marine_steel)
	st_steel.commit(mesh)
	
	var st_visor := SurfaceTool.new()
	st_visor.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_visor, Vector3(0, 1.57 * s, -0.17 * s), Vector3(0.28, 0.14, 0.04) * s)
	st_visor.generate_normals()
	st_visor.generate_tangents()
	st_visor.set_material(mat_raynor_visor)
	st_visor.commit(mesh)
	
	var st_thruster := SurfaceTool.new()
	st_thruster.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st_thruster, Vector3(-0.20 * s, 1.18 * s, 0.38 * s), 0.075 * s, 0.05 * s, 8)
	_add_cylinder(st_thruster, Vector3(0.20 * s, 1.18 * s, 0.38 * s), 0.075 * s, 0.05 * s, 8)
	st_thruster.generate_normals()
	st_thruster.generate_tangents()
	st_thruster.set_material(mat_marine_thruster)
	st_thruster.commit(mesh)
	
	mesh = normalize_mesh_ground(mesh)
	ResourceSaver.save(mesh, RAYNOR_BODY_PATH)
	print("[ModelGenerator] Saved: ", RAYNOR_BODY_PATH)


func _build_raynor_rifle() -> void:
	var mesh := ArrayMesh.new()
	
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_steel, Vector3(0, 0, -0.04), Vector3(0.16, 0.20, 0.52))
	_add_box(st_steel, Vector3(0, 0.02, -0.38), Vector3(0.11, 0.13, 0.30))
	_add_cylinder(st_steel, Vector3(0, 0.02, -0.54), 0.035, 0.10, 8)
	_add_box(st_steel, Vector3(0, -0.02, 0.28), Vector3(0.12, 0.18, 0.18))
	_add_box(st_steel, Vector3(0, -0.16, 0.12), Vector3(0.07, 0.16, 0.09))
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_marine_steel)
	st_steel.commit(mesh)
	
	var st_brass := SurfaceTool.new()
	st_brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st_brass, Vector3(0, 0.16, -0.10), 0.04, 0.28, 8)
	_add_box(st_brass, Vector3(0, 0.12, -0.18), Vector3(0.05, 0.06, 0.04))
	_add_box(st_brass, Vector3(0, 0.12, -0.02), Vector3(0.05, 0.06, 0.04))
	_add_box(st_brass, Vector3(-0.085, 0.01, -0.05), Vector3(0.015, 0.12, 0.32))
	_add_box(st_brass, Vector3(0.085, 0.01, -0.05), Vector3(0.015, 0.12, 0.32))
	st_brass.generate_normals()
	st_brass.generate_tangents()
	st_brass.set_material(mat_raynor_brass)
	st_brass.commit(mesh)
	
	var st_visor := SurfaceTool.new()
	st_visor.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_visor, Vector3(0, 0.16, -0.245), Vector3(0.05, 0.05, 0.01))
	st_visor.generate_normals()
	st_visor.generate_tangents()
	st_visor.set_material(mat_raynor_visor)
	st_visor.commit(mesh)
	
	ResourceSaver.save(mesh, RAYNOR_RIFLE_PATH)
	print("[ModelGenerator] Saved: ", RAYNOR_RIFLE_PATH)


# ==============================================================================
# 3. ZERG SWARM MESHES (ZERGLING, ROACH, BANELING, HYDRALISK)
# ==============================================================================

func _build_zergling_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var col_carapace := Color(1.0, 0.0, 0.0, 1.0)
	var col_flesh := Color(0.0, 0.0, 0.0, 1.0)
	var col_glow := Color(0.0, 1.0, 0.0, 1.0)
	
	_add_tapered_box(st, Vector3(0, 0.45, -0.44), Vector3(0.24, 0.14, 0.26), Vector3(0.18, 0.12, 0.22), col_carapace)
	_add_box(st, Vector3(0, 0.36, -0.52), Vector3(0.14, 0.08, 0.18), col_flesh)
	_add_wedge(st, Vector3(-0.16, 0.38, -0.64), Vector3(-0.10, 0.42, -0.46), Vector3(-0.14, 0.34, -0.46), Vector3(-0.06, 0.38, -0.46), col_carapace)
	_add_wedge(st, Vector3(0.16, 0.38, -0.64), Vector3(0.10, 0.42, -0.46), Vector3(0.06, 0.38, -0.46), Vector3(0.14, 0.34, -0.46), col_carapace)
	_add_box(st, Vector3(-0.11, 0.44, -0.48), Vector3(0.05, 0.04, 0.08), col_glow)
	_add_box(st, Vector3(0.11, 0.44, -0.48), Vector3(0.05, 0.04, 0.08), col_glow)
	
	_add_box(st, Vector3(0, 0.48, -0.15), Vector3(0.36, 0.24, 0.38), col_carapace)
	_add_wedge(st, Vector3(0, 0.68, -0.22), Vector3(-0.06, 0.58, -0.28), Vector3(0.06, 0.58, -0.28), Vector3(0, 0.58, -0.14), col_carapace)
	_add_wedge(st, Vector3(0, 0.66, -0.06), Vector3(-0.06, 0.58, -0.12), Vector3(0.06, 0.58, -0.12), Vector3(0, 0.58, 0.02), col_carapace)
	_add_box(st, Vector3(0, 0.32, -0.15), Vector3(0.26, 0.12, 0.34), col_flesh)
	
	_add_wedge(st, Vector3(-0.16, 0.78, -0.18), Vector3(-0.12, 0.56, -0.10), Vector3(-0.18, 0.56, -0.08), Vector3(-0.14, 0.56, -0.16), col_carapace)
	_add_wedge(st, Vector3(-0.18, 0.92, -0.36), Vector3(-0.14, 0.74, -0.22), Vector3(-0.20, 0.74, -0.20), Vector3(-0.16, 0.74, -0.26), col_carapace)
	_add_wedge(st, Vector3(0.16, 0.78, -0.18), Vector3(0.12, 0.56, -0.10), Vector3(0.14, 0.56, -0.16), Vector3(0.18, 0.56, -0.08), col_carapace)
	_add_wedge(st, Vector3(0.18, 0.92, -0.36), Vector3(0.14, 0.74, -0.22), Vector3(0.16, 0.74, -0.26), Vector3(0.20, 0.74, -0.20), col_carapace)
	
	_add_box(st, Vector3(-0.24, 0.32, -0.25), Vector3(0.10, 0.18, 0.12), col_carapace)
	_add_wedge(st, Vector3(-0.28, 0.0, -0.38), Vector3(-0.24, 0.22, -0.26), Vector3(-0.30, 0.22, -0.24), Vector3(-0.26, 0.22, -0.32), col_carapace)
	_add_box(st, Vector3(0.24, 0.32, -0.25), Vector3(0.10, 0.18, 0.12), col_carapace)
	_add_wedge(st, Vector3(0.28, 0.0, -0.38), Vector3(0.24, 0.22, -0.26), Vector3(0.26, 0.22, -0.32), Vector3(0.30, 0.22, -0.24), col_carapace)
	
	_add_box(st, Vector3(-0.26, 0.40, 0.12), Vector3(0.14, 0.24, 0.20), col_flesh)
	_add_wedge(st, Vector3(-0.30, 0.0, 0.14), Vector3(-0.24, 0.28, 0.10), Vector3(-0.32, 0.28, 0.12), Vector3(-0.28, 0.28, 0.20), col_carapace)
	_add_box(st, Vector3(0.26, 0.40, 0.12), Vector3(0.14, 0.24, 0.20), col_flesh)
	_add_wedge(st, Vector3(0.30, 0.0, 0.14), Vector3(0.24, 0.28, 0.10), Vector3(0.28, 0.28, 0.20), Vector3(0.32, 0.28, 0.12), col_carapace)
	
	_add_tapered_box(st, Vector3(0, 0.40, 0.28), Vector3(0.30, 0.22, 0.26), Vector3(0.18, 0.14, 0.20), col_carapace)
	_add_wedge(st, Vector3(0, 0.42, 0.58), Vector3(-0.06, 0.38, 0.38), Vector3(0.06, 0.38, 0.38), Vector3(0, 0.46, 0.38), col_carapace)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_zergling)
	st.commit(mesh)
	
	mesh = normalize_mesh_ground(mesh)
	ResourceSaver.save(mesh, ZERGLING_MESH_PATH)
	print("[ModelGenerator] Saved: ", ZERGLING_MESH_PATH)


func _build_roach_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var col_carapace := Color(1.0, 0.0, 0.0, 1.0)
	var col_flesh := Color(0.0, 0.0, 0.0, 1.0)
	var col_bile := Color(0.0, 1.0, 0.0, 1.0)
	
	_add_tapered_box(st, Vector3(0, 0.56, 0.02), Vector3(0.96, 0.36, 0.88), Vector3(0.72, 0.28, 0.68), col_carapace)
	_add_tapered_box(st, Vector3(0, 0.50, 0.38), Vector3(0.82, 0.28, 0.36), Vector3(0.56, 0.20, 0.28), col_carapace)
	_add_wedge(st, Vector3(0, 0.78, -0.10), Vector3(-0.10, 0.68, -0.24), Vector3(0.10, 0.68, -0.24), Vector3(0, 0.68, 0.04), col_carapace)
	_add_wedge(st, Vector3(0, 0.74, 0.16), Vector3(-0.08, 0.66, 0.04), Vector3(0.08, 0.66, 0.04), Vector3(0, 0.66, 0.28), col_carapace)
	
	_add_box(st, Vector3(-0.24, 0.65, 0.05), Vector3(0.08, 0.06, 0.14), col_bile)
	_add_box(st, Vector3(0.24, 0.65, 0.05), Vector3(0.08, 0.06, 0.14), col_bile)
	_add_box(st, Vector3(-0.18, 0.62, 0.24), Vector3(0.06, 0.05, 0.12), col_bile)
	_add_box(st, Vector3(0.18, 0.62, 0.24), Vector3(0.06, 0.05, 0.12), col_bile)
	
	_add_box(st, Vector3(0, 0.32, 0.0), Vector3(0.68, 0.18, 0.74), col_flesh)
	
	_add_tapered_box(st, Vector3(0, 0.40, -0.52), Vector3(0.52, 0.22, 0.32), Vector3(0.36, 0.16, 0.26), col_carapace)
	_add_box(st, Vector3(0, 0.30, -0.68), Vector3(0.22, 0.10, 0.14), col_bile)
	_add_wedge(st, Vector3(-0.24, 0.30, -0.76), Vector3(-0.14, 0.36, -0.58), Vector3(-0.22, 0.26, -0.58), Vector3(-0.10, 0.26, -0.58), col_carapace)
	_add_wedge(st, Vector3(0.24, 0.30, -0.76), Vector3(0.14, 0.36, -0.58), Vector3(0.10, 0.26, -0.58), Vector3(0.22, 0.26, -0.58), col_carapace)
	
	_add_box(st, Vector3(-0.48, 0.32, -0.32), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(-0.58, 0.0, -0.46), Vector3(-0.42, 0.24, -0.34), Vector3(-0.52, 0.24, -0.28), Vector3(-0.46, 0.24, -0.40), col_carapace)
	_add_box(st, Vector3(0.48, 0.32, -0.32), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(0.58, 0.0, -0.46), Vector3(0.42, 0.24, -0.34), Vector3(0.46, 0.24, -0.40), Vector3(0.52, 0.24, -0.28), col_carapace)
	
	_add_box(st, Vector3(-0.52, 0.32, 0.04), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(-0.64, 0.0, 0.04), Vector3(-0.46, 0.24, 0.10), Vector3(-0.54, 0.24, 0.06), Vector3(-0.48, 0.24, -0.04), col_carapace)
	_add_box(st, Vector3(0.52, 0.32, 0.04), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(0.64, 0.0, 0.04), Vector3(0.46, 0.24, 0.10), Vector3(0.48, 0.24, -0.04), Vector3(0.54, 0.24, 0.06), col_carapace)
	
	_add_box(st, Vector3(-0.48, 0.32, 0.36), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(-0.58, 0.0, 0.48), Vector3(-0.42, 0.24, 0.42), Vector3(-0.52, 0.24, 0.36), Vector3(-0.44, 0.24, 0.30), col_carapace)
	_add_box(st, Vector3(0.48, 0.32, 0.36), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(0.58, 0.0, 0.48), Vector3(0.42, 0.24, 0.42), Vector3(0.44, 0.24, 0.30), Vector3(0.52, 0.24, 0.36), col_carapace)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_roach)
	st.commit(mesh)
	
	mesh = normalize_mesh_ground(mesh)
	ResourceSaver.save(mesh, ROACH_MESH_PATH)
	print("[ModelGenerator] Saved: ", ROACH_MESH_PATH)


func _build_baneling_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var col_carapace := Color(1.0, 0.0, 0.0, 1.0)
	var col_flesh := Color(0.0, 0.0, 0.0, 1.0)
	var col_glow := Color(0.0, 1.0, 0.0, 1.0)
	
	# 1. Curled Head Shield & Jaws
	_add_tapered_box(st, Vector3(0, 0.35, -0.38), Vector3(0.38, 0.28, 0.26), Vector3(0.24, 0.20, 0.20), col_carapace)
	_add_box(st, Vector3(0, 0.22, -0.42), Vector3(0.18, 0.12, 0.16), col_glow)
	_add_wedge(st, Vector3(-0.16, 0.16, -0.48), Vector3(-0.10, 0.28, -0.34), Vector3(-0.18, 0.24, -0.34), Vector3(-0.12, 0.18, -0.34), col_carapace)
	_add_wedge(st, Vector3(0.16, 0.16, -0.48), Vector3(0.10, 0.28, -0.34), Vector3(0.12, 0.18, -0.34), Vector3(0.18, 0.24, -0.34), col_carapace)
	
	# 2. Caustic Acid Blister Sacs
	_add_box(st, Vector3(0, 0.56, 0.06), Vector3(0.68, 0.46, 0.58), col_glow)
	_add_tapered_box(st, Vector3(0, 0.76, 0.08), Vector3(0.50, 0.20, 0.44), Vector3(0.32, 0.12, 0.30), col_glow)
	_add_box(st, Vector3(-0.30, 0.50, 0.10), Vector3(0.22, 0.32, 0.36), col_glow)
	_add_box(st, Vector3(0.30, 0.50, 0.10), Vector3(0.22, 0.32, 0.36), col_glow)
	_add_box(st, Vector3(0, 0.44, 0.36), Vector3(0.44, 0.32, 0.32), col_glow)
	
	# 3. Chitinous Underside Cradle & Struts
	_add_box(st, Vector3(0, 0.26, 0.05), Vector3(0.52, 0.16, 0.58), col_flesh)
	_add_box(st, Vector3(-0.28, 0.32, 0.05), Vector3(0.12, 0.14, 0.56), col_carapace)
	_add_box(st, Vector3(0.28, 0.32, 0.05), Vector3(0.12, 0.14, 0.56), col_carapace)
	
	# 4. Vestigial Quadrupedal Rolling Claws (flush at y=0.0)
	_add_wedge(st, Vector3(-0.24, 0.0, -0.22), Vector3(-0.18, 0.20, -0.16), Vector3(-0.26, 0.20, -0.14), Vector3(-0.22, 0.20, -0.24), col_carapace)
	_add_wedge(st, Vector3(0.24, 0.0, -0.22), Vector3(0.18, 0.20, -0.16), Vector3(0.22, 0.20, -0.24), Vector3(0.26, 0.20, -0.14), col_carapace)
	_add_wedge(st, Vector3(-0.26, 0.0, 0.22), Vector3(-0.20, 0.20, 0.16), Vector3(-0.28, 0.20, 0.18), Vector3(-0.24, 0.20, 0.26), col_carapace)
	_add_wedge(st, Vector3(0.26, 0.0, 0.22), Vector3(0.20, 0.20, 0.16), Vector3(0.24, 0.20, 0.26), Vector3(0.28, 0.20, 0.18), col_carapace)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_baneling)
	st.commit(mesh)
	
	mesh = normalize_mesh_ground(mesh)
	ResourceSaver.save(mesh, BANELING_MESH_PATH)
	print("[ModelGenerator] Saved: ", BANELING_MESH_PATH)


func _build_hydralisk_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var col_carapace := Color(1.0, 0.0, 0.0, 1.0)
	var col_flesh := Color(0.0, 0.0, 0.0, 1.0)
	var col_glow := Color(0.0, 1.0, 0.0, 1.0)
	
	# 1. Serpentine Slithering Tail
	_add_tapered_box(st, Vector3(0, 0.22, 0.05), Vector3(0.52, 0.26, 0.35), Vector3(0.44, 0.22, 0.30), col_carapace)
	_add_tapered_box(st, Vector3(0, 0.16, 0.35), Vector3(0.42, 0.20, 0.35), Vector3(0.32, 0.15, 0.30), col_carapace)
	_add_wedge(st, Vector3(0, 0.08, 0.82), Vector3(-0.14, 0.0, 0.52), Vector3(0.14, 0.0, 0.52), Vector3(0, 0.16, 0.52), col_carapace)
	_add_box(st, Vector3(0, 0.04, 0.25), Vector3(0.30, 0.08, 0.60), col_flesh)
	
	# 2. Upright Muscular Torso & Chest
	_add_tapered_box(st, Vector3(0, 0.48, -0.05), Vector3(0.40, 0.32, 0.30), Vector3(0.36, 0.30, 0.26), col_flesh)
	_add_box(st, Vector3(0, 0.78, -0.12), Vector3(0.44, 0.36, 0.32), col_carapace)
	
	# 3. Flared Armored Cranial Hood (Crest)
	_add_tapered_box(st, Vector3(0, 1.10, -0.32), Vector3(0.28, 0.22, 0.28), Vector3(0.20, 0.16, 0.22), col_carapace)
	_add_wedge(st, Vector3(-0.35, 1.38, -0.15), Vector3(-0.12, 1.18, -0.25), Vector3(-0.16, 1.10, -0.08), Vector3(-0.06, 1.25, -0.10), col_carapace)
	_add_wedge(st, Vector3(0.35, 1.38, -0.15), Vector3(0.12, 1.18, -0.25), Vector3(0.06, 1.25, -0.10), Vector3(0.16, 1.10, -0.08), col_carapace)
	# Amber Eyes
	_add_box(st, Vector3(-0.12, 1.12, -0.36), Vector3(0.04, 0.04, 0.06), col_glow)
	_add_box(st, Vector3(0.12, 1.12, -0.36), Vector3(0.04, 0.04, 0.06), col_glow)
	
	# 4. Dorsal Spine Launchers
	_add_box(st, Vector3(-0.10, 0.92, -0.02), Vector3(0.08, 0.12, 0.22), col_glow)
	_add_box(st, Vector3(0.10, 0.92, -0.02), Vector3(0.08, 0.12, 0.22), col_glow)
	
	# 5. Twin Scythe Claws
	_add_box(st, Vector3(-0.32, 0.82, -0.14), Vector3(0.12, 0.24, 0.14), col_carapace)
	_add_wedge(st, Vector3(-0.38, 0.42, -0.45), Vector3(-0.30, 0.72, -0.22), Vector3(-0.36, 0.70, -0.16), Vector3(-0.28, 0.68, -0.24), col_carapace)
	_add_box(st, Vector3(0.32, 0.82, -0.14), Vector3(0.12, 0.24, 0.14), col_carapace)
	_add_wedge(st, Vector3(0.38, 0.42, -0.45), Vector3(0.30, 0.72, -0.22), Vector3(0.28, 0.68, -0.24), Vector3(0.36, 0.70, -0.16), col_carapace)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_hydralisk)
	st.commit(mesh)
	
	mesh = normalize_mesh_ground(mesh)
	ResourceSaver.save(mesh, HYDRALISK_MESH_PATH)
	print("[ModelGenerator] Saved: ", HYDRALISK_MESH_PATH)


func _build_auto_turret_mesh() -> void:
	var mesh := ArrayMesh.new()
	
	# Surface 0: Base & Chassis (Hull material)
	var st_hull := SurfaceTool.new()
	st_hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st_hull, Vector3(0, 0.20, 0), 0.35, 0.40, 12)
	# 3 Tripod stabilizer footpads
	_add_box(st_hull, Vector3(0, 0.06, -0.65), Vector3(0.24, 0.12, 0.35))
	_add_box(st_hull, Vector3(-0.55, 0.06, 0.40), Vector3(0.24, 0.12, 0.35))
	_add_box(st_hull, Vector3(0.55, 0.06, 0.40), Vector3(0.24, 0.12, 0.35))
	# Struts
	_add_box(st_hull, Vector3(0, 0.14, -0.35), Vector3(0.12, 0.12, 0.35))
	_add_box(st_hull, Vector3(-0.28, 0.14, 0.20), Vector3(0.30, 0.12, 0.12))
	_add_box(st_hull, Vector3(0.28, 0.14, 0.20), Vector3(0.30, 0.12, 0.12))
	st_hull.generate_normals()
	st_hull.generate_tangents()
	st_hull.set_material(mat_hull)
	st_hull.commit(mesh)
	
	# Surface 1: Turret Head & Twin Gatlings (Dark steel material)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_steel, Vector3(0, 0.70, 0), Vector3(0.55, 0.45, 0.65))
	_add_cylinder(st_steel, Vector3(-0.18, 0.70, -0.55), 0.05, 0.60, 8)
	_add_cylinder(st_steel, Vector3(0.18, 0.70, -0.55), 0.05, 0.60, 8)
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_dark_steel)
	st_steel.commit(mesh)
	
	# Surface 2: Optic Sensor (Blue glow)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_glow, Vector3(0, 0.88, -0.22), Vector3(0.18, 0.12, 0.18))
	st_glow.generate_normals()
	st_glow.generate_tangents()
	st_glow.set_material(mat_blue_glow)
	st_glow.commit(mesh)
	
	mesh = normalize_mesh_ground(mesh)
	ResourceSaver.save(mesh, AUTO_TURRET_MESH_PATH)
	ResourceSaver.save(mesh, AUTO_TURRET_STRUCT_PATH)
	print("[ModelGenerator] Saved: ", AUTO_TURRET_MESH_PATH)


func _ensure_structure_meshes() -> void:
	if not ResourceLoader.exists(CC_MESH_PATH) or not ResourceLoader.exists(BUNKER_MESH_PATH):
		# Create fallback structure meshes if needed
		if not ResourceLoader.exists(CC_MESH_PATH):
			var m_cc := ArrayMesh.new()
			var st_cc := SurfaceTool.new()
			st_cc.begin(Mesh.PRIMITIVE_TRIANGLES)
			_add_box(st_cc, Vector3(0, 2.0, 0), Vector3(8.0, 4.0, 8.0))
			st_cc.generate_normals()
			st_cc.set_material(mat_hull)
			st_cc.commit(m_cc)
			ResourceSaver.save(m_cc, CC_MESH_PATH)
		if not ResourceLoader.exists(BUNKER_MESH_PATH):
			var m_b := ArrayMesh.new()
			var st_b := SurfaceTool.new()
			st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
			_add_box(st_b, Vector3(0, 1.25, 0), Vector3(3.5, 2.5, 3.5))
			st_b.generate_normals()
			st_b.set_material(mat_hull)
			st_b.commit(m_b)
			ResourceSaver.save(m_b, BUNKER_MESH_PATH)


# ==============================================================================
# GLTF EXPORT HELPERS
# ==============================================================================

func _set_owner_recursive(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owner_recursive(child, root)


func _export_scene_to_glb(root: Node, glb_path: String) -> void:
	_set_owner_recursive(root, root)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err != OK:
		printerr("[GLTFExport] Error appending scene for ", glb_path, ": ", err)
		return
	err = doc.write_to_filesystem(state, glb_path)
	if err != OK:
		printerr("[GLTFExport] Error writing GLB to ", glb_path, ": ", err)
		return
	print("[GLTFExport] Exported GLB: ", glb_path)


func _add_pos_track(anim: Animation, path: String, times: Array, values: Array) -> void:
	var idx := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(idx, path)
	for i in range(times.size()):
		anim.track_insert_key(idx, float(times[i]), values[i])


func _add_rot_track(anim: Animation, path: String, times: Array, quats: Array) -> void:
	var idx := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(idx, path)
	anim.track_set_interpolation_type(idx, Animation.INTERPOLATION_LINEAR)
	for i in range(times.size()):
		var q: Quaternion = quats[i]
		anim.track_insert_key(idx, float(times[i]), q.normalized())


func _add_scale_track(anim: Animation, path: String, times: Array, scales: Array) -> void:
	var idx := anim.add_track(Animation.TYPE_SCALE_3D)
	anim.track_set_path(idx, path)
	for i in range(times.size()):
		anim.track_insert_key(idx, float(times[i]), scales[i])


# ==============================================================================
# 4. GLB EXPORTERS (ALL 9 MODELS)
# ==============================================================================

func _export_marine_glb() -> void:
	var root := Node3D.new()
	root.name = "Marine"
	
	var body := MeshInstance3D.new()
	body.name = "BodyMesh"
	body.mesh = load(MARINE_BODY_PATH)
	root.add_child(body)
	
	var rifle := MeshInstance3D.new()
	rifle.name = "RifleMesh"
	rifle.transform.origin = Vector3(0.3, 1.0, -0.4)
	rifle.mesh = load(MARINE_RIFLE_PATH)
	root.add_child(rifle)
	
	var muzzle := Marker3D.new()
	muzzle.name = "MuzzlePoint"
	muzzle.transform.origin = Vector3(0, 0, -0.46)
	rifle.add_child(muzzle)
	
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	
	var lib := AnimationLibrary.new()
	
	# idle
	var anim_idle := Animation.new()
	anim_idle.length = 1.4
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_idle, "BodyMesh:position", [0.0, 0.7, 1.4], [Vector3.ZERO, Vector3(0, 0.03, 0), Vector3.ZERO])
	_add_pos_track(anim_idle, "RifleMesh:position", [0.0, 0.7, 1.4], [Vector3(0.3, 1.0, -0.4), Vector3(0.3, 1.025, -0.4), Vector3(0.3, 1.0, -0.4)])
	lib.add_animation("idle", anim_idle)
	
	# run
	var anim_run := Animation.new()
	anim_run.length = 0.75
	anim_run.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_run, "BodyMesh:position", [0.0, 0.19, 0.38, 0.56, 0.75], [Vector3.ZERO, Vector3(0.04, 0.04, 0), Vector3.ZERO, Vector3(-0.04, 0.04, 0), Vector3.ZERO])
	_add_rot_track(anim_run, "BodyMesh:quaternion", [0.0, 0.19, 0.38, 0.56, 0.75], [Quaternion.IDENTITY, Quaternion(Vector3.UP, 0.05), Quaternion.IDENTITY, Quaternion(Vector3.UP, -0.05), Quaternion.IDENTITY])
	_add_pos_track(anim_run, "RifleMesh:position", [0.0, 0.19, 0.38, 0.56, 0.75], [Vector3(0.3, 1.0, -0.4), Vector3(0.32, 1.04, -0.38), Vector3(0.3, 1.0, -0.4), Vector3(0.28, 1.04, -0.38), Vector3(0.3, 1.0, -0.4)])
	lib.add_animation("run", anim_run)
	lib.add_animation("walk", anim_run.duplicate())
	
	# shoot
	var anim_shoot := Animation.new()
	anim_shoot.length = 0.4
	anim_shoot.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_shoot, "RifleMesh:position", [0.0, 0.08, 0.4], [Vector3(0.3, 1.0, -0.4), Vector3(0.3, 1.02, -0.32), Vector3(0.3, 1.0, -0.4)])
	_add_pos_track(anim_shoot, "BodyMesh:position", [0.0, 0.08, 0.4], [Vector3.ZERO, Vector3(0, 0, 0.02), Vector3.ZERO])
	lib.add_animation("shoot", anim_shoot)
	lib.add_animation("attack", anim_shoot.duplicate())
	
	# death
	var anim_death := Animation.new()
	anim_death.length = 1.0
	anim_death.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_death, "BodyMesh:position", [0.0, 0.5, 1.0], [Vector3.ZERO, Vector3(0, -0.25, 0.3), Vector3(0, -0.5, 0.6)])
	_add_rot_track(anim_death, "BodyMesh:quaternion", [0.0, 0.5, 1.0], [Quaternion.IDENTITY, Quaternion(Vector3.RIGHT, 0.8), Quaternion(Vector3.RIGHT, 1.57)])
	_add_pos_track(anim_death, "RifleMesh:position", [0.0, 0.5, 1.0], [Vector3(0.3, 1.0, -0.4), Vector3(0.45, 0.4, -0.2), Vector3(0.55, 0.05, 0.1)])
	lib.add_animation("death", anim_death)
	
	ap.add_animation_library("", lib)
	_export_scene_to_glb(root, "res://assets/models/marine.glb")
	root.free()


func _export_raynor_glb() -> void:
	var root := Node3D.new()
	root.name = "Raynor"
	
	var body := MeshInstance3D.new()
	body.name = "BodyMesh"
	body.mesh = load(RAYNOR_BODY_PATH)
	root.add_child(body)
	
	var rifle := MeshInstance3D.new()
	rifle.name = "RifleMesh"
	rifle.transform.origin = Vector3(0.35, 1.05, -0.45)
	rifle.mesh = load(RAYNOR_RIFLE_PATH)
	root.add_child(rifle)
	
	var muzzle := Marker3D.new()
	muzzle.name = "MuzzlePoint"
	muzzle.transform.origin = Vector3(0, 0, -0.5)
	rifle.add_child(muzzle)
	
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	
	var lib := AnimationLibrary.new()
	
	# idle
	var anim_idle := Animation.new()
	anim_idle.length = 1.5
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_idle, "BodyMesh:position", [0.0, 0.75, 1.5], [Vector3.ZERO, Vector3(0, 0.035, 0), Vector3.ZERO])
	_add_pos_track(anim_idle, "RifleMesh:position", [0.0, 0.75, 1.5], [Vector3(0.35, 1.05, -0.45), Vector3(0.35, 1.08, -0.45), Vector3(0.35, 1.05, -0.45)])
	lib.add_animation("idle", anim_idle)
	
	# run
	var anim_run := Animation.new()
	anim_run.length = 0.8
	anim_run.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_run, "BodyMesh:position", [0.0, 0.2, 0.4, 0.6, 0.8], [Vector3.ZERO, Vector3(0.05, 0.05, 0), Vector3.ZERO, Vector3(-0.05, 0.05, 0), Vector3.ZERO])
	_add_rot_track(anim_run, "BodyMesh:quaternion", [0.0, 0.2, 0.4, 0.6, 0.8], [Quaternion.IDENTITY, Quaternion(Vector3.UP, 0.05), Quaternion.IDENTITY, Quaternion(Vector3.UP, -0.05), Quaternion.IDENTITY])
	_add_pos_track(anim_run, "RifleMesh:position", [0.0, 0.2, 0.4, 0.6, 0.8], [Vector3(0.35, 1.05, -0.45), Vector3(0.38, 1.10, -0.42), Vector3(0.35, 1.05, -0.45), Vector3(0.32, 1.10, -0.42), Vector3(0.35, 1.05, -0.45)])
	lib.add_animation("run", anim_run)
	lib.add_animation("walk", anim_run.duplicate())
	
	# shoot
	var anim_shoot := Animation.new()
	anim_shoot.length = 0.45
	anim_shoot.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_shoot, "RifleMesh:position", [0.0, 0.09, 0.45], [Vector3(0.35, 1.05, -0.45), Vector3(0.35, 1.08, -0.35), Vector3(0.35, 1.05, -0.45)])
	_add_pos_track(anim_shoot, "BodyMesh:position", [0.0, 0.09, 0.45], [Vector3.ZERO, Vector3(0, 0, 0.03), Vector3.ZERO])
	lib.add_animation("shoot", anim_shoot)
	lib.add_animation("attack", anim_shoot.duplicate())
	
	# death
	var anim_death := Animation.new()
	anim_death.length = 1.2
	anim_death.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_death, "BodyMesh:position", [0.0, 0.6, 1.2], [Vector3.ZERO, Vector3(0, -0.28, 0.35), Vector3(0, -0.55, 0.7)])
	_add_rot_track(anim_death, "BodyMesh:quaternion", [0.0, 0.6, 1.2], [Quaternion.IDENTITY, Quaternion(Vector3.RIGHT, 0.8), Quaternion(Vector3.RIGHT, 1.57)])
	_add_pos_track(anim_death, "RifleMesh:position", [0.0, 0.6, 1.2], [Vector3(0.35, 1.05, -0.45), Vector3(0.50, 0.4, -0.2), Vector3(0.60, 0.05, 0.1)])
	lib.add_animation("death", anim_death)
	
	ap.add_animation_library("", lib)
	_export_scene_to_glb(root, "res://assets/models/raynor.glb")
	root.free()


func _export_zergling_glb() -> void:
	var root := Node3D.new()
	root.name = "Zergling"
	
	var body := MeshInstance3D.new()
	body.name = "BodyMesh"
	body.mesh = load(ZERGLING_MESH_PATH)
	root.add_child(body)
	
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	
	var lib := AnimationLibrary.new()
	
	var anim_idle := Animation.new()
	anim_idle.length = 0.9
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_idle, "BodyMesh:position", [0.0, 0.45, 0.9], [Vector3.ZERO, Vector3(0, 0.04, 0), Vector3.ZERO])
	lib.add_animation("idle", anim_idle)
	
	var anim_run := Animation.new()
	anim_run.length = 0.5
	anim_run.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_run, "BodyMesh:position", [0.0, 0.25, 0.5], [Vector3.ZERO, Vector3(0, 0.06, 0), Vector3.ZERO])
	lib.add_animation("run", anim_run)
	lib.add_animation("walk", anim_run.duplicate())
	
	var anim_attack := Animation.new()
	anim_attack.length = 0.38
	anim_attack.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_attack, "BodyMesh:position", [0.0, 0.15, 0.38], [Vector3.ZERO, Vector3(0, 0.12, -0.20), Vector3.ZERO])
	lib.add_animation("attack", anim_attack)
	lib.add_animation("shoot", anim_attack.duplicate())
	
	var anim_death := Animation.new()
	anim_death.length = 0.7
	anim_death.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_death, "BodyMesh:position", [0.0, 0.35, 0.7], [Vector3.ZERO, Vector3(0, -0.08, 0.10), Vector3(0, -0.15, 0.20)])
	lib.add_animation("death", anim_death)
	
	ap.add_animation_library("", lib)
	_export_scene_to_glb(root, "res://assets/models/zergling.glb")
	root.free()


func _export_roach_glb() -> void:
	var root := Node3D.new()
	root.name = "Roach"
	
	var body := MeshInstance3D.new()
	body.name = "BodyMesh"
	body.mesh = load(ROACH_MESH_PATH)
	root.add_child(body)
	
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	
	var lib := AnimationLibrary.new()
	
	var anim_idle := Animation.new()
	anim_idle.length = 1.1
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_idle, "BodyMesh:position", [0.0, 0.55, 1.1], [Vector3.ZERO, Vector3(0, 0.03, 0), Vector3.ZERO])
	lib.add_animation("idle", anim_idle)
	
	var anim_walk := Animation.new()
	anim_walk.length = 0.9
	anim_walk.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_walk, "BodyMesh:position", [0.0, 0.22, 0.45, 0.68, 0.9], [Vector3.ZERO, Vector3(0.04, 0.03, 0), Vector3.ZERO, Vector3(-0.04, 0.03, 0), Vector3.ZERO])
	lib.add_animation("walk", anim_walk)
	lib.add_animation("run", anim_walk.duplicate())
	
	var anim_attack := Animation.new()
	anim_attack.length = 0.6
	anim_attack.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_attack, "BodyMesh:position", [0.0, 0.25, 0.6], [Vector3.ZERO, Vector3(0, 0.05, 0.08), Vector3(0, 0.02, -0.12)])
	lib.add_animation("attack", anim_attack)
	lib.add_animation("shoot", anim_attack.duplicate())
	
	var anim_death := Animation.new()
	anim_death.length = 0.9
	anim_death.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_death, "BodyMesh:position", [0.0, 0.45, 0.9], [Vector3.ZERO, Vector3(0, -0.06, 0), Vector3(0, -0.12, 0)])
	lib.add_animation("death", anim_death)
	
	ap.add_animation_library("", lib)
	_export_scene_to_glb(root, "res://assets/models/roach.glb")
	root.free()


func _export_baneling_glb() -> void:
	var root := Node3D.new()
	root.name = "Baneling"
	
	var body := MeshInstance3D.new()
	body.name = "BodyMesh"
	body.mesh = load(BANELING_MESH_PATH)
	root.add_child(body)
	
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	
	var lib := AnimationLibrary.new()
	
	var anim_idle := Animation.new()
	anim_idle.length = 0.75
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_idle, "BodyMesh:position", [0.0, 0.375, 0.75], [Vector3.ZERO, Vector3(0, 0.04, 0), Vector3.ZERO])
	lib.add_animation("idle", anim_idle)
	
	var anim_run := Animation.new()
	anim_run.length = 0.45
	anim_run.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_run, "BodyMesh:position", [0.0, 0.225, 0.45], [Vector3.ZERO, Vector3(0, 0.06, 0), Vector3.ZERO])
	lib.add_animation("run", anim_run)
	lib.add_animation("walk", anim_run.duplicate())
	
	var anim_attack := Animation.new()
	anim_attack.length = 0.25
	anim_attack.loop_mode = Animation.LOOP_NONE
	_add_scale_track(anim_attack, "BodyMesh:scale", [0.0, 0.15, 0.25], [Vector3.ONE, Vector3(1.35, 1.35, 1.35), Vector3(0.1, 0.1, 0.1)])
	lib.add_animation("attack", anim_attack)
	lib.add_animation("shoot", anim_attack.duplicate())
	
	var anim_death := Animation.new()
	anim_death.length = 0.6
	anim_death.loop_mode = Animation.LOOP_NONE
	_add_scale_track(anim_death, "BodyMesh:scale", [0.0, 0.3, 0.6], [Vector3.ONE, Vector3(1.2, 0.5, 1.2), Vector3(1.3, 0.15, 1.3)])
	lib.add_animation("death", anim_death)
	
	ap.add_animation_library("", lib)
	_export_scene_to_glb(root, "res://assets/models/baneling.glb")
	root.free()


func _export_hydralisk_glb() -> void:
	var root := Node3D.new()
	root.name = "Hydralisk"
	
	var body := MeshInstance3D.new()
	body.name = "BodyMesh"
	body.mesh = load(HYDRALISK_MESH_PATH)
	root.add_child(body)
	
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	
	var lib := AnimationLibrary.new()
	
	var anim_idle := Animation.new()
	anim_idle.length = 1.3
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_idle, "BodyMesh:position", [0.0, 0.65, 1.3], [Vector3.ZERO, Vector3(0, 0.04, 0), Vector3.ZERO])
	lib.add_animation("idle", anim_idle)
	
	var anim_run := Animation.new()
	anim_run.length = 0.8
	anim_run.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_run, "BodyMesh:position", [0.0, 0.2, 0.4, 0.6, 0.8], [Vector3.ZERO, Vector3(0.05, 0.03, 0), Vector3.ZERO, Vector3(-0.05, 0.03, 0), Vector3.ZERO])
	lib.add_animation("run", anim_run)
	lib.add_animation("walk", anim_run.duplicate())
	
	var anim_shoot := Animation.new()
	anim_shoot.length = 0.5
	anim_shoot.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_shoot, "BodyMesh:position", [0.0, 0.2, 0.5], [Vector3.ZERO, Vector3(0, 0.05, 0.12), Vector3(0, 0.02, -0.18)])
	lib.add_animation("shoot", anim_shoot)
	lib.add_animation("attack", anim_shoot.duplicate())
	
	var anim_death := Animation.new()
	anim_death.length = 1.0
	anim_death.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_death, "BodyMesh:position", [0.0, 0.5, 1.0], [Vector3.ZERO, Vector3(0, -0.15, 0.2), Vector3(0, -0.3, 0.4)])
	_add_rot_track(anim_death, "BodyMesh:quaternion", [0.0, 0.5, 1.0], [Quaternion.IDENTITY, Quaternion(Vector3.RIGHT, 0.7), Quaternion(Vector3.RIGHT, 1.4)])
	lib.add_animation("death", anim_death)
	
	ap.add_animation_library("", lib)
	_export_scene_to_glb(root, "res://assets/models/hydralisk.glb")
	root.free()


func _export_command_center_glb() -> void:
	var root := Node3D.new()
	root.name = "CommandCenter"
	
	var fortress := MeshInstance3D.new()
	fortress.name = "FortressMesh"
	fortress.mesh = load(CC_MESH_PATH)
	root.add_child(fortress)
	
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	
	var lib := AnimationLibrary.new()
	
	var anim_idle := Animation.new()
	anim_idle.length = 2.0
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_idle, "FortressMesh:position", [0.0, 1.0, 2.0], [Vector3.ZERO, Vector3(0, 0.005, 0), Vector3.ZERO])
	lib.add_animation("idle", anim_idle)
	
	var anim_death := Animation.new()
	anim_death.length = 1.5
	anim_death.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_death, "FortressMesh:position", [0.0, 0.75, 1.5], [Vector3.ZERO, Vector3(0, -0.30, 0), Vector3(0, -0.60, 0)])
	lib.add_animation("death", anim_death)
	
	ap.add_animation_library("", lib)
	_export_scene_to_glb(root, "res://assets/models/structures/command_center.glb")
	root.free()


func _export_bunker_glb() -> void:
	var root := Node3D.new()
	root.name = "Bunker"
	
	var bunker_mesh := MeshInstance3D.new()
	bunker_mesh.name = "BunkerMesh"
	bunker_mesh.mesh = load(BUNKER_MESH_PATH)
	root.add_child(bunker_mesh)
	
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	
	var lib := AnimationLibrary.new()
	
	var anim_idle := Animation.new()
	anim_idle.length = 2.0
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	_add_pos_track(anim_idle, "BunkerMesh:position", [0.0, 1.0, 2.0], [Vector3.ZERO, Vector3(0, 0.004, 0), Vector3.ZERO])
	lib.add_animation("idle", anim_idle)
	
	var anim_death := Animation.new()
	anim_death.length = 1.2
	anim_death.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_death, "BunkerMesh:position", [0.0, 0.6, 1.2], [Vector3.ZERO, Vector3(0, -0.20, 0), Vector3(0, -0.40, 0)])
	lib.add_animation("death", anim_death)
	
	ap.add_animation_library("", lib)
	_export_scene_to_glb(root, "res://assets/models/structures/bunker.glb")
	root.free()


func _export_auto_turret_glb() -> void:
	var root := Node3D.new()
	root.name = "AutoTurret"
	
	# Base Assembly
	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := ArrayMesh.new()
	var st_base := SurfaceTool.new()
	st_base.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st_base, Vector3(0, 0.20, 0), 0.35, 0.40, 12)
	_add_box(st_base, Vector3(0, 0.06, -0.65), Vector3(0.24, 0.12, 0.35))
	_add_box(st_base, Vector3(-0.55, 0.06, 0.40), Vector3(0.24, 0.12, 0.35))
	_add_box(st_base, Vector3(0.55, 0.06, 0.40), Vector3(0.24, 0.12, 0.35))
	_add_box(st_base, Vector3(0, 0.14, -0.35), Vector3(0.12, 0.12, 0.35))
	_add_box(st_base, Vector3(-0.28, 0.14, 0.20), Vector3(0.30, 0.12, 0.12))
	_add_box(st_base, Vector3(0.28, 0.14, 0.20), Vector3(0.30, 0.12, 0.12))
	st_base.generate_normals()
	st_base.generate_tangents()
	st_base.set_material(mat_hull)
	st_base.commit(base_mesh)
	base.mesh = normalize_mesh_ground(base_mesh)
	root.add_child(base)
	
	# Turret Head Assembly
	var turret_head := Node3D.new()
	turret_head.name = "TurretHead"
	turret_head.transform.origin = Vector3(0, 0.45, 0)
	root.add_child(turret_head)
	
	var head_mesh := MeshInstance3D.new()
	head_mesh.name = "HeadMesh"
	var h_mesh := ArrayMesh.new()
	
	var st_h := SurfaceTool.new()
	st_h.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_h, Vector3(0, 0.35, 0), Vector3(0.55, 0.45, 0.65))
	_add_cylinder(st_h, Vector3(-0.18, 0.35, -0.55), 0.05, 0.60, 8)
	_add_cylinder(st_h, Vector3(0.18, 0.35, -0.55), 0.05, 0.60, 8)
	st_h.generate_normals()
	st_h.generate_tangents()
	st_h.set_material(mat_dark_steel)
	st_h.commit(h_mesh)
	
	var st_optic := SurfaceTool.new()
	st_optic.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_optic, Vector3(0, 0.52, -0.22), Vector3(0.18, 0.12, 0.18))
	st_optic.generate_normals()
	st_optic.generate_tangents()
	st_optic.set_material(mat_blue_glow)
	st_optic.commit(h_mesh)
	
	head_mesh.mesh = h_mesh
	turret_head.add_child(head_mesh)
	
	var muzzle_left := Marker3D.new()
	muzzle_left.name = "MuzzleLeft"
	muzzle_left.transform.origin = Vector3(-0.18, 0.35, -0.85)
	turret_head.add_child(muzzle_left)
	
	var muzzle_right := Marker3D.new()
	muzzle_right.name = "MuzzleRight"
	muzzle_right.transform.origin = Vector3(0.18, 0.35, -0.85)
	turret_head.add_child(muzzle_right)
	
	# AnimationPlayer
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	
	var lib := AnimationLibrary.new()
	
	var anim_idle := Animation.new()
	anim_idle.length = 2.0
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	_add_rot_track(anim_idle, "TurretHead:quaternion", [0.0, 0.5, 1.0, 1.5, 2.0], [Quaternion.IDENTITY, Quaternion(Vector3.UP, 0.4), Quaternion.IDENTITY, Quaternion(Vector3.UP, -0.4), Quaternion.IDENTITY])
	lib.add_animation("idle", anim_idle)
	
	var anim_shoot := Animation.new()
	anim_shoot.length = 0.35
	anim_shoot.loop_mode = Animation.LOOP_NONE
	_add_pos_track(anim_shoot, "TurretHead/HeadMesh:position", [0.0, 0.08, 0.35], [Vector3.ZERO, Vector3(0, 0, 0.08), Vector3.ZERO])
	lib.add_animation("shoot", anim_shoot)
	lib.add_animation("attack", anim_shoot.duplicate())
	
	var anim_death := Animation.new()
	anim_death.length = 1.0
	anim_death.loop_mode = Animation.LOOP_NONE
	_add_rot_track(anim_death, "TurretHead:quaternion", [0.0, 1.0], [Quaternion.IDENTITY, Quaternion(Vector3(1, 0, 0.5).normalized(), 0.45)])
	lib.add_animation("death", anim_death)
	
	ap.add_animation_library("", lib)
	_export_scene_to_glb(root, "res://assets/models/structures/auto_turret.glb")
	root.free()
