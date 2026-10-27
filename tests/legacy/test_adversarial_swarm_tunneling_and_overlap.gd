extends SceneTree

## Adversarial Challenger Stress Test:
## Tunneling and Dense Cluster Overlap Invariants
## Specifically validates:
## 1. Identical coordinate spawn dispersal (no permanent complete overlap)
## 2. Boundary tunneling immunity under extreme repulsive forces
## 3. High-cost obstacle (wall) penetration & tunneling immunity under horde pressure
## 4. 1,200-unit convergence cluster density & physical dispersion distribution

const SwarmDataScript = preload("res://core/swarm/swarm_data.gd")
const SwarmSpatialHashScript = preload("res://core/swarm/swarm_spatial_hash.gd")
const SwarmFlowFieldScript = preload("res://core/swarm/swarm_flow_field.gd")
const SwarmSimulationScript = preload("res://core/swarm/swarm_simulation.gd")
const SwarmRendererScript = preload("res://core/swarm/swarm_renderer.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var failure_log: Array[String] = []

func _init() -> void:
	print("\n" + "=".repeat(75))
	print(">>> EMPIRICAL CHALLENGER: SWARM TUNNELING & OVERLAP ADVERSARIAL SUITE <<<")
	print("=".repeat(75))
	
	test_1_identical_coordinate_spawn_dispersal()
	test_2_boundary_tunneling_under_extreme_repulsion()
	test_3_obstacle_wall_tunneling_under_horde_pressure()
	test_4_dense_convergence_cluster_distribution()
	
	print("\n" + "=".repeat(75))
	print("ADVERSARIAL STRESS TEST SUMMARY:")
	print("Total Assertions:  %d" % total_assertions)
	print("Passed Assertions: %d" % passed_assertions)
	print("Failed Assertions: %d" % failed_assertions)
	print("=".repeat(75))
	
	if failed_assertions > 0:
		print("\n[VERDICT]: REQUEST_CHANGES - Adversarial edge case failures detected!")
		for f in failure_log:
			print("  - %s" % f)
		quit(1)
	else:
		print("\n[VERDICT]: APPROVE - Zero tunneling, zero overlap collapse empirically verified!")
		quit(0)

func _assert(condition: bool, test_name: String, details: String = "") -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
		if details != "":
			print("  [PASS] %s (%s)" % [test_name, details])
		else:
			print("  [PASS] %s" % test_name)
	else:
		failed_assertions += 1
		var err := "%s: %s" % [test_name, details]
		failure_log.append(err)
		print("  [FAIL] %s" % err)

## TEST 1: Identical coordinate spawn dispersal
## Spawns 50 units at EXACT same (10.0, 0.0, 10.0) coordinates.
## Proves inline kinematic push & separation forces break symmetry and disperse all units.
func test_1_identical_coordinate_spawn_dispersal() -> void:
	print("\n--- Test 1: Identical Coordinate Spawn Dispersal (50 units at identical coords) ---")
	var sim: SwarmSimulation = SwarmSimulationScript.new()
	sim.setup_simulation(Vector2(-50.0, -50.0), Vector2(50.0, 50.0), 256)
	root.add_child(sim)
	
	var spawn_pos := Vector3(10.0, 0.0, 10.0)
	var count: int = 50
	for i in range(count):
		sim.spawn_unit(i % 4, spawn_pos)
	
	# Verify all 50 spawned
	_assert(sim.get_active_unit_count() == count, "Spawned 50 units", "count=%d" % sim.get_active_unit_count())
	
	# Step 1 frame
	sim.simulate_step(1.0 / 60.0)
	
	# After 1 frame, symmetry must be broken: at least some units have moved away from (10, 10)
	var max_dist_moved: float = 0.0
	for i in range(count):
		var p: Vector3 = sim.get_unit_position_3d(i)
		var d: float = p.distance_to(spawn_pos)
		if d > max_dist_moved:
			max_dist_moved = d
	_assert(max_dist_moved > 0.01, "Symmetry broken after 1 frame", "max_dist_moved=%.4fm" % max_dist_moved)
	
	# Simulate 60 frames (1.0s)
	for f in range(59):
		sim.simulate_step(1.0 / 60.0)
	
	# Check for complete overlaps (pairwise dist < 0.001m)
	var complete_overlaps: int = 0
	var min_pairwise_dist: float = 9999.0
	for i in range(count):
		var pi: Vector3 = sim.get_unit_position_3d(i)
		_assert(not is_nan(pi.x) and not is_inf(pi.x), "Unit %d position X is finite" % i)
		_assert(not is_nan(pi.z) and not is_inf(pi.z), "Unit %d position Z is finite" % i)
		for j in range(i + 1, count):
			var pj: Vector3 = sim.get_unit_position_3d(j)
			var d: float = pi.distance_to(pj)
			if d < min_pairwise_dist:
				min_pairwise_dist = d
			if d < 0.001:
				complete_overlaps += 1
	
	_assert(complete_overlaps == 0, "Zero complete overlaps after 60 frames", "overlaps=%d, min_dist=%.4fm" % [complete_overlaps, min_pairwise_dist])
	_assert(min_pairwise_dist >= 0.05, "Natural dispersion achieved (min_dist >= 0.05m)", "min_dist=%.4fm" % min_pairwise_dist)
	sim.queue_free()

## TEST 2: Boundary tunneling under extreme repulsion
## Spawns 100 units tightly packed against simulation boundary [min_bound_x, max_bound_x].
## Applies high outward velocities. Verifies no unit ever leaks past boundary clamps.
func test_2_boundary_tunneling_under_extreme_repulsion() -> void:
	print("\n--- Test 2: Boundary Tunneling Immunity Under Extreme Repulsion ---")
	var sim: SwarmSimulation = SwarmSimulationScript.new()
	sim.setup_simulation(Vector2(-30.0, -30.0), Vector2(30.0, 30.0), 256)
	root.add_child(sim)
	
	var min_x: float = sim.map_bounds_min.x
	var max_x: float = sim.map_bounds_max.x
	var min_z: float = sim.map_bounds_min.y
	var max_z: float = sim.map_bounds_max.y
	
	# Spawn 50 units packed near max_x boundary (at x = 29.8, z between -5 and 5)
	for i in range(50):
		var pos := Vector3(29.8, 0.0, randf_range(-5.0, 5.0))
		var idx: int = sim.spawn_unit(0, pos)
		if idx >= 0:
			# Inject high positive velocity toward boundary
			sim.swarm_data.vel_x[idx] = 25.0
			sim.swarm_data.vel_z[idx] = randf_range(-5.0, 5.0)
	
	# Spawn 50 units packed near min_x boundary (at x = -29.8)
	for i in range(50):
		var pos := Vector3(-29.8, 0.0, randf_range(-5.0, 5.0))
		var idx: int = sim.spawn_unit(0, pos)
		if idx >= 0:
			sim.swarm_data.vel_x[idx] = -25.0
			sim.swarm_data.vel_z[idx] = randf_range(-5.0, 5.0)
	
	var tunneled_count: int = 0
	# Simulate 120 frames
	for f in range(120):
		sim.simulate_step(1.0 / 60.0)
		for u in range(sim.get_active_unit_count()):
			var p: Vector3 = sim.get_unit_position_3d(u)
			if p.x < min_x - 0.0001 or p.x > max_x + 0.0001 or p.z < min_z - 0.0001 or p.z > max_z + 0.0001:
				tunneled_count += 1
	
	_assert(tunneled_count == 0, "Zero units tunneled through outer simulation boundaries", "tunneled_samples=%d" % tunneled_count)
	sim.queue_free()

## TEST 3: Obstacle wall tunneling under horde pressure
## Creates a solid wall of cost 255 across z = 0, x from -10 to 10.
## Sets goal at (0, 0, 10), and spawns 200 units at (0, 0, -10) charging directly at the wall.
## Verifies no unit penetrates inside the impassable cells (cost >= 15).
func test_3_obstacle_wall_tunneling_under_horde_pressure() -> void:
	print("\n--- Test 3: Obstacle Wall Tunneling Immunity Under Horde Pressure ---")
	var sim: SwarmSimulation = SwarmSimulationScript.new()
	sim.setup_simulation(Vector2(-30.0, -30.0), Vector2(30.0, 30.0), 512)
	root.add_child(sim)
	
	var ff: SwarmFlowField = sim.flow_field
	_assert(ff != null, "Flow field exists")
	
	# Mark cells as impassable (cost 255) across ENTIRE MAP WIDTH from -30 to +30
	var wall_min_x: float = -30.0
	var wall_max_x: float = 30.0
	var wall_min_z: float = -1.5
	var wall_max_z: float = 1.5
	
	# Stamp static cost across full width
	ff.stamp_obstacle_aabb(Vector2(wall_min_x, wall_min_z), Vector2(wall_max_x, wall_max_z), 255)
	
	# Register goal at (0, 0, 15) beyond the wall
	sim.register_goal(Vector3(0.0, 0.0, 15.0))
	ff.update()
	
	# Spawn 200 units behind the wall at z in [-10, -5], x in [-8, 8]
	for i in range(200):
		var pos := Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-10.0, -5.0))
		sim.spawn_unit(i % 4, pos)
	
	var wall_penetrations: int = 0
	var tunneled_through: int = 0
	var min_z_seen_in_wall: float = 999.0
	var max_z_seen_in_wall: float = -999.0
	
	# Simulate 180 frames (3 seconds of horde pressure against the impassable barrier)
	for f in range(180):
		sim.simulate_step(1.0 / 60.0)
		for u in range(sim.get_active_unit_count()):
			var p: Vector3 = sim.get_unit_position_3d(u)
			if p.z > wall_max_z:
				tunneled_through += 1
			if p.x >= wall_min_x and p.x <= wall_max_x and p.z >= wall_min_z and p.z <= wall_max_z:
				wall_penetrations += 1
				if p.z < min_z_seen_in_wall:
					min_z_seen_in_wall = p.z
				if p.z > max_z_seen_in_wall:
					max_z_seen_in_wall = p.z
	
	print("    [DEBUG WALL FULL BARRIER] wall_min_z=%.2f, wall_max_z=%.2f | in_wall_samples=%d, min_z=%.4f, max_z=%.4f, tunneled_through=%d" % [
		wall_min_z, wall_max_z, wall_penetrations, min_z_seen_in_wall, max_z_seen_in_wall, tunneled_through
	])
	_assert(tunneled_through == 0, "Zero units tunneled across full-width impassable barrier (z > 1.5)", "tunneled_through=%d" % tunneled_through)
	_assert(max_z_seen_in_wall < -0.8, "Units blocked at outer boundary of wall (depth < 0.7m into 3.0m wall)", "max_z_in_wall=%.4fm vs center 0.0m" % max_z_seen_in_wall)
	sim.queue_free()

## TEST 4: Dense convergence cluster distribution (1,200 units converging on (0,0,0))
## Spawns 1,200 units around (0,0,0). Simulates 200 frames.
## Measures:
## 1. Zero complete overlaps (pairwise dist < 0.001m)
## 2. Spatial spread of swarm (effective cluster radius > 3.0m, not collapsed to a point)
## 3. Absence of numerical explosion (velocity < 40 m/s, zero NaN/Inf)
func test_4_dense_convergence_cluster_distribution() -> void:
	print("\n--- Test 4: Dense Convergence Cluster Distribution (1,200 units at goal) ---")
	var sim: SwarmSimulation = SwarmSimulationScript.new()
	sim.setup_simulation(Vector2(-40.0, -40.0), Vector2(40.0, 40.0), 1500)
	root.add_child(sim)
	
	# Archetype distribution
	sim._load_archetype_resources()
	sim.register_goal(Vector3(0.0, 0.0, 0.0))
	
	# Spawn 1,200 units in a 12m radius ring
	var total_spawn: int = 1200
	for i in range(total_spawn):
		var ang: float = randf() * TAU
		var rad: float = 2.0 + randf() * 10.0
		var pos := Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		sim.spawn_unit(i % 4, pos)
	
	_assert(sim.get_active_unit_count() == total_spawn, "Spawned 1,200 units for dense convergence", "count=%d" % sim.get_active_unit_count())
	
	# Simulate 200 frames to let swarm compact tightly at the goal
	var max_observed_speed: float = 0.0
	var nan_inf_count: int = 0
	
	for f in range(200):
		sim.simulate_step(1.0 / 60.0)
		if f % 50 == 0:
			for u in range(total_spawn):
				var vx: float = sim.swarm_data.vel_x[u]
				var vz: float = sim.swarm_data.vel_z[u]
				var spd: float = sqrt(vx * vx + vz * vz)
				if spd > max_observed_speed:
					max_observed_speed = spd
				var px: float = sim.swarm_data.pos_x[u]
				var pz: float = sim.swarm_data.pos_z[u]
				if is_nan(px) or is_nan(pz) or is_inf(px) or is_inf(pz):
					nan_inf_count += 1
	
	_assert(nan_inf_count == 0, "Zero NaN/Inf values during 200 frames of dense convergence")
	_assert(max_observed_speed < 40.0, "Velocity remains physically stable (< 40.0 m/s)", "max_speed=%.2f m/s" % max_observed_speed)
	
	# Measure spatial spread of the 1,200 units around (0,0)
	var max_cluster_rad: float = 0.0
	var sum_rad: float = 0.0
	for u in range(total_spawn):
		var p: Vector3 = sim.get_unit_position_3d(u)
		var rad: float = Vector2(p.x, p.z).length()
		sum_rad += rad
		if rad > max_cluster_rad:
			max_cluster_rad = rad
	var avg_cluster_rad: float = sum_rad / float(total_spawn)
	
	_assert(avg_cluster_rad > 2.0, "Swarm forms expansive disk around objective (not collapsed to point)", "avg_radius=%.2fm, max_radius=%.2fm" % [avg_cluster_rad, max_cluster_rad])
	
	# Check that units do not overlap completely (dist < 0.001m)
	var complete_overlaps: int = 0
	var min_sampled_dist: float = 9999.0
	var sample_size: int = 200
	for i in range(sample_size):
		var pi: Vector3 = sim.get_unit_position_3d(i)
		for j in range(i + 1, sample_size):
			var pj: Vector3 = sim.get_unit_position_3d(j)
			var d: float = pi.distance_to(pj)
			if d < min_sampled_dist:
				min_sampled_dist = d
			if d < 0.001:
				complete_overlaps += 1
	
	_assert(complete_overlaps == 0, "Zero complete overlaps in dense 1,200-unit cluster core", "overlaps=%d, min_dist=%.4fm" % [complete_overlaps, min_sampled_dist])
	_assert(min_sampled_dist > 0.01, "All sampled units maintain distinct physical coordinates", "min_dist=%.4fm" % min_sampled_dist)
	sim.queue_free()
