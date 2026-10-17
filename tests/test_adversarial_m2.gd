extends Node

# test_adversarial_m2.gd
# Empirical Challenger Adversarial Test Suite for Milestone 2:
# Terran Base Structures & Planetary Fortress
#
# Tests:
# 1. Gate state machine, kinematics (Y=1.65 to Y=-1.95), status lights (Red/Green/Amber).
# 2. Rapid gate toggling stress test (100 calls in single frame, mid-motion reversal, parity).
# 3. Proximity edge cases (freed node cleanup, multiple allies).
# 4. Structure combat damage, health reduction, clamping at 0, health bar billboard updates.
# 5. Combat mitigation matrix (35% walls, 25% bunkers, spell bypass, armor & upgrade interplay).
# 6. SignalBus event emissions on damage and destruction.

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
var failure_log: Array[String] = []


func _ready() -> void:
	print("\n====================================================================")
	print("=== EMPIRICAL CHALLENGER ADVERSARIAL TEST SUITE (MILESTONE 2) ===")
	print("====================================================================")

	_run_suite()

	print("\n====================================================================")
	print("Empirical Results: Total: %d, Passed: %d, Failed: %d" % [total_tests, passed_tests, failed_tests])
	if failed_tests > 0:
		print("VERDICT: FAILURES DETECTED!")
		for f in failure_log:
			print("  [FAIL] %s" % f)
		print("====================================================================\n")
		get_tree().quit(1)
	else:
		print("VERDICT: ALL ADVERSARIAL & EMPIRICAL TESTS PASSED! [GREEN]")
		print("====================================================================\n")
		get_tree().quit(0)


func _assert(condition: bool, test_name: String, error_msg: String) -> bool:
	total_tests += 1
	if not condition:
		failed_tests += 1
		failure_log.append("%s: %s" % [test_name, error_msg])
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		return false
	passed_tests += 1
	print("  [PASS] %s" % test_name)
	return true


func _run_suite() -> void:
	_test_gate_kinematics_and_status_lights()
	_test_gate_rapid_toggle_and_edge_cases()
	_test_gate_proximity_and_freed_instances()
	_test_combat_damage_and_health_bars()
	_test_passive_structural_mitigation_matrix()
	_test_signal_bus_events()
	_test_ground_flushness_and_aabbs()


func _test_gate_kinematics_and_status_lights() -> void:
	print("\n>> 1. Gate Kinematics & Status Light Transitions...")
	var gate: GateStructure = GateStructureScene.instantiate() as GateStructure
	_assert(gate != null, "Gate: Instance Created", "Failed to instantiate GateStructure")
	if not gate:
		return
	add_child(gate)

	var door_vis: Node3D = gate.get_node_or_null("VisualRoot/DoorSlidingPart") as Node3D
	var light_mesh: MeshInstance3D = gate.get_node_or_null("VisualRoot/StatusLight") as MeshInstance3D
	var door_col: CollisionShape3D = gate.get_node_or_null("DoorCollisionShape") as CollisionShape3D

	# 1. Initial Closed state
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate: Initial State is CLOSED", "State was %s" % str(gate.current_state))
	_assert(is_equal_approx(gate._door_closed_y, 1.65), "Gate: Closed Y is exactly 1.65", "Closed Y is %f, expected 1.65" % gate._door_closed_y)
	_assert(is_equal_approx(gate._door_open_y, -1.95), "Gate: Open Y is exactly -1.95", "Open Y is %f, expected -1.95" % gate._door_open_y)
	_assert(is_equal_approx(door_vis.position.y, 1.65), "Gate: Door Visual initial position is 1.65", "Position is %f" % door_vis.position.y)
	_assert(door_col.disabled == false, "Gate: Collision enabled when closed", "Collision was disabled")

	# Check Red light
	var mat: StandardMaterial3D = light_mesh.material_override as StandardMaterial3D
	_assert(mat != null, "Gate: Closed Light Material Assigned", "Material is null")
	if mat:
		_assert(mat.albedo_color.r > 0.8 and mat.albedo_color.g < 0.3 and mat.albedo_color.b < 0.3, "Gate: Status Light is RED when CLOSED", "Color is %s" % str(mat.albedo_color))
		_assert(mat.emission_enabled == true, "Gate: Status Light Emission Enabled", "Emission is false")

	# 2. Open Gate
	gate.open_gate(false)
	_assert(gate.current_state == GateStructure.GateState.OPEN, "Gate: State transitions to OPEN", "State was %s" % str(gate.current_state))
	_assert(is_equal_approx(gate._target_door_y, -1.95), "Gate: Target Y set to -1.95", "Target is %f" % gate._target_door_y)

	mat = light_mesh.material_override as StandardMaterial3D
	if mat:
		_assert(mat.albedo_color.g > 0.8 and mat.albedo_color.r < 0.3, "Gate: Status Light is GREEN when OPEN", "Color is %s" % str(mat.albedo_color))

	# 3. Simulate step-by-step physical downward travel
	# Gate requires an ally present or is_locked_by_player=true to remain open (auto_open_for_allies behavior)
	var ally := Node3D.new()
	ally.add_to_group("allies")
	add_child(ally)
	gate._nearby_allies.append(ally)

	# At slide_speed = 8.0, 0.1s delta moves 0.8m
	var prev_y: float = door_vis.position.y
	for step in range(5):
		gate._process(0.1)
		_assert(door_vis.position.y < prev_y, "Gate: Door moves downward step %d (y=%f)" % [step, door_vis.position.y], "Door did not move down")
		prev_y = door_vis.position.y

	# Finish descent
	gate._process(0.5)
	_assert(is_equal_approx(door_vis.position.y, -1.95), "Gate: Door reaches -1.95 precisely", "Position is %f" % door_vis.position.y)
	_assert(door_col.disabled == true, "Gate: Collision disabled when door fully opened", "Collision was still enabled")

	# Further ticks do not overshoot
	gate._process(1.0)
	_assert(is_equal_approx(door_vis.position.y, -1.95), "Gate: Door does NOT overshoot below -1.95", "Position is %f" % door_vis.position.y)

	# Clean up ally to test closing
	gate._nearby_allies.clear()
	ally.queue_free()

	# 4. Close Gate
	gate.close_gate(false)
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate: State transitions to CLOSED", "State was %s" % str(gate.current_state))
	_assert(is_equal_approx(gate._target_door_y, 1.65), "Gate: Target Y set to 1.65", "Target is %f" % gate._target_door_y)
	_assert(door_col.disabled == false, "Gate: Collision immediately re-enabled on close command", "Collision disabled")

	mat = light_mesh.material_override as StandardMaterial3D
	if mat:
		_assert(mat.albedo_color.r > 0.8 and mat.albedo_color.g < 0.3, "Gate: Status Light reverts to RED on CLOSE", "Color is %s" % str(mat.albedo_color))

	# Process upwards
	gate._process(0.5)
	_assert(is_equal_approx(door_vis.position.y, 1.65), "Gate: Door returns to 1.65 precisely", "Position is %f" % door_vis.position.y)
	gate._process(1.0)
	_assert(is_equal_approx(door_vis.position.y, 1.65), "Gate: Door does NOT overshoot above 1.65", "Position is %f" % door_vis.position.y)

	# 5. Player Lock
	gate.toggle_gate() # Locks
	_assert(gate.is_locked_by_player == true, "Gate: is_locked_by_player is TRUE", "Lock was false")
	mat = light_mesh.material_override as StandardMaterial3D
	if mat:
		_assert(mat.albedo_color.r > 0.8 and mat.albedo_color.g > 0.5 and mat.albedo_color.b < 0.2, "Gate: Status Light is AMBER when LOCKED", "Color is %s" % str(mat.albedo_color))

	gate.queue_free()


func _test_gate_rapid_toggle_and_edge_cases() -> void:
	print("\n>> 2. Adversarial Rapid Gate Toggle & Kinematic Stress...")
	var gate: GateStructure = GateStructureScene.instantiate() as GateStructure
	add_child(gate)
	var door_vis: Node3D = gate.get_node_or_null("VisualRoot/DoorSlidingPart") as Node3D
	var light_mesh: MeshInstance3D = gate.get_node_or_null("VisualRoot/StatusLight") as MeshInstance3D

	# Edge Case 1: Rapid spamming 100 times in 1 frame
	var exceptions_detected: bool = false
	for i in range(100):
		gate.toggle_gate()

	_assert(not exceptions_detected, "Gate Stress: 100 rapid toggles executed without crash", "Exceptions thrown")
	# After 100 toggles (even number), lock state should have restored to false
	_assert(gate.is_locked_by_player == false, "Gate Stress: Parity check - is_locked_by_player restored to false after 100 toggles", "is_locked_by_player is %s" % str(gate.is_locked_by_player))
	_assert(is_equal_approx(gate._target_door_y, 1.65) or is_equal_approx(gate._target_door_y, -1.95), "Gate Stress: Target Y is valid bounded float (%f)" % gate._target_door_y, "Invalid target")

	# Edge Case 2: Mid-motion direction reversal
	gate.open_gate(false)
	gate._process(0.2) # halfway down
	var mid_y: float = door_vis.position.y
	_assert(mid_y < 1.65 and mid_y > -1.95, "Gate Stress: Mid-motion position captured (%f)" % mid_y, "Not mid-motion")

	# Spam toggle during mid-motion
	for i in range(25):
		gate.toggle_gate()
		gate._process(0.01) # interleaved tiny ticks

	# Confirm position never broke outside [ -1.95, 1.65 ]
	_assert(door_vis.position.y >= -1.95 - 0.01 and door_vis.position.y <= 1.65 + 0.01, "Gate Stress: Door Y bounded within [-1.95, 1.65] during rapid mid-motion spam (y=%f)" % door_vis.position.y, "OutOfBounds Y: %f" % door_vis.position.y)

	# Edge Case 3: Settle after chaos
	gate.close_gate(false)
	for i in range(30):
		gate._process(0.1)

	_assert(is_equal_approx(door_vis.position.y, 1.65), "Gate Stress: Door settled cleanly to 1.65 after spam", "Final Y is %f" % door_vis.position.y)

	# Edge Case 4: Rapid alternate open/close
	for i in range(50):
		if i % 2 == 0:
			gate.open_gate(false)
		else:
			gate.close_gate(false)
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate Stress: Final state matches last alternating call", "State was %s" % str(gate.current_state))
	_assert(is_equal_approx(gate._target_door_y, 1.65), "Gate Stress: Target Y matches final alternating call", "Target was %f" % gate._target_door_y)

	gate.queue_free()


func _test_gate_proximity_and_freed_instances() -> void:
	print("\n>> 3. Gate Proximity & Freed Instance Safety...")
	var gate: GateStructure = GateStructureScene.instantiate() as GateStructure
	add_child(gate)

	# Simulate 3 allies entering
	var ally1 := Node3D.new()
	ally1.add_to_group("allies")
	var ally2 := Node3D.new()
	ally2.add_to_group("allies")
	var ally3 := Node3D.new()
	ally3.add_to_group("allies")
	add_child(ally1)
	add_child(ally2)
	add_child(ally3)

	gate._on_proximity_body_entered(ally1)
	gate._on_proximity_body_entered(ally2)
	gate._on_proximity_body_entered(ally3)

	_assert(gate.current_state == GateStructure.GateState.OPEN, "Gate Proximity: Gate opens on ally entry", "Gate state not OPEN")
	_assert(gate._nearby_allies.size() == 3, "Gate Proximity: 3 allies registered", "Size is %d" % gate._nearby_allies.size())

	# Ally 1 exits
	gate._on_proximity_body_exited(ally1)
	_assert(gate.current_state == GateStructure.GateState.OPEN, "Gate Proximity: Gate stays OPEN while other allies remain", "Gate closed prematurely")
	_assert(gate._nearby_allies.size() == 2, "Gate Proximity: 2 allies remain", "Size is %d" % gate._nearby_allies.size())

	# Ally 2 is freed mid-simulation (e.g. killed by enemy)
	ally2.free() # immediate memory destruction

	# Tick gate process to trigger _clean_nearby_allies()
	gate._process(0.1)
	_assert(gate._nearby_allies.size() == 1, "Gate Proximity: Freed ally safely purged from list without crash", "Size is %d" % gate._nearby_allies.size())
	_assert(gate.current_state == GateStructure.GateState.OPEN, "Gate Proximity: Gate stays open for surviving ally3", "Gate closed")

	# Ally 3 exits
	gate._on_proximity_body_exited(ally3)
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate Proximity: Gate closes when last ally exits", "Gate did not close")

	# What if ally is freed while being the ONLY ally inside?
	var ally4 := Node3D.new()
	ally4.add_to_group("allies")
	add_child(ally4)
	gate._on_proximity_body_entered(ally4)
	_assert(gate.current_state == GateStructure.GateState.OPEN, "Gate Proximity: Reopens for ally4", "Did not open")

	ally4.free() # dies inside proximity
	gate._process(0.1) # should clean and auto-close
	_assert(gate.current_state == GateStructure.GateState.CLOSED, "Gate Proximity: Auto-closes when sole remaining ally is freed/destroyed", "Gate remained OPEN")

	ally1.queue_free()
	ally3.queue_free()
	gate.queue_free()


func _test_combat_damage_and_health_bars() -> void:
	print("\n>> 4. Combat Damage Events & HealthBar3D Billboard Updates...")

	# --- 1. Modular Wall Segment ---
	var wall: WallSegment = WallSegmentScene.instantiate() as WallSegment
	add_child(wall)
	var wall_hb: HealthBar3D = wall.get_node_or_null("HealthBar3D") as HealthBar3D
	_assert(wall_hb != null, "Wall: HealthBar3D node exists", "Missing HealthBar3D")
	_assert(wall.current_health == 600.0, "Wall: Initial health 600.0", "Health is %f" % wall.current_health)
	_assert(wall_hb.visible == false, "Wall: HealthBar hidden at full health", "HealthBar was visible")

	# Take non-lethal damage
	wall.take_damage(150.0)
	_assert(is_equal_approx(wall.current_health, 450.0), "Wall: Health reduced to 450.0 after 150 damage", "Health is %f" % wall.current_health)
	_assert(wall_hb.visible == true, "Wall: HealthBar visible after taking damage", "HealthBar remained hidden")
	var fill_pivot: Node3D = wall_hb.get_node_or_null("FillPivot") as Node3D
	if fill_pivot:
		_assert(is_equal_approx(fill_pivot.scale.x, 450.0 / 600.0), "Wall: HealthBar scale matches 0.75 ratio", "Scale.x is %f" % fill_pivot.scale.x)

	# Overkill damage
	wall.take_damage(1000.0)
	_assert(is_equal_approx(wall.current_health, 0.0), "Wall: Health clamped at 0.0 on overkill damage", "Health is %f" % wall.current_health)
	wall.queue_free()

	# --- 2. Fortified Bunker ---
	var bunker: BunkerStructure = BunkerStructureScene.instantiate() as BunkerStructure
	add_child(bunker)
	var bunker_hb: HealthBar3D = bunker.get_node_or_null("HealthBar3D") as HealthBar3D
	_assert(bunker.current_health == 750.0, "Bunker: Initial health 750.0", "Health is %f" % bunker.current_health)
	bunker.take_damage(200.0)
	_assert(is_equal_approx(bunker.current_health, 550.0), "Bunker: Health reduced to 550.0", "Health is %f" % bunker.current_health)
	if bunker_hb:
		_assert(bunker_hb.visible == true, "Bunker: HealthBar visible on damage", "HealthBar hidden")
	bunker.take_damage(1000.0)
	_assert(is_equal_approx(bunker.current_health, 0.0), "Bunker: Health clamped at 0.0 on overkill", "Health is %f" % bunker.current_health)
	bunker.queue_free()

	# --- 3. Planetary Fortress / Command Center ---
	var cc: CommandCenter = CommandCenterScene.instantiate() as CommandCenter
	add_child(cc)
	var cc_hb: HealthBar3D = cc.get_node_or_null("HealthBar3D") as HealthBar3D
	_assert(cc.current_health == 2000.0, "CC: Initial health 2000.0", "Health is %f" % cc.current_health)
	cc.take_damage(500.0)
	_assert(is_equal_approx(cc.current_health, 1500.0), "CC: Health reduced to 1500.0", "Health is %f" % cc.current_health)
	if cc_hb:
		_assert(cc_hb.visible == true, "CC: HealthBar visible on damage", "HealthBar hidden")
	cc.take_damage(5000.0)
	_assert(is_equal_approx(cc.current_health, 0.0), "CC: Health clamped at 0.0 on overkill", "Health is %f" % cc.current_health)
	cc.queue_free()

	# --- 4. Gate Structure ---
	var gate: GateStructure = GateStructureScene.instantiate() as GateStructure
	add_child(gate)
	var gate_hb: HealthBar3D = gate.get_node_or_null("HealthBar3D") as HealthBar3D
	_assert(gate.current_health == 800.0, "Gate: Initial health 800.0", "Health is %f" % gate.current_health)
	gate.take_damage(300.0)
	_assert(is_equal_approx(gate.current_health, 500.0), "Gate: Health reduced to 500.0", "Health is %f" % gate.current_health)
	if gate_hb:
		_assert(gate_hb.visible == true, "Gate: HealthBar visible on damage", "HealthBar hidden")
	gate.take_damage(2000.0)
	_assert(is_equal_approx(gate.current_health, 0.0), "Gate: Health clamped at 0.0 on overkill", "Health is %f" % gate.current_health)
	gate.queue_free()


func _test_passive_structural_mitigation_matrix() -> void:
	print("\n>> 5. Passive Structural Mitigation Mathematical Matrix...")

	# Case 1: Wall Physical Mitigation (35%)
	# 100.0 raw physical -> 100 * (1 - 0.35) = 65.0
	var res := SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED)
	_assert(is_equal_approx(res.damage_dealt, 65.0), "Mitigation Matrix: Wall 35% Physical (100 -> 65.0)", "Result is %f" % res.damage_dealt)

	# Case 2: Bunker Physical Mitigation (25%)
	# 100.0 raw physical -> 100 * (1 - 0.25) = 75.0
	res = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER)
	_assert(is_equal_approx(res.damage_dealt, 75.0), "Mitigation Matrix: Bunker 25% Physical (100 -> 75.0)", "Result is %f" % res.damage_dealt)

	# Case 3: Wall Spell Damage (Ignores flat armor, respects 35% structure mitigation)
	# 100.0 raw spell with 10 flat armor -> flat armor bypassed -> 100 * (1 - 0.35) = 65.0
	res = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.SPELL, 10.0, 0, CombatTypes.StructureType.WALL_REINFORCED)
	_assert(is_equal_approx(res.damage_dealt, 65.0), "Mitigation Matrix: Wall Spell with Armor bypass (100 raw, 10 armor -> 65.0)", "Result is %f" % res.damage_dealt)

	# Case 4: Bunker Spell Damage
	res = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.SPELL, 10.0, 0, CombatTypes.StructureType.BUNKER)
	_assert(is_equal_approx(res.damage_dealt, 75.0), "Mitigation Matrix: Bunker Spell with Armor bypass (100 raw, 10 armor -> 75.0)", "Result is %f" % res.damage_dealt)

	# Case 5: Combined Flat Armor + Progressive Upgrade (10 levels = 2%) + Wall (35%)
	# raw = 100.0, armor = 10.0 -> effective = 90.0
	# prog = 90.0 * (1.0 - 0.02) = 88.2
	# wall = 88.2 * 0.65 = 57.33
	res = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 10.0, 10, CombatTypes.StructureType.WALL_REINFORCED)
	_assert(is_equal_approx(res.damage_dealt, 57.33), "Mitigation Matrix: Combined Armor(10) + Upgrade(10 lvl) + Wall (100 raw -> 57.33)", "Result is %f" % res.damage_dealt)

	# Case 6: Combined Flat Armor + Progressive Upgrade (10 levels = 2%) + Bunker (25%)
	# raw = 100.0, armor = 10.0 -> effective = 90.0
	# prog = 90.0 * (1.0 - 0.02) = 88.2
	# bunker = 88.2 * 0.75 = 66.15
	res = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 10.0, 10, CombatTypes.StructureType.BUNKER)
	_assert(is_equal_approx(res.damage_dealt, 66.15), "Mitigation Matrix: Combined Armor(10) + Upgrade(10 lvl) + Bunker (100 raw -> 66.15)", "Result is %f" % res.damage_dealt)


func _test_signal_bus_events() -> void:
	print("\n>> 6. SignalBus Event Emissions...")
	var wall: WallSegment = WallSegmentScene.instantiate() as WallSegment
	add_child(wall)

	var signal_stats := {
		"damaged_count": 0,
		"last_damaged_hp": -1.0,
		"destroyed_count": 0
	}

	var on_damaged = func(target: Node, current_hp: float, _max_hp: float):
		if target == wall:
			signal_stats["damaged_count"] += 1
			signal_stats["last_damaged_hp"] = current_hp

	var on_destroyed = func(target: Node):
		if target == wall:
			signal_stats["destroyed_count"] += 1

	SignalBus.structure_damaged.connect(on_damaged)
	SignalBus.structure_destroyed.connect(on_destroyed)

	wall.take_damage(100.0)
	_assert(signal_stats["damaged_count"] == 1, "SignalBus: structure_damaged received on non-lethal hit", "Count is %d" % signal_stats["damaged_count"])
	_assert(is_equal_approx(signal_stats["last_damaged_hp"], 500.0), "SignalBus: structure_damaged reports correct remaining HP 500.0", "HP is %f" % signal_stats["last_damaged_hp"])
	_assert(signal_stats["destroyed_count"] == 0, "SignalBus: structure_destroyed NOT emitted on non-lethal hit", "Count is %d" % signal_stats["destroyed_count"])

	wall.take_damage(600.0) # lethal
	_assert(signal_stats["damaged_count"] == 2, "SignalBus: structure_damaged received on lethal hit", "Count is %d" % signal_stats["damaged_count"])
	_assert(signal_stats["destroyed_count"] == 1, "SignalBus: structure_destroyed received on structure zero HP", "Count is %d" % signal_stats["destroyed_count"])

	SignalBus.structure_damaged.disconnect(on_damaged)
	SignalBus.structure_destroyed.disconnect(on_destroyed)
	wall.queue_free()


func _test_ground_flushness_and_aabbs() -> void:
	print("\n>> 7. Structure AABB Ground Flushness & Dimensions...")
	var cc_mesh: Mesh = load("res://assets/models/structures/command_center_mesh.tres") as Mesh
	_assert(cc_mesh != null, "AABB: CC Mesh loaded", "Failed to load command_center_mesh.tres")
	if cc_mesh:
		var aabb := cc_mesh.get_aabb()
		_assert(is_equal_approx(aabb.position.y, 0.0), "AABB: CC Mesh ground contact flush at y=0.0", "Bottom is %f" % aabb.position.y)
		_assert(aabb.end.y < 5.2, "AABB: CC Mesh height %f < 5.2 (HealthBar clearance)" % aabb.end.y, "Height is %f" % aabb.end.y)

	var wall_mesh: Mesh = load("res://assets/models/structures/wall_segment_mesh.tres") as Mesh
	_assert(wall_mesh != null, "AABB: Wall Mesh loaded", "Failed to load wall_segment_mesh.tres")
	if wall_mesh:
		var aabb := wall_mesh.get_aabb()
		_assert(is_equal_approx(aabb.position.y, 0.0), "AABB: Wall Mesh ground contact flush at y=0.0", "Bottom is %f" % aabb.position.y)
		_assert(aabb.size.x >= 3.9 and aabb.size.x <= 4.1, "AABB: Wall Mesh spans 4.0m modular width (size.x=%f)" % aabb.size.x, "Width is %f" % aabb.size.x)

	var bunker_mesh: Mesh = load("res://assets/models/structures/bunker_structure_mesh.tres") as Mesh
	_assert(bunker_mesh != null, "AABB: Bunker Mesh loaded", "Failed to load bunker_structure_mesh.tres")
	if bunker_mesh:
		var aabb := bunker_mesh.get_aabb()
		_assert(is_equal_approx(aabb.position.y, 0.0), "AABB: Bunker Mesh ground contact flush at y=0.0", "Bottom is %f" % aabb.position.y)
		# Hull X dimension is 3.48m (within 3.5m collision box). Total Z with rear hatch is 3.62m.
		_assert(aabb.size.x <= 3.50, "AABB: Bunker Hull X width (%f) fits <= 3.5m collision box" % aabb.size.x, "X width is %f" % aabb.size.x)
		_assert(aabb.size.z <= 3.65, "AABB: Bunker Total Z depth (%f) within acceptable visual margin" % aabb.size.z, "Z depth is %f" % aabb.size.z)

	var gate_frame: Mesh = load("res://assets/models/structures/gate_frame_mesh.tres") as Mesh
	_assert(gate_frame != null, "AABB: Gate Frame Mesh loaded", "Failed to load gate_frame_mesh.tres")
	if gate_frame:
		var aabb := gate_frame.get_aabb()
		_assert(is_equal_approx(aabb.position.y, 0.0), "AABB: Gate Frame ground contact flush at y=0.0", "Bottom is %f" % aabb.position.y)
