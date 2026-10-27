extends Node

# Forensic Integrity Audit Script for Milestone 2: Terran Base Structures & Fortress
# Independent Empirical Verification Suite

var total_checks: int = 0
var passed_checks: int = 0
var failed_checks: int = 0
var findings: Array[String] = []


func _ready() -> void:
	print("=================================================================")
	print("=== FORENSIC INTEGRITY AUDIT: MILESTONE 2 BASE STRUCTURES ===")
	print("=================================================================")
	
	_audit_pbr_materials()
	_audit_structure_mesh_buffers()
	_audit_scene_hierarchies_and_collisions()
	_audit_gate_operational_contract()
	_audit_bunker_dynamic_upgrade()
	_audit_main_level_perimeter_integration()
	
	print("\n=================================================================")
	print("AUDIT SUMMARY: Total: %d, Passed: %d, Failed: %d" % [total_checks, passed_checks, failed_checks])
	if failed_checks > 0:
		print("VERDICT: INTEGRITY VIOLATION DETECTED")
		for f in findings:
			print("  [VIOLATION] %s" % f)
		print("=================================================================")
		get_tree().quit(1)
	else:
		print("VERDICT: CLEAN - ALL INTEGRITY CHECKS PASSED")
		print("=================================================================")
		get_tree().quit(0)


func _assert(cond: bool, check_name: String, details: String = "") -> void:
	total_checks += 1
	if not cond:
		failed_checks += 1
		findings.append("%s: %s" % [check_name, details])
		print("  [FAIL] %s - %s" % [check_name, details])
	else:
		passed_checks += 1
		print("  [PASS] %s" % check_name)


func _audit_pbr_materials() -> void:
	print("\n--- Phase 1: PBR Material Authenticity Audit ---")
	var mat_paths := [
		"res://assets/materials/structures/terran_hull_pbr.tres",
		"res://assets/materials/structures/terran_dark_steel.tres",
		"res://assets/materials/structures/terran_blue_glow.tres",
		"res://assets/materials/structures/terran_exhaust_glow.tres",
		"res://assets/materials/structures/terran_beacon_red.tres",
		"res://assets/materials/structures/terran_hazard_stripe.tres",
		"res://assets/materials/structures/terran_slit_amber.tres",
		"res://assets/materials/structures/terran_catwalk.tres"
	]
	
	for path in mat_paths:
		var res: Resource = ResourceLoader.load(path)
		_assert(res != null, "Material Exists: " + path.get_file(), "Failed to load resource")
		_assert(res is StandardMaterial3D, "Material is StandardMaterial3D: " + path.get_file(), "Type is %s" % (res.get_class() if res else "null"))
		if res is StandardMaterial3D:
			var mat: StandardMaterial3D = res as StandardMaterial3D
			_assert(mat.albedo_color.a > 0.0, "Material Albedo Valid: " + path.get_file(), "Albedo color is transparent or zero")
			if path.contains("glow") or path.contains("slit") or path.contains("beacon"):
				_assert(mat.emission_enabled, "Emission Enabled: " + path.get_file(), "Emission should be enabled for glow material")
				_assert(mat.emission_energy_multiplier >= 1.5, "Emission Energy Multiplier Authentic: " + path.get_file(), "Energy is %f" % mat.emission_energy_multiplier)
			if path.contains("hull") or path.contains("steel") or path.contains("catwalk"):
				_assert(mat.metallic >= 0.7, "Metallic Parameter Authentic: " + path.get_file(), "Metallic is %f" % mat.metallic)


func _audit_structure_mesh_buffers() -> void:
	print("\n--- Phase 2: Authentic 3D Mesh Vertex Buffer Forensic Audit ---")
	var mesh_specs := {
		"res://assets/models/structures/command_center_mesh.tres": {"min_surfaces": 5, "min_verts": 500, "expected_min_y": 0.0, "max_height": 5.1},
		"res://assets/models/structures/wall_segment_mesh.tres": {"min_surfaces": 4, "min_verts": 200, "expected_min_y": 0.0, "max_height": 3.6},
		"res://assets/models/structures/bunker_structure_mesh.tres": {"min_surfaces": 4, "min_verts": 300, "expected_min_y": 0.0, "max_height": 3.0},
		"res://assets/models/structures/gate_frame_mesh.tres": {"min_surfaces": 4, "min_verts": 250, "expected_min_y": 0.0, "max_height": 4.5},
		"res://assets/models/structures/gate_door_mesh.tres": {"min_surfaces": 4, "min_verts": 150, "expected_min_y": -1.7, "max_height": 1.7},
		"res://assets/models/structures/gate_light_mesh.tres": {"min_surfaces": 2, "min_verts": 40, "expected_min_y": -0.2, "max_height": 0.2}
	}
	
	for path in mesh_specs.keys():
		var spec: Dictionary = mesh_specs[path]
		var res: Resource = ResourceLoader.load(path)
		var fname: String = path.get_file()
		_assert(res != null, "Mesh Exists: " + fname, "Failed to load mesh resource")
		_assert(res is ArrayMesh, "Mesh is ArrayMesh: " + fname, "Resource is not ArrayMesh")
		if not (res is ArrayMesh):
			continue
		
		var am: ArrayMesh = res as ArrayMesh
		var surf_count: int = am.get_surface_count()
		_assert(surf_count >= spec["min_surfaces"], "Surface Count: %s (got %d, need >=%d)" % [fname, surf_count, spec["min_surfaces"]], "Insufficient surfaces")
		
		var total_verts: int = 0
		var total_indices: int = 0
		for s in range(surf_count):
			var arrays: Array = am.surface_get_arrays(s)
			_assert(arrays.size() == Mesh.ARRAY_MAX, "Surface Array Count: %s[s%d]" % [fname, s], "Arrays size is %d" % arrays.size())
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			
			_assert(verts.size() > 0, "Non-Empty Vertex Buffer: %s[s%d] (%d verts)" % [fname, s, verts.size()], "Vertex buffer empty")
			_assert(norms.size() == verts.size(), "Normal Buffer Matches Verts: %s[s%d]" % [fname, s], "Normals size %d vs verts %d" % [norms.size(), verts.size()])
			_assert(uvs.size() == verts.size(), "UV Buffer Matches Verts: %s[s%d]" % [fname, s], "UVs size %d vs verts %d" % [uvs.size(), verts.size()])
			
			if arrays[Mesh.ARRAY_INDEX] != null:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				_assert(indices.size() > 0 and indices.size() % 3 == 0, "Valid Index Buffer: %s[s%d] (%d indices)" % [fname, s, indices.size()], "Invalid index buffer")
				total_indices += indices.size()
			else:
				_assert(verts.size() % 3 == 0, "Unindexed Triangles Divisible by 3: %s[s%d]" % [fname, s], "Vertex count %d not divisible by 3" % verts.size())
				total_indices += verts.size()
			
			# Check non-degeneracy
			var has_nan := false
			var min_v := Vector3(INF, INF, INF)
			var max_v := Vector3(-INF, -INF, -INF)
			for v in verts:
				if is_nan(v.x) or is_nan(v.y) or is_nan(v.z):
					has_nan = true
					break
				min_v.x = minf(min_v.x, v.x)
				min_v.y = minf(min_v.y, v.y)
				min_v.z = minf(min_v.z, v.z)
				max_v.x = maxf(max_v.x, v.x)
				max_v.y = maxf(max_v.y, v.y)
				max_v.z = maxf(max_v.z, v.z)
			_assert(not has_nan, "No NaN Vertices: %s[s%d]" % [fname, s], "NaN found in vertex buffer")
			_assert((max_v - min_v).length() > 0.01, "Non-Zero Bounding Volume: %s[s%d]" % [fname, s], "Degenerate zero-size volume")
			
			# Material check
			var mat: Material = am.surface_get_material(s)
			_assert(mat != null, "Surface Has Material: %s[s%d]" % [fname, s], "Surface material is null")
			
			total_verts += verts.size()
		
		_assert(total_verts >= spec["min_verts"], "Authentic Geometry Density: %s (%d verts >= %d)" % [fname, total_verts, spec["min_verts"]], "Vertex density too low")
		
		# AABB verification
		var aabb := am.get_aabb()
		if fname != "gate_door_mesh.tres" and fname != "gate_light_mesh.tres":
			_assert(is_equal_approx(aabb.position.y, spec["expected_min_y"]), "Ground Contact Flush at 0.0: %s (y=%f)" % [fname, aabb.position.y], "Mesh does not anchor at y=0.0")
		_assert(aabb.end.y <= spec["max_height"], "Height Within Bounds: %s (max_y=%f <= %f)" % [fname, aabb.end.y, spec["max_height"]], "Height exceeds maximum bound")


func _audit_scene_hierarchies_and_collisions() -> void:
	print("\n--- Phase 3: Scene Hierarchies & Strict Collision Invariants Audit ---")
	
	# 1. Command Center
	var cc_scene := load("res://entities/structures/command_center.tscn") as PackedScene
	_assert(cc_scene != null, "Scene Loaded: command_center.tscn", "Failed to load")
	if cc_scene:
		var cc: Node = cc_scene.instantiate()
		var col: CollisionShape3D = cc.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col != null and col.shape is BoxShape3D, "CC: CollisionShape3D is BoxShape3D", "Missing or wrong type")
		if col and col.shape is BoxShape3D:
			var b := col.shape as BoxShape3D
			_assert(b.size.is_equal_approx(Vector3(8, 4, 8)), "CC: Invariant BoxShape3D(8, 4, 8)", "Got size %s" % str(b.size))
			_assert(col.position.is_equal_approx(Vector3(0, 2, 0)), "CC: Invariant Collision Position (0, 2, 0)", "Got pos %s" % str(col.position))
		var vroot := cc.get_node_or_null("VisualRoot")
		_assert(vroot != null, "CC: VisualRoot Exists", "VisualRoot missing")
		var fmesh := cc.get_node_or_null("VisualRoot/FortressMesh") as MeshInstance3D
		_assert(fmesh != null and fmesh.mesh is ArrayMesh, "CC: FortressMesh is ArrayMesh", "FortressMesh missing or wrong type")
		cc.free()
	
	# 2. Wall Segment
	var wall_scene := load("res://entities/structures/wall_segment.tscn") as PackedScene
	_assert(wall_scene != null, "Scene Loaded: wall_segment.tscn", "Failed to load")
	if wall_scene:
		var wall: Node = wall_scene.instantiate()
		var col: CollisionShape3D = wall.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col != null and col.shape is BoxShape3D, "Wall: CollisionShape3D is BoxShape3D", "Missing or wrong type")
		if col and col.shape is BoxShape3D:
			var b := col.shape as BoxShape3D
			_assert(b.size.is_equal_approx(Vector3(4, 3.2, 1.2)), "Wall: Invariant BoxShape3D(4, 3.2, 1.2)", "Got size %s" % str(b.size))
			_assert(col.position.is_equal_approx(Vector3(0, 1.6, 0)), "Wall: Invariant Collision Position (0, 1.6, 0)", "Got pos %s" % str(col.position))
		var wmesh := wall.get_node_or_null("VisualRoot/WallMesh") as MeshInstance3D
		_assert(wmesh != null and wmesh.mesh is ArrayMesh, "Wall: WallMesh is ArrayMesh", "WallMesh missing or wrong type")
		wall.free()
	
	# 3. Bunker Structure Scene
	var bunker_scene := load("res://entities/structures/bunker_structure.tscn") as PackedScene
	_assert(bunker_scene != null, "Scene Loaded: bunker_structure.tscn", "Failed to load")
	if bunker_scene:
		var bunker: Node = bunker_scene.instantiate()
		var col: CollisionShape3D = bunker.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col != null and col.shape is BoxShape3D, "Bunker: CollisionShape3D is BoxShape3D", "Missing or wrong type")
		if col and col.shape is BoxShape3D:
			var b := col.shape as BoxShape3D
			_assert(b.size.is_equal_approx(Vector3(3.5, 2.5, 3.5)), "Bunker: Invariant BoxShape3D(3.5, 2.5, 3.5)", "Got size %s" % str(b.size))
			_assert(col.position.is_equal_approx(Vector3(0, 1.25, 0)), "Bunker: Invariant Collision Position (0, 1.25, 0)", "Got pos %s" % str(col.position))
		var bmesh := bunker.get_node_or_null("VisualRoot/BunkerMesh") as MeshInstance3D
		_assert(bmesh != null and bmesh.mesh is ArrayMesh, "Bunker: BunkerMesh is ArrayMesh", "BunkerMesh missing or wrong type")
		bunker.free()
	
	# 4. Gate Structure Scene
	var gate_scene := load("res://entities/structures/gate_structure.tscn") as PackedScene
	_assert(gate_scene != null, "Scene Loaded: gate_structure.tscn", "Failed to load")
	if gate_scene:
		var gate: Node = gate_scene.instantiate()
		var dcol := gate.get_node_or_null("DoorCollisionShape") as CollisionShape3D
		_assert(dcol != null and dcol.shape is BoxShape3D, "Gate: DoorCollisionShape is BoxShape3D", "Missing")
		if dcol and dcol.shape is BoxShape3D:
			var b := dcol.shape as BoxShape3D
			_assert(b.size.is_equal_approx(Vector3(4, 3.3, 0.6)), "Gate: Door Collision BoxShape3D(4, 3.3, 0.6)", "Got size %s" % str(b.size))
		var pcol_left := gate.get_node_or_null("PillarLeftCol") as CollisionShape3D
		var pcol_right := gate.get_node_or_null("PillarRightCol") as CollisionShape3D
		_assert(pcol_left != null and pcol_right != null, "Gate: Left & Right Pillar Collisions Exist", "Pillar collision missing")
		var prox := gate.get_node_or_null("ProximityArea") as Area3D
		_assert(prox != null, "Gate: ProximityArea Exists", "ProximityArea missing")
		gate.free()


func _audit_gate_operational_contract() -> void:
	print("\n--- Phase 4: Gate Strict Node Path Contracts & Operational Dynamics Audit ---")
	var gate_scene := load("res://entities/structures/gate_structure.tscn") as PackedScene
	var gate: GateStructure = gate_scene.instantiate() as GateStructure
	add_child(gate)
	
	# Contract node paths
	var door_vis: Node3D = gate.get_node_or_null("VisualRoot/DoorSlidingPart") as Node3D
	_assert(door_vis != null, "Contract: $VisualRoot/DoorSlidingPart Exists", "Node missing at required relative path")
	
	var status_light: MeshInstance3D = gate.get_node_or_null("VisualRoot/StatusLight") as MeshInstance3D
	_assert(status_light != null, "Contract: $VisualRoot/StatusLight Exists", "Node missing at required relative path")
	
	# Operational states
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate Starts in CLOSED State", "Initial state is not CLOSED")
	if status_light and status_light.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = status_light.material_override as StandardMaterial3D
		_assert(mat.albedo_color.r > 0.8 and mat.albedo_color.g < 0.3, "Gate Closed StatusLight is Red", "Color is %s" % str(mat.albedo_color))
	
	# Open gate transition
	gate.open_gate(false)
	_assert(gate.current_state == GateStructure.GateState.OPEN, "Gate Changes State to OPEN", "State is not OPEN")
	if status_light and status_light.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = status_light.material_override as StandardMaterial3D
		_assert(mat.albedo_color.g > 0.8 and mat.albedo_color.r < 0.3, "Gate Open StatusLight is Green", "Color is %s" % str(mat.albedo_color))
	
	# Slide animation step
	var dummy_ally := Node3D.new()
	dummy_ally.add_to_group("allies")
	add_child(dummy_ally)
	gate._nearby_allies.append(dummy_ally)
	
	var initial_y: float = door_vis.position.y
	gate._process(0.2)
	_assert(door_vis.position.y < initial_y, "Gate Door Slides Downward on Tick", "Door Y did not decrease: %f vs %f" % [door_vis.position.y, initial_y])
	gate._process(0.6) # complete sliding
	var door_col: CollisionShape3D = gate.get_node_or_null("DoorCollisionShape") as CollisionShape3D
	_assert(door_col.disabled == true, "Gate Door Collision Disabled when Open", "Door collision should be disabled")
	
	# Player lock toggle
	gate.toggle_gate()
	_assert(gate.is_locked_by_player == true, "Gate Player Lock Engaged on Toggle", "is_locked_by_player is false")
	if status_light and status_light.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = status_light.material_override as StandardMaterial3D
		_assert(mat.albedo_color.r > 0.8 and mat.albedo_color.g > 0.5, "Gate Locked StatusLight is Amber", "Color is %s" % str(mat.albedo_color))
	
	# Restore and close
	gate.toggle_gate() # unlock
	gate.close_gate(false)
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate State Restored to CLOSED", "State is not CLOSED")
	_assert(door_col.disabled == false, "Gate Door Collision Re-enabled when Closed", "Door collision should be enabled")
	
	gate._nearby_allies.clear()
	dummy_ally.free()
	gate.free()


func _audit_bunker_dynamic_upgrade() -> void:
	print("\n--- Phase 5: Bunker Dynamic Visual Upgrade & Mitigation Audit ---")
	var BunkerScript = load("res://levels/bunker_structure.gd")
	var node := StaticBody3D.new()
	node.set_script(BunkerScript)
	var vr := Node3D.new()
	vr.name = "VisualRoot"
	node.add_child(vr)
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	mi.mesh = BoxMesh.new()
	vr.add_child(mi)
	
	add_child(node)
	_assert(mi.mesh is ArrayMesh, "BunkerScript Upgraded Primitive BoxMesh to ArrayMesh", "Mesh is %s" % mi.mesh.get_class())
	if mi.mesh is ArrayMesh:
		var am: ArrayMesh = mi.mesh as ArrayMesh
		_assert(am.get_surface_count() >= 4, "Upgraded Bunker Mesh has >=4 surfaces", "Surfaces: %d" % am.get_surface_count())
	node.free()
	
	# Mitigation checks
	var SFECombatEngine = load("res://core/combat/sfe_combat_engine.gd")
	var CombatTypes = load("res://core/combat/combat_types.gd")
	var bunker_mit = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER)
	_assert(is_equal_approx(bunker_mit.damage_dealt, 75.0), "Bunker 25% Passive Mitigation Authentic", "Damage dealt is %f" % bunker_mit.damage_dealt)
	var wall_mit = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED)
	_assert(is_equal_approx(wall_mit.damage_dealt, 65.0), "Wall 35% Passive Mitigation Authentic", "Damage dealt is %f" % wall_mit.damage_dealt)


func _audit_main_level_perimeter_integration() -> void:
	print("\n--- Phase 6: MainLevel 30-Structure Perimeter & Flow Field Integration Audit ---")
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	_assert(main_scene != null, "main_level.tscn Loads Cleanly", "Failed to load main level scene")
	if not main_scene:
		return
	
	var main_level: Node = main_scene.instantiate()
	add_child(main_level)
	
	# Check structures in perimeter
	var perimeter := main_level.get_node_or_null("NavigationRegion3D/BasePerimeter") as Node3D
	_assert(perimeter != null, "NavigationRegion3D/BasePerimeter Exists", "BasePerimeter not found")
	if perimeter:
		var cc := perimeter.get_node_or_null("CommandCenter")
		_assert(cc != null and cc is CommandCenter, "Perimeter Contains CommandCenter", "CommandCenter missing")
		var w_gate := perimeter.get_node_or_null("WestGate")
		var e_gate := perimeter.get_node_or_null("EastGate")
		_assert(w_gate != null and e_gate != null, "Perimeter Contains Both WestGate and EastGate", "Gates missing")
		var w_bunker := perimeter.get_node_or_null("BunkerWest")
		var e_bunker := perimeter.get_node_or_null("BunkerEast")
		_assert(w_bunker != null and e_bunker != null, "Perimeter Contains Both BunkerWest and BunkerEast", "Bunkers missing")
		
		# Verify bunker meshes are upgraded
		if w_bunker:
			var bmi := w_bunker.get_node_or_null("VisualRoot/MeshInstance3D") as MeshInstance3D
			_assert(bmi != null and bmi.mesh is ArrayMesh, "BunkerWest Visual Upgraded to ArrayMesh", "BunkerWest mesh is %s" % (bmi.mesh.get_class() if bmi and bmi.mesh else "null"))
		if e_bunker:
			var bmi := e_bunker.get_node_or_null("VisualRoot/MeshInstance3D") as MeshInstance3D
			_assert(bmi != null and bmi.mesh is ArrayMesh, "BunkerEast Visual Upgraded to ArrayMesh", "BunkerEast mesh is %s" % (bmi.mesh.get_class() if bmi and bmi.mesh else "null"))
		
		var walls := 0
		for child in perimeter.get_children():
			if child is WallSegment:
				walls += 1
		_assert(walls == 25, "Perimeter Contains Exactly 25 Wall Segments", "Found %d walls" % walls)
	
	# Flow field dynamic obstacle count check
	var sim = main_level.get("swarm_simulation")
	if sim and sim.flow_field:
		var obs_count: int = sim.flow_field.registered_obstacles.size()
		_assert(obs_count == 30, "SwarmSimulation Registered Exactly 30 Dynamic Obstacles", "Registered %d obstacles" % obs_count)
	else:
		_assert(false, "SwarmSimulation/FlowField Initialized in MainLevel", "swarm_simulation or flow_field is null")
	
	main_level.queue_free()
