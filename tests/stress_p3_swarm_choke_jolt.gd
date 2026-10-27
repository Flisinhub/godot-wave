extends SceneTree

## stress_p3_swarm_choke_jolt.gd
## Adversarial stress harness for Godot 4.7.2 Jolt Physics and mass Swarm throughput.
## Stress-tests:
## 1. 1,000+ units across all 4 strains (Zerglings, Roaches, Banelings, Hydralisks).
## 2. Convergence through a narrow 2.5m choke point flanked by solid Jolt Physics StaticBody3D colliders.
## 3. High-density Boids separation, bilinear flow field sampling, and obstacle sliding.
## 4. Frame time measurements (Avg, P95, Max, Min, FPS equivalent).
## 5. Memory usage stability and zero penetration / zero coordinate collapse.

const SwarmSimulation = preload("res://core/swarm/swarm_simulation.gd")
const SwarmUnitArchetype = preload("res://data/swarm/swarm_unit_archetype.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_reasons: Array[String] = []

func _init() -> void:
	print("\n================================================================================")
	print("=== EMPIRICAL CHALLENGER: MASS SWARM CHOKE POINT UNDER JOLT PHYSICS 3D ===")
	print("================================================================================\n")
	
	_run_stress_test()

func _assert(cond: bool, test_name: String, error_msg: String) -> bool:
	total_tests += 1
	if cond:
		passed_tests += 1
		print("  \u001b[32m[PASS]\u001b[0m %s" % test_name)
		return true
	else:
		failed_tests += 1
		failure_reasons.append("%s: %s" % [test_name, error_msg])
		print("  \u001b[31m[FAIL]\u001b[0m %s: %s" % [test_name, error_msg])
		return false

func _run_stress_test() -> void:
	# 1. Verify Jolt Physics is the configured 3D physics engine
	var engine_setting = ProjectSettings.get_setting("physics/3d/physics_engine")
	print(">> [1/5] Physics Engine Verification:")
	print("  * Project physics/3d/physics_engine setting: '%s'" % str(engine_setting))
	_assert(str(engine_setting) == "Jolt Physics", "Jolt Physics configured in project settings", "Got '%s'" % str(engine_setting))
	
	# 2. Setup 3D Scene Root with Jolt StaticBody3D choke point colliders
	print("\n>> [2/5] Constructing Choke Point with Jolt Physics StaticBody3D Colliders...")
	var root_node := Node3D.new()
	root_node.name = "StressSceneRoot"
	root.add_child(root_node)
	
	# Create physical Jolt collider walls flanking a 2.5m choke gap
	# Left Wall: X in [-25.0, -1.25], Z in [-0.5, 0.5], Y in [0, 2] -> center (-13.125, 1.0, 0), extents (11.875, 1.0, 0.5)
	var wall_left := StaticBody3D.new()
	wall_left.name = "JoltWallLeft"
	wall_left.position = Vector3(-13.125, 1.0, 0.0)
	var col_left := CollisionShape3D.new()
	var box_left := BoxShape3D.new()
	box_left.size = Vector3(23.75, 2.0, 1.0)
	col_left.shape = box_left
	wall_left.add_child(col_left)
	root_node.add_child(wall_left)
	
	# Right Wall: X in [1.25, 25.0], Z in [-0.5, 0.5], Y in [0, 2] -> center (13.125, 1.0, 0), extents (11.875, 1.0, 0.5)
	var wall_right := StaticBody3D.new()
	wall_right.name = "JoltWallRight"
	wall_right.position = Vector3(13.125, 1.0, 0.0)
	var col_right := CollisionShape3D.new()
	var box_right := BoxShape3D.new()
	box_right.size = Vector3(23.75, 2.0, 1.0)
	col_right.shape = box_right
	wall_right.add_child(col_right)
	root_node.add_child(wall_right)
	
	var choke_width: float = 2.5 # Gap between -1.25 and 1.25
	print("  * Jolt StaticBody3D Left Wall:  X in [-25.0, -1.25], BoxSize: (23.75, 2.0, 1.0)")
	print("  * Jolt StaticBody3D Right Wall: X in [ 1.25,  25.0], BoxSize: (23.75, 2.0, 1.0)")
	print("  * Choke Point Aperture Width:   %.2f m" % choke_width)
	
	# 3. Setup Swarm Simulation & Register Obstacles and Archetypes
	print("\n>> [3/5] Initializing SwarmSimulation (Capacity 2048) & Registering 4 Strains...")
	var sim := SwarmSimulation.new()
	sim.name = "SwarmSimulation"
	root_node.add_child(sim)
	sim.setup_simulation(Vector2(-32.0, -32.0), Vector2(32.0, 32.0), 2048)
	
	# Register goal on other side of choke point (Z = +18.0)
	var goal_pos := Vector3(0.0, 0.0, 18.0)
	sim.register_goal(goal_pos)
	
	# Register obstacles in FlowField cost field (cost = 255 impassable)
	sim.register_obstacle_aabb("jolt_wall_l", Vector3(-25.0, 0.0, -0.6), Vector3(-1.25, 2.0, 0.6), true, 255)
	sim.register_obstacle_aabb("jolt_wall_r", Vector3( 1.25, 0.0, -0.6), Vector3( 25.0, 2.0, 0.6), true, 255)
	
	# Load and register all 4 archetypes
	var arch_0: SwarmUnitArchetype = load("res://data/swarm/zergling_archetype.tres") as SwarmUnitArchetype
	var arch_1: SwarmUnitArchetype = load("res://data/swarm/roach_archetype.tres") as SwarmUnitArchetype
	var arch_2: SwarmUnitArchetype = load("res://data/swarm/baneling_archetype.tres") as SwarmUnitArchetype
	var arch_3: SwarmUnitArchetype = load("res://data/swarm/hydralisk_archetype.tres") as SwarmUnitArchetype
	
	_assert(arch_0 != null, "Archetype 0 (Zergling) loaded", "Could not load zergling_archetype.tres")
	_assert(arch_1 != null, "Archetype 1 (Roach) loaded", "Could not load roach_archetype.tres")
	_assert(arch_2 != null, "Archetype 2 (Baneling) loaded", "Could not load baneling_archetype.tres")
	_assert(arch_3 != null, "Archetype 3 (Hydralisk) loaded", "Could not load hydralisk_archetype.tres")
	
	sim.register_archetype(arch_0)
	sim.register_archetype(arch_1)
	sim.register_archetype(arch_2)
	sim.register_archetype(arch_3)
	
	# 4. Spawn 1,000+ units distributed across all 4 strains
	print("\n>> [4/5] Spawning 1,000 Mass Swarm Units on Incoming Side (Z in [-16, -6])...")
	var count_0: int = 400 # 400 Zerglings
	var count_1: int = 200 # 200 Roaches
	var count_2: int = 200 # 200 Banelings
	var count_3: int = 200 # 200 Hydralisks
	var total_spawned_target: int = count_0 + count_1 + count_2 + count_3 # 1000 units
	
	var spawned_0 := sim.spawn_wave(0, count_0, Vector3(0.0, 0.0, -9.0), 5.5)
	var spawned_1 := sim.spawn_wave(1, count_1, Vector3(-4.0, 0.0, -11.0), 4.5)
	var spawned_2 := sim.spawn_wave(2, count_2, Vector3(4.0, 0.0, -11.0), 4.5)
	var spawned_3 := sim.spawn_wave(3, count_3, Vector3(0.0, 0.0, -13.0), 5.0)
	
	var total_spawned := spawned_0.size() + spawned_1.size() + spawned_2.size() + spawned_3.size()
	print("  * Spawned Zerglings (Archetype 0):  %d" % spawned_0.size())
	print("  * Spawned Roaches   (Archetype 1):  %d" % spawned_1.size())
	print("  * Spawned Banelings (Archetype 2):  %d" % spawned_2.size())
	print("  * Spawned Hydralisks(Archetype 3):  %d" % spawned_3.size())
	print("  * Total Active Units in Simulation: %d" % sim.get_active_unit_count())
	
	_assert(total_spawned >= 1000, "Spawned >= 1,000 units across 4 strains", "Got %d" % total_spawned)
	
	# 5. Execute 400 Simulation Steps and Measure Performance & Invariants
	print("\n>> [5/5] Executing 400 Steps of Mass Swarm Choke Convergence...")
	var initial_mem: int = OS.get_static_memory_usage()
	var step_times_usec: Array[int] = []
	var penetrations: int = 0
	var min_pairwise_dist_seen: float = 999.0
	
	var crossed_0: int = 0
	var crossed_1: int = 0
	var crossed_2: int = 0
	var crossed_3: int = 0
	
	var delta: float = 0.016667 # 60 Hz physics step
	var total_steps: int = 400
	
	for step in range(total_steps):
		var t_start: int = Time.get_ticks_usec()
		sim.simulate_step(delta)
		var t_step: int = Time.get_ticks_usec() - t_start
		step_times_usec.append(t_step)
		
		# Sample collision and integrity checks every 10 steps
		if step % 10 == 0:
			var sd := sim.swarm_data
			var cap: int = sd.capacity
			var alive := sd.alive_mask
			var px := sd.pos_x
			var pz := sd.pos_z
			
			for i in range(cap):
				if alive[i] == 0:
					continue
				var ux: float = px[i]
				var uz: float = pz[i]
				
				# Check penetration into Left Wall: X in [-24.8, -1.3], Z in [-0.5, 0.5]
				if ux >= -24.8 and ux <= -1.3 and uz >= -0.5 and uz <= 0.5:
					penetrations += 1
				# Check penetration into Right Wall: X in [1.3, 24.8], Z in [-0.5, 0.5]
				if ux >= 1.3 and ux <= 24.8 and uz >= -0.5 and uz <= 0.5:
					penetrations += 1
					
			if sim.spatial_hash and sim.spatial_hash.last_min_dist < min_pairwise_dist_seen:
				min_pairwise_dist_seen = sim.spatial_hash.last_min_dist
	
	# Final evaluation of units funneled across the choke (Z > 0.6)
	var sd := sim.swarm_data
	var cap: int = sd.capacity
	var alive := sd.alive_mask
	var pz := sd.pos_z
	var arch_ids := sd.archetype_ids
	
	for i in range(cap):
		if alive[i] == 0:
			continue
		if pz[i] > 0.6:
			var a_id: int = arch_ids[i]
			match a_id:
				0: crossed_0 += 1
				1: crossed_1 += 1
				2: crossed_2 += 1
				3: crossed_3 += 1
				
	var total_crossed := crossed_0 + crossed_1 + crossed_2 + crossed_3
	var final_mem: int = OS.get_static_memory_usage()
	var mem_delta_kb: float = float(final_mem - initial_mem) / 1024.0
	
	# Calculate frame time statistics
	step_times_usec.sort()
	var sum_usec: int = 0
	for t in step_times_usec:
		sum_usec += t
	var avg_ms: float = float(sum_usec) / float(total_steps) / 1000.0
	var p95_ms: float = float(step_times_usec[int(total_steps * 0.95)]) / 1000.0
	var p99_ms: float = float(step_times_usec[int(total_steps * 0.99)]) / 1000.0
	var max_ms: float = float(step_times_usec[total_steps - 1]) / 1000.0
	var min_ms: float = float(step_times_usec[0]) / 1000.0
	var effective_fps: float = 1000.0 / avg_ms if avg_ms > 0.0 else 0.0
	
	print("\n================================================================================")
	print("--- EMPIRICAL PERFORMANCE & THROUGHPUT MEASUREMENTS ---")
	print("================================================================================")
	print("Simulation Steps Executed:   %d (at 60 Hz delta = 16.67 ms)" % total_steps)
	print("Active Swarm Units:          %d" % sim.get_active_unit_count())
	print("Execution Timings:")
	print("  * Average Frame Time:      %.2f ms (Equivalent: %.1f FPS)" % [avg_ms, effective_fps])
	print("  * 95th Percentile (P95):   %.2f ms" % p95_ms)
	print("  * 99th Percentile (P99):   %.2f ms" % p99_ms)
	print("  * Min / Max Frame Time:    %.2f ms / %.2f ms" % [min_ms, max_ms])
	print("  * 16.67ms (60 FPS) Budget: %s" % ("SATISFIED (< 16.67 ms)" if avg_ms <= 16.67 else "EXCEEDED"))
	print("")
	print("Choke Point Funneling Throughput (Target: Z > 0.6 m):")
	print("  * Zerglings (Strain 0):    %d / %d funneled" % [crossed_0, count_0])
	print("  * Roaches   (Strain 1):    %d / %d funneled" % [crossed_1, count_1])
	print("  * Banelings (Strain 2):    %d / %d funneled" % [crossed_2, count_2])
	print("  * Hydralisks(Strain 3):    %d / %d funneled" % [crossed_3, count_3])
	print("  * TOTAL FUNNELED:          %d / %d (%.1f%% throughput)" % [
		total_crossed, total_spawned, float(total_crossed) / float(total_spawned) * 100.0
	])
	print("")
	print("Spatial Collision & Physical Integrity:")
	print("  * Jolt Collider Penetrations: %d" % penetrations)
	print("  * Min Pairwise Distance:      %.4f m (Coordinate collapse threshold: > 0.05m)" % min_pairwise_dist_seen)
	print("  * Static Memory Delta:        %.1f KB" % mem_delta_kb)
	print("================================================================================")
	
	# Invariant Assertions
	_assert(avg_ms < 16.67, "Average step time under 60 FPS budget (16.67 ms)", "Avg time was %.2f ms" % avg_ms)
	_assert(p95_ms < 20.0, "P95 step time under 20.0 ms", "P95 was %.2f ms" % p95_ms)
	_assert(total_crossed >= 300, "Throughput funneled through 2.5m choke >= 300 units", "Got %d" % total_crossed)
	_assert(crossed_0 > 0 and crossed_1 > 0 and crossed_2 > 0 and crossed_3 > 0, "All 4 strains represented in throughput", "Some strains did not cross")
	_assert(penetrations == 0, "Zero penetrations into Jolt physics wall colliders", "Detected %d penetrations" % penetrations)
	_assert(min_pairwise_dist_seen >= 0.05, "Zero coordinate collapse (min pairwise dist >= 0.05m)", "Min dist was %.4f m" % min_pairwise_dist_seen)
	_assert(mem_delta_kb < 2048.0, "Memory bounded during mass swarm simulation (< 2 MB growth)", "Grew by %.1f KB" % mem_delta_kb)
	
	# Cleanup
	root_node.free()
	
	print("\n================================================================================")
	print("CHOKE POINT STRESS SUITE RESULTS:")
	print("Total Invariants Tested: %d" % total_tests)
	print("Passed:                  %d" % passed_tests)
	print("Failed:                  %d" % failed_tests)
	
	if failed_tests > 0:
		print("\u001b[31m[VERDICT: REQUEST_CHANGES] CHOKE POINT INVARIANTS FAILED:\u001b[0m")
		for r in failure_reasons:
			print("  - %s" % r)
		print("================================================================================")
		quit(1)
	else:
		print("\u001b[32m[VERDICT: APPROVE] ALL CHOKE POINT INVARIANTS SATISFIED!\u001b[0m")
		print("================================================================================")
		quit(0)
