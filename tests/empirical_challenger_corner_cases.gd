extends SceneTree

## Empirical Adversarial Challenger: Swarm Corner Cases Verification
## Specifically stress-tests:
## 1. Multi-goal divergence: Boids bifurcating between 2 distant attractors.
## 2. Dead-end traps: U-shaped obstacle pocket navigation and tunneling resistance.
## 3. Bottleneck congestion: High-density flow through a 2m choke point.

const SwarmSimulationScript = preload("res://core/swarm/swarm_simulation.gd")
const SwarmUnitArchetypeScript = preload("res://data/swarm/swarm_unit_archetype.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _init() -> void:
	print("\n================================================================================")
	print(">>> EMPIRICAL CHALLENGER: CORNER CASE BOIDS BEHAVIOR SUITE <<<")
	print("================================================================================")
	
	test_corner_1_multigoal_divergence()
	test_corner_2_dead_end_u_trap()
	test_corner_3_bottleneck_choke_congestion()
	
	print("\n================================================================================")
	print("CORNER CASE STRESS SUMMARY:")
	print("Total Tests:  %d" % total_tests)
	print("Passed:       %d" % passed_tests)
	print("Failed:       %d" % failed_tests)
	
	if failed_tests > 0:
		print("\u001b[31m[VERDICT: REQUEST_CHANGES] CORNER CASE DEFECTS DETECTED:\u001b[0m")
		for f in failures:
			print("  - %s" % f)
		print("================================================================================")
		quit(1)
	else:
		print("\u001b[32m[VERDICT: APPROVE] ALL CORNER CASE INVARIANTS SATISFIED!\u001b[0m")
		print("================================================================================")
		quit(0)


func _assert(cond: bool, test_name: String, error_msg: String) -> bool:
	total_tests += 1
	if cond:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
		return true
	else:
		failed_tests += 1
		var err := "%s: %s" % [test_name, error_msg]
		failures.append(err)
		print("  [FAIL] %s" % err)
		return false


func _setup_sim(min_b: Vector2 = Vector2(-32.0, -32.0), max_b: Vector2 = Vector2(32.0, 32.0), cap: int = 1024) -> SwarmSimulation:
	var sim = SwarmSimulationScript.new()
	sim.setup_simulation(min_b, max_b, cap)
	root.add_child(sim)
	sim._ready()
	if sim.renderer:
		sim.renderer._ready()
	
	var archetypes_to_load := [
		"res://data/swarm/zergling_archetype.tres",
		"res://data/swarm/roach_archetype.tres",
		"res://data/swarm/baneling_archetype.tres",
		"res://data/swarm/hydralisk_archetype.tres"
	]
	for p in archetypes_to_load:
		if ResourceLoader.exists(p):
			var a = load(p) as SwarmUnitArchetype
			if a and not sim.archetype_defs.has(a.archetype_id):
				sim.register_archetype(a)
	return sim


# ------------------------------------------------------------------------------
# Corner 1: Multi-Goal Divergence
# ------------------------------------------------------------------------------
func test_corner_1_multigoal_divergence() -> void:
	print("\n--- Corner 1: Multi-Goal Divergence & Bifurcation ---")
	var sim := _setup_sim(Vector2(-35.0, -35.0), Vector2(35.0, 35.0), 512)
	
	var goal_a := Vector3(-25.0, 0.0, 0.0)
	var goal_b := Vector3(25.0, 0.0, 0.0)
	sim.register_goal(goal_a)
	sim.register_goal(goal_b)
	
	# Spawn 60 units on left (should go to A), 60 on right (should go to B), 40 in middle
	var left_units: Array[int] = []
	var right_units: Array[int] = []
	var mid_units: Array[int] = []
	
	for i in range(60):
		var p_left := Vector3(randf_range(-18.0, -8.0), 0.0, randf_range(-4.0, 4.0))
		var idx_l := sim.spawn_unit(0, p_left)
		if idx_l >= 0: left_units.append(idx_l)
		
		var p_right := Vector3(randf_range(8.0, 18.0), 0.0, randf_range(-4.0, 4.0))
		var idx_r := sim.spawn_unit(1, p_right)
		if idx_r >= 0: right_units.append(idx_r)
		
	for i in range(40):
		var p_mid := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-3.0, 3.0))
		var idx_m := sim.spawn_unit(2, p_mid)
		if idx_m >= 0: mid_units.append(idx_m)
	
	var initial_dist_a := 0.0
	for idx in left_units:
		initial_dist_a += sim.get_unit_position_3d(idx).distance_to(goal_a)
	initial_dist_a /= float(left_units.size())
	
	var initial_dist_b := 0.0
	for idx in right_units:
		initial_dist_b += sim.get_unit_position_3d(idx).distance_to(goal_b)
	initial_dist_b /= float(right_units.size())
	
	var nan_detected := false
	for step in range(120):
		sim.simulate_step(1.0 / 60.0)
		for u in range(sim.get_active_unit_count()):
			var p := sim.get_unit_position_3d(u)
			if is_nan(p.x) or is_nan(p.z) or is_inf(p.x) or is_inf(p.z):
				nan_detected = true
				break
		if nan_detected:
			break
	
	var final_dist_a := 0.0
	for idx in left_units:
		final_dist_a += sim.get_unit_position_3d(idx).distance_to(goal_a)
	final_dist_a /= float(left_units.size())
	
	var final_dist_b := 0.0
	for idx in right_units:
		final_dist_b += sim.get_unit_position_3d(idx).distance_to(goal_b)
	final_dist_b /= float(right_units.size())
	
	# Middle units must diverge to either A or B, not freeze at center
	var mid_moved_count := 0
	for idx in mid_units:
		var p := sim.get_unit_position_3d(idx)
		if absf(p.x) > 3.0:
			mid_moved_count += 1
	
	print("  -> Initial Left Dist to A: %.2fm -> Final: %.2fm" % [initial_dist_a, final_dist_a])
	print("  -> Initial Right Dist to B: %.2fm -> Final: %.2fm" % [initial_dist_b, final_dist_b])
	print("  -> Mid units diverged away from ridge (|x| > 3m): %d / %d" % [mid_moved_count, mid_units.size()])
	
	_assert(not nan_detected, "Multi-goal Divergence: Numerical stability (zero NaN/Inf)", "NaN or Inf detected during multi-goal flow!")
	_assert(final_dist_a < initial_dist_a - 4.0, "Multi-goal Divergence: Left wing converged to Goal A", "Left units failed to converge to Goal A")
	_assert(final_dist_b < initial_dist_b - 4.0, "Multi-goal Divergence: Right wing converged to Goal B", "Right units failed to converge to Goal B")
	_assert(mid_moved_count >= 30, "Multi-goal Divergence: Saddle point boids resolved and broke symmetry", "Mid units stuck at saddle point: %d / %d" % [mid_moved_count, mid_units.size()])
	sim.queue_free()


# ------------------------------------------------------------------------------
# Corner 2: Dead-End U-Trap
# ------------------------------------------------------------------------------
func test_corner_2_dead_end_u_trap() -> void:
	print("\n--- Corner 2: Dead-End U-Trap Navigation & Tunneling Resistance ---")
	var sim := _setup_sim(Vector2(-30.0, -30.0), Vector2(30.0, 30.0), 512)
	
	# Register U-trap obstacles:
	# Left wall: X in [-5.0, -4.0], Z in [0.0, 10.0]
	# Back wall: X in [-5.0, 5.0], Z in [9.0, 10.5]
	# Right wall: X in [4.0, 5.0], Z in [0.0, 10.0]
	sim.register_obstacle_aabb("u_wall_l", Vector3(-5.0, 0.0, 0.0), Vector3(-4.0, 0.0, 10.0), true, 255)
	sim.register_obstacle_aabb("u_wall_b", Vector3(-5.0, 0.0, 9.0), Vector3(5.0, 0.0, 10.5), true, 255)
	sim.register_obstacle_aabb("u_wall_r", Vector3(4.0, 0.0, 0.0), Vector3(5.0, 0.0, 10.0), true, 255)
	
	# Goal is placed on the other side of the back wall: (0, 0, 18)
	var goal := Vector3(0.0, 0.0, 18.0)
	sim.register_goal(goal)
	
	# Spawn 60 units directly inside the pocket mouth at Z=2 to Z=7
	var spawned: Array[int] = []
	for i in range(60):
		var p := Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(2.0, 7.0))
		var idx := sim.spawn_unit(i % 4, p, 50.0, 8.0)
		if idx >= 0:
			spawned.append(idx)
	
	var wall_penetrations := 0
	var escaped_count := 0
	
	for step in range(300):
		sim.simulate_step(1.0 / 60.0)
		for idx in spawned:
			var p := sim.get_unit_position_3d(idx)
			# Check penetrations into Left wall interior
			if p.x >= -4.8 and p.x <= -4.2 and p.z >= 0.2 and p.z <= 9.8:
				wall_penetrations += 1
			# Back wall interior
			elif p.x >= -4.8 and p.x <= 4.8 and p.z >= 9.2 and p.z <= 10.3:
				wall_penetrations += 1
			# Right wall interior
			elif p.x >= 4.2 and p.x <= 4.8 and p.z >= 0.2 and p.z <= 9.8:
				wall_penetrations += 1
	
	for idx in spawned:
		var p := sim.get_unit_position_3d(idx)
		if p.z >= 11.0: # Reached behind the U-pocket
			escaped_count += 1
	
	print("  -> Wall Penetration Events: %d" % wall_penetrations)
	print("  -> Boids Navigated Out of U-Pocket and Reached Goal Side: %d / %d" % [escaped_count, spawned.size()])
	
	_assert(wall_penetrations == 0, "Dead-End U-Trap: Zero wall penetrations under dead-end pressure", "Wall penetrations observed: %d" % wall_penetrations)
	_assert(escaped_count > 0, "Dead-End U-Trap: Dijkstra flow field guided boids out of dead-end trap", "Zero boids escaped the dead-end trap!")
	sim.queue_free()


# ------------------------------------------------------------------------------
# Corner 3: Bottleneck Choke Congestion
# ------------------------------------------------------------------------------
func test_corner_3_bottleneck_choke_congestion() -> void:
	print("\n--- Corner 3: Bottleneck Choke Congestion & Flow Invariants ---")
	var sim := _setup_sim(Vector2(-30.0, -30.0), Vector2(30.0, 30.0), 512)
	
	# Bottleneck: 2m choke at X in [-1.0, 1.0], Z in [-0.5, 0.5]
	# Left wall: X in [-25.0, -1.0], Z in [-0.5, 0.5]
	# Right wall: X in [1.0, 25.0], Z in [-0.5, 0.5]
	sim.register_obstacle_aabb("choke_wall_l", Vector3(-25.0, 0.0, -0.5), Vector3(-1.0, 0.0, 0.5), true, 255)
	sim.register_obstacle_aabb("choke_wall_r", Vector3(1.0, 0.0, -0.5), Vector3(25.0, 0.0, 0.5), true, 255)
	
	# Goal on far side: (0, 0, 15)
	sim.register_goal(Vector3(0.0, 0.0, 15.0))
	
	# Spawn 200 units approaching choke from incoming side: Z in [-12.0, -3.0], X in [-8.0, 8.0]
	var spawned: Array[int] = []
	for i in range(200):
		var p := Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-12.0, -3.0))
		var idx := sim.spawn_unit(i % 4, p, 50.0, 7.5)
		if idx >= 0:
			spawned.append(idx)
	
	var choke_penetrations := 0
	var min_dist_observed := 999.0
	var zero_overlap_count := 0
	
	for step in range(250):
		sim.simulate_step(1.0 / 60.0)
		
		# Check wall penetrations
		for idx in spawned:
			var p := sim.get_unit_position_3d(idx)
			if (p.x <= -1.2 and p.x >= -24.8 and p.z >= -0.4 and p.z <= 0.4) or \
			   (p.x >= 1.2 and p.x <= 24.8 and p.z >= -0.4 and p.z <= 0.4):
				choke_penetrations += 1
		
		# Sample pair distances at choke area (Z in [-2.0, 2.0]) every 10 frames
		if step % 10 == 0:
			var near_choke: Array[Vector3] = []
			for idx in spawned:
				var p := sim.get_unit_position_3d(idx)
				if absf(p.z) <= 2.5:
					near_choke.append(p)
			
			for i in range(near_choke.size()):
				for j in range(i + 1, near_choke.size()):
					var d := near_choke[i].distance_to(near_choke[j])
					if d < min_dist_observed:
						min_dist_observed = d
					if d < 0.005:
						zero_overlap_count += 1
	
	var crossed_choke := 0
	for idx in spawned:
		var p := sim.get_unit_position_3d(idx)
		if p.z > 1.0:
			crossed_choke += 1
	
	print("  -> Choke Penetrations: %d" % choke_penetrations)
	print("  -> Bottleneck Minimum Observed Distance: %.4fm" % min_dist_observed)
	print("  -> Zero-Overlap Failures (< 0.005m): %d" % zero_overlap_count)
	print("  -> Units Successfully Funneled Through Choke (Z > 1.0): %d / %d" % [crossed_choke, spawned.size()])
	
	_assert(choke_penetrations == 0, "Bottleneck Choke: Zero penetrations into choke barricade walls", "Penetrations observed: %d" % choke_penetrations)
	_assert(zero_overlap_count == 0, "Bottleneck Choke: No coordinate collapse (<0.005m) in bottleneck crowd", "Collapse detected: %d" % zero_overlap_count)
	_assert(min_dist_observed > 0.01, "Bottleneck Choke: Minimum unit separation maintained (>0.01m)", "Min distance was %.4fm" % min_dist_observed)
	_assert(crossed_choke > 50, "Bottleneck Choke: Effective throughput funneled through 2m gap (>50 units)", "Insufficient throughput: %d" % crossed_choke)
	sim.queue_free()
