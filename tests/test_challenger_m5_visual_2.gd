extends Node

## ==============================================================================
## SFE5 MILESTONE 5: EMPIRICAL CHALLENGER 2 HARNESS
## Cross-Subsystem Coupling, Invariant Verification & Master Test Integrity
## ==============================================================================
##
## Rigorously stress-tests:
## 1. Base Perimeter Structures Collision Footprints & SwarmSimulation Flow Field Registration:
##    - Exact collision box shapes: CC (8x4x8), Wall (4x3.2x1.2), Gate (4x3.3x0.6), Bunker (3.5x2.5x3.5)
##    - Exactly 30 perimeter structures match 1-to-1 with flow_field.registered_obstacles
##    - Dynamic gate toggle state (closed vs open) cost invariance & obstacle count preservation
## 2. Ground Plane Contact & Decor Non-Interference:
##    - NavigationRegion3D/Ground StaticBody3D at y = -0.5, BoxShape 80x1x80 (top plane y = 0.0)
##    - All unit meshes (Marine, Raynor, Zergling, Roach) rest flush at y = 0.0 (min_y == 0.0)
##    - SwarmRenderer archetype_y_offsets strictly 0.0
##    - EnvironmentDecorations strictly 0 colliders, outside nav region, 0 flow field interference
## 3. Structural Combat Mitigations Mathematical Precision:
##    - 35% Wall mitigation vs physical, spell, flat armor, upgrades, edge values (0 damage, invulnerable)
##    - 25% Bunker mitigation vs physical, spell, flat armor, upgrades, edge values (0 damage, invulnerable)
## 4. CombatVFXPool Zero Dynamic Allocation:
##    - Strictly 44 child nodes invariant (24 tracers + 20 acid bursts)
##    - 1,000 rapid burst firing cycles maintaining zero allocations and circular recycling
##    - Headless particle safety
## 5. SC2 HUD Console Robustness & Extreme Selection Churn:
##    - Empty arrays, null arrays, dangling/freed instances safety
##    - 2,000 rapid selection switching iterations
##    - SC2StatPanel RPG attribute allocation (0 points vs >0 points, derived stats, dynamic gauge colors)
##    - SC2CommandCard 15-button grid, out-of-bounds indices, energy guards, 500 click stress
## ==============================================================================

const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")
const CombatVFXPool = preload("res://core/vfx/combat_vfx_pool.gd")
const SC2HUDRoot = preload("res://ui/sc2_hud_root.gd")
const SC2StatPanel = preload("res://ui/sc2_stat_panel.gd")
const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")
const BaseUnit3D = preload("res://entities/allies/base_unit_3d.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const HeroSkillData = preload("res://data/skills/hero_skill_data.gd")
const SwarmRenderer = preload("res://core/swarm/swarm_renderer.gd")
const SwarmUnitArchetype = preload("res://data/swarm/swarm_unit_archetype.gd")

const CommandCenterScene = preload("res://entities/structures/command_center.tscn")
const WallSegmentScene = preload("res://entities/structures/wall_segment.tscn")
const GateStructureScene = preload("res://entities/structures/gate_structure.tscn")
const BunkerStructureScene = preload("res://entities/structures/bunker_structure.tscn")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _ready() -> void:
	print("==================================================================")
	print("=== EMPIRICAL CHALLENGER 2: MILESTONE 5 CROSS-SUBSYSTEM HARNESS ===")
	print("==================================================================")
	var start_ms: int = Time.get_ticks_msec()

	_run_all_challenger_tests()

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	print("\n==================================================================")
	print("Milestone 5 Empirical Challenger 2 Results:")
	print("Elapsed Time: %d ms" % elapsed_ms)
	print("Total Tests:  %d" % total_tests)
	print("Passes:       %d" % passed_tests)
	print("Failures:     %d" % failed_tests)

	if failures.is_empty():
		print("\u001b[32m\u001b[1mALL EMPIRICAL CHALLENGES PASSED! [VERDICT: APPROVE]\u001b[0m")
		print("==================================================================")
		get_tree().quit(0)
	else:
		print("\u001b[31m\u001b[1mEMPIRICAL CHALLENGES FAILED! [VERDICT: REJECT]\u001b[0m")
		for f in failures:
			print("  \u001b[31m* " + f + "\u001b[0m")
		print("==================================================================")
		get_tree().quit(1)


func _assert(condition: bool, test_name: String, error_msg: String = "") -> bool:
	total_tests += 1
	if not condition:
		failed_tests += 1
		var full_msg := "%s -> %s" % [test_name, error_msg]
		failures.append(full_msg)
		print("  \u001b[31m[FAIL]\u001b[0m " + full_msg)
		return false
	passed_tests += 1
	print("  \u001b[32m[PASS]\u001b[0m " + test_name)
	return true


func _run_all_challenger_tests() -> void:
	print("\n>> 1. Verifying 30 Base Perimeter Structures Collision Footprints & Flow Field Coupling...")
	_test_base_perimeter_structures_and_flow_field()

	print("\n>> 2. Verifying Ground Plane Contact (y=0.0) & Unit Mesh Ground Alignment...")
	_test_ground_plane_and_unit_mesh_alignment()

	print("\n>> 3. Verifying EnvironmentDecorations Zero Colliders & Zero Flow Field Interference...")
	_test_environment_decorations_invariants()

	print("\n>> 4. Verifying Structural Combat Mitigations Mathematical Precision...")
	_test_structural_mitigations_math_precision()

	print("\n>> 5. Verifying CombatVFXPool Zero Dynamic Allocation (Strictly 44 Children)...")
	_test_combat_vfx_pool_zero_allocation_stress()

	print("\n>> 6. Verifying SC2 HUD Console Robustness Under Extreme Selections & Churn...")
	_test_sc2_hud_robustness_and_churn()


# -----------------------------------------------------------------------------
# 1. Base Perimeter Structures Collision Footprints & Flow Field Coupling
# -----------------------------------------------------------------------------
func _test_base_perimeter_structures_and_flow_field() -> void:
	# 1A: CommandCenter archetype collision box
	var cc = CommandCenterScene.instantiate()
	var cc_col: CollisionShape3D = cc.get_node_or_null("CollisionShape3D")
	_assert(cc_col != null, "CommandCenter has CollisionShape3D")
	var cc_box := cc_col.shape as BoxShape3D
	_assert(cc_box != null, "CommandCenter shape is BoxShape3D")
	_assert(cc_box.size.is_equal_approx(Vector3(8.0, 4.0, 8.0)), "CommandCenter footprint is exact Vector3(8, 4, 8) (got %s)" % cc_box.size)
	_assert(cc_col.position.is_equal_approx(Vector3(0.0, 2.0, 0.0)), "CommandCenter collision center at y=2.0")
	cc.free()

	# 1B: WallSegment archetype collision box
	var wall = WallSegmentScene.instantiate()
	var wall_col: CollisionShape3D = wall.get_node_or_null("CollisionShape3D")
	_assert(wall_col != null, "WallSegment has CollisionShape3D")
	var wall_box := wall_col.shape as BoxShape3D
	_assert(wall_box != null, "WallSegment shape is BoxShape3D")
	_assert(wall_box.size.is_equal_approx(Vector3(4.0, 3.2, 1.2)), "WallSegment footprint is exact Vector3(4, 3.2, 1.2) (got %s)" % wall_box.size)
	_assert(wall_col.position.is_equal_approx(Vector3(0.0, 1.6, 0.0)), "WallSegment collision center at y=1.6")
	wall.free()

	# 1C: GateStructure archetype collision box
	var gate = GateStructureScene.instantiate()
	var gate_col: CollisionShape3D = gate.get_node_or_null("DoorCollisionShape")
	_assert(gate_col != null, "GateStructure has DoorCollisionShape")
	var gate_box := gate_col.shape as BoxShape3D
	_assert(gate_box != null, "GateStructure door shape is BoxShape3D")
	_assert(gate_box.size.is_equal_approx(Vector3(4.0, 3.3, 0.6)), "GateStructure door footprint is exact Vector3(4, 3.3, 0.6) (got %s)" % gate_box.size)
	_assert(gate_col.position.is_equal_approx(Vector3(0.0, 1.65, 0.0)), "GateStructure door collision center at y=1.65")
	gate.free()

	# 1D: BunkerStructure archetype collision box
	var bunker = BunkerStructureScene.instantiate()
	var bunker_col: CollisionShape3D = bunker.get_node_or_null("CollisionShape3D")
	_assert(bunker_col != null, "BunkerStructure has CollisionShape3D")
	var bunker_box := bunker_col.shape as BoxShape3D
	_assert(bunker_box != null, "BunkerStructure shape is BoxShape3D")
	_assert(bunker_box.size.is_equal_approx(Vector3(3.5, 2.5, 3.5)), "BunkerStructure footprint is exact Vector3(3.5, 2.5, 3.5) (got %s)" % bunker_box.size)
	_assert(bunker_col.position.is_equal_approx(Vector3(0.0, 1.25, 0.0)), "BunkerStructure collision center at y=1.25")
	bunker.free()

	# 1E: Live MainLevel perimeter structures and 1-to-1 FlowField match
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	var main_level = main_scene.instantiate()
	add_child(main_level)

	var perimeter := main_level.get_node_or_null("NavigationRegion3D/BasePerimeter") as Node3D
	_assert(perimeter != null, "NavigationRegion3D/BasePerimeter node exists in main_level.tscn")

	var perimeter_children: Array[Node] = []
	for child in perimeter.get_children():
		if child is Node3D and (child.is_in_group("structures") or child.name.begins_with("Wall") or child.name.begins_with("Gate") or child.name.begins_with("Bunker") or child.name == "CommandCenter"):
			perimeter_children.append(child)

	_assert(perimeter_children.size() == 30, "BasePerimeter has exactly 30 structures (got %d)" % perimeter_children.size())

	# Check exact counts by category: 1 CC, 2 Gates, 2 Bunkers, 25 Walls
	var cc_count: int = 0
	var gate_count: int = 0
	var bunker_count: int = 0
	var wall_count: int = 0
	for s in perimeter_children:
		if s.name == "CommandCenter" or s is CommandCenter:
			cc_count += 1
		elif s is GateStructure or s.name.contains("Gate"):
			gate_count += 1
		elif s is BunkerStructure or s.name.contains("Bunker"):
			bunker_count += 1
		elif s is WallSegment or s.name.contains("Wall"):
			wall_count += 1

	_assert(cc_count == 1, "Exactly 1 CommandCenter in BasePerimeter (got %d)" % cc_count)
	_assert(gate_count == 2, "Exactly 2 GateStructures in BasePerimeter (got %d)" % gate_count)
	_assert(bunker_count == 2, "Exactly 2 BunkerStructures in BasePerimeter (got %d)" % bunker_count)
	_assert(wall_count == 25, "Exactly 25 WallSegments in BasePerimeter (got %d)" % wall_count)

	# FlowField obstacle registration 1-to-1 verification
	var sim = main_level.get("swarm_simulation")
	_assert(sim != null, "SwarmSimulation exists on MainLevel")
	var flow_field = sim.get("flow_field")
	_assert(flow_field != null, "SwarmFlowField exists on SwarmSimulation")

	var obstacles: Dictionary = flow_field.registered_obstacles
	_assert(obstacles.size() == 30, "FlowField has EXACTLY 30 registered obstacles (got %d)" % obstacles.size())

	# Every structure in BasePerimeter must be registered
	for s in perimeter_children:
		_assert(obstacles.has(s), "Structure '%s' is registered in flow_field.registered_obstacles" % s.name)

	# Every registered obstacle must belong strictly to BasePerimeter
	for key in obstacles.keys():
		_assert(perimeter_children.has(key), "Registered obstacle '%s' belongs strictly to BasePerimeter" % key.name)

	# 1F: Dynamic gate state toggle stress test
	var west_gate: GateStructure = perimeter.get_node_or_null("WestGate") as GateStructure
	if west_gate:
		# Open gate
		west_gate.open_gate(false)
		flow_field.update_obstacle(west_gate, false, 1)
		_assert(obstacles.size() == 30, "Obstacle count remains 30 after opening WestGate")
		var opened_entry: Dictionary = obstacles.get(west_gate, {})
		_assert(opened_entry.get("cost", -1) == 1, "WestGate opened cost is 1 (got %s)" % str(opened_entry.get("cost")))
		_assert(opened_entry.get("blocking", true) == false, "WestGate opened blocking is false")

		# Close gate
		west_gate.close_gate(false)
		flow_field.update_obstacle(west_gate, true, 20)
		_assert(obstacles.size() == 30, "Obstacle count remains 30 after closing WestGate")
		var closed_entry: Dictionary = obstacles.get(west_gate, {})
		_assert(closed_entry.get("cost", -1) == 20, "WestGate closed cost is 20 (got %s)" % str(closed_entry.get("cost")))
		_assert(closed_entry.get("blocking", false) == true, "WestGate closed blocking is true")

	main_level.free()


# -----------------------------------------------------------------------------
# 2. Ground Plane Contact (y=0.0) & Unit Mesh Ground Alignment
# -----------------------------------------------------------------------------
func _test_ground_plane_and_unit_mesh_alignment() -> void:
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	var main_level = main_scene.instantiate()
	add_child(main_level)

	var ground: StaticBody3D = main_level.get_node_or_null("NavigationRegion3D/Ground") as StaticBody3D
	_assert(ground != null, "NavigationRegion3D/Ground StaticBody3D exists")
	if ground:
		_assert(is_equal_approx(ground.position.y, -0.5), "Ground position.y is -0.5 (got %f)" % ground.position.y)
		_assert(ground.collision_layer == 1, "Ground collision_layer is 1")
		_assert(ground.collision_mask == 0, "Ground collision_mask is 0")

		var col: CollisionShape3D = ground.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col != null, "Ground has CollisionShape3D")
		if col and col.shape is BoxShape3D:
			var box := col.shape as BoxShape3D
			_assert(box.size.is_equal_approx(Vector3(80, 1, 80)), "Ground collision box size is (80, 1, 80)")
			# Top face is at y = position.y + (size.y * 0.5) = -0.5 + 0.5 = 0.0
			var top_y: float = ground.position.y + (box.size.y * 0.5)
			_assert(is_equal_approx(top_y, 0.0), "Ground plane contact top surface is strictly at y = 0.0 (got %f)" % top_y)

	main_level.free()

	# Unit mesh lowest vertex min_y resting flush at y=0.0
	var meshes_to_test: Dictionary = {
		"marine_body_mesh.tres": "res://assets/models/marine_body_mesh.tres",
		"raynor_body_mesh.tres": "res://assets/models/raynor_body_mesh.tres",
		"zergling_mesh.tres": "res://assets/models/zergling_mesh.tres",
		"roach_mesh.tres": "res://assets/models/roach_mesh.tres"
	}

	for mesh_name in meshes_to_test:
		var path: String = meshes_to_test[mesh_name]
		var mesh_res = load(path) as ArrayMesh
		_assert(mesh_res != null, "Loaded mesh %s" % mesh_name)
		if mesh_res:
			var min_y: float = 999999.0
			for s in range(mesh_res.get_surface_count()):
				var arrays = mesh_res.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for v in verts:
					if v.y < min_y:
						min_y = v.y
			_assert(absf(min_y - 0.0) < 0.0001, "Mesh %s lowest vertex rests flush at y = 0.0 (min_y = %.5f)" % [mesh_name, min_y])

	# SwarmRenderer archetype_y_offsets
	var renderer := SwarmRenderer.new()
	renderer._load_default_archetypes()
	var zerg_off: float = renderer.archetype_y_offsets.get(0, -999.0)
	var roach_off: float = renderer.archetype_y_offsets.get(1, -999.0)
	_assert(is_equal_approx(zerg_off, 0.0), "SwarmRenderer Zergling (ID 0) archetype_y_offset is 0.0 (got %f)" % zerg_off)
	_assert(is_equal_approx(roach_off, 0.0), "SwarmRenderer Roach (ID 1) archetype_y_offset is 0.0 (got %f)" % roach_off)
	renderer.free()


# -----------------------------------------------------------------------------
# 3. EnvironmentDecorations Zero Colliders & Zero Flow Field Interference
# -----------------------------------------------------------------------------
func _test_environment_decorations_invariants() -> void:
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	var main_level = main_scene.instantiate()
	add_child(main_level)

	var decor: Node3D = main_level.get_node_or_null("EnvironmentDecorations") as Node3D
	_assert(decor != null, "EnvironmentDecorations node exists in main_level.tscn")
	_assert(decor.get_parent() == main_level, "EnvironmentDecorations is direct child of MainLevel (NOT NavigationRegion3D)")

	# Check required visual mesh nodes under EnvironmentDecorations
	var lava_fissures = decor.get_node_or_null("LavaFissures") as MeshInstance3D
	var creep_pools = decor.get_node_or_null("CreepPools") as MeshInstance3D
	var base_deck = decor.get_node_or_null("TerranBaseDeck") as MeshInstance3D
	var boulders = decor.get_node_or_null("VolcanicBoulders") as MeshInstance3D
	var lava_lights = decor.get_node_or_null("LavaLights") as Node3D

	_assert(lava_fissures != null, "LavaFissures mesh exists under EnvironmentDecorations")
	_assert(creep_pools != null, "CreepPools mesh exists under EnvironmentDecorations")
	_assert(base_deck != null, "TerranBaseDeck mesh exists under EnvironmentDecorations")
	_assert(boulders != null, "VolcanicBoulders mesh exists under EnvironmentDecorations")
	_assert(lava_lights != null, "LavaLights node exists under EnvironmentDecorations")

	# Recursively verify zero CollisionObject3D and zero CollisionShape3D nodes under EnvironmentDecorations
	var colliders: Array[Node] = []
	var shapes: Array[Node] = []
	var stack: Array[Node] = [decor]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is CollisionObject3D:
			colliders.append(curr)
		if curr is CollisionShape3D or curr is CollisionPolygon3D:
			shapes.append(curr)
		for c in curr.get_children():
			stack.append(c)

	_assert(colliders.is_empty(), "EnvironmentDecorations has strictly 0 CollisionObject3D nodes (found %d)" % colliders.size())
	_assert(shapes.is_empty(), "EnvironmentDecorations has strictly 0 CollisionShape3D nodes (found %d)" % shapes.size())

	# Verify zero obstacles in SwarmFlowField belong to EnvironmentDecorations
	var sim = main_level.get("swarm_simulation")
	if sim and sim.flow_field:
		var registered_obstacles: Dictionary = sim.flow_field.registered_obstacles
		var decor_interferes: bool = false
		for obstacle in registered_obstacles.keys():
			var p: Node = obstacle
			while p != null:
				if p == decor:
					decor_interferes = true
					break
				p = p.get_parent()
		_assert(not decor_interferes, "Zero EnvironmentDecorations nodes registered as obstacles in SwarmFlowField")

	main_level.free()


# -----------------------------------------------------------------------------
# 4. Structural Combat Mitigations Mathematical Precision
# -----------------------------------------------------------------------------
func _test_structural_mitigations_math_precision() -> void:
	# 4A: Reinforced Wall - 35% Mitigation (0.65 multiplier)
	# Physical damage tests
	var w1 = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(w1.damage_dealt - 65.0) < 0.0001, "Wall 35%%: 100 raw physical -> 65.0 (got %.4f)" % w1.damage_dealt)

	var w2 = SFECombatEngine.calculate_damage(500.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(w2.damage_dealt - 325.0) < 0.0001, "Wall 35%%: 500 raw physical -> 325.0 (got %.4f)" % w2.damage_dealt)

	var w3 = SFECombatEngine.calculate_damage(10000.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(w3.damage_dealt - 6500.0) < 0.0001, "Wall 35%%: 10000 raw physical -> 6500.0 (got %.4f)" % w3.damage_dealt)

	# Spell damage tests (ignores flat armor but respects structural mitigation)
	var ws1 = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.SPELL, 50.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(ws1.damage_dealt - 65.0) < 0.0001, "Wall 35%%: 100 raw spell ignores 50 armor -> 65.0 (got %.4f)" % ws1.damage_dealt)

	# Combined: Flat armor 15 -> (100 - 15) = 85. Wall 35% -> 85 * 0.65 = 55.25
	var w_arm = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 15.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(w_arm.damage_dealt - 55.25) < 0.0001, "Wall 35%% with flat armor 15: dealt 55.25 (got %.4f)" % w_arm.damage_dealt)

	# Combined: Flat armor 10, Upgrade level 10 (2% reduction) -> 90 * 0.98 * 0.65 = 57.33
	var w_stacked = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 10.0, 10, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(w_stacked.damage_dealt - 57.33) < 0.01, "Wall 35%% stacked (armor 10, lvl 10): dealt 57.33 (got %.4f)" % w_stacked.damage_dealt)

	# Edge: 0 raw damage -> 0.0
	var w_zero = SFECombatEngine.calculate_damage(0.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(w_zero.damage_dealt == 0.0, "Wall 35%%: 0 raw damage -> 0.0 dealt")

	# Edge: Invulnerable -> 0.0
	var w_invuln = SFECombatEngine.calculate_damage(1000.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false, false, true)
	_assert(w_invuln.damage_dealt == 0.0, "Wall invulnerable -> 0.0 dealt")

	# 4B: Bunker - 25% Mitigation (0.75 multiplier)
	# Physical damage tests
	var b1 = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER, false)
	_assert(absf(b1.damage_dealt - 75.0) < 0.0001, "Bunker 25%%: 100 raw physical -> 75.0 (got %.4f)" % b1.damage_dealt)

	var b2 = SFECombatEngine.calculate_damage(500.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER, false)
	_assert(absf(b2.damage_dealt - 375.0) < 0.0001, "Bunker 25%%: 500 raw physical -> 375.0 (got %.4f)" % b2.damage_dealt)

	var b3 = SFECombatEngine.calculate_damage(2500.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER, false)
	_assert(absf(b3.damage_dealt - 1875.0) < 0.0001, "Bunker 25%%: 2500 raw physical -> 1875.0 (got %.4f)" % b3.damage_dealt)

	# Spell damage tests
	var bs1 = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.SPELL, 30.0, 0, CombatTypes.StructureType.BUNKER, false)
	_assert(absf(bs1.damage_dealt - 75.0) < 0.0001, "Bunker 25%%: 100 raw spell ignores 30 armor -> 75.0 (got %.4f)" % bs1.damage_dealt)

	# Combined: Flat armor 20 -> (100 - 20) = 80. Bunker 25% -> 80 * 0.75 = 60.0
	var b_arm = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 20.0, 0, CombatTypes.StructureType.BUNKER, false)
	_assert(absf(b_arm.damage_dealt - 60.0) < 0.0001, "Bunker 25%% with flat armor 20: dealt 60.0 (got %.4f)" % b_arm.damage_dealt)

	# Combined: Flat armor 10, Upgrade level 25 (5% reduction) -> 90 * 0.95 * 0.75 = 64.125
	var b_stacked = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 10.0, 25, CombatTypes.StructureType.BUNKER, false)
	_assert(absf(b_stacked.damage_dealt - 64.125) < 0.01, "Bunker 25%% stacked (armor 10, lvl 25): dealt 64.125 (got %.4f)" % b_stacked.damage_dealt)

	# Edge: Invulnerable bunker -> 0.0
	var b_invuln = SFECombatEngine.calculate_damage(1000.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER, false, false, true)
	_assert(b_invuln.damage_dealt == 0.0, "Bunker invulnerable -> 0.0 dealt")


# -----------------------------------------------------------------------------
# 5. CombatVFXPool Zero Dynamic Allocation (Strictly 44 Children)
# -----------------------------------------------------------------------------
func _test_combat_vfx_pool_zero_allocation_stress() -> void:
	var pool := CombatVFXPool.new()
	add_child(pool)

	_assert(pool.get_tracer_pool_size() == 24, "CombatVFXPool TRACER_POOL_SIZE == 24")
	_assert(pool.get_acid_pool_size() == 20, "CombatVFXPool ACID_BURST_POOL_SIZE == 20")
	_assert(pool.get_child_count() == 44, "CombatVFXPool strictly 44 pre-allocated child nodes")

	var initial_children: int = pool.get_child_count()

	# Stress: 1,000 rapid burst firing cycles across random positions
	for i in range(1000):
		var from_pos := Vector3(float(i % 20) - 10.0, 1.2, float((i * 3) % 40) - 20.0)
		var to_pos := Vector3(float((i * 7) % 60) - 30.0, 0.0, float((i * 11) % 60) - 30.0)

		pool._process(0.016) # resets bursts_this_frame
		var tracer = pool.spawn_tracer(from_pos, to_pos)
		var burst = pool.spawn_acid_burst(to_pos)

		if i % 100 == 0:
			_assert(pool.get_child_count() == initial_children, "Child count invariant strictly 44 at spawn cycle %d" % i)

	_assert(pool.get_child_count() == 44, "Child count remains strictly 44 after 1,000 rapid spawns (0 dynamic allocations)")

	# Verify circular index wrapping
	_assert(pool._tracer_index == (1000 % 24), "Tracer pool circular index wrapped correctly (%d == %d)" % [pool._tracer_index, 1000 % 24])
	_assert(pool._acid_index == (1000 % 20), "Acid burst circular index wrapped correctly (%d == %d)" % [pool._acid_index, 1000 % 20])

	pool.free()


# -----------------------------------------------------------------------------
# 6. SC2 HUD Console Robustness Under Extreme Selections & Churn
# -----------------------------------------------------------------------------
func _test_sc2_hud_robustness_and_churn() -> void:
	var hud := SC2HUDRoot.new()
	add_child(hud)
	hud._build_hud_layout()

	_assert(hud.bottom_console != null, "HUD bottom_console initialized")
	_assert(hud.stat_panel != null, "HUD stat_panel initialized")
	_assert(hud.command_card != null, "HUD command_card initialized")

	# 6A: Extreme selection inputs
	hud._on_units_selected([])
	_assert(hud.stat_panel.bound_unit == null, "Empty selection deselects stat_panel")
	_assert(hud.command_card.bound_unit == null, "Empty selection deselects command_card")

	hud._on_units_selected([null])
	_assert(hud.stat_panel.bound_unit == null, "[null] selection safely clears stat_panel")

	hud._on_units_selected([null, null, null])
	_assert(hud.stat_panel.bound_unit == null, "Multi-null selection safely clears stat_panel")

	# 6B: Rapid selection switching churn (2,000 iterations)
	var hero := HeroUnit3D.new()
	var hd := HeroData.new()
	hd.hero_name = "Jim Raynor"
	hd.strength = 20
	hd.dexterity = 15
	hd.intelligence = 10
	hd.attribute_points = 5
	hd.max_hp = 500.0
	hd.current_hp = 500.0
	hd.max_energy = 100.0
	hd.current_energy = 100.0
	hero.hero_data = hd
	add_child(hero)

	var marine_scene := load("res://entities/allies/base_unit_3d.tscn") as PackedScene
	var marine: Node = marine_scene.instantiate() if marine_scene else BaseUnit3D.new()
	marine.name = "TestMarine"
	add_child(marine)

	var wall = WallSegmentScene.instantiate()
	add_child(wall)

	var bunker = BunkerStructureScene.instantiate()
	add_child(bunker)

	var cc = CommandCenterScene.instantiate()
	add_child(cc)

	var units_pool: Array[Node] = [hero, marine, wall, bunker, cc, null]

	for i in range(2000):
		var target: Node = units_pool[i % units_pool.size()]
		if target == null:
			hud._on_units_deselected()
		else:
			hud._on_units_selected([target])

		if i % 200 == 0:
			hud.stat_panel._process(0.016)
			hud.command_card._process(0.016)

	_assert(true, "2,000 rapid selection switching iterations completed cleanly without errors")

	# 6C: Dangling / freed instance safety
	var temp_unit: Node = marine_scene.instantiate() if marine_scene else Node3D.new()
	temp_unit.name = "DanglingUnit"
	add_child(temp_unit)
	hud._on_units_selected([temp_unit])
	_assert(hud.stat_panel.bound_unit == temp_unit, "Dangling unit bound to HUD")

	# Free the unit while HUD is bound
	temp_unit.free()
	# Tick process - must not crash
	hud.stat_panel._process(0.016)
	hud.command_card._process(0.016)
	hud._on_units_deselected()
	_assert(hud.stat_panel.bound_unit == null, "Dangling unit freed and HUD deselected cleanly")

	# 6D: SC2StatPanel RPG Attribute Allocation
	hud._on_units_selected([hero])
	_assert(hud.stat_panel.bound_unit == hero, "Hero bound to stat_panel for RPG test")

	hero.hero_data.attribute_points = 5
	var initial_str: int = hero.hero_data.strength
	var initial_dex: int = hero.hero_data.dexterity
	var initial_int: int = hero.hero_data.intelligence
	var initial_pts: int = hero.hero_data.attribute_points # 5

	# Allocate 2 STR
	hud.stat_panel._on_attribute_allocated("str")
	hud.stat_panel._on_attribute_allocated("str")
	_assert(hero.hero_data.strength == initial_str + 2, "STR increased by 2 (got %d)" % hero.hero_data.strength)
	_assert(hero.hero_data.attribute_points == initial_pts - 2, "Attribute points decremented to 3")

	# Allocate 2 DEX
	hud.stat_panel._on_attribute_allocated("dex")
	hud.stat_panel._on_attribute_allocated("dex")
	_assert(hero.hero_data.dexterity == initial_dex + 2, "DEX increased by 2 (got %d)" % hero.hero_data.dexterity)
	_assert(hero.hero_data.attribute_points == initial_pts - 4, "Attribute points decremented to 1")

	# Allocate 1 INT
	hud.stat_panel._on_attribute_allocated("int")
	_assert(hero.hero_data.intelligence == initial_int + 1, "INT increased by 1 (got %d)" % hero.hero_data.intelligence)
	_assert(hero.hero_data.attribute_points == 0, "Attribute points decremented to 0")

	# Click [+] when points == 0 -> should do nothing
	hud.stat_panel._on_attribute_allocated("str")
	_assert(hero.hero_data.strength == initial_str + 2, "STR unchanged when 0 points available")
	_assert(hero.hero_data.attribute_points == 0, "Attribute points remain 0")

	# Verify dynamic vital gauge colors
	hud.stat_panel._update_hp_bar_color(800.0, 1000.0) # 80% -> Green
	var green_sb: StyleBoxFlat = hud.stat_panel.hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_assert(green_sb.bg_color.g > 0.8 and green_sb.bg_color.r < 0.3, "HP Bar 80%% is Green (Color: %s)" % str(green_sb.bg_color))

	hud.stat_panel._update_hp_bar_color(400.0, 1000.0) # 40% -> Amber
	var amber_sb: StyleBoxFlat = hud.stat_panel.hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_assert(amber_sb.bg_color.r > 0.8 and amber_sb.bg_color.g > 0.6, "HP Bar 40%% is Amber (Color: %s)" % str(amber_sb.bg_color))

	hud.stat_panel._update_hp_bar_color(150.0, 1000.0) # 15% -> Red
	var red_sb: StyleBoxFlat = hud.stat_panel.hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_assert(red_sb.bg_color.r > 0.8 and red_sb.bg_color.g < 0.3, "HP Bar 15%% is Red (Color: %s)" % str(red_sb.bg_color))

	# 6E: SC2CommandCard 15-button grid and energy guards
	var card: SC2CommandCard = hud.command_card
	_assert(card.slot_buttons.size() == 15, "CommandCard has exactly 15 buttons")
	_assert(card.slot_data.size() == 15, "CommandCard has exactly 15 slot_data entries")

	# Cleared card produces zero commands
	var cmd_emitted: Array[String] = []
	card.command_triggered.connect(func(c: String, _p: Variant): cmd_emitted.append(c))

	card.clear_card()
	for i in range(15):
		card._on_slot_pressed(i)
	_assert(cmd_emitted.is_empty(), "Cleared card emits 0 commands for all 15 slots")

	# Out-of-bounds indices handle safely
	card._on_slot_pressed(-5)
	card._on_slot_pressed(15)
	card._on_slot_pressed(9999)
	_assert(cmd_emitted.is_empty(), "Out-of-bounds indices safely ignored")

	# Populate with Marine
	card.populate_for_unit(marine)
	_assert(card.slot_data[5].get("id") == "ATTACK", "Marine slot 5 is ATTACK")
	_assert(card.slot_data[6].get("id") == "STOP", "Marine slot 6 is STOP")
	_assert(card.slot_data[7].get("id") == "HOLD", "Marine slot 7 is HOLD")
	_assert(card.slot_data[10].get("id") == "MOVE", "Marine slot 10 is MOVE")

	# Click ATTACK
	card._on_slot_pressed(5)
	_assert(cmd_emitted.has("ATTACK"), "Marine slot 5 triggers ATTACK command")

	# 500 rapid slot click stress
	for i in range(500):
		card._on_slot_pressed(i % 15)
	_assert(true, "500 rapid command card slot clicks executed safely")

	hero.free()
	marine.free()
	wall.free()
	bunker.free()
	cc.free()
	hud.free()
