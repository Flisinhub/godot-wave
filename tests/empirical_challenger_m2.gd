extends Node

# Empirical Challenger 2 Verification Harness for Milestone 2:
# Terran Base Structures & Planetary Fortress
#
# Tasks verified empirically:
# 1. Exact AABB footprints of all 30 base structures (1 Command Center, 2 Gates, 2 Bunkers, 25 Walls)
#    in SwarmSimulation.register_obstacle_aabb() / FlowField.registered_obstacles.
# 2. Ground flushness (y = 0.0) of bottom vertices for:
#    - Command Center (command_center_mesh.tres)
#    - Modular Walls (wall_segment_mesh.tres)
#    - Fortified Bunkers (bunker_structure_mesh.tres)
#    - Gate Pillars & Frame (gate_frame_mesh.tres)
# 3. Collision shape boundaries and ground-flush alignment for all structures.
# 4. Runtime mesh upgrade of BunkerWest and BunkerEast in main_level.tscn.
# 5. Dynamic obstacle registration on gate open/close and structure destruction.
# 6. Strict Gate node contracts ($VisualRoot/DoorSlidingPart, $VisualRoot/StatusLight).
# 7. Spatial perimeter continuity across all 25 wall segments and 2 gates.
# 8. Adversarial Stress Tests:
#    - Rapid gate toggle & player locking priority vs ally proximity
#    - Combat engine structural mitigation (Physical & Spell)
#    - Command Center lethal damage & base_destroyed signal

const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")

var failures: Array[String] = []
var tests_run: int = 0
var tests_passed: int = 0


func _ready() -> void:
	print("==================================================================")
	print("=== EMPIRICAL CHALLENGER 2: MILESTONE 2 VERIFICATION HARNESS ===")
	print("==================================================================")
	
	test_mesh_lowest_vertices_and_flushness()
	test_collision_bounds_ground_flushness()
	test_main_level_structure_count_and_transforms()
	test_all_30_structures_exact_aabb_registration()
	test_dynamic_obstacle_updates()
	test_bunker_runtime_visual_replacement()
	test_gate_strict_node_contracts()
	test_wall_perimeter_continuity()
	test_adversarial_gate_stress()
	test_adversarial_mitigation_stress()
	test_adversarial_command_center_lethal()
	
	print("\n==================================================================")
	print("Empirical Verification Results:")
	print("Tests Run:    %d" % tests_run)
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % failures.size())
	
	if failures.is_empty():
		print("\u001b[32mALL EMPIRICAL CHALLENGE CHECKS PASSED PERFECTLY! [VERDICT: APPROVE]\u001b[0m")
		print("==================================================================")
		get_tree().quit(0)
	else:
		print("\u001b[31mEMPIRICAL CHECKS FAILED: [VERDICT: REJECT]\u001b[0m")
		for f in failures:
			print("\u001b[31m  * " + f + "\u001b[0m")
		print("==================================================================")
		get_tree().quit(1)


func _assert(condition: bool, msg: String) -> void:
	tests_run += 1
	if condition:
		tests_passed += 1
		print("  [PASS] " + msg)
	else:
		failures.append(msg)
		print("  [FAIL] " + msg)


func _get_mesh_extents(mesh: Mesh) -> Dictionary:
	var min_y := 999999.0
	var max_y := -999999.0
	var min_x := 999999.0
	var max_x := -999999.0
	var min_z := 999999.0
	var max_z := -999999.0
	var total_verts := 0
	
	if mesh is ArrayMesh:
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_VERTEX:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for v in verts:
					total_verts += 1
					if v.y < min_y: min_y = v.y
					if v.y > max_y: max_y = v.y
					if v.x < min_x: min_x = v.x
					if v.x > max_x: max_x = v.x
					if v.z < min_z: min_z = v.z
					if v.z > max_z: max_z = v.z
	
	return {
		"min_y": min_y, "max_y": max_y,
		"min_x": min_x, "max_x": max_x,
		"min_z": min_z, "max_z": max_z,
		"total_verts": total_verts
	}


# -----------------------------------------------------------------------------
# 1. MESH LOWEST VERTICES & GROUND FLUSHNESS (y = 0.0)
# -----------------------------------------------------------------------------
func test_mesh_lowest_vertices_and_flushness() -> void:
	print("\n>> 1. Testing Mesh Lowest Vertices and Ground Flushness (y = 0.0)...")
	
	# Command Center
	var cc_mesh: Mesh = load("res://assets/models/structures/command_center_mesh.tres")
	_assert(cc_mesh != null, "CC: command_center_mesh.tres loaded successfully")
	if cc_mesh:
		var ext := _get_mesh_extents(cc_mesh)
		_assert(is_equal_approx(ext.min_y, 0.0), "CC: Bottom vertices flush at y=0.0 (actual: %f, verts: %d)" % [ext.min_y, ext.total_verts])
		_assert(ext.max_y > 4.5 and ext.max_y < 5.2, "CC: Top vertices height < 5.2m (under HealthBar3D, actual: %f)" % ext.max_y)
		_assert(ext.min_x >= -4.0 and ext.max_x <= 4.0, "CC: X extents within [-4.0, 4.0] (actual: [%f, %f])" % [ext.min_x, ext.max_x])
		_assert(ext.min_z >= -4.0 and ext.max_z <= 4.0, "CC: Z extents within [-4.0, 4.0] (actual: [%f, %f])" % [ext.min_z, ext.max_z])
	
	# Wall Segment
	var wall_mesh: Mesh = load("res://assets/models/structures/wall_segment_mesh.tres")
	_assert(wall_mesh != null, "Wall: wall_segment_mesh.tres loaded successfully")
	if wall_mesh:
		var ext := _get_mesh_extents(wall_mesh)
		_assert(is_equal_approx(ext.min_y, 0.0), "Wall: Bottom vertices flush at y=0.0 (actual: %f, verts: %d)" % [ext.min_y, ext.total_verts])
		_assert(ext.max_y > 3.0 and ext.max_y < 3.8, "Wall: Parapet height < 3.8m (under HealthBar3D, actual: %f)" % ext.max_y)
		_assert(ext.max_x - ext.min_x >= 3.9 and ext.max_x - ext.min_x <= 4.1, "Wall: Modular span is ~4.0m (actual: %f)" % (ext.max_x - ext.min_x))
	
	# Fortified Bunker
	var bunker_mesh: Mesh = load("res://assets/models/structures/bunker_structure_mesh.tres")
	_assert(bunker_mesh != null, "Bunker: bunker_structure_mesh.tres loaded successfully")
	if bunker_mesh:
		var ext := _get_mesh_extents(bunker_mesh)
		_assert(is_equal_approx(ext.min_y, 0.0), "Bunker: Bottom vertices flush at y=0.0 (actual: %f, verts: %d)" % [ext.min_y, ext.total_verts])
		_assert(ext.max_y > 2.3 and ext.max_y < 2.9, "Bunker: Roof cupola height within bounds (actual: %f)" % ext.max_y)
		_assert(ext.max_x - ext.min_x >= 3.2 and ext.max_x - ext.min_x <= 3.6, "Bunker: Octagonal diameter ~3.5m (actual: %f)" % (ext.max_x - ext.min_x))
	
	# Gate Frame (Gantry Pillars and Lintel)
	var gate_frame_mesh: Mesh = load("res://assets/models/structures/gate_frame_mesh.tres")
	_assert(gate_frame_mesh != null, "Gate Frame: gate_frame_mesh.tres loaded successfully")
	if gate_frame_mesh:
		var ext := _get_mesh_extents(gate_frame_mesh)
		_assert(is_equal_approx(ext.min_y, 0.0), "Gate Frame: Left & Right Pillars bottom vertices flush at y=0.0 (actual: %f, verts: %d)" % [ext.min_y, ext.total_verts])
		_assert(ext.max_y > 3.8 and ext.max_y < 4.3, "Gate Frame: Lintel height < 4.3m (under HealthBar3D, actual: %f)" % ext.max_y)
		_assert(ext.max_x - ext.min_x >= 5.8 and ext.max_x - ext.min_x <= 6.2, "Gate Frame: Gantry span ~6.0m (actual: %f)" % (ext.max_x - ext.min_x))


# -----------------------------------------------------------------------------
# 2. COLLISION BOUNDS GROUND FLUSHNESS
# -----------------------------------------------------------------------------
func test_collision_bounds_ground_flushness() -> void:
	print("\n>> 2. Testing Collision Shape Bounds and Ground Alignment...")
	
	# Command Center Collision: BoxShape3D(8, 4, 8) at (0, 2, 0)
	var cc_scene := load("res://entities/structures/command_center.tscn") as PackedScene
	var cc_inst: StaticBody3D = cc_scene.instantiate() as StaticBody3D
	var cc_col: CollisionShape3D = cc_inst.get_node("CollisionShape3D") as CollisionShape3D
	var cc_box: BoxShape3D = cc_col.shape as BoxShape3D
	var cc_bottom_y: float = cc_col.position.y - (cc_box.size.y * 0.5)
	_assert(is_equal_approx(cc_bottom_y, 0.0), "CC Collision: Bottom of box shape rests flush at y=0.0 (actual: %f)" % cc_bottom_y)
	cc_inst.queue_free()
	
	# Wall Segment Collision: BoxShape3D(4, 3.2, 1.2) at (0, 1.6, 0)
	var wall_scene := load("res://entities/structures/wall_segment.tscn") as PackedScene
	var wall_inst: StaticBody3D = wall_scene.instantiate() as StaticBody3D
	var wall_col: CollisionShape3D = wall_inst.get_node("CollisionShape3D") as CollisionShape3D
	var wall_box: BoxShape3D = wall_col.shape as BoxShape3D
	var wall_bottom_y: float = wall_col.position.y - (wall_box.size.y * 0.5)
	_assert(is_equal_approx(wall_bottom_y, 0.0), "Wall Collision: Bottom of box shape rests flush at y=0.0 (actual: %f)" % wall_bottom_y)
	wall_inst.queue_free()
	
	# Bunker Structure Collision: BoxShape3D(3.5, 2.5, 3.5) at (0, 1.25, 0)
	var bunker_scene := load("res://entities/structures/bunker_structure.tscn") as PackedScene
	var bunker_inst: StaticBody3D = bunker_scene.instantiate() as StaticBody3D
	var bunker_col: CollisionShape3D = bunker_inst.get_node("CollisionShape3D") as CollisionShape3D
	var bunker_box: BoxShape3D = bunker_col.shape as BoxShape3D
	var bunker_bottom_y: float = bunker_col.position.y - (bunker_box.size.y * 0.5)
	_assert(is_equal_approx(bunker_bottom_y, 0.0), "Bunker Collision: Bottom of box shape rests flush at y=0.0 (actual: %f)" % bunker_bottom_y)
	bunker_inst.queue_free()
	
	# Gate Structure Collisions: Pillars at (±2.5, 1.8, 0), Door at (0, 1.65, 0)
	var gate_scene := load("res://entities/structures/gate_structure.tscn") as PackedScene
	var gate_inst: StaticBody3D = gate_scene.instantiate() as StaticBody3D
	var left_col: CollisionShape3D = gate_inst.get_node("PillarLeftCol") as CollisionShape3D
	var right_col: CollisionShape3D = gate_inst.get_node("PillarRightCol") as CollisionShape3D
	var door_col: CollisionShape3D = gate_inst.get_node("DoorCollisionShape") as CollisionShape3D
	
	var left_box: BoxShape3D = left_col.shape as BoxShape3D
	var left_bottom_y: float = left_col.position.y - (left_box.size.y * 0.5)
	_assert(is_equal_approx(left_bottom_y, 0.0), "Gate Left Pillar Collision: Bottom rests flush at y=0.0 (actual: %f)" % left_bottom_y)
	
	var right_box: BoxShape3D = right_col.shape as BoxShape3D
	var right_bottom_y: float = right_col.position.y - (right_box.size.y * 0.5)
	_assert(is_equal_approx(right_bottom_y, 0.0), "Gate Right Pillar Collision: Bottom rests flush at y=0.0 (actual: %f)" % right_bottom_y)
	
	var door_box: BoxShape3D = door_col.shape as BoxShape3D
	var door_bottom_y: float = door_col.position.y - (door_box.size.y * 0.5)
	_assert(is_equal_approx(door_bottom_y, 0.0), "Gate Door Collision: Closed bottom rests flush at y=0.0 (actual: %f)" % door_bottom_y)
	gate_inst.queue_free()


# -----------------------------------------------------------------------------
# 3. MAIN LEVEL STRUCTURE INVENTORY AND TRANSFORMS
# -----------------------------------------------------------------------------
func test_main_level_structure_count_and_transforms() -> void:
	print("\n>> 3. Testing MainLevel 30 Base Structures Inventory and Ground Flushness...")
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	_assert(main_scene != null, "MainLevel: Scene loaded successfully")
	if not main_scene:
		return
	
	var main_level: Node = main_scene.instantiate()
	add_child(main_level)
	
	var perimeter := main_level.get_node_or_null("NavigationRegion3D/BasePerimeter") as Node3D
	_assert(perimeter != null, "MainLevel: BasePerimeter exists under NavigationRegion3D")
	if not perimeter:
		main_level.queue_free()
		return
	
	var cc_count := 0
	var gate_count := 0
	var bunker_count := 0
	var wall_count := 0
	
	for child in perimeter.get_children():
		if child is CommandCenter:
			cc_count += 1
			_assert(is_equal_approx(child.global_position.y, 0.0), "MainLevel CC: global_position.y == 0.0 (actual: %f)" % child.global_position.y)
		elif child is GateStructure:
			gate_count += 1
			_assert(is_equal_approx(child.global_position.y, 0.0), "MainLevel Gate '%s': global_position.y == 0.0 (actual: %f)" % [child.name, child.global_position.y])
		elif child is BunkerStructure:
			bunker_count += 1
			_assert(is_equal_approx(child.global_position.y, 0.0), "MainLevel Bunker '%s': global_position.y == 0.0 (actual: %f)" % [child.name, child.global_position.y])
		elif child is WallSegment:
			wall_count += 1
			_assert(is_equal_approx(child.global_position.y, 0.0), "MainLevel Wall '%s': global_position.y == 0.0 (actual: %f)" % [child.name, child.global_position.y])
	
	_assert(cc_count == 1, "MainLevel: Exactly 1 Command Center found in BasePerimeter (actual: %d)" % cc_count)
	_assert(gate_count == 2, "MainLevel: Exactly 2 GateStructures found in BasePerimeter (actual: %d)" % gate_count)
	_assert(bunker_count == 2, "MainLevel: Exactly 2 BunkerStructures found in BasePerimeter (actual: %d)" % bunker_count)
	_assert(wall_count == 25, "MainLevel: Exactly 25 WallSegments found in BasePerimeter (actual: %d)" % wall_count)
	_assert(cc_count + gate_count + bunker_count + wall_count == 30, "MainLevel: Total 30 base structures in BasePerimeter (actual: %d)" % (cc_count + gate_count + bunker_count + wall_count))
	
	main_level.queue_free()


# -----------------------------------------------------------------------------
# 4. EXACT AABB REGISTRATION IN SWARMSIMULATION / FLOWFIELD
# -----------------------------------------------------------------------------
func test_all_30_structures_exact_aabb_registration() -> void:
	print("\n>> 4. Empirically Verifying Exact Flow Field AABB Registration for all 30 Base Structures...")
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	var main_level: Node = main_scene.instantiate()
	add_child(main_level)
	
	var swarm_sim = main_level.get("swarm_simulation")
	_assert(swarm_sim != null, "SwarmSimulation instance active on MainLevel")
	if not swarm_sim:
		main_level.queue_free()
		return
	
	var flow_field = swarm_sim.get("flow_field")
	_assert(flow_field != null, "SwarmFlowField instance active in SwarmSimulation")
	if not flow_field:
		main_level.queue_free()
		return
	
	var registered_obstacles: Dictionary = flow_field.registered_obstacles
	_assert(registered_obstacles.size() >= 30, "FlowField has at least 30 registered obstacles (actual: %d)" % registered_obstacles.size())
	
	var perimeter := main_level.get_node_or_null("NavigationRegion3D/BasePerimeter") as Node3D
	var verified_structures := 0
	
	print("\n--- BASE STRUCTURE REGISTRATION AUDIT TABLE ---")
	print(String("%-18s | %-16s | %-24s | %-24s | %-8s | %s") % ["Structure", "Position", "Min (X, Z)", "Max (X, Z)", "Cost", "Blocking"])
	print("--------------------------------------------------------------------------------------------------------")
	
	for child in perimeter.get_children():
		if not (child is Node3D):
			continue
		var s := child as Node3D
		if not (s is CommandCenter or s is GateStructure or s is BunkerStructure or s is WallSegment):
			continue
		
		# Structure must be registered by node reference
		_assert(registered_obstacles.has(s), "FlowField registered obstacle for '%s'" % s.name)
		if not registered_obstacles.has(s):
			continue
		
		var obs: Dictionary = registered_obstacles[s]
		var actual_min: Vector2 = obs["min"]
		var actual_max: Vector2 = obs["max"]
		var actual_blocking: bool = obs["blocking"]
		var actual_cost: int = obs["cost"]
		
		var expected_min: Vector2
		var expected_max: Vector2
		var expected_blocking: bool
		var expected_cost: int
		
		if s is WallSegment:
			var local_half := Vector3(2.0, 1.6, 0.6)
			var basis := s.global_transform.basis
			var world_half_x: float = absf(basis.x.x * local_half.x) + absf(basis.z.x * local_half.z)
			var world_half_z: float = absf(basis.x.z * local_half.x) + absf(basis.z.z * local_half.z)
			var half_size := Vector3(world_half_x + 0.15, 1.6, world_half_z + 0.15)
			expected_min = Vector2(s.global_position.x - half_size.x, s.global_position.z - half_size.z)
			expected_max = Vector2(s.global_position.x + half_size.x, s.global_position.z + half_size.z)
			var is_front_wall: bool = (s.global_position.z <= 5.0)
			expected_cost = 60 if is_front_wall else 255
			expected_blocking = true
		elif s is GateStructure:
			var half_size := Vector3(3.1, 1.6, 0.8)
			expected_min = Vector2(s.global_position.x - half_size.x, s.global_position.z - half_size.z)
			expected_max = Vector2(s.global_position.x + half_size.x, s.global_position.z + half_size.z)
			var is_closed: bool = ((s as GateStructure).current_state == GateStructure.GateState.CLOSED)
			expected_cost = 20 if is_closed else 1
			expected_blocking = is_closed
		elif s is CommandCenter:
			var half_size := Vector3(4.0, 2.0, 4.0)
			expected_min = Vector2(s.global_position.x - half_size.x, s.global_position.z - half_size.z)
			expected_max = Vector2(s.global_position.x + half_size.x, s.global_position.z + half_size.z)
			expected_cost = 255
			expected_blocking = true
		elif s is BunkerStructure:
			var half_size := Vector3(2.5, 1.5, 2.5)
			expected_min = Vector2(s.global_position.x - half_size.x, s.global_position.z - half_size.z)
			expected_max = Vector2(s.global_position.x + half_size.x, s.global_position.z + half_size.z)
			expected_cost = 80
			expected_blocking = true
		
		# Print audit line
		print(String("%-18s | %-16s | %-24s | %-24s | %-8d | %s") % [
			s.name,
			"(%d, %d, %d)" % [roundi(s.position.x), roundi(s.position.y), roundi(s.position.z)],
			"(%.2f, %.2f)" % [actual_min.x, actual_min.y],
			"(%.2f, %.2f)" % [actual_max.x, actual_max.y],
			actual_cost,
			str(actual_blocking)
		])
		
		# Verify exact matching
		var min_ok := actual_min.is_equal_approx(expected_min)
		var max_ok := actual_max.is_equal_approx(expected_max)
		var block_ok := (actual_blocking == expected_blocking)
		var cost_ok := (actual_cost == expected_cost)
		
		_assert(min_ok and max_ok, "AABB Footprint for '%s' matches expected: min=%s, max=%s (actual min=%s, max=%s)" % [s.name, str(expected_min), str(expected_max), str(actual_min), str(actual_max)])
		_assert(block_ok and cost_ok, "Blocking & Cost for '%s' matches expected: block=%s, cost=%d (actual block=%s, cost=%d)" % [s.name, str(expected_blocking), expected_cost, str(actual_blocking), actual_cost])
		
		verified_structures += 1
	
	print("--------------------------------------------------------------------------------------------------------\n")
	_assert(verified_structures == 30, "All 30 Base Structures individually checked and verified in FlowField (verified: %d)" % verified_structures)
	
	main_level.queue_free()


# -----------------------------------------------------------------------------
# 5. DYNAMIC OBSTACLE UPDATES (GATE TOGGLE & STRUCTURE DESTRUCTION)
# -----------------------------------------------------------------------------
func test_dynamic_obstacle_updates() -> void:
	print("\n>> 5. Testing Dynamic Obstacle Updates (Gate Open/Close & Structure Destruction)...")
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	var main_level: Node = main_scene.instantiate()
	add_child(main_level)
	
	var swarm_sim = main_level.get("swarm_simulation")
	var flow_field = swarm_sim.get("flow_field")
	var perimeter := main_level.get_node_or_null("NavigationRegion3D/BasePerimeter") as Node3D
	
	var west_gate: GateStructure = perimeter.get_node_or_null("WestGate") as GateStructure
	_assert(west_gate != null, "Dynamic: WestGate found")
	
	if west_gate:
		# Initial state: CLOSED, blocking=true, cost=20
		var obs_closed: Dictionary = flow_field.registered_obstacles[west_gate]
		_assert(obs_closed["blocking"] == true and obs_closed["cost"] == 20, "Gate Dynamic: Initially closed (blocking=true, cost=20)")
		
		# Open gate
		west_gate.open_gate(true)
		var obs_open: Dictionary = flow_field.registered_obstacles[west_gate]
		_assert(obs_open["blocking"] == false and obs_open["cost"] == 1, "Gate Dynamic: After open_gate(), FlowField updated (blocking=false, cost=1)")
		
		# Close gate
		west_gate.close_gate(true)
		var obs_reclosed: Dictionary = flow_field.registered_obstacles[west_gate]
		_assert(obs_reclosed["blocking"] == true and obs_reclosed["cost"] == 20, "Gate Dynamic: After close_gate(), FlowField restored (blocking=true, cost=20)")
	
	# Structure destruction dynamic update
	var wall_target: WallSegment = perimeter.get_node_or_null("WallSouth5") as WallSegment
	_assert(wall_target != null, "Destruction: WallSouth5 found")
	if wall_target:
		_assert(flow_field.registered_obstacles.has(wall_target), "Destruction: WallSouth5 initially registered in FlowField")
		var initial_count: int = flow_field.registered_obstacles.size()
		
		# Trigger destruction signal
		main_level._on_structure_destroyed(wall_target)
		
		_assert(not flow_field.registered_obstacles.has(wall_target), "Destruction: WallSouth5 successfully unregistered from FlowField")
		_assert(flow_field.registered_obstacles.size() == initial_count - 1, "Destruction: Obstacle count decremented by 1 (new count: %d)" % flow_field.registered_obstacles.size())
	
	main_level.queue_free()


# -----------------------------------------------------------------------------
# 6. BUNKER RUNTIME VISUAL REPLACEMENT IN MAIN_LEVEL
# -----------------------------------------------------------------------------
func test_bunker_runtime_visual_replacement() -> void:
	print("\n>> 6. Testing Bunker Runtime Visual Upgrade in MainLevel...")
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	var main_level: Node = main_scene.instantiate()
	add_child(main_level)
	
	var perimeter := main_level.get_node_or_null("NavigationRegion3D/BasePerimeter") as Node3D
	var bunker_west: BunkerStructure = perimeter.get_node_or_null("BunkerWest") as BunkerStructure
	var bunker_east: BunkerStructure = perimeter.get_node_or_null("BunkerEast") as BunkerStructure
	
	_assert(bunker_west != null and bunker_east != null, "Bunkers: BunkerWest & BunkerEast present in MainLevel")
	
	for b in [bunker_west, bunker_east]:
		if not b: continue
		var vr := b.get_node_or_null("VisualRoot") as Node3D
		_assert(vr != null, "Bunker '%s': VisualRoot exists" % b.name)
		if vr:
			var mesh_inst := vr.get_node_or_null("MeshInstance3D") as MeshInstance3D
			_assert(mesh_inst != null, "Bunker '%s': MeshInstance3D exists under VisualRoot" % b.name)
			if mesh_inst:
				_assert(mesh_inst.mesh is ArrayMesh, "Bunker '%s': Mesh dynamically upgraded from primitive BoxMesh to ArrayMesh" % b.name)
				var am := mesh_inst.mesh as ArrayMesh
				_assert(am.get_surface_count() >= 4, "Bunker '%s': Upgraded mesh has >= 4 surfaces (actual: %d)" % [b.name, am.get_surface_count()])
				_assert(mesh_inst.transform.origin.is_equal_approx(Vector3.ZERO), "Bunker '%s': MeshInstance3D transform reset to origin (actual: %s)" % [b.name, str(mesh_inst.transform.origin)])
	
	main_level.queue_free()


# -----------------------------------------------------------------------------
# 7. STRICT GATE NODE CONTRACTS & STATUS LIGHT STATES
# -----------------------------------------------------------------------------
func test_gate_strict_node_contracts() -> void:
	print("\n>> 7. Testing Strict Gate Node Contracts and Status Light States...")
	var gate_scene := load("res://entities/structures/gate_structure.tscn") as PackedScene
	var gate: GateStructure = gate_scene.instantiate() as GateStructure
	add_child(gate)
	
	# Node paths contract
	var door_vis := gate.get_node_or_null("VisualRoot/DoorSlidingPart") as Node3D
	var status_light := gate.get_node_or_null("VisualRoot/StatusLight") as MeshInstance3D
	_assert(door_vis != null, "Contract: $VisualRoot/DoorSlidingPart strictly exists")
	_assert(status_light != null, "Contract: $VisualRoot/StatusLight strictly exists as MeshInstance3D")
	
	# Status Light color tests:
	# CLOSED -> Red
	gate.close_gate(false)
	var mat_closed := status_light.material_override as StandardMaterial3D
	_assert(mat_closed != null and mat_closed.albedo_color.r > 0.8 and mat_closed.albedo_color.g < 0.3, "Gate Light: CLOSED state is RED (actual: %s)" % str(mat_closed.albedo_color))
	
	# OPEN -> Green
	gate.open_gate(false)
	var mat_open := status_light.material_override as StandardMaterial3D
	_assert(mat_open != null and mat_open.albedo_color.g > 0.8 and mat_open.albedo_color.r < 0.3, "Gate Light: OPEN state is GREEN (actual: %s)" % str(mat_open.albedo_color))
	
	# LOCKED -> Amber
	gate.toggle_gate() # locks
	var mat_locked := status_light.material_override as StandardMaterial3D
	_assert(mat_locked != null and mat_locked.albedo_color.r > 0.8 and mat_locked.albedo_color.g > 0.5, "Gate Light: LOCKED state is AMBER (actual: %s)" % str(mat_locked.albedo_color))
	
	gate.queue_free()


# -----------------------------------------------------------------------------
# 8. PERIMETER CONTINUITY AND WALL ALIGNMENT
# -----------------------------------------------------------------------------
func test_wall_perimeter_continuity() -> void:
	print("\n>> 8. Testing Base Perimeter Wall Alignment and Continuous Sealing...")
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	var main_level: Node = main_scene.instantiate()
	add_child(main_level)
	
	var perimeter := main_level.get_node_or_null("NavigationRegion3D/BasePerimeter") as Node3D
	
	# Verify South Wall continuous span: 9 walls from X=-16 to X=+16 with spacing 4.0m
	var south_xs := [-16.0, -12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0, 16.0]
	for i in range(south_xs.size()):
		var wall_name := "WallSouth%d" % (i + 1)
		var w := perimeter.get_node_or_null(wall_name) as WallSegment
		_assert(w != null, "Perimeter: '%s' exists" % wall_name)
		if w:
			_assert(is_equal_approx(w.position.x, south_xs[i]) and is_equal_approx(w.position.z, 24.0), "Perimeter: '%s' positioned at (%f, 0, 24.0) (actual: %s)" % [wall_name, south_xs[i], str(w.position)])
	
	# Verify West Wall continuous span: 5 walls from Z=6 to Z=22 with spacing 4.0m at X=-18
	var west_zs := [6.0, 10.0, 14.0, 18.0, 22.0]
	for i in range(west_zs.size()):
		var wall_name := "WallWest%d" % (i + 1)
		var w := perimeter.get_node_or_null(wall_name) as WallSegment
		_assert(w != null, "Perimeter: '%s' exists" % wall_name)
		if w:
			_assert(is_equal_approx(w.position.x, -18.0) and is_equal_approx(w.position.z, west_zs[i]), "Perimeter: '%s' positioned at (-18.0, 0, %f) (actual: %s)" % [wall_name, west_zs[i], str(w.position)])
	
	# Verify East Wall continuous span: 5 walls from Z=6 to Z=22 with spacing 4.0m at X=+18
	var east_zs := [6.0, 10.0, 14.0, 18.0, 22.0]
	for i in range(east_zs.size()):
		var wall_name := "WallEast%d" % (i + 1)
		var w := perimeter.get_node_or_null(wall_name) as WallSegment
		_assert(w != null, "Perimeter: '%s' exists" % wall_name)
		if w:
			_assert(is_equal_approx(w.position.x, 18.0) and is_equal_approx(w.position.z, east_zs[i]), "Perimeter: '%s' positioned at (18.0, 0, %f) (actual: %s)" % [wall_name, east_zs[i], str(w.position)])
	
	main_level.queue_free()


# -----------------------------------------------------------------------------
# 9. ADVERSARIAL GATE STRESS: RAPID TOGGLE & LOCKING PRIORITY VS PROXIMITY
# -----------------------------------------------------------------------------
func test_adversarial_gate_stress() -> void:
	print("\n>> 9. Testing Adversarial Gate Stress: Rapid Toggle & Player Lock Priority...")
	var gate_scene := load("res://entities/structures/gate_structure.tscn") as PackedScene
	var gate: GateStructure = gate_scene.instantiate() as GateStructure
	add_child(gate)
	
	# Rapid toggle stress: toggle 20 times in rapid succession
	for i in range(20):
		gate.toggle_gate()
	_assert(gate.is_locked_by_player == false, "Gate Stress: 20 rapid toggles returned correctly to unlocked state")
	
	# Test Player Lock Priority over Proximity:
	# 1. Engage player lock while closed (open gate then toggle to lock closed)
	gate.open_gate(false)
	gate.toggle_gate() # closes and engages is_locked_by_player = true
	_assert(gate.is_locked_by_player == true, "Gate Stress: Gate manually locked by player")
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate Stress: State is CLOSED while locked")
	
	# 2. Add ally to proximity area
	var dummy_ally := CharacterBody3D.new()
	dummy_ally.add_to_group("allies")
	add_child(dummy_ally)
	gate._on_proximity_body_entered(dummy_ally)
	
	# Gate MUST remain CLOSED because is_locked_by_player is true!
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate Stress: Ally proximity ignored when player manual lock engaged")
	
	# 3. Unlock by player -> should immediately open because ally is present!
	gate.toggle_gate() # unlocks
	_assert(gate.is_locked_by_player == false, "Gate Stress: Player lock disengaged")
	_assert(gate.current_state == GateStructure.GateState.OPEN, "Gate Stress: Gate automatically opened upon unlock due to present ally")
	
	# 4. Remove ally
	gate._on_proximity_body_exited(dummy_ally)
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate Stress: Gate automatically closes when ally departs")
	
	dummy_ally.queue_free()
	gate.queue_free()


# -----------------------------------------------------------------------------
# 10. ADVERSARIAL COMBAT ENGINE STRUCTURAL MITIGATION
# -----------------------------------------------------------------------------
func test_adversarial_mitigation_stress() -> void:
	print("\n>> 10. Testing Adversarial Combat Engine Mitigation on Structures...")
	
	# 1. Physical vs Wall: 100 raw dmg -> 35% passive mitigation -> 65 dmg
	var wall_phys := SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED)
	_assert(is_equal_approx(wall_phys.damage_dealt, 65.0), "Combat Stress: Physical damage vs Reinforced Wall deals 65.0 (actual: %f)" % wall_phys.damage_dealt)
	
	# 2. Spell vs Wall: 100 raw spell dmg -> 35% passive mitigation -> 65 dmg
	var wall_spell := SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.SPELL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED)
	_assert(is_equal_approx(wall_spell.damage_dealt, 65.0), "Combat Stress: Spell damage vs Reinforced Wall deals 65.0 (actual: %f)" % wall_spell.damage_dealt)
	
	# 3. Physical vs Bunker: 100 raw dmg -> 25% passive mitigation -> 75 dmg
	var bunker_phys := SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER)
	_assert(is_equal_approx(bunker_phys.damage_dealt, 75.0), "Combat Stress: Physical damage vs Bunker deals 75.0 (actual: %f)" % bunker_phys.damage_dealt)
	
	# 4. Spell vs Bunker: 100 raw spell dmg -> 25% passive mitigation -> 75 dmg
	var bunker_spell := SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.SPELL, 0.0, 0, CombatTypes.StructureType.BUNKER)
	_assert(is_equal_approx(bunker_spell.damage_dealt, 75.0), "Combat Stress: Spell damage vs Bunker deals 75.0 (actual: %f)" % bunker_spell.damage_dealt)
	
	# 5. Invulnerable Structure: 100 raw dmg -> 0 dmg
	var invuln := SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false, false, true)
	_assert(is_equal_approx(invuln.damage_dealt, 0.0), "Combat Stress: Invulnerable structure receives 0.0 damage (actual: %f)" % invuln.damage_dealt)


# -----------------------------------------------------------------------------
# 11. ADVERSARIAL COMMAND CENTER LETHAL DAMAGE & BASE DESTRUCTION SIGNAL
# -----------------------------------------------------------------------------
func test_adversarial_command_center_lethal() -> void:
	print("\n>> 11. Testing Adversarial Command Center Lethal Damage & Base Destruction...")
	var cc_scene := load("res://entities/structures/command_center.tscn") as PackedScene
	var cc: CommandCenter = cc_scene.instantiate() as CommandCenter
	add_child(cc)
	
	var fired := [false]
	var struct_callable := func(s):
		print("DEBUG: SignalBus.structure_destroyed emitted for: ", s.name)
		fired[0] = true
	SignalBus.structure_destroyed.connect(struct_callable)
	
	cc.take_damage(2500.0)
	_assert(fired[0] == true, "CC Stress: Structure destroyed signal emitted on lethal breakdown")
	_assert(is_equal_approx(cc.current_health, 0.0), "CC Stress: Health clamped at 0.0 (actual: %f)" % cc.current_health)
	
	SignalBus.structure_destroyed.disconnect(struct_callable)
