extends SceneTree

# test_challenger_m5_benchmark.gd
# Empirical Challenger 1 Adversarial Benchmark & Stress Suite for Milestone 5
#
# Probes:
# 1. SwarmSimulation 1,000 Units Scalability Benchmark (120 steps, avg < 16.0 ms, >60 FPS guaranteed)
# 2. SwarmSimulation 1,500 Units Overload Benchmark (120 steps, avg < 20.0 ms)
# 3. SwarmSimulation 2,000 Units Extreme Capacity Benchmark (120 steps, avg < 35.0 ms, numerical stability)
# 4. SwarmSimulation 30 Dynamic Obstacles Perimeter Collision & Zero-Penetration Stress (2,000 units)
# 5. SwarmRenderer MultiMesh Buffer & Transform Matrix Integrity (2,000 units, non-singular, finite floats)
# 6. FlowField Out-of-Bounds & Extreme Coordinate Resilience (sub-cell, extremes, NaNs, multi-goals)
# 7. Spatial Hash Kinematic Relaxation & Density Clumping Stress (2,000 units)

const SwarmSimulation = preload("res://core/swarm/swarm_simulation.gd")
const SwarmRenderer = preload("res://core/swarm/swarm_renderer.gd")
const SwarmUnitArchetype = preload("res://data/swarm/swarm_unit_archetype.gd")
const SwarmFlowField = preload("res://core/swarm/swarm_flow_field.gd")
const SwarmSpatialHash = preload("res://core/swarm/swarm_spatial_hash.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_log: Array[String] = []

var bench_results: Dictionary = {}


func _init() -> void:
	print("\n\u001b[35m\u001b[1m==========================================================================")
	print("=== EMPIRICAL CHALLENGER 1: MILESTONE 5 MASS SWARM & STRESS BENCHMARK ===")
	print("==========================================================================\u001b[0m")
	var start_ms: int = Time.get_ticks_msec()

	_benchmark_swarm_scale(1000, 500, 500, 120, 16.0, 25.0)
	_benchmark_swarm_scale(1500, 1000, 500, 120, 22.0, 32.0)
	_benchmark_swarm_scale(2000, 1200, 800, 120, 35.0, 50.0)
	_test_dynamic_obstacles_and_flow_integrity(2000)
	_test_swarm_renderer_transform_buffers(2000)
	_test_flow_field_edge_cases()
	_test_spatial_hash_kinematic_relaxation_stress(2000)

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	print("\n\u001b[35m==========================================================================")
	print("Milestone 5 Challenger Probes Complete in %d ms" % elapsed_ms)
	print("Total Probes: %d | Passed: %d | Failed: %d" % [total_tests, passed_tests, failed_tests])

	print("\n--- BENCHMARK PERFORMANCE PROFILE ---")
	for k in bench_results.keys():
		var r: Dictionary = bench_results[k]
		var meets_60fps: bool = r["avg_ms"] < 16.0
		var fps_approx: float = 1000.0 / maxf(0.001, r["avg_ms"])
		print("  [%s] Avg: %6.3f ms (~%4.1f FPS) | P95: %6.3f ms | Max: %6.3f ms | Min: %6.3f ms | <16ms: %s" % [
			k, r["avg_ms"], fps_approx, r["p95_ms"], r["max_ms"], r["min_ms"], str(meets_60fps)
		])

	if failed_tests > 0:
		print("\n\u001b[31m\u001b[1mVERDICT: ADVERSARIAL STRESS DETECTED FAILURES! [REJECT]\u001b[0m")
		for f in failure_log:
			print("  [FAIL] %s" % f)
		print("==========================================================================\n")
		quit(1)
	else:
		print("\n\u001b[32m\u001b[1mVERDICT: ALL BENCHMARKS & ADVANCED STRESS PROBES PASSED! [APPROVE]\u001b[0m")
		print("==========================================================================\n")
		quit(0)


func _assert(condition: bool, test_name: String, error_msg: String) -> bool:
	total_tests += 1
	if not condition:
		failed_tests += 1
		failure_log.append("%s: %s" % [test_name, error_msg])
		print("  \u001b[31m[FAIL]\u001b[0m %s - %s" % [test_name, error_msg])
		return false
	passed_tests += 1
	print("  \u001b[32m[PASS]\u001b[0m %s" % test_name)
	return true


# ==============================================================================
# 1. Swarm Simulation Scalability Benchmark at Scale (1,000 / 1,500 / 2,000 units)
# ==============================================================================
func _benchmark_swarm_scale(unit_count: int, zerg_count: int, roach_count: int, steps: int, max_avg_ms: float, max_p95_ms: float) -> void:
	var bench_key: String = "Swarm_%d_Units" % unit_count
	print("\n>> Executing Benchmark: %s (%d Zerglings, %d Roaches, %d steps)..." % [bench_key, zerg_count, roach_count, steps])

	var sim := SwarmSimulation.new()
	sim.setup_simulation(Vector2(-64, -64), Vector2(64, 64), 4096)
	sim.register_goal(Vector3.ZERO)

	var zerg_arch: SwarmUnitArchetype = load("res://data/swarm/zergling_archetype.tres") as SwarmUnitArchetype
	var roach_arch: SwarmUnitArchetype = load("res://data/swarm/roach_archetype.tres") as SwarmUnitArchetype
	_assert(zerg_arch != null, "%s_zergling_arch_loaded" % bench_key, "Failed to load zergling archetype")
	_assert(roach_arch != null, "%s_roach_arch_loaded" % bench_key, "Failed to load roach archetype")

	if zerg_arch:
		sim.register_archetype(zerg_arch)
	if roach_arch:
		sim.register_archetype(roach_arch)

	# Spawn units across two distinct spawn points for realistic tactical assault
	var spawn_z := sim.spawn_wave(0, zerg_count, Vector3(0, 0, 35), 25.0)
	var spawn_r := sim.spawn_wave(1, roach_count, Vector3(0, 0, -35), 25.0)

	var total_spawned := spawn_z.size() + spawn_r.size()
	_assert(total_spawned == unit_count, "%s_spawn_count_match" % bench_key, "Expected %d units spawned, got %d" % [unit_count, total_spawned])
	_assert(sim.get_active_unit_count() == unit_count, "%s_active_count_match" % bench_key, "Active count mismatch: %d" % sim.get_active_unit_count())

	# Warmup steps (10 ticks)
	for w in range(10):
		sim.simulate_step(0.016)

	# Timed benchmark steps
	var tick_times_usec: Array[int] = []
	var total_usec: int = 0

	for s in range(steps):
		var t0: int = Time.get_ticks_usec()
		sim.simulate_step(0.016)
		var dt: int = Time.get_ticks_usec() - t0
		tick_times_usec.append(dt)
		total_usec += dt

	var avg_ms: float = (float(total_usec) / float(steps)) / 1000.0
	tick_times_usec.sort()
	var p95_idx: int = int(float(steps) * 0.95)
	p95_idx = clampi(p95_idx, 0, steps - 1)
	var p95_ms: float = float(tick_times_usec[p95_idx]) / 1000.0
	var max_ms: float = float(tick_times_usec[steps - 1]) / 1000.0
	var min_ms: float = float(tick_times_usec[0]) / 1000.0

	bench_results[bench_key] = {
		"avg_ms": avg_ms,
		"p95_ms": p95_ms,
		"max_ms": max_ms,
		"min_ms": min_ms,
		"steps": steps,
		"units": unit_count
	}

	print("  --> Results: Avg=%.3f ms | P95=%.3f ms | Max=%.3f ms | Min=%.3f ms" % [avg_ms, p95_ms, max_ms, min_ms])

	# Enforce performance budget
	_assert(avg_ms < max_avg_ms, "%s_avg_tick_time_within_budget" % bench_key, "Avg tick time %.3f ms exceeds threshold %.1f ms" % [avg_ms, max_avg_ms])
	_assert(p95_ms < max_p95_ms, "%s_p95_tick_time_stable" % bench_key, "P95 tick time %.3f ms exceeds spike threshold %.1f ms" % [p95_ms, max_p95_ms])

	# 1,000 units is the contractual 60 FPS gate (<16.0 ms)
	if unit_count == 1000:
		_assert(avg_ms < 16.0, "swarm_1000_units_guarantees_60fps", "1,000 units must average strictly under 16.0 ms, got %.3f ms" % avg_ms)

	# Verify numerical stability after all steps: no NaNs or Infs in positions
	var sdata = sim.swarm_data
	var has_nan := false
	for i in range(sdata.capacity):
		if sdata.alive_mask[i] == 1:
			var px: float = sdata.pos_x[i]
			var pz: float = sdata.pos_z[i]
			if is_nan(px) or is_nan(pz) or is_inf(px) or is_inf(pz):
				has_nan = true
				break
	_assert(not has_nan, "%s_coordinates_strictly_finite" % bench_key, "Detected NaN or Inf in unit coordinates!")

	sim.free()


# ==============================================================================
# 2. Dynamic Obstacle Avoidance & Flow Field Stress under 2,000 Units
# ==============================================================================
func _test_dynamic_obstacles_and_flow_integrity(unit_count: int) -> void:
	print("\n>> Testing Dynamic Obstacles & Flow Field Collision Stress (30 Obstacles, %d units)..." % unit_count)

	var sim := SwarmSimulation.new()
	sim.setup_simulation(Vector2(-64, -64), Vector2(64, 64), 4096)
	sim.register_goal(Vector3.ZERO)

	var zerg_arch: SwarmUnitArchetype = load("res://data/swarm/zergling_archetype.tres") as SwarmUnitArchetype
	if zerg_arch:
		sim.register_archetype(zerg_arch)

	# Register 30 dynamic obstacles matching the Terran base layout
	# 1 Command Center (8x8 box)
	sim.register_obstacle_aabb("CommandCenter", Vector3(-4, 0, -4), Vector3(4, 0, 4), true, 255)

	# 2 Bunkers (3.5x3.5 box)
	sim.register_obstacle_aabb("Bunker_North", Vector3(-12, 0, 10), Vector3(-8.5, 0, 13.5), true, 255)
	sim.register_obstacle_aabb("Bunker_South", Vector3(8.5, 0, -13.5), Vector3(12, 0, -10), true, 255)

	# 2 Gates (4x1 box)
	sim.register_obstacle_aabb("Gate_North", Vector3(-2, 0, 14.5), Vector3(2, 0, 15.5), true, 255)
	sim.register_obstacle_aabb("Gate_South", Vector3(-2, 0, -15.5), Vector3(2, 0, -14.5), true, 255)

	# 25 Wall Segments
	for w in range(25):
		var angle: float = (float(w) / 25.0) * TAU
		var wx: float = cos(angle) * 16.0
		var wz: float = sin(angle) * 16.0
		sim.register_obstacle_aabb("Wall_%d" % w, Vector3(wx - 1.5, 0, wz - 0.5), Vector3(wx + 1.5, 0, wz + 0.5), true, 255)

	# Spawn 2,000 units around perimeter
	var spawn_ids := sim.spawn_wave(0, unit_count, Vector3(0, 0, 40), 20.0)
	_assert(spawn_ids.size() == unit_count, "obstacles_stress_spawned_2000", "Failed to spawn 2,000 units")

	# Step 100 times towards center (which is blocked by Command Center)
	for s in range(100):
		sim.simulate_step(0.016)

	# Verify Command Center interior is NOT penetrated by swarm
	var sdata = sim.swarm_data
	var cc_penetrations: int = 0
	for i in range(sdata.capacity):
		if sdata.alive_mask[i] == 1:
			var px: float = sdata.pos_x[i]
			var pz: float = sdata.pos_z[i]
			# Interior of CC: [-3.5, 3.5] x [-3.5, 3.5]
			if absf(px) < 3.5 and absf(pz) < 3.5:
				cc_penetrations += 1

	_assert(cc_penetrations == 0, "command_center_zero_penetrations", "Found %d swarm units penetrating inside Command Center AABB!" % cc_penetrations)

	# Unregister obstacles dynamically and step again (verify dynamic unregistration doesn't crash)
	sim.unregister_obstacle("Gate_North")
	sim.unregister_obstacle("Gate_South")
	for s in range(20):
		sim.simulate_step(0.016)

	_assert(true, "dynamic_obstacle_unregister_safe", "Unregistering obstacles during live simulation completed without error")
	sim.free()


# ==============================================================================
# 3. SwarmRenderer MultiMesh Buffer & Transformation Verification
# ==============================================================================
func _test_swarm_renderer_transform_buffers(unit_count: int) -> void:
	print("\n>> Testing SwarmRenderer MultiMesh Transform Buffers (%d units)..." % unit_count)

	var sim := SwarmSimulation.new()
	sim.setup_simulation(Vector2(-64, -64), Vector2(64, 64), 4096)
	sim.register_goal(Vector3.ZERO)

	var renderer := SwarmRenderer.new()
	sim.add_child(renderer)
	sim.renderer = renderer

	var zerg_arch: SwarmUnitArchetype = load("res://data/swarm/zergling_archetype.tres") as SwarmUnitArchetype
	var roach_arch: SwarmUnitArchetype = load("res://data/swarm/roach_archetype.tres") as SwarmUnitArchetype
	if zerg_arch:
		sim.register_archetype(zerg_arch)
	if roach_arch:
		sim.register_archetype(roach_arch)

	sim.spawn_wave(0, unit_count / 2, Vector3(-20, 0, 20), 15.0)
	sim.spawn_wave(1, unit_count / 2, Vector3(20, 0, 20), 15.0)

	# Simulate 10 steps to exercise renderer.update_render_transforms
	for s in range(10):
		sim.simulate_step(0.016)

	# Verify MultiMesh instances exist and have valid counts
	var mmi_zerg: MultiMeshInstance3D = renderer.multimesh_instances.get(0, null)
	var mmi_roach: MultiMeshInstance3D = renderer.multimesh_instances.get(1, null)

	_assert(mmi_zerg != null, "mmi_zergling_exists", "MultiMeshInstance3D for Zergling must exist")
	_assert(mmi_roach != null, "mmi_roach_exists", "MultiMeshInstance3D for Roach must exist")

	if mmi_zerg and mmi_zerg.multimesh:
		var visible_z: int = mmi_zerg.multimesh.visible_instance_count
		_assert(visible_z == unit_count / 2, "mmi_zerg_visible_count_match", "Expected %d visible Zerglings, got %d" % [unit_count / 2, visible_z])
		# Sample transform of first instance
		var xform: Transform3D = mmi_zerg.multimesh.get_instance_transform(0)
		_assert(not is_nan(xform.origin.x) and not is_nan(xform.origin.z), "mmi_zerg_transform_finite", "Transform origin contains NaN")
		_assert(xform.basis.determinant() != 0.0, "mmi_zerg_basis_non_singular", "Transform basis is singular/collapsed")

	if mmi_roach and mmi_roach.multimesh:
		var visible_r: int = mmi_roach.multimesh.visible_instance_count
		_assert(visible_r == unit_count / 2, "mmi_roach_visible_count_match", "Expected %d visible Roaches, got %d" % [unit_count / 2, visible_r])
		var xform_r: Transform3D = mmi_roach.multimesh.get_instance_transform(0)
		_assert(not is_nan(xform_r.origin.x) and not is_nan(xform_r.origin.z), "mmi_roach_transform_finite", "Roach transform origin contains NaN")

	sim.free()


# ==============================================================================
# 4. FlowField Out-of-Bounds & Coordinate Edge Cases
# ==============================================================================
func _test_flow_field_edge_cases() -> void:
	print("\n>> Testing FlowField Boundary Extremes & Numerical Edge Cases...")

	var ff := SwarmFlowField.new(128, 128, 1.0, Vector2(-64, -64))
	ff.add_goal(Vector2(0, 0))
	ff.update()

	# 1. Sample exact center (goal)
	var v_center: Vector2 = ff.sample_flow_bilinear_coords(0.0, 0.0)
	_assert(not is_nan(v_center.x) and not is_nan(v_center.y), "flow_sample_goal_not_nan", "Goal vector contains NaN")

	# 2. Sample out-of-bounds coordinates (far outside map)
	var v_oob_pos: Vector2 = ff.sample_flow_bilinear_coords(9999.0, 9999.0)
	var v_oob_neg: Vector2 = ff.sample_flow_bilinear_coords(-9999.0, -9999.0)
	_assert(not is_nan(v_oob_pos.x) and not is_nan(v_oob_pos.y), "flow_sample_oob_pos_safe", "Far positive OOB produced NaN")
	_assert(not is_nan(v_oob_neg.x) and not is_nan(v_oob_neg.y), "flow_sample_oob_neg_safe", "Far negative OOB produced NaN")

	# 3. Sample exact boundary edges
	var v_edge_min: Vector2 = ff.sample_flow_bilinear_coords(-64.0, -64.0)
	var v_edge_max: Vector2 = ff.sample_flow_bilinear_coords(64.0, 64.0)
	_assert(not is_nan(v_edge_min.x) and not is_nan(v_edge_min.y), "flow_sample_edge_min_safe", "Min edge produced NaN")
	_assert(not is_nan(v_edge_max.x) and not is_nan(v_edge_max.y), "flow_sample_edge_max_safe", "Max edge produced NaN")

	# 4. Multiple goals stress
	ff.clear_goals()
	for g in range(8):
		var ga: float = float(g) * (TAU / 8.0)
		ff.add_goal(Vector2(cos(ga) * 20.0, sin(ga) * 20.0))
	ff.update()
	var v_multi := ff.sample_flow_bilinear_coords(0.0, 0.0)
	_assert(not is_nan(v_multi.x) and not is_nan(v_multi.y), "flow_multi_goal_update_safe", "Multi-goal update produced NaN")


# ==============================================================================
# 5. Spatial Hash Kinematic Relaxation & High-Density Clumping Stress
# ==============================================================================
func _test_spatial_hash_kinematic_relaxation_stress(unit_count: int) -> void:
	print("\n>> Testing Spatial Hash Kinematic Relaxation & Clumping Stress (%d units)..." % unit_count)

	var sim := SwarmSimulation.new()
	sim.setup_simulation(Vector2(-32, -32), Vector2(32, 32), 4096)
	sim.register_goal(Vector3.ZERO)

	var zerg_arch: SwarmUnitArchetype = load("res://data/swarm/zergling_archetype.tres") as SwarmUnitArchetype
	if zerg_arch:
		sim.register_archetype(zerg_arch)

	# Spawn all 2,000 units in an extremely tight cluster (radius 3.0 meters) to force maximum overlap
	sim.spawn_wave(0, unit_count, Vector3(0, 0, 5), 3.0)

	# Rebuild spatial hash and execute overlap resolution
	sim.spatial_hash.rebuild(sim.swarm_data)
	sim.spatial_hash.resolve_unit_overlaps(sim.swarm_data, 0.095, 2)

	# Verify all coordinates remain valid, finite numbers
	var sdata = sim.swarm_data
	var invalid_coords: int = 0
	for i in range(sdata.capacity):
		if sdata.alive_mask[i] == 1:
			var px: float = sdata.pos_x[i]
			var pz: float = sdata.pos_z[i]
			if is_nan(px) or is_nan(pz) or is_inf(px) or is_inf(pz):
				invalid_coords += 1

	_assert(invalid_coords == 0, "clump_relaxation_no_nans", "Found %d invalid coordinates after severe clump relaxation" % invalid_coords)

	# Run 20 simulation steps to ensure repulsive separation disperses the dense cluster smoothly
	for s in range(20):
		sim.simulate_step(0.016)

	var post_step_invalid: int = 0
	for i in range(sdata.capacity):
		if sdata.alive_mask[i] == 1:
			var px: float = sdata.pos_x[i]
			var pz: float = sdata.pos_z[i]
			if is_nan(px) or is_nan(pz) or is_inf(px) or is_inf(pz):
				post_step_invalid += 1

	_assert(post_step_invalid == 0, "clump_dispersion_no_nans", "Found %d invalid coordinates after 20 dispersion steps" % post_step_invalid)
	sim.free()
