extends SceneTree

# Procedural 3D Structure & Mesh Generator for Special Forces Elite 5 (SFE5)
# Generates authentic StarCraft II inspired Terran base structures:
# 1. Planetary Fortress / Command Center (Octagonal bastion, twin Ibex cannons, radar dish, exhaust stacks, beacon lights)
# 2. Modular Fortified Wall Segment (Interlocking flanges, sloped glacis deflection armor, buttresses, catwalk)
# 3. Fortified Bunker Bastion (Octagonal pillbox, observation & firing embrasures, weapon cupola, comms mast)
# 4. Automated Security Gate Frame (Fortified gantry pillars, overhead lintel girder, hazard decals)
# 5. Automated Security Gate Sliding Door (Interlocking heavy blast door panels, central pressure seal)
# 6. Automated Security Gate Status Beacon (Bezel housing and multi-state luminaire lens)

const CC_MESH_PATH := "res://assets/models/structures/command_center_mesh.tres"
const WALL_MESH_PATH := "res://assets/models/structures/wall_segment_mesh.tres"
const BUNKER_MESH_PATH := "res://assets/models/structures/bunker_structure_mesh.tres"
const GATE_FRAME_PATH := "res://assets/models/structures/gate_frame_mesh.tres"
const GATE_DOOR_PATH := "res://assets/models/structures/gate_door_mesh.tres"
const GATE_LIGHT_PATH := "res://assets/models/structures/gate_light_mesh.tres"

var mat_hull: Material
var mat_dark_steel: Material
var mat_blue_glow: Material
var mat_exhaust_glow: Material
var mat_beacon_red: Material
var mat_hazard: Material
var mat_amber_slit: Material
var mat_catwalk: Material


func _init() -> void:
	print("[StructureGenerator] Starting authentic Terran structure synthesis...")
	_ensure_directories()
	_load_materials()
	
	_build_command_center_mesh()
	_build_wall_segment_mesh()
	_build_bunker_mesh()
	_build_gate_frame_mesh()
	_build_gate_door_mesh()
	_build_gate_light_mesh()
	
	print("[StructureGenerator] All 6 Terran structure models generated and saved successfully!")
	quit(0)


func _ensure_directories() -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets/models/structures"):
		dir.make_dir_recursive("assets/models/structures")
	if not dir.dir_exists("assets/materials/structures"):
		dir.make_dir_recursive("assets/materials/structures")


func _load_materials() -> void:
	mat_hull = load("res://assets/materials/structures/terran_hull_pbr.tres")
	mat_dark_steel = load("res://assets/materials/structures/terran_dark_steel.tres")
	mat_blue_glow = load("res://assets/materials/structures/terran_blue_glow.tres")
	mat_exhaust_glow = load("res://assets/materials/structures/terran_exhaust_glow.tres")
	mat_beacon_red = load("res://assets/materials/structures/terran_beacon_red.tres")
	mat_hazard = load("res://assets/materials/structures/terran_hazard_stripe.tres")
	mat_amber_slit = load("res://assets/materials/structures/terran_slit_amber.tres")
	mat_catwalk = load("res://assets/materials/structures/terran_catwalk.tres")


# ==============================================================================
# GEOMETRY GENERATION HELPERS
# ==============================================================================

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


func _add_triangle(st: SurfaceTool, p1: Vector3, p2: Vector3, p3: Vector3, norm: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(norm)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p1)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(p2)
	st.set_uv(Vector2(0.5, 1))
	st.add_vertex(p3)


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


func _add_tapered_box(st: SurfaceTool, center: Vector3, bottom_size: Vector3, top_size: Vector3, col: Color = Color.WHITE) -> void:
	var hb := bottom_size * 0.5
	var ht := top_size * 0.5
	var hy := bottom_size.y * 0.5
	
	var b000 := center + Vector3(-hb.x, -hy, -hb.z)
	var b001 := center + Vector3(-hb.x, -hy,  hb.z)
	var b100 := center + Vector3( hb.x, -hy, -hb.z)
	var b101 := center + Vector3( hb.x, -hy,  hb.z)
	
	var t010 := center + Vector3(-ht.x,  hy, -ht.z)
	var t011 := center + Vector3(-ht.x,  hy,  ht.z)
	var t110 := center + Vector3( ht.x,  hy, -ht.z)
	var t111 := center + Vector3( ht.x,  hy,  ht.z)
	
	var n_fwd := (Vector3.FORWARD + Vector3.UP * 0.3).normalized()
	var n_back := (Vector3.BACK + Vector3.UP * 0.3).normalized()
	var n_right := (Vector3.RIGHT + Vector3.UP * 0.3).normalized()
	var n_left := (Vector3.LEFT + Vector3.UP * 0.3).normalized()
	
	_add_quad(st, b001, b101, t111, t011, n_fwd, col)
	_add_quad(st, b100, b000, t010, t110, n_back, col)
	_add_quad(st, t011, t111, t110, t010, Vector3.UP, col)
	_add_quad(st, b000, b100, b101, b001, Vector3.DOWN, col)
	_add_quad(st, b101, b100, t110, t111, n_right, col)
	_add_quad(st, b000, b001, t011, t010, n_left, col)


func _add_wedge(st: SurfaceTool, tip: Vector3, b1: Vector3, b2: Vector3, b3: Vector3, col: Color = Color.WHITE) -> void:
	var n1 := (b2 - b1).cross(tip - b1).normalized()
	_add_triangle(st, b1, b2, tip, n1, col)
	var n2 := (b3 - b2).cross(tip - b2).normalized()
	_add_triangle(st, b2, b3, tip, n2, col)
	var n3 := (b1 - b3).cross(tip - b3).normalized()
	_add_triangle(st, b3, b1, tip, n3, col)
	var n_base := (b2 - b1).cross(b3 - b1).normalized()
	_add_triangle(st, b1, b3, b2, n_base, col)


func _add_cylinder(st: SurfaceTool, center: Vector3, radius_bottom: float, radius_top: float, height: float, segments: int, col: Color = Color.WHITE) -> void:
	var half_h := height * 0.5
	var y_bot := center.y - half_h
	var y_top := center.y + half_h
	
	for i in range(segments):
		var a1 := float(i) / float(segments) * TAU
		var a2 := float(i + 1) / float(segments) * TAU
		
		var b1 := center + Vector3(cos(a1) * radius_bottom, -half_h, sin(a1) * radius_bottom)
		var b2 := center + Vector3(cos(a2) * radius_bottom, -half_h, sin(a2) * radius_bottom)
		var t1 := center + Vector3(cos(a1) * radius_top, half_h, sin(a1) * radius_top)
		var t2 := center + Vector3(cos(a2) * radius_top, half_h, sin(a2) * radius_top)
		
		var side_norm := Vector3(cos((a1 + a2) * 0.5), 0, sin((a1 + a2) * 0.5)).normalized()
		_add_quad(st, b1, b2, t2, t1, side_norm, col)
		_add_triangle(st, center + Vector3(0, half_h, 0), t1, t2, Vector3.UP, col)
		_add_triangle(st, center + Vector3(0, -half_h, 0), b2, b1, Vector3.DOWN, col)


func _add_octagonal_prism(st: SurfaceTool, center: Vector3, radius_bottom: float, radius_top: float, height: float, col: Color = Color.WHITE) -> void:
	_add_cylinder(st, center, radius_bottom, radius_top, height, 8, col)


# ==============================================================================
# 1. TERRAN COMMAND CENTER / PLANETARY FORTRESS MESH
# ==============================================================================

func _build_command_center_mesh() -> void:
	var mesh := ArrayMesh.new()
	
	# Surface 0: Terran Hull PBR
	var st_hull := SurfaceTool.new()
	st_hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Octagonal Fortified Base Chassis (Ground y=0.0 to y=1.4)
	# Centered at (0, 0.7, 0), bottom at y=0.0, top at y=1.4
	_add_octagonal_prism(st_hull, Vector3(0, 0.7, 0), 3.9, 3.65, 1.4, Color.WHITE)
	
	# Mid-Tier Armored Bastion Hull (y=1.4 to y=3.0)
	_add_octagonal_prism(st_hull, Vector3(0, 2.2, 0), 3.4, 3.1, 1.6, Color.WHITE)
	
	# Armored Sponsons / Lateral Bastion Wings (Left and Right)
	_add_box(st_hull, Vector3(-3.2, 1.5, 0), Vector3(1.0, 1.6, 3.2), Color.WHITE)
	_add_box(st_hull, Vector3(3.2, 1.5, 0), Vector3(1.0, 1.6, 3.2), Color.WHITE)
	
	# Forward Armored Citadel Alcove / Ramp Bastion (Z = -3.2)
	_add_box(st_hull, Vector3(0, 0.6, -3.2), Vector3(3.2, 1.2, 1.4), Color.WHITE)
	
	# Upper Command Bridge Superstructure (y=2.9 to y=4.1)
	_add_octagonal_prism(st_hull, Vector3(0, 3.5, 0), 2.5, 2.2, 1.2, Color.WHITE)
	# Observation Bridge Canopy (y=4.1 to y=4.4)
	_add_tapered_box(st_hull, Vector3(0, 4.25, -0.2), Vector3(2.4, 0.3, 2.0), Vector3(2.0, 0.3, 1.6), Color.WHITE)
	
	# Planetary Fortress Heavy Twin Ibex Cannon Turrets (Barbette on forward roof)
	_add_cylinder(st_hull, Vector3(0, 3.95, -1.6), 1.0, 0.9, 0.25, 12, Color.WHITE)
	_add_box(st_hull, Vector3(0, 4.20, -1.6), Vector3(1.6, 0.45, 1.4), Color.WHITE)
	# Heavy Armored Cannon Barrels (Left and Right) extending forward
	_add_cylinder(st_hull, Vector3(-0.45, 4.20, -2.6), 0.15, 0.15, 1.6, 8, Color.WHITE)
	_add_cylinder(st_hull, Vector3(0.45, 4.20, -2.6), 0.15, 0.15, 1.6, 8, Color.WHITE)
	# Barrel Muzzle Brakes
	_add_box(st_hull, Vector3(-0.45, 4.20, -3.45), Vector3(0.38, 0.36, 0.28), Color.WHITE)
	_add_box(st_hull, Vector3(0.45, 4.20, -3.45), Vector3(0.38, 0.36, 0.28), Color.WHITE)
	
	st_hull.generate_normals()
	st_hull.generate_tangents()
	st_hull.set_material(mat_hull)
	st_hull.commit(mesh)
	
	# Surface 1: Terran Dark Steel (Machinery, stabilizer footpads, vents, radar dish)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 4 Heavy Hydraulic Footpads resting flush at ground y=0.0
	var footpad_coords := [
		Vector3(-3.2, 0.15, -3.2),
		Vector3(3.2, 0.15, -3.2),
		Vector3(-3.2, 0.15, 3.2),
		Vector3(3.2, 0.15, 3.2)
	]
	for fp in footpad_coords:
		_add_box(st_steel, fp, Vector3(1.2, 0.3, 1.2), Color.WHITE)
		# Hydraulic cylinder connecting footpad to hull
		_add_cylinder(st_steel, fp + Vector3(0, 0.5, 0), 0.22, 0.18, 0.8, 8, Color.WHITE)
	
	# Rear Angled Dual Exhaust Smokestacks (Left & Right at rear Z=+2.2, y=2.6 to 3.9)
	_add_cylinder(st_steel, Vector3(-1.6, 3.25, 2.2), 0.42, 0.38, 1.3, 8, Color.WHITE)
	_add_cylinder(st_steel, Vector3(1.6, 3.25, 2.2), 0.42, 0.38, 1.3, 8, Color.WHITE)
	# Exhaust rims / dissipator rings
	_add_cylinder(st_steel, Vector3(-1.6, 3.95, 2.2), 0.48, 0.45, 0.14, 8, Color.WHITE)
	_add_cylinder(st_steel, Vector3(1.6, 3.95, 2.2), 0.48, 0.45, 0.14, 8, Color.WHITE)
	
	# Communication Radar Dish Pedestal & Parabolic Dish
	_add_cylinder(st_steel, Vector3(-1.5, 3.95, 0.8), 0.14, 0.12, 0.7, 8, Color.WHITE)
	# Radar dish gimbal head
	_add_box(st_steel, Vector3(-1.5, 4.35, 0.8), Vector3(0.28, 0.18, 0.28), Color.WHITE)
	# Parabolic Dish reflector (hexagonal dish angled 35° upward)
	_add_octagonal_prism(st_steel, Vector3(-1.5, 4.58, 0.68), 0.65, 0.75, 0.12, Color.WHITE)
	# Feed horn sensor extending from center of dish
	_add_cylinder(st_steel, Vector3(-1.5, 4.68, 0.58), 0.04, 0.03, 0.22, 6, Color.WHITE)
	
	# Communication Antenna Mast (at X=+1.5, Z=+0.8, y=3.6 to 4.75)
	_add_cylinder(st_steel, Vector3(1.5, 4.15, 0.8), 0.10, 0.05, 0.95, 8, Color.WHITE)
	_add_box(st_steel, Vector3(1.5, 4.45, 0.8), Vector3(0.55, 0.03, 0.03), Color.WHITE)
	_add_box(st_steel, Vector3(1.5, 4.25, 0.8), Vector3(0.80, 0.03, 0.03), Color.WHITE)
	
	# Recessed blast door hatch on forward ramp
	_add_box(st_steel, Vector3(0, 0.6, -3.92), Vector3(1.6, 1.1, 0.1), Color.WHITE)
	
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_dark_steel)
	st_steel.commit(mesh)
	
	# Surface 2: Terran Blue Glow (Command bridge visor & power conduits)
	var st_blue := SurfaceTool.new()
	st_blue.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Panoramic Command Bridge Visor Glass
	_add_box(st_blue, Vector3(0, 4.18, -1.05), Vector3(1.8, 0.20, 0.15), Color.WHITE)
	_add_box(st_blue, Vector3(-0.95, 4.18, -0.65), Vector3(0.15, 0.20, 0.8), Color.WHITE)
	_add_box(st_blue, Vector3(0.95, 4.18, -0.65), Vector3(0.15, 0.20, 0.8), Color.WHITE)
	
	# Power Conduits along hull flank
	_add_box(st_blue, Vector3(-3.2, 2.3, 0), Vector3(0.08, 0.08, 2.4), Color.WHITE)
	_add_box(st_blue, Vector3(3.2, 2.3, 0), Vector3(0.08, 0.08, 2.4), Color.WHITE)
	
	st_blue.generate_normals()
	st_blue.generate_tangents()
	st_blue.set_material(mat_blue_glow)
	st_blue.commit(mesh)
	
	# Surface 3: Exhaust Thermal Glow
	var st_exhaust := SurfaceTool.new()
	st_exhaust.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_add_cylinder(st_exhaust, Vector3(-1.6, 3.88, 2.2), 0.34, 0.34, 0.08, 8, Color.WHITE)
	_add_cylinder(st_exhaust, Vector3(1.6, 3.88, 2.2), 0.34, 0.34, 0.08, 8, Color.WHITE)
	
	st_exhaust.generate_normals()
	st_exhaust.generate_tangents()
	st_exhaust.set_material(mat_exhaust_glow)
	st_exhaust.commit(mesh)
	
	# Surface 4: Aviation Beacon Red
	var st_beacon := SurfaceTool.new()
	st_beacon.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Pinnacle strobe beacon atop the antenna mast at y=4.72
	_add_box(st_beacon, Vector3(1.5, 4.72, 0.8), Vector3(0.12, 0.14, 0.12), Color.WHITE)
	
	# 4 Corner Navigation Lights
	_add_box(st_beacon, Vector3(-3.1, 2.85, -3.1), Vector3(0.12, 0.12, 0.12), Color.WHITE)
	_add_box(st_beacon, Vector3(3.1, 2.85, -3.1), Vector3(0.12, 0.12, 0.12), Color.WHITE)
	_add_box(st_beacon, Vector3(-3.1, 2.85, 3.1), Vector3(0.12, 0.12, 0.12), Color.WHITE)
	_add_box(st_beacon, Vector3(3.1, 2.85, 3.1), Vector3(0.12, 0.12, 0.12), Color.WHITE)
	
	st_beacon.generate_normals()
	st_beacon.generate_tangents()
	st_beacon.set_material(mat_beacon_red)
	st_beacon.commit(mesh)
	
	# Surface 5: Hazard Stripes
	var st_hazard := SurfaceTool.new()
	st_hazard.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Hazard warning borders framing the vehicle ramp
	_add_box(st_hazard, Vector3(-1.5, 0.6, -3.92), Vector3(0.18, 1.1, 0.12), Color.WHITE)
	_add_box(st_hazard, Vector3(1.5, 0.6, -3.92), Vector3(0.18, 1.1, 0.12), Color.WHITE)
	_add_box(st_hazard, Vector3(0, 1.2, -3.92), Vector3(3.18, 0.15, 0.12), Color.WHITE)
	
	st_hazard.generate_normals()
	st_hazard.generate_tangents()
	st_hazard.set_material(mat_hazard)
	st_hazard.commit(mesh)
	
	ResourceSaver.save(mesh, CC_MESH_PATH)
	print("[StructureGenerator] Saved Command Center mesh: ", CC_MESH_PATH)


# ==============================================================================
# 2. MODULAR FORTIFIED WALL SEGMENT MESH
# ==============================================================================

func _build_wall_segment_mesh() -> void:
	var mesh := ArrayMesh.new()
	
	# Surface 0: Terran Hull PBR
	var st_hull := SurfaceTool.new()
	st_hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Main Wall Core Slab (Width: 4.0m, Height: 3.2m, Depth: 0.8m)
	# Centered at (0, 1.6, 0)
	_add_box(st_hull, Vector3(0, 1.6, 0), Vector3(3.96, 3.2, 0.76), Color.WHITE)
	
	# Forward Sloped Glacis Deflection Plate (Front Z=+0.38 to +0.58, Y=0.0 to 1.8)
	# 65° sloped armor plate to deflect incoming horde spines and claws
	_add_tapered_box(st_hull, Vector3(0, 0.9, 0.48), Vector3(3.96, 1.8, 0.22), Vector3(3.96, 1.8, 0.08), Color.WHITE)
	
	# Twin Forward Beveled Buttresses (At X = -1.2 and X = +1.2)
	# Triangular vertical buttress ribs reinforcing against kinetic impacts
	_add_tapered_box(st_hull, Vector3(-1.2, 1.3, 0.48), Vector3(0.5, 2.6, 0.24), Vector3(0.3, 2.6, 0.08), Color.WHITE)
	_add_tapered_box(st_hull, Vector3(1.2, 1.3, 0.48), Vector3(0.5, 2.6, 0.24), Vector3(0.3, 2.6, 0.08), Color.WHITE)
	
	# Twin Rear Buttresses (At X = -1.2 and X = +1.2 on rear face)
	_add_tapered_box(st_hull, Vector3(-1.2, 1.3, -0.46), Vector3(0.5, 2.6, 0.20), Vector3(0.3, 2.6, 0.08), Color.WHITE)
	_add_tapered_box(st_hull, Vector3(1.2, 1.3, -0.46), Vector3(0.5, 2.6, 0.20), Vector3(0.3, 2.6, 0.08), Color.WHITE)
	
	# Top Armored Parapet / Crenelated Balustrade (Y = 2.9 to 3.25)
	# Forward shielding wall with central observation port
	_add_box(st_hull, Vector3(-1.2, 3.08, 0.42), Vector3(1.5, 0.35, 0.16), Color.WHITE)
	_add_box(st_hull, Vector3(1.2, 3.08, 0.42), Vector3(1.5, 0.35, 0.16), Color.WHITE)
	_add_box(st_hull, Vector3(0, 2.98, 0.42), Vector3(0.9, 0.15, 0.16), Color.WHITE)
	
	st_hull.generate_normals()
	st_hull.generate_tangents()
	st_hull.set_material(mat_hull)
	st_hull.commit(mesh)
	
	# Surface 1: Terran Dark Steel (Interlocking flanges, rivets, base anchor flange)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Interlocking Side Flanges (ensuring continuous walls have seamless visual snap)
	# Male interlocking tongue at X = +2.0
	_add_box(st_steel, Vector3(1.99, 1.6, 0), Vector3(0.06, 3.1, 0.5), Color.WHITE)
	# Female interlocking groove trim at X = -2.0
	_add_box(st_steel, Vector3(-1.99, 1.6, 0), Vector3(0.06, 3.1, 0.6), Color.WHITE)
	
	# Ground Anchoring Footing Flange (flush at y = 0.0)
	_add_box(st_steel, Vector3(0, 0.1, 0), Vector3(4.0, 0.2, 1.15), Color.WHITE)
	
	# Heavy Corner Rivets along buttress brackets
	var rivet_positions := [
		Vector3(-1.2, 0.4, 0.59), Vector3(-1.2, 1.2, 0.56), Vector3(-1.2, 2.0, 0.52),
		Vector3(1.2, 0.4, 0.59), Vector3(1.2, 1.2, 0.56), Vector3(1.2, 2.0, 0.52),
		Vector3(-1.2, 0.4, -0.56), Vector3(-1.2, 1.8, -0.50),
		Vector3(1.2, 0.4, -0.56), Vector3(1.2, 1.8, -0.50)
	]
	for rv in rivet_positions:
		_add_box(st_steel, rv, Vector3(0.10, 0.10, 0.08), Color.WHITE)
	
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_dark_steel)
	st_steel.commit(mesh)
	
	# Surface 2: Terran Blue Glow (Recessed parapet energy conduit)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Horizontal recessed energy line across the upper parapet face
	_add_box(st_glow, Vector3(0, 2.85, 0.42), Vector3(3.8, 0.06, 0.04), Color.WHITE)
	
	st_glow.generate_normals()
	st_glow.generate_tangents()
	st_glow.set_material(mat_blue_glow)
	st_glow.commit(mesh)
	
	# Surface 3: Catwalk Grating
	var st_catwalk := SurfaceTool.new()
	st_catwalk.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Recessed infantry observation walkway along the top (y = 2.92)
	_add_box(st_catwalk, Vector3(0, 2.92, -0.05), Vector3(3.9, 0.06, 0.65), Color.WHITE)
	
	st_catwalk.generate_normals()
	st_catwalk.generate_tangents()
	st_catwalk.set_material(mat_catwalk)
	st_catwalk.commit(mesh)
	
	ResourceSaver.save(mesh, WALL_MESH_PATH)
	print("[StructureGenerator] Saved Wall Segment mesh: ", WALL_MESH_PATH)


# ==============================================================================
# 3. FORTIFIED BUNKER BASTION MESH
# ==============================================================================

func _build_bunker_mesh() -> void:
	var mesh := ArrayMesh.new()
	
	# Surface 0: Terran Hull PBR
	var st_hull := SurfaceTool.new()
	st_hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Octagonal Fortified Lower Bastion Hull (Ground y=0.0 to 1.2)
	# Centered at (0, 0.6, 0), radius 1.70, height 1.2
	_add_octagonal_prism(st_hull, Vector3(0, 0.6, 0), 1.72, 1.62, 1.2, Color.WHITE)
	
	# Mid-Tier Armor Visor & Firing Sponson (y=1.2 to 1.9)
	# Overhanging ballistic visor protecting embrasures
	_add_octagonal_prism(st_hull, Vector3(0, 1.55, 0), 1.64, 1.52, 0.7, Color.WHITE)
	
	# Upper Roof Parapet & Weapon Cupola (y=1.9 to 2.45)
	_add_octagonal_prism(st_hull, Vector3(0, 2.15, 0), 1.52, 1.38, 0.5, Color.WHITE)
	
	# Central Roof Rotating Weapon Port / Hatch Barbette (y=2.4)
	_add_cylinder(st_hull, Vector3(0, 2.42, 0), 0.65, 0.60, 0.16, 12, Color.WHITE)
	
	st_hull.generate_normals()
	st_hull.generate_tangents()
	st_hull.set_material(mat_hull)
	st_hull.commit(mesh)
	
	# Surface 1: Terran Dark Steel (Armor rims, hatches, searchlight, comms mast)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Ground Base Footing Flange (flush at y=0.0)
	_add_octagonal_prism(st_steel, Vector3(0, 0.08, 0), 1.74, 1.74, 0.16, Color.WHITE)
	
	# Rear Infantry Access Blast Hatch on South face (Z = +1.60)
	_add_box(st_steel, Vector3(0, 0.7, 1.62), Vector3(1.0, 1.1, 0.14), Color.WHITE)
	_add_cylinder(st_steel, Vector3(0, 0.7, 1.70), 0.18, 0.18, 0.06, 8, Color.WHITE) # locking wheel
	
	# Tactical Searchlight & Sensor Housing (on forward roof lip at Z = -1.2, y = 2.45)
	_add_box(st_steel, Vector3(0, 2.46, -1.25), Vector3(0.4, 0.22, 0.35), Color.WHITE)
	
	# Tactical Communications Mast (at X = +0.8, Z = +0.6, y = 2.3 to 2.8)
	_add_cylinder(st_steel, Vector3(0.8, 2.55, 0.6), 0.08, 0.04, 0.55, 8, Color.WHITE)
	_add_box(st_steel, Vector3(0.8, 2.75, 0.6), Vector3(0.3, 0.03, 0.03), Color.WHITE)
	
	# Heavy Corner Rivets on lower skirt
	for i in range(8):
		var a := float(i) / 8.0 * TAU
		var rv := Vector3(cos(a) * 1.68, 0.3, sin(a) * 1.68)
		_add_box(st_steel, rv, Vector3(0.08, 0.08, 0.08), Color.WHITE)
	
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_dark_steel)
	st_steel.commit(mesh)
	
	# Surface 2: Amber Slit Glow (Observation slits & firing embrasures)
	var st_amber := SurfaceTool.new()
	st_amber.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Front North Firing Embrasure
	_add_box(st_amber, Vector3(0, 1.48, -1.60), Vector3(1.3, 0.16, 0.12), Color.WHITE)
	# North-West Embrasure (45° angle)
	var nw_pos := Vector3(-1.08, 1.48, -1.08)
	_add_box(st_amber, nw_pos, Vector3(0.8, 0.16, 0.12), Color.WHITE)
	# North-East Embrasure (45° angle)
	var ne_pos := Vector3(1.08, 1.48, -1.08)
	_add_box(st_amber, ne_pos, Vector3(0.8, 0.16, 0.12), Color.WHITE)
	# West and East Lateral Slits
	_add_box(st_amber, Vector3(-1.60, 1.48, 0), Vector3(0.12, 0.16, 0.8), Color.WHITE)
	_add_box(st_amber, Vector3(1.60, 1.48, 0), Vector3(0.12, 0.16, 0.8), Color.WHITE)
	
	st_amber.generate_normals()
	st_amber.generate_tangents()
	st_amber.set_material(mat_amber_slit)
	st_amber.commit(mesh)
	
	# Surface 3: Terran Blue Glow (Searchlight lens & comms indicator)
	var st_blue := SurfaceTool.new()
	st_blue.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Forward searchlight optic lens
	_add_cylinder(st_blue, Vector3(0, 2.46, -1.43), 0.10, 0.10, 0.04, 8, Color.WHITE)
	# Comms mast avionics beacon
	_add_box(st_blue, Vector3(0.8, 2.82, 0.6), Vector3(0.08, 0.08, 0.08), Color.WHITE)
	
	st_blue.generate_normals()
	st_blue.generate_tangents()
	st_blue.set_material(mat_blue_glow)
	st_blue.commit(mesh)
	
	ResourceSaver.save(mesh, BUNKER_MESH_PATH)
	print("[StructureGenerator] Saved Bunker mesh: ", BUNKER_MESH_PATH)


# ==============================================================================
# 4. AUTOMATED SECURITY GATE FRAME MESH
# ==============================================================================

func _build_gate_frame_mesh() -> void:
	var mesh := ArrayMesh.new()
	
	# Surface 0: Terran Hull PBR (Twin Fortified Gantry Towers & Overhead Lintel)
	var st_hull := SurfaceTool.new()
	st_hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Left Gantry Pillar Tower (Centered at X = -2.5, Y = 1.8, Z = 0)
	_add_box(st_hull, Vector3(-2.5, 1.8, 0), Vector3(0.98, 3.6, 1.38), Color.WHITE)
	# Right Gantry Pillar Tower (Centered at X = +2.5, Y = 1.8, Z = 0)
	_add_box(st_hull, Vector3(2.5, 1.8, 0), Vector3(0.98, 3.6, 1.38), Color.WHITE)
	
	# Overhead Gantry Archway Girder / Lintel (Span: 6.0m, Y = 3.6 to 4.15, Depth: 1.38m)
	_add_box(st_hull, Vector3(0, 3.82, 0), Vector3(5.98, 0.64, 1.38), Color.WHITE)
	
	# Corner Structural Gussets connecting Pillars to Lintel
	_add_wedge(st_hull, Vector3(-1.9, 3.4, 0.6), Vector3(-2.1, 3.4, 0.6), Vector3(-1.9, 3.6, 0.6), Vector3(-1.9, 3.4, -0.6), Color.WHITE)
	_add_wedge(st_hull, Vector3(1.9, 3.4, 0.6), Vector3(1.9, 3.6, 0.6), Vector3(2.1, 3.4, 0.6), Vector3(1.9, 3.4, -0.6), Color.WHITE)
	
	st_hull.generate_normals()
	st_hull.generate_tangents()
	st_hull.set_material(mat_hull)
	st_hull.commit(mesh)
	
	# Surface 1: Terran Dark Steel (Guide rails, hydraulic lift cylinders, base plates)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Left & Right Base Ground Anchor Plates (flush at y = 0.0)
	_add_box(st_steel, Vector3(-2.5, 0.1, 0), Vector3(1.2, 0.2, 1.6), Color.WHITE)
	_add_box(st_steel, Vector3(2.5, 0.1, 0), Vector3(1.2, 0.2, 1.6), Color.WHITE)
	
	# Internal Blast Door Guide Tracks with heavy vertical tooth rails
	# Along inner face of Left pillar (X = -2.0)
	_add_box(st_steel, Vector3(-2.0, 1.8, 0), Vector3(0.08, 3.4, 0.65), Color.WHITE)
	# Along inner face of Right pillar (X = +2.0)
	_add_box(st_steel, Vector3(2.0, 1.8, 0), Vector3(0.08, 3.4, 0.65), Color.WHITE)
	
	# Dual Pneumatic Lift Actuators / Hydraulic Cylinders (mounting to pillars)
	_add_cylinder(st_steel, Vector3(-2.2, 2.4, 0.6), 0.12, 0.12, 2.2, 8, Color.WHITE)
	_add_cylinder(st_steel, Vector3(2.2, 2.4, 0.6), 0.12, 0.12, 2.2, 8, Color.WHITE)
	_add_cylinder(st_steel, Vector3(-2.2, 2.4, -0.6), 0.12, 0.12, 2.2, 8, Color.WHITE)
	_add_cylinder(st_steel, Vector3(2.2, 2.4, -0.6), 0.12, 0.12, 2.2, 8, Color.WHITE)
	
	# Overhead Girder Reinforcement Bands
	_add_box(st_steel, Vector3(-1.2, 3.82, 0), Vector3(0.12, 0.70, 1.42), Color.WHITE)
	_add_box(st_steel, Vector3(1.2, 3.82, 0), Vector3(0.12, 0.70, 1.42), Color.WHITE)
	
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_dark_steel)
	st_steel.commit(mesh)
	
	# Surface 2: Hazard Warning Stripes
	var st_hazard := SurfaceTool.new()
	st_hazard.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Hazard warning strip along the underside of the overhead lintel (visible above gate threshold)
	_add_box(st_hazard, Vector3(0, 3.48, 0), Vector3(4.0, 0.08, 1.36), Color.WHITE)
	# Hazard diagonal corners on pillar bases
	_add_box(st_hazard, Vector3(-2.5, 0.3, 0.70), Vector3(0.9, 0.2, 0.04), Color.WHITE)
	_add_box(st_hazard, Vector3(2.5, 0.3, 0.70), Vector3(0.9, 0.2, 0.04), Color.WHITE)
	
	st_hazard.generate_normals()
	st_hazard.generate_tangents()
	st_hazard.set_material(mat_hazard)
	st_hazard.commit(mesh)
	
	# Surface 3: Terran Blue Glow (Maintenance conduit indicator)
	var st_blue := SurfaceTool.new()
	st_blue.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_add_box(st_blue, Vector3(-2.5, 3.2, 0.70), Vector3(0.6, 0.05, 0.02), Color.WHITE)
	_add_box(st_blue, Vector3(2.5, 3.2, 0.70), Vector3(0.6, 0.05, 0.02), Color.WHITE)
	
	st_blue.generate_normals()
	st_blue.generate_tangents()
	st_blue.set_material(mat_blue_glow)
	st_blue.commit(mesh)
	
	ResourceSaver.save(mesh, GATE_FRAME_PATH)
	print("[StructureGenerator] Saved Gate Frame mesh: ", GATE_FRAME_PATH)


# ==============================================================================
# 5. AUTOMATED SECURITY GATE SLIDING BLAST DOOR MESH
# ==============================================================================

func _build_gate_door_mesh() -> void:
	var mesh := ArrayMesh.new()
	
	# Sliding door operates under DoorSlidingPart (initial pos: Vector3(0, 1.65, 0))
	# Mesh is centered at Vector3(0, 0, 0) locally.
	# Width: 4.0m, Height: 3.3m, Depth: 0.52m
	# Bottom at local y = -1.65 (flush with ground when closed!), Top at local y = +1.65
	
	# Surface 0: Terran Hull PBR (Twin Interlocking Blast Door Slabs)
	var st_hull := SurfaceTool.new()
	st_hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Left Door Panel (Width: 1.95m, Height: 3.28m, Depth: 0.48m)
	_add_box(st_hull, Vector3(-0.99, 0, 0), Vector3(1.94, 3.28, 0.46), Color.WHITE)
	# Right Door Panel (Width: 1.95m, Height: 3.28m, Depth: 0.48m)
	_add_box(st_hull, Vector3(0.99, 0, 0), Vector3(1.94, 3.28, 0.46), Color.WHITE)
	
	# Chevron Blast Reinforcement Ribs on front face (Z = +0.25)
	_add_tapered_box(st_hull, Vector3(-1.0, 0.6, 0.25), Vector3(1.5, 0.35, 0.08), Vector3(1.3, 0.35, 0.04), Color.WHITE)
	_add_tapered_box(st_hull, Vector3(1.0, 0.6, 0.25), Vector3(1.5, 0.35, 0.08), Vector3(1.3, 0.35, 0.04), Color.WHITE)
	_add_tapered_box(st_hull, Vector3(-1.0, -0.6, 0.25), Vector3(1.5, 0.35, 0.08), Vector3(1.3, 0.35, 0.04), Color.WHITE)
	_add_tapered_box(st_hull, Vector3(1.0, -0.6, 0.25), Vector3(1.5, 0.35, 0.08), Vector3(1.3, 0.35, 0.04), Color.WHITE)
	
	st_hull.generate_normals()
	st_hull.generate_tangents()
	st_hull.set_material(mat_hull)
	st_hull.commit(mesh)
	
	# Surface 1: Terran Dark Steel (Central pressure seal & interlocking teeth)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Central Hydraulic Pressure Seam / Locking Clamps
	_add_box(st_steel, Vector3(0, 0, 0), Vector3(0.12, 3.3, 0.50), Color.WHITE)
	# 4 Heavy Mechanical Locking Clamps across center seam
	_add_box(st_steel, Vector3(0, 0.9, 0.27), Vector3(0.35, 0.18, 0.10), Color.WHITE)
	_add_box(st_steel, Vector3(0, 0.3, 0.27), Vector3(0.35, 0.18, 0.10), Color.WHITE)
	_add_box(st_steel, Vector3(0, -0.3, 0.27), Vector3(0.35, 0.18, 0.10), Color.WHITE)
	_add_box(st_steel, Vector3(0, -0.9, 0.27), Vector3(0.35, 0.18, 0.10), Color.WHITE)
	
	# Top & Bottom Interlocking Guide Teeth
	_add_box(st_steel, Vector3(0, 1.63, 0), Vector3(3.9, 0.05, 0.44), Color.WHITE)
	_add_box(st_steel, Vector3(0, -1.63, 0), Vector3(3.9, 0.05, 0.44), Color.WHITE)
	
	st_steel.generate_normals()
	st_steel.generate_tangents()
	st_steel.set_material(mat_dark_steel)
	st_steel.commit(mesh)
	
	# Surface 2: Hazard Warning Stripes (Bottom threshold border)
	var st_hazard := SurfaceTool.new()
	st_hazard.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_add_box(st_hazard, Vector3(0, -1.45, 0.24), Vector3(3.9, 0.18, 0.04), Color.WHITE)
	_add_box(st_hazard, Vector3(0, -1.45, -0.24), Vector3(3.9, 0.18, 0.04), Color.WHITE)
	
	st_hazard.generate_normals()
	st_hazard.generate_tangents()
	st_hazard.set_material(mat_hazard)
	st_hazard.commit(mesh)
	
	# Surface 3: Terran Blue Glow (Vertical status line along door edge)
	var st_blue := SurfaceTool.new()
	st_blue.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_add_box(st_blue, Vector3(-0.06, 0, 0.24), Vector3(0.03, 2.6, 0.02), Color.WHITE)
	_add_box(st_blue, Vector3(0.06, 0, 0.24), Vector3(0.03, 2.6, 0.02), Color.WHITE)
	
	st_blue.generate_normals()
	st_blue.generate_tangents()
	st_blue.set_material(mat_blue_glow)
	st_blue.commit(mesh)
	
	ResourceSaver.save(mesh, GATE_DOOR_PATH)
	print("[StructureGenerator] Saved Gate Door mesh: ", GATE_DOOR_PATH)


# ==============================================================================
# 6. AUTOMATED SECURITY GATE STATUS BEACON MESH
# ==============================================================================

func _build_gate_light_mesh() -> void:
	var mesh := ArrayMesh.new()
	
	# Status Light Fixture (Dimensions: 0.8m x 0.25m x 0.20m)
	# Surface 0: Bezel / Housing in Dark Steel
	var st_bezel := SurfaceTool.new()
	st_bezel.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Protective Beveled Armor Housing Frame
	_add_box(st_bezel, Vector3(0, 0, -0.05), Vector3(0.84, 0.28, 0.14), Color.WHITE)
	_add_box(st_bezel, Vector3(-0.40, 0, 0.04), Vector3(0.06, 0.24, 0.06), Color.WHITE)
	_add_box(st_bezel, Vector3(0.40, 0, 0.04), Vector3(0.06, 0.24, 0.06), Color.WHITE)
	_add_box(st_bezel, Vector3(0, 0.12, 0.04), Vector3(0.74, 0.04, 0.06), Color.WHITE)
	_add_box(st_bezel, Vector3(0, -0.12, 0.04), Vector3(0.74, 0.04, 0.06), Color.WHITE)
	
	st_bezel.generate_normals()
	st_bezel.generate_tangents()
	st_bezel.set_material(mat_dark_steel)
	st_bezel.commit(mesh)
	
	# Surface 1: Luminaire Lens (Central illuminated emitter)
	# Will be dynamically overridden by gate_structure.gd (_mat_open, _mat_closed, _mat_locked)
	# But provide default closed crimson emission so it renders perfectly before first tick
	var st_lens := SurfaceTool.new()
	st_lens.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	_add_box(st_lens, Vector3(0, 0, 0.04), Vector3(0.74, 0.20, 0.06), Color.WHITE)
	
	st_lens.generate_normals()
	st_lens.generate_tangents()
	# Use closed red as default
	var default_mat := StandardMaterial3D.new()
	default_mat.albedo_color = Color(1.0, 0.1, 0.1)
	default_mat.emission_enabled = true
	default_mat.emission = Color(1.0, 0.15, 0.15)
	default_mat.emission_energy_multiplier = 2.0
	st_lens.set_material(default_mat)
	st_lens.commit(mesh)
	
	ResourceSaver.save(mesh, GATE_LIGHT_PATH)
	print("[StructureGenerator] Saved Gate Light mesh: ", GATE_LIGHT_PATH)
