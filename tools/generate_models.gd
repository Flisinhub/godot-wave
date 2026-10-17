extends SceneTree

# Procedural 3D Model & Mesh Generator for Special Forces Elite 5 (SFE5)
# Generates authentic StarCraft II inspired models:
# 1. Terran Marine CMC-400 Powered Armor (Body)
# 2. C-14 Impaler Gauss Rifle
# 3. Jim Raynor Commander Armor (Custom skull visor, brass trim, heroic scale)
# 4. Jim Raynor Custom Heavy Gauss Rifle (Laser module, extended shroud)
# 5. Zergling Swarm Unit (Segmented chitin, raptor blades, claw talons, acid eyes)
# 6. Roach Swarm Unit (Calcified dorsal dome, hexapod chassis, acid ducts)

const MARINE_BODY_PATH := "res://assets/models/marine_body_mesh.tres"
const MARINE_RIFLE_PATH := "res://assets/models/c14_gauss_rifle_mesh.tres"
const RAYNOR_BODY_PATH := "res://assets/models/raynor_body_mesh.tres"
const RAYNOR_RIFLE_PATH := "res://assets/models/raynor_rifle_mesh.tres"
const ZERGLING_MESH_PATH := "res://assets/models/zergling_mesh.tres"
const ROACH_MESH_PATH := "res://assets/models/roach_mesh.tres"

var mat_marine_armor: Material
var mat_marine_steel: Material
var mat_marine_visor: Material
var mat_marine_thruster: Material
var mat_raynor_armor: Material
var mat_raynor_brass: Material
var mat_raynor_visor: Material
var mat_zergling: Material
var mat_roach: Material


func _init() -> void:
	print("[ModelGenerator] Starting authentic 3D model synthesis...")
	_ensure_directories()
	_load_materials()
	
	_build_marine_body()
	_build_c14_rifle()
	_build_raynor_body()
	_build_raynor_rifle()
	_build_zergling_mesh()
	_build_roach_mesh()
	
	print("[ModelGenerator] All 6 models generated and saved successfully!")
	quit(0)


func _ensure_directories() -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets"):
		dir.make_dir("assets")
	if not dir.dir_exists("assets/models"):
		dir.make_dir("assets/models")
	if not dir.dir_exists("assets/materials"):
		dir.make_dir("assets/materials")
	if not dir.dir_exists("assets/shaders"):
		dir.make_dir("assets/shaders")


func _load_materials() -> void:
	mat_marine_armor = load("res://assets/materials/marine_armor_pbr.tres")
	mat_marine_steel = load("res://assets/materials/marine_steel_dark.tres")
	mat_marine_visor = load("res://assets/materials/marine_visor_glow.tres")
	mat_marine_thruster = load("res://assets/materials/marine_thruster_glow.tres")
	mat_raynor_armor = load("res://assets/materials/raynor_armor_pbr.tres")
	mat_raynor_brass = load("res://assets/materials/raynor_brass_trim.tres")
	mat_raynor_visor = load("res://assets/materials/raynor_visor_glow.tres")
	mat_zergling = load("res://assets/materials/zergling_material.tres")
	mat_roach = load("res://assets/materials/roach_material.tres")


# ==============================================================================
# GEOMETRY BUILDER HELPERS
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
	
	# Front (+Z)
	_add_quad(st, v001, v101, v111, v011, Vector3.FORWARD, col)
	# Back (-Z)
	_add_quad(st, v100, v000, v010, v110, Vector3.BACK, col)
	# Top (+Y)
	_add_quad(st, v011, v111, v110, v010, Vector3.UP, col)
	# Bottom (-Y)
	_add_quad(st, v000, v100, v101, v001, Vector3.DOWN, col)
	# Right (+X)
	_add_quad(st, v101, v100, v110, v111, Vector3.RIGHT, col)
	# Left (-X)
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
		
		# Side quad
		var p1 := Vector3(x1, y_bot, z1)
		var p2 := Vector3(x2, y_bot, z2)
		var p3 := Vector3(x2, y_top, z2)
		var p4 := Vector3(x1, y_top, z1)
		_add_quad(st, p1, p2, p3, p4, n_mid, col)
		
		# Top cap
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(Vector3(center.x, y_top, center.z))
		st.set_uv(Vector2(cos(a1) * 0.5 + 0.5, sin(a1) * 0.5 + 0.5))
		st.add_vertex(p4)
		st.set_uv(Vector2(cos(a2) * 0.5 + 0.5, sin(a2) * 0.5 + 0.5))
		st.add_vertex(p3)
		
		# Bottom cap
		st.set_normal(Vector3.DOWN)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(Vector3(center.x, y_bot, center.z))
		st.set_uv(Vector2(cos(a2) * 0.5 + 0.5, sin(a2) * 0.5 + 0.5))
		st.add_vertex(p2)
		st.set_uv(Vector2(cos(a1) * 0.5 + 0.5, sin(a1) * 0.5 + 0.5))
		st.add_vertex(p1)


func _add_wedge(st: SurfaceTool, tip: Vector3, b1: Vector3, b2: Vector3, b3: Vector3, col: Color = Color.WHITE) -> void:
	# Tetrahedron / claw wedge
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


# ==============================================================================
# 1. TERRAN MARINE CMC-400 POWERED ARMOR BODY
# ==============================================================================

func _build_marine_body() -> void:
	var mesh := ArrayMesh.new()
	
	# Surface 1: Blue CMC-400 Powered Armor Shell
	var st_armor := SurfaceTool.new()
	st_armor.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Cuirass / Torso Upper Chest Plate
	_add_tapered_box(st_armor, Vector3(0, 1.15, -0.02), Vector3(0.54, 0.35, 0.38), Vector3(0.62, 0.35, 0.44))
	# Abdominal Armored Segments
	_add_box(st_armor, Vector3(0, 0.88, 0.0), Vector3(0.48, 0.22, 0.34))
	# Pelvic Groin Armor
	_add_tapered_box(st_armor, Vector3(0, 0.68, 0.0), Vector3(0.38, 0.18, 0.30), Vector3(0.46, 0.18, 0.32))
	
	# Massive Rounded Pauldrons (Shoulders)
	_add_box(st_armor, Vector3(-0.44, 1.32, 0.0), Vector3(0.28, 0.28, 0.38))
	_add_box(st_armor, Vector3(0.44, 1.32, 0.0), Vector3(0.28, 0.28, 0.38))
	# Pauldron trim bevels
	_add_box(st_armor, Vector3(-0.46, 1.44, 0.0), Vector3(0.22, 0.06, 0.34))
	_add_box(st_armor, Vector3(0.46, 1.44, 0.0), Vector3(0.22, 0.06, 0.34))
	
	# Upper Arms
	_add_box(st_armor, Vector3(-0.38, 1.08, -0.02), Vector3(0.18, 0.24, 0.20))
	_add_box(st_armor, Vector3(0.38, 1.08, -0.02), Vector3(0.18, 0.24, 0.20))
	# Forearm Armored Gauntlets
	_add_box(st_armor, Vector3(-0.34, 0.90, -0.18), Vector3(0.16, 0.18, 0.30))
	_add_box(st_armor, Vector3(0.34, 0.90, -0.18), Vector3(0.16, 0.18, 0.30))
	
	# Thighs (Cuisses)
	_add_box(st_armor, Vector3(-0.20, 0.48, 0.0), Vector3(0.20, 0.28, 0.24))
	_add_box(st_armor, Vector3(0.20, 0.48, 0.0), Vector3(0.20, 0.28, 0.24))
	# Knee Guards (Poleyns)
	_add_box(st_armor, Vector3(-0.20, 0.38, -0.12), Vector3(0.18, 0.14, 0.12))
	_add_box(st_armor, Vector3(0.20, 0.38, -0.12), Vector3(0.18, 0.14, 0.12))
	# Greaves / Shin Armor
	_add_box(st_armor, Vector3(-0.20, 0.20, -0.02), Vector3(0.22, 0.26, 0.24))
	_add_box(st_armor, Vector3(0.20, 0.20, -0.02), Vector3(0.22, 0.26, 0.24))
	
	# Magnetic Combat Boots (Feet rest flush on Y = 0.0)
	_add_box(st_armor, Vector3(-0.20, 0.06, -0.04), Vector3(0.24, 0.12, 0.36))
	_add_box(st_armor, Vector3(0.20, 0.06, -0.04), Vector3(0.24, 0.12, 0.36))
	
	# Helmet Dome
	_add_box(st_armor, Vector3(0, 1.58, 0.02), Vector3(0.36, 0.32, 0.36))
	_add_box(st_armor, Vector3(0, 1.72, 0.02), Vector3(0.28, 0.08, 0.28))
	
	st_armor.generate_normals()
	st_armor.generate_tangents()
	st_armor.set_material(mat_marine_armor)
	st_armor.commit(mesh)
	
	# Surface 2: Dark Gunmetal Steel (Joints, intake vents, backpack)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Neck Gorget & Respirator
	_add_box(st_steel, Vector3(0, 1.40, -0.05), Vector3(0.26, 0.12, 0.24))
	# Chest Intake Vents
	_add_box(st_steel, Vector3(0, 1.20, -0.21), Vector3(0.32, 0.14, 0.04))
	# Backpack Power Pack Housing
	_add_box(st_steel, Vector3(0, 1.22, 0.26), Vector3(0.44, 0.44, 0.24))
	# Micro-fusion exhaust thruster cylinders (Left & Right)
	_add_cylinder(st_steel, Vector3(-0.18, 1.32, 0.36), 0.08, 0.28, 8)
	_add_cylinder(st_steel, Vector3(0.18, 1.32, 0.36), 0.08, 0.28, 8)
	# Flexible Elbow & Knee Joints
	_add_box(st_steel, Vector3(-0.36, 0.98, -0.05), Vector3(0.14, 0.10, 0.16))
	_add_box(st_steel, Vector3(0.36, 0.98, -0.05), Vector3(0.14, 0.10, 0.16))
	_add_box(st_steel, Vector3(-0.20, 0.34, 0.0), Vector3(0.16, 0.08, 0.18))
	_add_box(st_steel, Vector3(0.20, 0.34, 0.0), Vector3(0.16, 0.08, 0.18))
	# Armored Combat Gloves Gripping Gun
	_add_box(st_steel, Vector3(-0.30, 0.88, -0.32), Vector3(0.14, 0.12, 0.14))
	_add_box(st_steel, Vector3(0.26, 0.92, -0.36), Vector3(0.14, 0.12, 0.14))
	
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_marine_steel)
	st_steel.commit(mesh)
	
	# Surface 3: Tactical Amber Glowing Visor
	var st_visor := SurfaceTool.new()
	st_visor.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_visor, Vector3(0, 1.56, -0.16), Vector3(0.26, 0.12, 0.04))
	st_visor.generate_normals()
	st_visor.generate_tangents()
	st_visor.set_material(mat_marine_visor)
	st_visor.commit(mesh)
	
	# Surface 4: Micro-Fusion Thruster Cyan Glow
	var st_thruster := SurfaceTool.new()
	st_thruster.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st_thruster, Vector3(-0.18, 1.18, 0.36), 0.065, 0.04, 8)
	_add_cylinder(st_thruster, Vector3(0.18, 1.18, 0.36), 0.065, 0.04, 8)
	st_thruster.generate_normals()
	st_thruster.generate_tangents()
	st_thruster.set_material(mat_marine_thruster)
	st_thruster.commit(mesh)
	
	ResourceSaver.save(mesh, MARINE_BODY_PATH)
	print("[ModelGenerator] Saved: ", MARINE_BODY_PATH)


# ==============================================================================
# 2. C-14 IMPALER GAUSS RIFLE
# ==============================================================================

func _build_c14_rifle() -> void:
	var mesh := ArrayMesh.new()
	
	# Surface 1: Gunmetal Steel Body & Barrel
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Main Receiver Chassis (centered at 0, 0, 0 in weapon space)
	_add_box(st_steel, Vector3(0, 0, -0.02), Vector3(0.14, 0.18, 0.46))
	# Perforated Barrel Shroud
	_add_box(st_steel, Vector3(0, 0.02, -0.32), Vector3(0.10, 0.12, 0.24))
	# Dual Muzzle Barrels
	_add_cylinder(st_steel, Vector3(0, 0.04, -0.46), 0.025, 0.08, 8)
	_add_cylinder(st_steel, Vector3(0, -0.02, -0.46), 0.025, 0.08, 8)
	# Upper Optical Rail / Carry Handle
	_add_box(st_steel, Vector3(0, 0.12, -0.06), Vector3(0.06, 0.06, 0.32))
	# Rear Stock
	_add_box(st_steel, Vector3(0, -0.02, 0.24), Vector3(0.10, 0.16, 0.16))
	# Pistol Grip
	_add_box(st_steel, Vector3(0, -0.14, 0.10), Vector3(0.06, 0.14, 0.08))
	
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_marine_steel)
	st_steel.commit(mesh)
	
	# Surface 2: Blue Armor Housing Accents & Ammo Hopper
	var st_armor := SurfaceTool.new()
	st_armor.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Underslung Ammo Magazine Hopper
	_add_box(st_armor, Vector3(0, -0.15, -0.08), Vector3(0.12, 0.18, 0.18))
	# Receiver Side Plating
	_add_box(st_armor, Vector3(-0.075, 0.01, -0.04), Vector3(0.02, 0.14, 0.28))
	_add_box(st_armor, Vector3(0.075, 0.01, -0.04), Vector3(0.02, 0.14, 0.28))
	
	st_armor.generate_normals()
	st_armor.generate_tangents()
	st_armor.set_material(mat_marine_armor)
	st_armor.commit(mesh)
	
	ResourceSaver.save(mesh, MARINE_RIFLE_PATH)
	print("[ModelGenerator] Saved: ", MARINE_RIFLE_PATH)


# ==============================================================================
# 3. JIM RAYNOR COMMANDER HERO ARMOR
# ==============================================================================

func _build_raynor_body() -> void:
	var mesh := ArrayMesh.new()
	var s: float = 1.08 # Raynor heroic scale multiplier
	
	# Surface 1: Commander Midnight Blue Armor
	var st_armor := SurfaceTool.new()
	st_armor.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Cuirass
	_add_tapered_box(st_armor, Vector3(0, 1.16 * s, -0.02 * s), Vector3(0.56, 0.36, 0.40) * s, Vector3(0.66, 0.36, 0.46) * s)
	_add_box(st_armor, Vector3(0, 0.88 * s, 0.0), Vector3(0.50, 0.22, 0.36) * s)
	_add_tapered_box(st_armor, Vector3(0, 0.68 * s, 0.0), Vector3(0.40, 0.18, 0.32) * s, Vector3(0.48, 0.18, 0.34) * s)
	
	# Massive Pauldrons
	_add_box(st_armor, Vector3(-0.48 * s, 1.34 * s, 0.0), Vector3(0.32, 0.30, 0.42) * s)
	_add_box(st_armor, Vector3(0.48 * s, 1.34 * s, 0.0), Vector3(0.32, 0.30, 0.42) * s)
	
	# Arms & Gauntlets
	_add_box(st_armor, Vector3(-0.42 * s, 1.08 * s, -0.02 * s), Vector3(0.20, 0.24, 0.22) * s)
	_add_box(st_armor, Vector3(0.42 * s, 1.08 * s, -0.02 * s), Vector3(0.20, 0.24, 0.22) * s)
	_add_box(st_armor, Vector3(-0.36 * s, 0.90 * s, -0.18 * s), Vector3(0.18, 0.20, 0.32) * s)
	_add_box(st_armor, Vector3(0.36 * s, 0.90 * s, -0.18 * s), Vector3(0.18, 0.20, 0.32) * s)
	
	# Legs
	_add_box(st_armor, Vector3(-0.22 * s, 0.48 * s, 0.0), Vector3(0.22, 0.28, 0.26) * s)
	_add_box(st_armor, Vector3(0.22 * s, 0.48 * s, 0.0), Vector3(0.22, 0.28, 0.26) * s)
	_add_box(st_armor, Vector3(-0.22 * s, 0.38 * s, -0.13 * s), Vector3(0.20, 0.14, 0.14) * s)
	_add_box(st_armor, Vector3(0.22 * s, 0.38 * s, -0.13 * s), Vector3(0.20, 0.14, 0.14) * s)
	_add_box(st_armor, Vector3(-0.22 * s, 0.20 * s, -0.02 * s), Vector3(0.24, 0.26, 0.26) * s)
	_add_box(st_armor, Vector3(0.22 * s, 0.20 * s, -0.02 * s), Vector3(0.24, 0.26, 0.26) * s)
	
	# Heavy Boots resting on Y = 0.0
	_add_box(st_armor, Vector3(-0.22 * s, 0.06 * s, -0.04 * s), Vector3(0.26, 0.12, 0.38) * s)
	_add_box(st_armor, Vector3(0.22 * s, 0.06 * s, -0.04 * s), Vector3(0.26, 0.12, 0.38) * s)
	
	# Helmet
	_add_box(st_armor, Vector3(0, 1.58 * s, 0.02 * s), Vector3(0.38, 0.34, 0.38) * s)
	_add_box(st_armor, Vector3(0, 1.74 * s, 0.02 * s), Vector3(0.30, 0.08, 0.30) * s)
	
	st_armor.generate_normals()
	st_armor.generate_tangents()
	st_armor.set_material(mat_raynor_armor)
	st_armor.commit(mesh)
	
	# Surface 2: Polished Brass / Gold Commander Trim & Eagle Insignia
	var st_brass := SurfaceTool.new()
	st_brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Pauldron Golden Crests
	_add_box(st_brass, Vector3(-0.50 * s, 1.48 * s, 0.0), Vector3(0.24, 0.08, 0.38) * s)
	_add_box(st_brass, Vector3(0.50 * s, 1.48 * s, 0.0), Vector3(0.24, 0.08, 0.38) * s)
	# Chest Commander Gorget Chevron
	_add_box(st_brass, Vector3(0, 1.30 * s, -0.22 * s), Vector3(0.28, 0.06, 0.06) * s)
	_add_box(st_brass, Vector3(0, 1.22 * s, -0.22 * s), Vector3(0.18, 0.05, 0.06) * s)
	# Knee Guard Brass Caps
	_add_box(st_brass, Vector3(-0.22 * s, 0.38 * s, -0.18 * s), Vector3(0.14, 0.08, 0.04) * s)
	_add_box(st_brass, Vector3(0.22 * s, 0.38 * s, -0.18 * s), Vector3(0.14, 0.08, 0.04) * s)
	
	st_brass.generate_normals()
	st_brass.generate_tangents()
	st_brass.set_material(mat_raynor_brass)
	st_brass.commit(mesh)
	
	# Surface 3: Steel Powerpack & Joints
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
	
	# Surface 4: Raynor Skull Visor Glow (High-intensity Amber/Crimson)
	var st_visor := SurfaceTool.new()
	st_visor.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st_visor, Vector3(0, 1.57 * s, -0.17 * s), Vector3(0.28, 0.14, 0.04) * s)
	st_visor.generate_normals()
	st_visor.generate_tangents()
	st_visor.set_material(mat_raynor_visor)
	st_visor.commit(mesh)
	
	# Surface 5: Thruster Core Glow
	var st_thruster := SurfaceTool.new()
	st_thruster.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st_thruster, Vector3(-0.20 * s, 1.18 * s, 0.38 * s), 0.075 * s, 0.05 * s, 8)
	_add_cylinder(st_thruster, Vector3(0.20 * s, 1.18 * s, 0.38 * s), 0.075 * s, 0.05 * s, 8)
	st_thruster.generate_normals()
	st_thruster.generate_tangents()
	st_thruster.set_material(mat_marine_thruster)
	st_thruster.commit(mesh)
	
	ResourceSaver.save(mesh, RAYNOR_BODY_PATH)
	print("[ModelGenerator] Saved: ", RAYNOR_BODY_PATH)


# ==============================================================================
# 4. JIM RAYNOR CUSTOM HERO WEAPON
# ==============================================================================

func _build_raynor_rifle() -> void:
	var mesh := ArrayMesh.new()
	
	# Surface 1: Heavy Gunmetal Receiver & Long Barrel
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Extended Heavy Receiver
	_add_box(st_steel, Vector3(0, 0, -0.04), Vector3(0.16, 0.20, 0.52))
	# Extended Fluted Barrel Shroud
	_add_box(st_steel, Vector3(0, 0.02, -0.38), Vector3(0.11, 0.13, 0.30))
	# Muzzle Brake with Side Compensator Vents
	_add_cylinder(st_steel, Vector3(0, 0.02, -0.54), 0.035, 0.10, 8)
	# Rear Heavy Stock
	_add_box(st_steel, Vector3(0, -0.02, 0.28), Vector3(0.12, 0.18, 0.18))
	# Pistol Grip
	_add_box(st_steel, Vector3(0, -0.16, 0.12), Vector3(0.07, 0.16, 0.09))
	
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_marine_steel)
	st_steel.commit(mesh)
	
	# Surface 2: Brass Inlays & Scope Housing
	var st_brass := SurfaceTool.new()
	st_brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Elevated Tactical Scope
	_add_cylinder(st_brass, Vector3(0, 0.16, -0.10), 0.04, 0.28, 8)
	# Scope Mounts
	_add_box(st_brass, Vector3(0, 0.12, -0.18), Vector3(0.05, 0.06, 0.04))
	_add_box(st_brass, Vector3(0, 0.12, -0.02), Vector3(0.05, 0.06, 0.04))
	# Polished Brass Side Panels
	_add_box(st_brass, Vector3(-0.085, 0.01, -0.05), Vector3(0.015, 0.12, 0.32))
	_add_box(st_brass, Vector3(0.085, 0.01, -0.05), Vector3(0.015, 0.12, 0.32))
	
	st_brass.generate_normals()
	st_brass.generate_tangents()
	st_brass.set_material(mat_raynor_brass)
	st_brass.commit(mesh)
	
	# Surface 3: Tactical Red Scope Lens Glow
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
# 5. ZERGLING SWARM UNIT (MultiMesh & Shader Optimized)
# ==============================================================================

func _build_zergling_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# COLOR encoding for zerg_swarm.gdshader:
	# COLOR.r = 1.0 (Carapace Chitin) vs 0.0 (Fleshy Tissue)
	# COLOR.g = 1.0 (Emissive Gland/Eye Glow) vs 0.0 (Non-emissive)
	var col_carapace := Color(1.0, 0.0, 0.0, 1.0)
	var col_flesh := Color(0.0, 0.0, 0.0, 1.0)
	var col_glow := Color(0.0, 1.0, 0.0, 1.0)
	
	# --- 1. HEAD & MANDIBLES (z: -0.35 to -0.65, y: 0.32 to 0.55) ---
	# Cranial Shield / Forehead Chitin
	_add_tapered_box(st, Vector3(0, 0.45, -0.44), Vector3(0.24, 0.14, 0.26), Vector3(0.18, 0.12, 0.22), col_carapace)
	# Snarling Jaw / Mouth Interior (Flesh)
	_add_box(st, Vector3(0, 0.36, -0.52), Vector3(0.14, 0.08, 0.18), col_flesh)
	# Outer Pincer Mandibles (Left & Right)
	_add_wedge(st, Vector3(-0.16, 0.38, -0.64), Vector3(-0.10, 0.42, -0.46), Vector3(-0.14, 0.34, -0.46), Vector3(-0.06, 0.38, -0.46), col_carapace)
	_add_wedge(st, Vector3(0.16, 0.38, -0.64), Vector3(0.10, 0.42, -0.46), Vector3(0.06, 0.38, -0.46), Vector3(0.14, 0.34, -0.46), col_carapace)
	# Compound Eyes (Lime Green Glow)
	_add_box(st, Vector3(-0.11, 0.44, -0.48), Vector3(0.05, 0.04, 0.08), col_glow)
	_add_box(st, Vector3(0.11, 0.44, -0.48), Vector3(0.05, 0.04, 0.08), col_glow)
	
	# --- 2. THORAX & DORSAL CARAPACE (z: -0.30 to 0.05, y: 0.35 to 0.62) ---
	_add_box(st, Vector3(0, 0.48, -0.15), Vector3(0.36, 0.24, 0.38), col_carapace)
	# Dorsal Ridge Spines
	_add_wedge(st, Vector3(0, 0.68, -0.22), Vector3(-0.06, 0.58, -0.28), Vector3(0.06, 0.58, -0.28), Vector3(0, 0.58, -0.14), col_carapace)
	_add_wedge(st, Vector3(0, 0.66, -0.06), Vector3(-0.06, 0.58, -0.12), Vector3(0.06, 0.58, -0.12), Vector3(0, 0.58, 0.02), col_carapace)
	# Underbelly Fleshy Ribs
	_add_box(st, Vector3(0, 0.32, -0.15), Vector3(0.26, 0.12, 0.34), col_flesh)
	
	# --- 3. RAPTOR DORSAL WINGS / SCYTHE BLADES ---
	# Twin forward-swept chitin blades curving up and over shoulders
	# Left Blade Base -> Arch -> Scythe Tip
	_add_wedge(st, Vector3(-0.16, 0.78, -0.18), Vector3(-0.12, 0.56, -0.10), Vector3(-0.18, 0.56, -0.08), Vector3(-0.14, 0.56, -0.16), col_carapace)
	_add_wedge(st, Vector3(-0.18, 0.92, -0.36), Vector3(-0.14, 0.74, -0.22), Vector3(-0.20, 0.74, -0.20), Vector3(-0.16, 0.74, -0.26), col_carapace)
	# Right Blade Base -> Arch -> Scythe Tip
	_add_wedge(st, Vector3(0.16, 0.78, -0.18), Vector3(0.12, 0.56, -0.10), Vector3(0.14, 0.56, -0.16), Vector3(0.18, 0.56, -0.08), col_carapace)
	_add_wedge(st, Vector3(0.18, 0.92, -0.36), Vector3(0.14, 0.74, -0.22), Vector3(0.16, 0.74, -0.26), Vector3(0.20, 0.74, -0.20), col_carapace)
	
	# --- 4. FORELIMBS & SICKLE CLAWS (touching ground y=0.0 at z=-0.35) ---
	# Left Forelimb
	_add_box(st, Vector3(-0.24, 0.32, -0.25), Vector3(0.10, 0.18, 0.12), col_carapace)
	_add_wedge(st, Vector3(-0.28, 0.0, -0.38), Vector3(-0.24, 0.22, -0.26), Vector3(-0.30, 0.22, -0.24), Vector3(-0.26, 0.22, -0.32), col_carapace)
	# Right Forelimb
	_add_box(st, Vector3(0.24, 0.32, -0.25), Vector3(0.10, 0.18, 0.12), col_carapace)
	_add_wedge(st, Vector3(0.28, 0.0, -0.38), Vector3(0.24, 0.22, -0.26), Vector3(0.26, 0.22, -0.32), Vector3(0.30, 0.22, -0.24), col_carapace)
	
	# --- 5. HIND LEGS & RUNNING TALONS (touching ground y=0.0 at z=0.15) ---
	# Left Muscular Thigh & Hock
	_add_box(st, Vector3(-0.26, 0.40, 0.12), Vector3(0.14, 0.24, 0.20), col_flesh)
	_add_wedge(st, Vector3(-0.30, 0.0, 0.14), Vector3(-0.24, 0.28, 0.10), Vector3(-0.32, 0.28, 0.12), Vector3(-0.28, 0.28, 0.20), col_carapace)
	# Right Muscular Thigh & Hock
	_add_box(st, Vector3(0.26, 0.40, 0.12), Vector3(0.14, 0.24, 0.20), col_flesh)
	_add_wedge(st, Vector3(0.30, 0.0, 0.14), Vector3(0.24, 0.28, 0.10), Vector3(0.28, 0.28, 0.20), Vector3(0.32, 0.28, 0.12), col_carapace)
	
	# --- 6. ABDOMEN & TAIL (z: 0.10 to 0.55, y: 0.32 to 0.50) ---
	_add_tapered_box(st, Vector3(0, 0.40, 0.28), Vector3(0.30, 0.22, 0.26), Vector3(0.18, 0.14, 0.20), col_carapace)
	# Whip Tail Stinger
	_add_wedge(st, Vector3(0, 0.42, 0.58), Vector3(-0.06, 0.38, 0.38), Vector3(0.06, 0.38, 0.38), Vector3(0, 0.46, 0.38), col_carapace)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_zergling)
	st.commit(mesh)
	
	ResourceSaver.save(mesh, ZERGLING_MESH_PATH)
	print("[ModelGenerator] Saved: ", ZERGLING_MESH_PATH)


# ==============================================================================
# 6. ROACH SWARM UNIT (Calcified Dorsal Dome & Hexapod Digging Chassis)
# ==============================================================================

func _build_roach_mesh() -> void:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var col_carapace := Color(1.0, 0.0, 0.0, 1.0)
	var col_flesh := Color(0.0, 0.0, 0.0, 1.0)
	var col_bile := Color(0.0, 1.0, 0.0, 1.0)
	
	# --- 1. MASSIVE CALCIFIED DORSAL DOME CARAPACE (z: -0.45 to 0.50, y: 0.30 to 0.78, x: ±0.52) ---
	# Central Heavy Dome Shell
	_add_tapered_box(st, Vector3(0, 0.56, 0.02), Vector3(0.96, 0.36, 0.88), Vector3(0.72, 0.28, 0.68), col_carapace)
	# Overlapping Rear Chitin Plate
	_add_tapered_box(st, Vector3(0, 0.50, 0.38), Vector3(0.82, 0.28, 0.36), Vector3(0.56, 0.20, 0.28), col_carapace)
	# Dorsal Spine Crests
	_add_wedge(st, Vector3(0, 0.78, -0.10), Vector3(-0.10, 0.68, -0.24), Vector3(0.10, 0.68, -0.24), Vector3(0, 0.68, 0.04), col_carapace)
	_add_wedge(st, Vector3(0, 0.74, 0.16), Vector3(-0.08, 0.66, 0.04), Vector3(0.08, 0.66, 0.04), Vector3(0, 0.66, 0.28), col_carapace)
	
	# Dorsal Acid Secretion Vents (Glowing Virulent Emerald Bile)
	_add_box(st, Vector3(-0.24, 0.65, 0.05), Vector3(0.08, 0.06, 0.14), col_bile)
	_add_box(st, Vector3(0.24, 0.65, 0.05), Vector3(0.08, 0.06, 0.14), col_bile)
	_add_box(st, Vector3(-0.18, 0.62, 0.24), Vector3(0.06, 0.05, 0.12), col_bile)
	_add_box(st, Vector3(0.18, 0.62, 0.24), Vector3(0.06, 0.05, 0.12), col_bile)
	
	# Underbelly Organic Muscle Tissue
	_add_box(st, Vector3(0, 0.32, 0.0), Vector3(0.68, 0.18, 0.74), col_flesh)
	
	# --- 2. HEAVY ARMORED HEAD & ACID MAW (z: -0.40 to -0.72, y: 0.22 to 0.48) ---
	# Sloped Chitinous Head Shield
	_add_tapered_box(st, Vector3(0, 0.40, -0.52), Vector3(0.52, 0.22, 0.32), Vector3(0.36, 0.16, 0.26), col_carapace)
	# Caustic Acid Spit Mouth Conduits (Glow)
	_add_box(st, Vector3(0, 0.30, -0.68), Vector3(0.22, 0.10, 0.14), col_bile)
	# Heavy Mandibular Crushing Jaws
	_add_wedge(st, Vector3(-0.24, 0.30, -0.76), Vector3(-0.14, 0.36, -0.58), Vector3(-0.22, 0.26, -0.58), Vector3(-0.10, 0.26, -0.58), col_carapace)
	_add_wedge(st, Vector3(0.24, 0.30, -0.76), Vector3(0.14, 0.36, -0.58), Vector3(0.10, 0.26, -0.58), Vector3(0.22, 0.26, -0.58), col_carapace)
	
	# --- 3. HEXAPOD DIGGING LEGS (6 heavy legs, claw tips touch ground at y=0.0) ---
	# Front Legs (Left & Right)
	_add_box(st, Vector3(-0.48, 0.32, -0.32), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(-0.58, 0.0, -0.46), Vector3(-0.42, 0.24, -0.34), Vector3(-0.52, 0.24, -0.28), Vector3(-0.46, 0.24, -0.40), col_carapace)
	_add_box(st, Vector3(0.48, 0.32, -0.32), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(0.58, 0.0, -0.46), Vector3(0.42, 0.24, -0.34), Vector3(0.46, 0.24, -0.40), Vector3(0.52, 0.24, -0.28), col_carapace)
	
	# Middle Legs (Left & Right)
	_add_box(st, Vector3(-0.52, 0.32, 0.04), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(-0.64, 0.0, 0.04), Vector3(-0.46, 0.24, 0.10), Vector3(-0.54, 0.24, 0.06), Vector3(-0.48, 0.24, -0.04), col_carapace)
	_add_box(st, Vector3(0.52, 0.32, 0.04), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(0.64, 0.0, 0.04), Vector3(0.46, 0.24, 0.10), Vector3(0.48, 0.24, -0.04), Vector3(0.54, 0.24, 0.06), col_carapace)
	
	# Rear Legs (Left & Right)
	_add_box(st, Vector3(-0.48, 0.32, 0.36), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(-0.58, 0.0, 0.48), Vector3(-0.42, 0.24, 0.42), Vector3(-0.52, 0.24, 0.36), Vector3(-0.44, 0.24, 0.30), col_carapace)
	_add_box(st, Vector3(0.48, 0.32, 0.36), Vector3(0.18, 0.18, 0.18), col_carapace)
	_add_wedge(st, Vector3(0.58, 0.0, 0.48), Vector3(0.42, 0.24, 0.42), Vector3(0.44, 0.24, 0.30), Vector3(0.52, 0.24, 0.36), col_carapace)
	
	st.generate_normals()
	st.generate_tangents()
	st.set_material(mat_roach)
	st.commit(mesh)
	
	ResourceSaver.save(mesh, ROACH_MESH_PATH)
	print("[ModelGenerator] Saved: ", ROACH_MESH_PATH)
