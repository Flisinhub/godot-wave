extends SceneTree

## Empirical Adversarial Challenger: Swarm Edge Cases & Collision Stress
## Specifically targets:
## 1. Boundary tunneling under high velocity and repulsive forces.
## 2. Complete unit overlap / coordinate collapse in dense clusters.
## 3. Impassable obstacle penetration / tunneling.
## 4. Corner trapping and numerical stability (no NaN / Inf).

const SwarmSimulationScript = preload("res://core/swarm/swarm_simulation.gd")
const SwarmDataScript = preload("res://core/swarm/swarm_data.gd")
const SwarmUnitArchetypeScript = preload("res://data/swarm/swarm_unit_archetype.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []

func _init() -> void:
	print("\n================================================================================")
	print(">>> EMPIRICAL CHALLENGER ITERATION 5: BOUNDARY & CLUSTER STRESS HARNESS <<<")
	print("================================================================================")
	
	test_1_boundary_clamping_and_tunneling_prevention()
	test_2_co_located_spawn_dispersion_and_overlap_prevention()
	test_3_dense_cluster_bottleneck_collapse_prevention()
	test_4_impassable_obstacle_tunneling_prevention()
	test_5_corner_trap_extreme_pressure_stress()
	
	print("\n================================================================================")
	print("ADVERSARIAL STRESS SUMMARY:")
	print("Total Tests:  %d" % total_tests)
	print("Passed:       %d" % passed_tests)
	print("Failed:       %d" % failed_tests)
	
	if failed_tests > 0:
		print("\u001b[31m[VERDICT: REQUEST_CHANGES] ADVERSARIAL FLAWS DETECTED:\u001b[0m")
		for f in failures:
			print("  - %s" % f)
		print("================================================================================")
		quit(1)
	else:
		print("\u001b[32m[VERDICT: APPROVE] ALL ADVERSARIAL STRESS INVARIANTS SATISFIED!\u001b[0m")
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
# Test 1: Boundary Clamping & Tunneling Prevention
# ------------------------------------------------------------------------------
func test_1_boundary_clamping_and_tunneling_prevention() -> void:
	print("\n--- Test 1: Boundary Clamping & Tunneling Prevention ---")
	var min_b := Vector2(-20.0, -20.0)
	var max_b := Vector2(20.0, 20.0)
	var sim := _setup_sim(min_b, max_b, 512)
	
	# Spawn units right near the 4 boundaries and corners with velocities directed outwards
	var margin_x := max_b.x - 0.5
	var margin_z := max_b.y - 0.5
	var min_margin_x := min_b.x + 0.5
	var min_margin_z := min_b.y + 0.5
	
	# Direct outward goals
	sim.register_goal(Vector3(100.0, 0.0, 100.0))
	
	# Spawn 200 units on outer perimeter
	for i in range(50):
		sim.spawn_unit(0, Vector3(randf_range(min_b.x, max_b.x), 0.0, max_b.y - 0.6), 50.0, 25.0) # High speed North
		sim.spawn_unit(1, Vector3(randf_range(min_b.x, max_b.x), 0.0, min_b.y + 0.6), 50.0, 25.0) # South
		sim.spawn_unit(2, Vector3(max_b.x - 0.6, 0.0, randf_range(min_b.y, max_b.y)), 50.0, 25.0) # East
		sim.spawn_unit(3, Vector3(min_b.x + 0.6, 0.0, randf_range(min_b.y, max_b.y)), 50.0, 25.0) # West
	
	var tunneled := false
	var out_of_bounds_count := 0
	for step in range(120):
		sim.simulate_step(1.0 / 60.0)
		for u in range(sim.get_active_unit_count()):
			var p := sim.get_unit_position_3d(u)
			if p.x < (min_b.x + 0.49) or p.x > (max_b.x - 0.49) or p.z < (min_b.y + 0.49) or p.z > (max_b.y - 0.49):
				tunneled = true
				out_of_bounds_count += 1
				break
		if tunneled:
			break
	
	_assert(not tunneled, "Boundary Clamping Invariant", "Units tunneled outside bounds! Out of bounds detections: %d" % out_of_bounds_count)
	sim.queue_free()


# ------------------------------------------------------------------------------
# Test 2: Co-located Spawn Dispersion & Overlap Prevention
# ------------------------------------------------------------------------------
func test_2_co_located_spawn_dispersion_and_overlap_prevention() -> void:
	print("\n--- Test 2: Co-located Spawn Dispersion & Overlap Prevention ---")
	var sim := _setup_sim(Vector2(-20.0, -20.0), Vector2(20.0, 20.0), 256)
	
	# Test 2A: 4 units spawned at exact same point (0.0, 0.0)
	var spawned_4: Array[int] = []
	for i in range(4):
		var idx := sim.spawn_unit(i % 4, Vector3(0.0, 0.0, 0.0), 50.0, 6.0)
		if idx >= 0:
			spawned_4.append(idx)
	
	sim.simulate_step(1.0 / 60.0)
	var identical_4: int = 0
	for i in range(spawned_4.size()):
		var p1 := sim.get_unit_position_3d(spawned_4[i])
		for j in range(i + 1, spawned_4.size()):
			var p2 := sim.get_unit_position_3d(spawned_4[j])
			if p1.distance_to(p2) < 0.0001:
				identical_4 += 1
	
	_assert(identical_4 == 0, "4 Co-located Units 1-Frame Dispersal: zero pairs remain co-located", "Pairs still identical: %d" % identical_4)
	
	for s in range(30):
		sim.simulate_step(1.0 / 60.0)
	
	var min_pair_dist_4: float = 999.0
	for i in range(spawned_4.size()):
		var p1 := sim.get_unit_position_3d(spawned_4[i])
		for j in range(i + 1, spawned_4.size()):
			var p2 := sim.get_unit_position_3d(spawned_4[j])
			var d := p1.distance_to(p2)
			if d < min_pair_dist_4:
				min_pair_dist_4 = d
	
	_assert(min_pair_dist_4 > 0.1, "4 Co-located Units 30-Frame Dispersion: min distance > 0.1m", "Min distance was %.4f m" % min_pair_dist_4)
	sim.queue_free()


# ------------------------------------------------------------------------------
# Test 3: Dense Cluster Bottleneck Collapse Prevention
# ------------------------------------------------------------------------------
func test_3_dense_cluster_bottleneck_collapse_prevention() -> void:
	print("\n--- Test 3: Dense Cluster Bottleneck Collapse Prevention ---")
	var sim := _setup_sim(Vector2(-25.0, -25.0), Vector2(25.0, 25.0), 512)
	
	# Register central goal
	sim.register_goal(Vector3(0.0, 0.0, 0.0))
	
	# Spawn 150 units in a dense disk of radius 1.5m around the goal
	for i in range(150):
		var ang := randf() * TAU
		var rad := sqrt(randf()) * 1.5
		sim.spawn_unit(i % 4, Vector3(cos(ang) * rad, 0.0, sin(ang) * rad), 50.0, 7.0)
	
	# Run 80 frames: under inward flow towards (0, 0), separation must prevent collapse
	var zero_overlap_failures: int = 0
	var min_dist_observed: float = 999.0
	
	for step in range(80):
		sim.simulate_step(1.0 / 60.0)
		
		# Sample every 10 frames
		if step % 10 == 0:
			var act := sim.get_active_unit_count()
			for i in range(min(50, act)):
				var p1 := sim.get_unit_position_3d(i)
				for j in range(i + 1, min(50, act)):
					var p2 := sim.get_unit_position_3d(j)
					var d := p1.distance_to(p2)
					if d < min_dist_observed:
						min_dist_observed = d
					if d < 0.005:
						zero_overlap_failures += 1
	
	_assert(zero_overlap_failures == 0, "Bottleneck Convergence: No complete unit overlap (dist < 0.005m)", "Overlap failures: %d, min dist: %.5f" % [zero_overlap_failures, min_dist_observed])
	_assert(min_dist_observed > 0.01, "Bottleneck Minimum Separation Invariant (min dist > 0.01m)", "Observed min dist: %.4f m" % min_dist_observed)
	sim.queue_free()


# ------------------------------------------------------------------------------
# Test 4: Impassable Obstacle Tunneling Prevention
# ------------------------------------------------------------------------------
func test_4_impassable_obstacle_tunneling_prevention() -> void:
	print("\n--- Test 4: Impassable Obstacle Tunneling Prevention ---")
	var sim := _setup_sim(Vector2(-30.0, -30.0), Vector2(30.0, 30.0), 512)
	
	# Create impassable obstacle wall from X=[-5, 5], Z=[-1, 1]
	sim.register_obstacle_aabb("test_wall", Vector3(-5.0, 0.0, -1.0), Vector3(5.0, 0.0, 1.0), true, 255)
	
	# Goal behind the wall: (0, 0, 10)
	sim.register_goal(Vector3(0.0, 0.0, 10.0))
	
	# Spawn a column of 20 units stacked tightly in Z directly facing the wall at X=0
	# Wall starts at Z = -1.0. Place units at Z = -1.2, -1.3, -1.4, ...
	var spawned: Array[int] = []
	for i in range(20):
		var p := Vector3(0.0, 0.0, -1.1 - float(i) * 0.15)
		var idx := sim.spawn_unit(0, p, 50.0, 10.0)
		if idx >= 0:
			spawned.append(idx)
	
	var penetrated_count: int = 0
	var deepest_penetration_z: float = -999.0
	for step in range(200):
		sim.simulate_step(1.0 / 60.0)
		for idx in spawned:
			var pos := sim.get_unit_position_3d(idx)
			# Wall interior: x in [-4.5, 4.5] and z in [-0.9, 0.9]
			if pos.x >= -4.5 and pos.x <= 4.5 and pos.z >= -0.9 and pos.z <= 0.9:
				penetrated_count += 1
				if pos.z > deepest_penetration_z:
					deepest_penetration_z = pos.z
	
	if penetrated_count > 0:
		print("    -> Obstacle penetration confirmed! Penetration events: %d, deepest Z in wall: %.4f" % [penetrated_count, deepest_penetration_z])
	
	_assert(penetrated_count == 0, "Impassable Obstacle Tunneling Prevention", "Units penetrated into wall obstacle interior! Deepest Z=%.4f" % deepest_penetration_z)
	sim.queue_free()


# ------------------------------------------------------------------------------
# Test 5: Corner Trap & Numerical Stability Stress
# ------------------------------------------------------------------------------
func test_5_corner_trap_extreme_pressure_stress() -> void:
	print("\n--- Test 5: Corner Trap & Numerical Stability Stress ---")
	var min_b := Vector2(-20.0, -20.0)
	var max_b := Vector2(20.0, 20.0)
	var sim := _setup_sim(min_b, max_b, 512)
	
	# Goal deep in the corner: (-25, -25)
	sim.register_goal(Vector3(-25.0, 0.0, -25.0))
	
	# Spawn 100 units cramped into a 2x2 area right at corner (-19.0, -19.0)
	for i in range(100):
		var p := Vector3(randf_range(-19.3, -17.5), 0.0, randf_range(-19.3, -17.5))
		sim.spawn_unit(i % 4, p, 50.0, 12.0)
	
	var nan_detected: bool = false
	var corner_tunneled: bool = false
	
	for step in range(100):
		sim.simulate_step(1.0 / 60.0)
		for u in range(sim.get_active_unit_count()):
			var p := sim.get_unit_position_3d(u)
			var h := sim.get_unit_heading(u)
			if is_nan(p.x) or is_nan(p.z) or is_inf(p.x) or is_inf(p.z) or is_nan(h) or is_inf(h):
				nan_detected = true
				break
			if p.x < (min_b.x + 0.49) or p.z < (min_b.y + 0.49):
				corner_tunneled = true
				break
		if nan_detected or corner_tunneled:
			break
	
	_assert(not nan_detected, "Corner Trap Numerical Stability: zero NaN/Inf", "NaN or Inf detected in corner compression!")
	_assert(not corner_tunneled, "Corner Trap Boundary Clamping: no tunneling out of corner", "Units escaped through corner boundary!")
	sim.queue_free()

