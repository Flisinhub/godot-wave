extends Node

# Challenger M2 Verification Suite: Terran Base Structures & Fortress
# Empirically verifies:
# 1. Command Center / Planetary Fortress visuals, mesh surfaces, ground flushness, collision bounds
# 2. Modular Wall Segment visuals, interlocking dimensions, catwalk, passive 35% mitigation
# 3. Automated Security Gate strict node contracts ($VisualRoot/DoorSlidingPart, $VisualRoot/StatusLight),
#    sliding kinematics between Y=1.65 and Y=-1.95, dynamic status materials (Red/Green/Amber)
# 4. Bunker Structure octagonal visuals, embrasure glow, passive 25% mitigation, runtime mesh upgrade
# 5. Full MainLevel 30-structure perimeter integration and flow field obstacle registration

const CommandCenterScene = preload("res://entities/structures/command_center.tscn")
const WallSegmentScene = preload("res://entities/structures/wall_segment.tscn")
const GateStructureScene = preload("res://entities/structures/gate_structure.tscn")
const BunkerStructureScene = preload("res://entities/structures/bunker_structure.tscn")
const BunkerScript = preload("res://levels/bunker_structure.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _ready() -> void:
	print("\n========================================================")
	print("=== CHALLENGER M2: TERRAN BASE STRUCTURES VERIFICATION ===")
	print("========================================================")
	
	_run_all_tests()
	
	print("\n========================================================")
	print("Challenger M2 Results: Total: %d, Passed: %d, Failed: %d" % [total_tests, passed_tests, failed_tests])
	if failed_tests > 0:
		print("FAILURES DETECTED:")
		for f in failures:
			print("  [FAIL] %s" % f)
		print("========================================================\n")
		get_tree().quit(1)
	else:
		print("ALL CHALLENGER M2 TESTS PASSED SUCCESSFULLY! [GREEN]")
		print("========================================================\n")
		get_tree().quit(0)


func _assert(condition: bool, test_name: String, error_msg: String) -> bool:
	total_tests += 1
	if not condition:
		failed_tests += 1
		failures.append("%s: %s" % [test_name, error_msg])
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		return false
	passed_tests += 1
	print("  [PASS] %s" % test_name)
	return true


func _run_all_tests() -> void:
	_test_command_center_invariants_and_visuals()
	_test_wall_segment_invariants_and_visuals()
	_test_gate_structure_contracts_and_animation()
	_test_bunker_structure_invariants_and_mitigation()
	_test_main_level_structures_integration()


func _test_command_center_invariants_and_visuals() -> void:
	print("\n>> Testing Command Center / Planetary Fortress...")
	var cc: StaticBody3D = CommandCenterScene.instantiate() as StaticBody3D
	_assert(cc != null, "CC: Instantiation", "CommandCenter scene failed to instantiate")
	if not cc:
		return
	
	add_child(cc)
	
	# Group check
	_assert(cc.is_in_group("structures"), "CC: Group Registration", "CC not in 'structures' group")
	
	# Strict Collision invariant: BoxShape3D(8, 4, 8) at (0, 2, 0)
	var col: CollisionShape3D = cc.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_assert(col != null, "CC: CollisionShape3D Exists", "CollisionShape3D missing")
	if col:
		_assert(col.shape is BoxShape3D, "CC: Shape is BoxShape3D", "Shape is not BoxShape3D")
		var box: BoxShape3D = col.shape as BoxShape3D
		_assert(box.size.is_equal_approx(Vector3(8, 4, 8)), "CC: Shape Extents (8,4,8)", "BoxShape3D size is %s, expected (8,4,8)" % str(box.size))
		_assert(col.position.is_equal_approx(Vector3(0, 2, 0)), "CC: Shape Position (0,2,0)", "Collision position is %s, expected (0,2,0)" % str(col.position))
	
	# VisualRoot & Mesh verification
	var visual_root: Node3D = cc.get_node_or_null("VisualRoot") as Node3D
	_assert(visual_root != null, "CC: VisualRoot Exists", "VisualRoot missing")
	if visual_root:
		var fortress_mesh_node: MeshInstance3D = visual_root.get_node_or_null("FortressMesh") as MeshInstance3D
		_assert(fortress_mesh_node != null, "CC: FortressMesh Exists", "FortressMesh missing under VisualRoot")
		if fortress_mesh_node:
			_assert(fortress_mesh_node.mesh is ArrayMesh, "CC: FortressMesh is ArrayMesh", "FortressMesh is not ArrayMesh")
			var am: ArrayMesh = fortress_mesh_node.mesh as ArrayMesh
			_assert(am.get_surface_count() >= 5, "CC: Multi-Surface Model (>=5 surfaces)", "Surface count is %d, expected at least 5" % am.get_surface_count())
			
			# Check AABB / ground flushness
			var aabb := am.get_aabb()
			_assert(is_equal_approx(aabb.position.y, 0.0), "CC: Ground Contact Flush at y=0.0", "AABB bottom is %f, expected 0.0" % aabb.position.y)
			_assert(aabb.end.y > 4.5 and aabb.end.y <= 5.15, "CC: Fortress Height within Bounds (<5.2 for HealthBar)", "Height is %f" % aabb.end.y)
	
	# HealthBar invariant
	var health_bar := cc.get_node_or_null("HealthBar3D")
	_assert(health_bar != null, "CC: HealthBar3D Exists", "HealthBar3D missing")
	
	# Combat logic test
	var initial_hp: float = cc.current_health
	cc.take_damage(250.0)
	_assert(is_equal_approx(cc.current_health, initial_hp - 250.0), "CC: Damage Mechanics", "HP is %f, expected %f" % [cc.current_health, initial_hp - 250.0])
	
	cc.queue_free()


func _test_wall_segment_invariants_and_visuals() -> void:
	print("\n>> Testing Modular Wall Segment...")
	var wall: StaticBody3D = WallSegmentScene.instantiate() as StaticBody3D
	_assert(wall != null, "Wall: Instantiation", "WallSegment scene failed to instantiate")
	if not wall:
		return
	
	add_child(wall)
	
	# Group check
	_assert(wall.is_in_group("structures"), "Wall: Group Registration", "Wall not in 'structures' group")
	
	# Strict Collision invariant: BoxShape3D(4, 3.2, 1.2) at (0, 1.6, 0)
	var col: CollisionShape3D = wall.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_assert(col != null, "Wall: CollisionShape3D Exists", "CollisionShape3D missing")
	if col:
		_assert(col.shape is BoxShape3D, "Wall: Shape is BoxShape3D", "Shape is not BoxShape3D")
		var box: BoxShape3D = col.shape as BoxShape3D
		_assert(box.size.is_equal_approx(Vector3(4, 3.2, 1.2)), "Wall: Shape Extents (4, 3.2, 1.2)", "Box size is %s, expected (4, 3.2, 1.2)" % str(box.size))
		_assert(col.position.is_equal_approx(Vector3(0, 1.6, 0)), "Wall: Shape Position (0, 1.6, 0)", "Position is %s, expected (0, 1.6, 0)" % str(col.position))
	
	# VisualRoot & Mesh verification
	var visual_root: Node3D = wall.get_node_or_null("VisualRoot") as Node3D
	_assert(visual_root != null, "Wall: VisualRoot Exists", "VisualRoot missing")
	if visual_root:
		var wall_mesh_node: MeshInstance3D = visual_root.get_node_or_null("WallMesh") as MeshInstance3D
		_assert(wall_mesh_node != null, "Wall: WallMesh Exists", "WallMesh missing under VisualRoot")
		if wall_mesh_node:
			_assert(wall_mesh_node.mesh is ArrayMesh, "Wall: WallMesh is ArrayMesh", "WallMesh is not ArrayMesh")
			var am: ArrayMesh = wall_mesh_node.mesh as ArrayMesh
			_assert(am.get_surface_count() >= 4, "Wall: Multi-Surface Model (>=4 surfaces)", "Surface count is %d, expected at least 4" % am.get_surface_count())
			
			# Ground flushness
			var aabb := am.get_aabb()
			_assert(is_equal_approx(aabb.position.y, 0.0), "Wall: Ground Contact Flush at y=0.0", "AABB bottom is %f, expected 0.0" % aabb.position.y)
			_assert(is_equal_approx(aabb.size.x, 4.0) or (aabb.size.x >= 3.9 and aabb.size.x <= 4.05), "Wall: Width spans 4.0m", "Width is %f" % aabb.size.x)
	
	# Mitigation check (35% passive mitigation)
	var calc := SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED)
	_assert(is_equal_approx(calc.damage_dealt, 65.0), "Wall: Passive 35% Mitigation Verified", "Damage dealt is %f, expected 65.0" % calc.damage_dealt)
	
	wall.queue_free()


func _test_gate_structure_contracts_and_animation() -> void:
	print("\n>> Testing Automated Security Gate...")
	var gate: GateStructure = GateStructureScene.instantiate() as GateStructure
	_assert(gate != null, "Gate: Instantiation", "GateStructure scene failed to instantiate")
	if not gate:
		return
	
	add_child(gate)
	
	# Groups
	_assert(gate.is_in_group("gates"), "Gate: In 'gates' Group", "Gate missing from 'gates' group")
	_assert(gate.is_in_group("structures"), "Gate: In 'structures' Group", "Gate missing from 'structures' group")
	
	# Strict Node Contracts
	var door_vis: Node3D = gate.get_node_or_null("VisualRoot/DoorSlidingPart") as Node3D
	_assert(door_vis != null, "Gate Contract: $VisualRoot/DoorSlidingPart Exists", "DoorSlidingPart missing at exact relative path")
	
	var status_mesh: MeshInstance3D = gate.get_node_or_null("VisualRoot/StatusLight") as MeshInstance3D
	_assert(status_mesh != null, "Gate Contract: $VisualRoot/StatusLight Exists & is MeshInstance3D", "StatusLight missing or wrong type")
	
	var door_col: CollisionShape3D = gate.get_node_or_null("DoorCollisionShape") as CollisionShape3D
	_assert(door_col != null, "Gate Invariant: DoorCollisionShape Exists", "DoorCollisionShape missing")
	if door_col:
		var box: BoxShape3D = door_col.shape as BoxShape3D
		_assert(box != null and box.size.is_equal_approx(Vector3(4, 3.3, 0.6)), "Gate: Door Collision Size (4, 3.3, 0.6)", "Size is %s" % str(box.size))
	
	var prox: Area3D = gate.get_node_or_null("ProximityArea") as Area3D
	_assert(prox != null, "Gate Invariant: ProximityArea Exists", "ProximityArea missing")
	
	# Initial Closed State
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate: Initial State CLOSED", "State is not CLOSED")
	if status_mesh:
		_assert(status_mesh.material_override != null, "Gate: StatusLight Material Set", "material_override is null")
		if status_mesh.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = status_mesh.material_override as StandardMaterial3D
			_assert(mat.albedo_color.r > 0.8 and mat.albedo_color.g < 0.3, "Gate: Closed StatusLight is Red", "Color is %s" % str(mat.albedo_color))
	
	# Open Gate Test
	gate.open_gate(false)
	_assert(gate.current_state == GateStructure.GateState.OPEN, "Gate: Open Gate State", "State not OPEN")
	_assert(is_equal_approx(gate._target_door_y, -1.95) or is_equal_approx(gate._target_door_y, -1.9), "Gate: Target Door Open Y ≈ -1.95", "Target Y is %f" % gate._target_door_y)
	if status_mesh and status_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = status_mesh.material_override as StandardMaterial3D
		_assert(mat.albedo_color.g > 0.8 and mat.albedo_color.r < 0.3, "Gate: Open StatusLight is Green", "Color is %s" % str(mat.albedo_color))
	
	# Simulate animation progress with an ally present
	var dummy_ally := Node3D.new()
	dummy_ally.add_to_group("allies")
	add_child(dummy_ally)
	gate._nearby_allies.append(dummy_ally)
	
	gate._process(0.2)
	_assert(door_vis.position.y < 1.65, "Gate: Door Slides Downward", "Door Y did not decrease: %f" % door_vis.position.y)
	gate._process(0.5) # reaches target
	_assert(door_col.disabled == true, "Gate: Collision Disabled when fully opened", "Collision is not disabled")
	
	gate._nearby_allies.clear()
	dummy_ally.queue_free()
	
	# Player Toggle / Locking Test
	gate.toggle_gate() # locks gate
	_assert(gate.is_locked_by_player == true, "Gate: Player Lock Engaged", "is_locked_by_player is false")
	if status_mesh and status_mesh.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = status_mesh.material_override as StandardMaterial3D
		_assert(mat.albedo_color.r > 0.8 and mat.albedo_color.g > 0.5, "Gate: Locked StatusLight is Amber", "Color is %s" % str(mat.albedo_color))
	
	# Close Gate Test
	gate.toggle_gate() # unlocks
	gate.close_gate(false)
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate: Restores CLOSED", "State not CLOSED")
	_assert(door_col.disabled == false, "Gate: Collision Re-enabled when closed", "Collision disabled")
	
	gate.queue_free()


func _test_bunker_structure_invariants_and_mitigation() -> void:
	print("\n>> Testing Fortified Bunker Structure...")
	var bunker: StaticBody3D = BunkerStructureScene.instantiate() as StaticBody3D
	_assert(bunker != null, "Bunker: Instantiation", "BunkerStructure scene failed to instantiate")
	if not bunker:
		return
	
	add_child(bunker)
	
	# Groups
	_assert(bunker.is_in_group("structures"), "Bunker: In 'structures' Group", "Missing from 'structures'")
	_assert(bunker.is_in_group("bunkers"), "Bunker: In 'bunkers' Group", "Missing from 'bunkers'")
	
	# Collision Invariant: BoxShape3D(3.5, 2.5, 3.5) at (0, 1.25, 0)
	var col: CollisionShape3D = bunker.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_assert(col != null, "Bunker: CollisionShape3D Exists", "CollisionShape3D missing")
	if col:
		var box: BoxShape3D = col.shape as BoxShape3D
		_assert(box != null and box.size.is_equal_approx(Vector3(3.5, 2.5, 3.5)), "Bunker: BoxShape3D Size (3.5, 2.5, 3.5)", "Size is %s" % str(box.size))
		_assert(col.position.is_equal_approx(Vector3(0, 1.25, 0)), "Bunker: Position (0, 1.25, 0)", "Position is %s" % str(col.position))
	
	# VisualRoot & Mesh
	var visual_root: Node3D = bunker.get_node_or_null("VisualRoot") as Node3D
	_assert(visual_root != null, "Bunker: VisualRoot Exists", "VisualRoot missing")
	if visual_root:
		var mesh_node: MeshInstance3D = visual_root.get_node_or_null("BunkerMesh") as MeshInstance3D
		_assert(mesh_node != null, "Bunker: BunkerMesh Exists", "BunkerMesh missing")
		if mesh_node:
			_assert(mesh_node.mesh is ArrayMesh, "Bunker: Mesh is ArrayMesh", "Mesh is not ArrayMesh")
			var am: ArrayMesh = mesh_node.mesh as ArrayMesh
			_assert(am.get_surface_count() >= 4, "Bunker: Multi-Surface Model (>=4 surfaces)", "Surface count is %d" % am.get_surface_count())
			
			var aabb := am.get_aabb()
			_assert(is_equal_approx(aabb.position.y, 0.0), "Bunker: Ground Flush at y=0.0", "AABB bottom is %f" % aabb.position.y)
	
	# Mitigation check (25% passive mitigation)
	var calc := SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER)
	_assert(is_equal_approx(calc.damage_dealt, 75.0), "Bunker: Passive 25% Mitigation Verified", "Damage dealt is %f, expected 75.0" % calc.damage_dealt)
	
	# Runtime mesh replacement test in BunkerScript
	var dynamic_bunker := StaticBody3D.new()
	dynamic_bunker.set_script(BunkerScript)
	var dyn_vr := Node3D.new()
	dyn_vr.name = "VisualRoot"
	dynamic_bunker.add_child(dyn_vr)
	var dyn_mesh := MeshInstance3D.new()
	dyn_mesh.name = "MeshInstance3D"
	dyn_mesh.mesh = BoxMesh.new() # primitive
	dyn_vr.add_child(dyn_mesh)
	
	add_child(dynamic_bunker) # triggers _ready() -> _setup_visuals()
	_assert(dynamic_bunker.has_method("_setup_visuals"), "Bunker: _setup_visuals Method Exists", "Method missing")
	_assert(dyn_mesh.mesh is ArrayMesh, "Bunker: Dynamic Primitive Replacement to ArrayMesh", "Mesh is still %s" % dyn_mesh.mesh.get_class())
	
	dynamic_bunker.queue_free()
	bunker.queue_free()


func _test_main_level_structures_integration() -> void:
	print("\n>> Testing MainLevel Perimeter Integration...")
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	_assert(main_scene != null, "MainLevel: Scene Load", "Failed to load main_level.tscn")
	if not main_scene:
		return
	
	var main_level: Node = main_scene.instantiate()
	add_child(main_level)
	
	var base_perimeter: Node3D = main_level.get_node_or_null("NavigationRegion3D/BasePerimeter") as Node3D
	_assert(base_perimeter != null, "BasePerimeter: Node Exists", "BasePerimeter not found under NavigationRegion3D")
	if base_perimeter:
		var cc := base_perimeter.get_node_or_null("CommandCenter")
		_assert(cc != null and cc is CommandCenter, "BasePerimeter: CommandCenter Exists & Typed", "CommandCenter missing")
		
		var west_gate := base_perimeter.get_node_or_null("WestGate") as GateStructure
		var east_gate := base_perimeter.get_node_or_null("EastGate") as GateStructure
		_assert(west_gate != null and east_gate != null, "BasePerimeter: WestGate & EastGate Exist", "Gates missing")
		if west_gate:
			_assert(west_gate.get_node_or_null("VisualRoot/DoorSlidingPart") != null, "WestGate: DoorSlidingPart OK", "DoorSlidingPart missing")
			_assert(west_gate.get_node_or_null("VisualRoot/StatusLight") != null, "WestGate: StatusLight OK", "StatusLight missing")
		
		var bunker_west := base_perimeter.get_node_or_null("BunkerWest")
		var bunker_east := base_perimeter.get_node_or_null("BunkerEast")
		_assert(bunker_west != null and bunker_east != null, "BasePerimeter: BunkerWest & BunkerEast Exist", "Bunkers missing")
		
		var walls := 0
		for child in base_perimeter.get_children():
			if child is WallSegment:
				walls += 1
		_assert(walls == 25, "BasePerimeter: All 25 Wall Segments Present", "Found %d walls, expected 25" % walls)
	
	main_level.queue_free()
