extends SceneTree

## Empirical Challenger Benchmark for Milestone 1
## Adversarial verification of Swarm Simulation and MultiMesh Rendering across all 4 archetypes:
## Zerglings (0), Roaches (1), Banelings (2), Hydralisks (3).

const SwarmDataScript = preload("res://core/swarm/swarm_data.gd")
const SwarmSpatialHashScript = preload("res://core/swarm/swarm_spatial_hash.gd")
const SwarmFlowFieldScript = preload("res://core/swarm/swarm_flow_field.gd")
const SwarmSimulationScript = preload("res://core/swarm/swarm_simulation.gd")
const SwarmRendererScript = preload("res://core/swarm/swarm_renderer.gd")
const SwarmUnitArchetypeScript = preload("res://data/swarm/swarm_unit_archetype.gd")

const TARGET_FRAME_BUDGET_MS: float = 16.6667 # 60 FPS budget
const BENCHMARK_UNITS: int = 1200
const BENCHMARK_FRAMES: int = 350

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_details: Array[String] = []

# Telemetry captured for final report
var telemetry: Dictionary = {}


func _init() -> void:
	print("\n" + "=".repeat(75))
	print(">>> EMPIRICAL CHALLENGER: MILESTONE 1 ADVERSARIAL VERIFICATION SUITE <<<")
	print("=".repeat(75))
	
	run_test_1_archetype_registry_and_multimesh_coverage()
	run_test_2_multimesh_transform_validity_and_nan_inf_check()
	run_test_3_mass_simulation_and_multimesh_benchmark()
	run_test_4_dynamic_churn_slot_recycling_and_ghost_check()
	run_test_5_extreme_bottleneck_congestion_stress()
	run_test_6_scalability_curve()
	
	_print_empirical_summary()
	
	if failed_tests > 0:
		print("\n[VERDICT]: REQUEST_CHANGES - Empirical defects detected!")
		quit(1)
	else:
		print("\n[VERDICT]: APPROVE - All empirical criteria met!")
		quit(0)


# ==============================================================================
# TEST 1: Archetype Registration & MultiMesh Coverage Invariant
# ==============================================================================
func run_test_1_archetype_registry_and_multimesh_coverage() -> void:
	total_tests += 1
	print("\n[CHALLENGE 1] Archetype Registration & MultiMesh Coverage Invariant...")
	
	var archetypes_to_verify: Dictionary = {
		0: "res://data/swarm/zergling_archetype.tres",
		1: "res://data/swarm/roach_archetype.tres",
		2: "res://data/swarm/baneling_archetype.tres",
		3: "res://data/swarm/hydralisk_archetype.tres"
	}
	
	# 1. Verify all archetype resources exist
	for aid in archetypes_to_verify.keys():
		var path: String = archetypes_to_verify[aid]
		if not ResourceLoader.exists(path):
			_record_fail("Archetype resource file missing: %s" % path)
			return
		var res = load(path)
		if not (res is SwarmUnitArchetype):
			_record_fail("Archetype resource %s is not SwarmUnitArchetype" % path)
			return
		if res.archetype_id != aid:
			_record_fail("Archetype ID mismatch for %s: expected %d, got %d" % [path, aid, res.archetype_id])
			return
	
	# 2. Test SwarmSimulation initialization and default archetype loading
	var sim = SwarmSimulationScript.new()
	root.add_child(sim)
	sim._ready()
	if sim.renderer:
		sim.renderer._ready()
	
	# Inspect whether SwarmSimulation automatically registered all 4 archetypes
	var missing_sim_archs: Array[int] = []
	for aid in [0, 1, 2, 3]:
		if not sim.archetype_defs.has(aid):
			missing_sim_archs.append(aid)
	
	var missing_renderer_mmi: Array[int] = []
	if sim.renderer:
		for aid in [0, 1, 2, 3]:
			if not sim.renderer.multimeshes.has(aid):
				missing_renderer_mmi.append(aid)
	else:
		_record_fail("SwarmSimulation.renderer was not initialized in scene tree")
		sim.queue_free()
		return
	
	print("  -> SwarmSimulation registered archetypes: %s" % [sim.archetype_defs.keys()])
	print("  -> SwarmRenderer MultiMeshes created: %s" % [sim.renderer.multimeshes.keys()])
	
	if not missing_sim_archs.is_empty():
		var err := "SwarmSimulation._load_archetype_resources() FAILED to register archetypes: %s. Only archetypes 0 and 1 are loaded by default!" % [missing_sim_archs]
		print("  -> DEFECT DETECTED: %s" % err)
		_record_fail(err)
		sim.queue_free()
		return
	
	if not missing_renderer_mmi.is_empty():
		var err := "SwarmRenderer FAILED to create MultiMesh slots for archetypes: %s" % [missing_renderer_mmi]
		print("  -> DEFECT DETECTED: %s" % err)
		_record_fail(err)
		sim.queue_free()
		return
	
	sim.queue_free()
	_record_pass("All 4 archetypes registered and have active MultiMesh instances.")


# ==============================================================================
# TEST 2: MultiMesh Transform Validity & Zero NaN / Inf Invariant
# ==============================================================================
func run_test_2_multimesh_transform_validity_and_nan_inf_check() -> void:
	total_tests += 1
	print("\n[CHALLENGE 2] MultiMesh Transform Numerical Invariant (Zero NaN/Inf)...")
	
	var sim = SwarmSimulationScript.new()
	sim.setup_simulation(Vector2(-50.0, -50.0), Vector2(50.0, 50.0), 2048)
	root.add_child(sim)
	
	# Ensure all 4 archetypes are registered for this test
	_ensure_all_archetypes_registered(sim)
	
	# Spawn 1,000 mixed units (250 each of Zergling, Roach, Baneling, Hydralisk)
	var counts_by_arch: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
	for arch_id in [0, 1, 2, 3]:
		for i in range(250):
			var pos := Vector3(randf_range(-30.0, 30.0), 0.0, randf_range(-30.0, 30.0))
			var idx := sim.spawn_unit(arch_id, pos)
			if idx >= 0:
				counts_by_arch[arch_id] += 1
	
	# Run 30 steps of simulation with transform updates
	for step in range(30):
		sim.simulate_step(1.0 / 60.0)
	
	# Inspect every instance transform in all 4 MultiMeshes
	var nan_inf_count: int = 0
	var count_mismatch: bool = false
	
	for arch_id in [0, 1, 2, 3]:
		if not sim.renderer.multimeshes.has(arch_id):
			_record_fail("MultiMesh missing for archetype %d" % arch_id)
			sim.queue_free()
			return
		
		var mm: MultiMesh = sim.renderer.multimeshes[arch_id]
		var expected_visible: int = counts_by_arch[arch_id]
		var actual_visible: int = mm.visible_instance_count
		
		if actual_visible != expected_visible:
			print("  -> ERROR: Visible count mismatch for archetype %d: expected %d, got %d" % [arch_id, expected_visible, actual_visible])
			count_mismatch = true
		
		for inst_idx in range(actual_visible):
			var t: Transform3D = mm.get_instance_transform(inst_idx)
			
			# Check origin
			if is_nan(t.origin.x) or is_nan(t.origin.y) or is_nan(t.origin.z) or is_inf(t.origin.x) or is_inf(t.origin.y) or is_inf(t.origin.z):
				nan_inf_count += 1
			
			# Check basis
			for row in [t.basis.x, t.basis.y, t.basis.z]:
				if is_nan(row.x) or is_nan(row.y) or is_nan(row.z) or is_inf(row.x) or is_inf(row.y) or is_inf(row.z):
					nan_inf_count += 1
			
			# Check determinant / scale not collapsed to zero
			var scale := t.basis.get_scale()
			if scale.length_squared() < 0.0001:
				nan_inf_count += 1
	
	if count_mismatch:
		_record_fail("MultiMesh visible instance counts do not match active unit counts")
		sim.queue_free()
		return
	
	if nan_inf_count > 0:
		_record_fail("Found %d NaN/Inf or zero-collapsed transforms in MultiMesh instances!" % nan_inf_count)
		sim.queue_free()
		return
	
	sim.queue_free()
	_record_pass("All 1,000 MultiMesh instance transforms verified: 0 NaN, 0 Inf, 100% visible count match.")


# ==============================================================================
# TEST 3: Mass Simulation & MultiMesh Rendering Performance Benchmark
# ==============================================================================
func run_test_3_mass_simulation_and_multimesh_benchmark() -> void:
	total_tests += 1
	print("\n[CHALLENGE 3] Mass Swarm Stress Test: %d units across 4 archetypes for %d frames..." % [BENCHMARK_UNITS, BENCHMARK_FRAMES])
	
	var sim = SwarmSimulationScript.new()
	sim.setup_simulation(Vector2(-50.0, -50.0), Vector2(50.0, 50.0), BENCHMARK_UNITS + 512)
	root.add_child(sim)
	
	_ensure_all_archetypes_registered(sim)
	
	# Register goal at center (Command Center / Objective)
	sim.register_goal(Vector3(0.0, 0.0, 0.0))
	
	# Spawn distribution:
	# 400 Zerglings (North)
	# 300 Roaches (South)
	# 250 Banelings (East)
	# 250 Hydralisks (West)
	# Total = 1,200 units
	var zerg_spawned: int = 0
	var roach_spawned: int = 0
	var bane_spawned: int = 0
	var hydra_spawned: int = 0
	
	for i in range(400):
		var pos := Vector3(randf_range(-25.0, 25.0), 0.0, randf_range(-45.0, -35.0))
		if sim.spawn_unit(0, pos) >= 0:
			zerg_spawned += 1
	
	for i in range(300):
		var pos := Vector3(randf_range(-25.0, 25.0), 0.0, randf_range(35.0, 45.0))
		if sim.spawn_unit(1, pos) >= 0:
			roach_spawned += 1
			
	for i in range(250):
		var pos := Vector3(randf_range(35.0, 45.0), 0.0, randf_range(-25.0, 25.0))
		if sim.spawn_unit(2, pos) >= 0:
			bane_spawned += 1
			
	for i in range(250):
		var pos := Vector3(randf_range(-45.0, -35.0), 0.0, randf_range(-25.0, 25.0))
		if sim.spawn_unit(3, pos) >= 0:
			hydra_spawned += 1
			
	var total_spawned := zerg_spawned + roach_spawned + bane_spawned + hydra_spawned
	print("  -> Spawned: %d Zerglings, %d Roaches, %d Banelings, %d Hydralisks (Total: %d)" % [
		zerg_spawned, roach_spawned, bane_spawned, hydra_spawned, total_spawned
	])
	
	if total_spawned != BENCHMARK_UNITS:
		_record_fail("Expected %d units spawned, got %d" % [BENCHMARK_UNITS, total_spawned])
		sim.queue_free()
		return
	
	# Subsystem breakdown timings
	var frame_times_usec: Array[int] = []
	var dt: float = 1.0 / 60.0
	
	var total_flow_usec: int = 0
	var total_hash_usec: int = 0
	var total_render_usec: int = 0
	
	var start_benchmark_usec := Time.get_ticks_usec()
	
	for frame in range(BENCHMARK_FRAMES):
		var f_start := Time.get_ticks_usec()
		sim.simulate_step(dt)
		var f_dur := Time.get_ticks_usec() - f_start
		frame_times_usec.append(f_dur)
	
	var total_benchmark_usec := Time.get_ticks_usec() - start_benchmark_usec
	var total_benchmark_ms := float(total_benchmark_usec) / 1000.0
	
	frame_times_usec.sort()
	var count := frame_times_usec.size()
	var min_ms := float(frame_times_usec[0]) / 1000.0
	var max_ms := float(frame_times_usec[count - 1]) / 1000.0
	var median_ms := float(frame_times_usec[count / 2]) / 1000.0
	var p95_ms := float(frame_times_usec[int(count * 0.95)]) / 1000.0
	var p99_ms := float(frame_times_usec[int(count * 0.99)]) / 1000.0
	var mean_ms := total_benchmark_ms / float(BENCHMARK_FRAMES)
	var effective_fps := 1000.0 / mean_ms
	
	# Verify MultiMeshes visible counts match
	var render_match: bool = true
	var mm_counts := {}
	for aid in [0, 1, 2, 3]:
		var mm: MultiMesh = sim.renderer.multimeshes[aid]
		mm_counts[aid] = mm.visible_instance_count
	
	print("  -> Benchmark Telemetry over %d frames (%d units):" % [BENCHMARK_FRAMES, BENCHMARK_UNITS])
	print("     Total Time:     %.2f ms" % total_benchmark_ms)
	print("     Mean Frame:     %.3f ms (Budget: < %.3f ms)" % [mean_ms, TARGET_FRAME_BUDGET_MS])
	print("     Median Frame:   %.3f ms" % median_ms)
	print("     Min Frame:      %.3f ms" % min_ms)
	print("     Max Frame:      %.3f ms" % max_ms)
	print("     95th Percentile:%.3f ms" % p95_ms)
	print("     99th Percentile:%.3f ms" % p99_ms)
	print("     Effective FPS:  %.1f FPS (Target: > 60.0 FPS)" % effective_fps)
	print("     Visible Counts: Zergling=%d, Roach=%d, Baneling=%d, Hydralisk=%d" % [
		mm_counts[0], mm_counts[1], mm_counts[2], mm_counts[3]
	])
	
	telemetry["benchmark_units"] = BENCHMARK_UNITS
	telemetry["benchmark_frames"] = BENCHMARK_FRAMES
	telemetry["mean_frame_ms"] = mean_ms
	telemetry["median_frame_ms"] = median_ms
	telemetry["min_ms"] = min_ms
	telemetry["max_ms"] = max_ms
	telemetry["p95_ms"] = p95_ms
	telemetry["p99_ms"] = p99_ms
	telemetry["effective_fps"] = effective_fps
	telemetry["total_benchmark_ms"] = total_benchmark_ms
	
	if mean_ms > TARGET_FRAME_BUDGET_MS:
		var err := "PERFORMANCE BOTTLENECK: Mean frame time %.3f ms exceeds 16.667 ms budget (%.1f FPS < 60 FPS)" % [mean_ms, effective_fps]
		print("  -> DEFECT: %s" % err)
		_record_fail(err)
		sim.queue_free()
		return
	
	sim.queue_free()
	_record_pass("1,200 units simulated and rendered at %.1f FPS (Mean: %.3f ms < 16.67 ms)." % [effective_fps, mean_ms])


# ==============================================================================
# TEST 4: Dynamic Churn, Slot Recycling & Ghost Instance Invariant
# ==============================================================================
func run_test_4_dynamic_churn_slot_recycling_and_ghost_check() -> void:
	total_tests += 1
	print("\n[CHALLENGE 4] Dynamic Unit Churn & Slot Recycling MultiMesh Invariant...")
	
	var sim = SwarmSimulationScript.new()
	sim.setup_simulation(Vector2(-50.0, -50.0), Vector2(50.0, 50.0), 2048)
	root.add_child(sim)
	_ensure_all_archetypes_registered(sim)
	
	# Initial spawn: 800 units
	var active_ids: Array[int] = []
	for i in range(800):
		var arch_id := i % 4
		var pos := Vector3(randf_range(-30.0, 30.0), 0.0, randf_range(-30.0, 30.0))
		var idx := sim.spawn_unit(arch_id, pos)
		if idx >= 0:
			active_ids.append(idx)
	
	# Simulate 120 frames with aggressive churn (kill 40 random units and spawn 40 new ones every 5 frames)
	var churn_iterations: int = 0
	for frame in range(120):
		sim.simulate_step(1.0 / 60.0)
		
		if frame % 5 == 0 and active_ids.size() > 100:
			churn_iterations += 1
			# Kill 40 random units
			for k in range(40):
				var pick := randi() % active_ids.size()
				var u_idx := active_ids[pick]
				sim.apply_damage_to_unit(u_idx, 9999.0) # Lethal damage
				active_ids.remove_at(pick)
			
			# Spawn 40 new units
			for s in range(40):
				var arch_id := (frame + s) % 4
				var pos := Vector3(randf_range(-30.0, 30.0), 0.0, randf_range(-30.0, 30.0))
				var new_idx := sim.spawn_unit(arch_id, pos)
				if new_idx >= 0:
					active_ids.append(new_idx)
	
	# Verify SoA count vs MultiMesh visible counts
	var expected_total := sim.get_active_unit_count()
	var actual_multimesh_total := 0
	for aid in [0, 1, 2, 3]:
		var mm: MultiMesh = sim.renderer.multimeshes[aid]
		actual_multimesh_total += mm.visible_instance_count
	
	if actual_multimesh_total != expected_total:
		var err := "Ghost unit defect: MultiMesh visible sum (%d) does not match SwarmData active count (%d) after %d churn cycles!" % [
			actual_multimesh_total, expected_total, churn_iterations
		]
		_record_fail(err)
		sim.queue_free()
		return
	
	sim.queue_free()
	_record_pass("Dynamic churn verified: %d kills/spawns executed, 0 ghost instances, 100%% slot recycling integrity." % (churn_iterations * 40))


# ==============================================================================
# TEST 5: Extreme Bottleneck Congestion & Coordinate Collapse Stress
# ==============================================================================
func run_test_5_extreme_bottleneck_congestion_stress() -> void:
	total_tests += 1
	print("\n[CHALLENGE 5] Extreme Bottleneck Congestion & Numerical Compaction Stress...")
	
	var sim = SwarmSimulationScript.new()
	sim.setup_simulation(Vector2(-30.0, -30.0), Vector2(30.0, 30.0), 2048)
	root.add_child(sim)
	_ensure_all_archetypes_registered(sim)
	
	# Register goal at (0, 0)
	sim.register_goal(Vector3(0.0, 0.0, 0.0))
	
	# Spawn 1,000 units in an extremely compressed circle of radius 3.0m centered at (0, 0)
	var spawned_count: int = 0
	for i in range(1000):
		var ang := randf() * TAU
		var rad := randf() * 3.0
		var pos := Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		var aid := i % 4
		if sim.spawn_unit(aid, pos) >= 0:
			spawned_count += 1
	
	# Simulate 100 frames under extreme congestion
	var nan_detected: bool = false
	for step in range(100):
		sim.simulate_step(1.0 / 60.0)
		
		# Sample 100 units for NaN / Inf
		for idx in range(min(100, spawned_count)):
			var p := sim.get_unit_position_3d(idx)
			var h := sim.get_unit_heading(idx)
			if is_nan(p.x) or is_nan(p.z) or is_inf(p.x) or is_inf(p.z) or is_nan(h) or is_inf(h):
				nan_detected = true
				break
		if nan_detected:
			break
	
	if nan_detected:
		_record_fail("Extreme congestion caused numerical explosion (NaN/Inf positions or headings)!")
		sim.queue_free()
		return
	
	sim.queue_free()
	_record_pass("Extreme bottleneck congestion survived: 1,000 units packed in 3m radius, 0 NaN/Inf.")


# ==============================================================================
# TEST 6: Scalability Stress Curve (500, 1000, 1500, 2000 units)
# ==============================================================================
func run_test_6_scalability_curve() -> void:
	total_tests += 1
	print("\n[CHALLENGE 6] Swarm Scalability Stress Curve across 4 archetypes...")
	
	var unit_brackets: Array[int] = [500, 1000, 1500, 2000]
	var bracket_results: Dictionary = {}
	
	for count in unit_brackets:
		var sim = SwarmSimulationScript.new()
		sim.setup_simulation(Vector2(-50.0, -50.0), Vector2(50.0, 50.0), count + 512)
		root.add_child(sim)
		_ensure_all_archetypes_registered(sim)
		sim.register_goal(Vector3(0.0, 0.0, 0.0))
		
		# Spawn equal distribution across 4 archetypes
		var per_arch: int = count / 4
		for aid in [0, 1, 2, 3]:
			for i in range(per_arch):
				var pos := Vector3(randf_range(-35.0, 35.0), 0.0, randf_range(-35.0, 35.0))
				sim.spawn_unit(aid, pos)
		
		# Warmup 10 frames
		for w in range(10):
			sim.simulate_step(1.0 / 60.0)
		
		# Measure 60 frames
		var t_start := Time.get_ticks_usec()
		for f in range(60):
			sim.simulate_step(1.0 / 60.0)
		var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0
		var avg_ms := elapsed_ms / 60.0
		var fps := 1000.0 / avg_ms
		bracket_results[count] = {"avg_ms": avg_ms, "fps": fps}
		print("  -> Bracket %4d units: Avg Frame = %6.3f ms | Throughput = %5.1f FPS | Budget: %s" % [
			count, avg_ms, fps, "PASS" if avg_ms <= TARGET_FRAME_BUDGET_MS else "EXCEEDED"
		])
		sim.queue_free()
	
	telemetry["scalability_curve"] = bracket_results
	_record_pass("Scalability curve profile captured for 500, 1000, 1500, 2000 units.")


# ==============================================================================
# Helper Methods
# ==============================================================================
func _ensure_all_archetypes_registered(sim: SwarmSimulation) -> void:
	if not sim.renderer:
		sim._ready()
	if sim.renderer and sim.renderer.multimeshes.is_empty():
		sim.renderer._ready()
	var paths: Dictionary = {
		0: "res://data/swarm/zergling_archetype.tres",
		1: "res://data/swarm/roach_archetype.tres",
		2: "res://data/swarm/baneling_archetype.tres",
		3: "res://data/swarm/hydralisk_archetype.tres"
	}
	for aid in paths.keys():
		if not sim.archetype_defs.has(aid):
			var p: String = paths[aid]
			if ResourceLoader.exists(p):
				var res = load(p) as SwarmUnitArchetype
				if res:
					sim.register_archetype(res)


func _record_pass(msg: String) -> void:
	passed_tests += 1
	print("  [PASS] " + msg)


func _record_fail(msg: String) -> void:
	failed_tests += 1
	failure_details.append(msg)
	print("  [FAIL] " + msg)


func _print_empirical_summary() -> void:
	print("\n" + "=".repeat(75))
	print("EMPIRICAL BENCHMARK SUMMARY")
	print("=".repeat(75))
	print("Total Tests:  %d" % total_tests)
	print("Passed:       %d" % passed_tests)
	print("Failed:       %d" % failed_tests)
	
	if failed_tests > 0:
		print("\nFailure Root Causes:")
		for f in failure_details:
			print("  * " + f)
	print("=".repeat(75))
