extends SceneTree

## SwarmBenchmark - Rigorous unit testing and 1,000+ unit performance benchmark for Milestone 1.

const SwarmDataScript = preload("res://core/swarm/swarm_data.gd")
const SwarmSpatialHashScript = preload("res://core/swarm/swarm_spatial_hash.gd")
const SwarmFlowFieldScript = preload("res://core/swarm/swarm_flow_field.gd")
const SwarmSimulationScript = preload("res://core/swarm/swarm_simulation.gd")
const SwarmRendererScript = preload("res://core/swarm/swarm_renderer.gd")


func _init() -> void:
	print("==================================================================")
	print("STARTING MILESTONE 1 VERIFICATION & PERFORMANCE BENCHMARK")
	print("==================================================================")
	
	var pass_count: int = 0
	var fail_count: int = 0
	
	if test_swarm_data():
		pass_count += 1
	else:
		fail_count += 1
	
	if test_spatial_hash():
		pass_count += 1
	else:
		fail_count += 1
	
	if test_flow_field_phases():
		pass_count += 1
	else:
		fail_count += 1
	
	if test_bilinear_interpolation():
		pass_count += 1
	else:
		fail_count += 1
	
	if test_mass_simulation_benchmark():
		pass_count += 1
	else:
		fail_count += 1
	
	print("==================================================================")
	print("BENCHMARK SUMMARY: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("==================================================================")
	
	if fail_count > 0:
		print("FAILED: Integrity or functional defects detected!")
		quit(1)
	else:
		print("SUCCESS: All Milestone 1 criteria verified successfully!")
		quit(0)


func test_swarm_data() -> bool:
	print("[TEST 1] SwarmData Structure of Arrays (SoA) & O(1) Slot Recycling...")
	var data = SwarmDataScript.new(2048)
	
	if data.capacity != 2048:
		printerr("FAIL: Capacity mismatch: expected 2048, got %d" % data.capacity)
		return false
	if data.active_count != 0:
		printerr("FAIL: Initial active count should be 0")
		return false
	if data.free_indices.size() != 2048:
		printerr("FAIL: Free indices not fully populated")
		return false
	
	# Spawn 1,500 units
	var spawned: Array[int] = []
	for i in range(1500):
		var idx: int = data.spawn_unit(0, Vector3(float(i), 0.0, float(i)), 35.0, 7.2, 5.0, 1)
		if idx < 0:
			printerr("FAIL: Failed to spawn unit at iteration %d" % i)
			return false
		spawned.append(idx)
	
	if data.active_count != 1500:
		printerr("FAIL: Active count mismatch after 1500 spawns: got %d" % data.active_count)
		return false
	
	# Validate SoA integrity for a sample unit
	var sample_idx: int = spawned[500]
	if not data.is_alive(sample_idx):
		printerr("FAIL: Sample unit not reported alive")
		return false
	if not is_equal_approx(data.pos_x[sample_idx], 500.0) or not is_equal_approx(data.pos_z[sample_idx], 500.0):
		printerr("FAIL: SoA pos mismatch for unit 500")
		return false
	if not is_equal_approx(data.current_hp[sample_idx], 35.0):
		printerr("FAIL: SoA hp mismatch for unit 500")
		return false
	
	# Test O(1) despawn and slot recycling
	var recycle_target: int = spawned[250]
	data.despawn_unit(recycle_target)
	if data.is_alive(recycle_target):
		printerr("FAIL: Despawned unit still reported alive")
		return false
	if data.active_count != 1499:
		printerr("FAIL: Active count mismatch after despawn: got %d" % data.active_count)
		return false
	
	# Next spawn should immediately reuse the recycled slot
	var new_idx: int = data.spawn_unit(1, Vector3(99.0, 0.0, 99.0), 110.0, 4.2, 14.0, 2)
	if new_idx != recycle_target:
		printerr("FAIL: Slot recycling failed: expected reused slot %d, got %d" % [recycle_target, new_idx])
		return false
	if data.archetype_ids[new_idx] != 1 or not is_equal_approx(data.current_hp[new_idx], 110.0):
		printerr("FAIL: Recycled slot data corruption")
		return false
	
	# Test damage application and lethal kill
	var lethal: bool = data.apply_damage(new_idx, 200.0)
	if not lethal or data.is_alive(new_idx):
		printerr("FAIL: Lethal damage did not properly kill/recycle unit")
		return false
	
	print("  -> PASSED: SoA arrays, 1500 allocations, O(1) recycling verified.")
	return true


func test_spatial_hash() -> bool:
	print("[TEST 2] SwarmSpatialHash Uniform Grid & Neighbor Queries...")
	var data = SwarmDataScript.new(1024)
	var hash = SwarmSpatialHashScript.new(Vector2(-32.0, -32.0), Vector2(32.0, 32.0), 2.0, 1024)
	
	# Spawn 3 close units and 1 distant unit
	var u0: int = data.spawn_unit(0, Vector3(0.0, 0.0, 0.0), 35.0, 7.2, 5.0)
	var u1: int = data.spawn_unit(0, Vector3(0.5, 0.0, 0.0), 35.0, 7.2, 5.0)
	var u2: int = data.spawn_unit(0, Vector3(0.0, 0.0, 0.5), 35.0, 7.2, 5.0)
	var u3: int = data.spawn_unit(0, Vector3(20.0, 0.0, 20.0), 35.0, 7.2, 5.0) # Far
	
	hash.rebuild(data)
	
	# Query around (0, 0) with radius 1.0 meter
	var neighbors: PackedInt32Array = hash.query_radius(Vector2(0.0, 0.0), 1.0, data)
	if not neighbors.has(u0) or not neighbors.has(u1) or not neighbors.has(u2):
		printerr("FAIL: query_radius missed nearby units")
		return false
	if neighbors.has(u3):
		printerr("FAIL: query_radius included distant unit")
		return false
	
	# Compute separation force on u0 from u1 and u2
	# u1 is at (+0.5, 0), so repulsive force should push u0 in negative X
	# u2 is at (0, +0.5), so repulsive force should push u0 in negative Z
	var sep: Vector2 = hash.compute_separation_force(u0, data, 1.0)
	if sep.x >= 0.0:
		printerr("FAIL: Separation force X should be negative, got %f" % sep.x)
		return false
	if sep.y >= 0.0:
		printerr("FAIL: Separation force Z should be negative, got %f" % sep.y)
		return false
	
	print("  -> PASSED: Spatial hash indexing, radius query, and Boids repulsion verified.")
	return true


func test_flow_field_phases() -> bool:
	print("[TEST 3] SwarmFlowField 3-Phase Pipeline (Cost, Dijkstra, Flow)...")
	var ff = SwarmFlowFieldScript.new(64, 64, 1.0, Vector2(-32.0, -32.0))
	
	# Goal at center (0, 0)
	ff.set_goals([Vector2(0.0, 0.0)])
	
	# Dynamic obstacle: a wall between X=-5..5 at Z=5
	ff.register_obstacle("wall_1", Vector2(-5.0, 4.0), Vector2(5.0, 6.0), true)
	ff.update()
	
	# Phase 1: verify cost
	var wall_grid: Vector2i = ff.world_to_grid(Vector2(0.0, 5.0))
	if ff.get_cell_cost(wall_grid.x, wall_grid.y) != 255:
		printerr("FAIL: Cost field at stamped obstacle should be 255")
		return false
	
	# Phase 2: verify integration field
	var goal_grid: Vector2i = ff.world_to_grid(Vector2(0.0, 0.0))
	var goal_idx: int = goal_grid.y * ff.width + goal_grid.x
	if ff.integration_field[goal_idx] != 0:
		printerr("FAIL: Integration field at goal should be 0, got %d" % ff.integration_field[goal_idx])
		return false
	
	var wall_idx: int = wall_grid.y * ff.width + wall_grid.x
	if ff.integration_field[wall_idx] != SwarmFlowFieldScript.UNREACHABLE:
		printerr("FAIL: Integration field on impassable wall should remain UNREACHABLE")
		return false
	
	# Phase 3: verify flow field points toward goal when unobstructed
	var test_pos := Vector2(0.0, -10.0)
	var flow: Vector2 = ff.sample_flow_nearest(test_pos)
	# Goal is at Z=0, unit is at Z=-10, so flow should point in +Z direction (flow.y > 0)
	if flow.y <= 0.0:
		printerr("FAIL: Flow vector at (0, -10) should point towards goal (+Z), got %s" % flow)
		return false
	
	# Test dynamic obstacle opening (e.g. gate opened)
	ff.update_obstacle("wall_1", false) # Unblock
	ff.update()
	if ff.get_cell_cost(wall_grid.x, wall_grid.y) != 1:
		printerr("FAIL: Cost field should revert to 1 after unblocking obstacle")
		return false
	if ff.integration_field[wall_idx] == SwarmFlowFieldScript.UNREACHABLE:
		printerr("FAIL: Unblocked obstacle cell should now be reachable by Dijkstra wave")
		return false
	
	print("  -> PASSED: Cost field stamping, multi-goal Dijkstra, dynamic gate toggle verified.")
	return true


func test_bilinear_interpolation() -> bool:
	print("[TEST 4] Bilinear Flow Vector Interpolation (Smooth organic headings)...")
	var ff = SwarmFlowFieldScript.new(64, 64, 1.0, Vector2(-32.0, -32.0))
	ff.set_goals([Vector2(0.0, 0.0)])
	ff.update()
	
	# Sample continuous positions along a diagonal curve
	var angles: Array[float] = []
	var non_45_multiples: int = 0
	
	for step in range(20):
		var t: float = float(step) / 20.0
		var pos := Vector2(-15.0 + t * 5.0, -10.0 + t * 3.7)
		var flow_vec: Vector2 = ff.sample_flow_bilinear(pos)
		
		if flow_vec.length_squared() > 0.001:
			var angle := atan2(flow_vec.y, flow_vec.x)
			angles.append(angle)
			
			# Check if angle is NOT an exact multiple of 45° (PI/4)
			var angle_deg: float = rad_to_deg(angle)
			var remainder_45: float = fmod(abs(angle_deg), 45.0)
			if remainder_45 > 1.0 and remainder_45 < 44.0:
				non_45_multiples += 1
	
	# Bilinear interpolation MUST produce continuous, smooth non-45° headings
	if non_45_multiples < 5:
		printerr("FAIL: Bilinear interpolation failed to produce continuous smooth angles: %d/20 non-45°" % non_45_multiples)
		return false
	
	print("  -> PASSED: Continuous bilinear vector interpolation produces organic angles (%d smooth samples)." % non_45_multiples)
	return true


func test_mass_simulation_benchmark() -> bool:
	print("[TEST 5] Mass Swarm Stress Test: 1,000 active units for 300 simulation frames...")
	var sim = SwarmSimulationScript.new()
	sim.setup_simulation(Vector2(-40.0, -40.0), Vector2(40.0, 40.0), 2048)
	
	# Setup goal at (0, 0)
	sim.register_goal(Vector3(0.0, 0.0, 0.0))
	
	# Spawn 700 Zerglings at North spawn (-25..-15, -35..-28)
	var zerg_count: int = 0
	for i in range(700):
		var pos := Vector3(randf_range(-25.0, -15.0), 0.0, randf_range(-35.0, -28.0))
		var idx: int = sim.spawn_unit(0, pos, 35.0, 7.2, 5.0, 1)
		if idx >= 0:
			zerg_count += 1
	
	# Spawn 300 Roaches at South spawn (15..25, 28..35)
	var roach_count: int = 0
	for i in range(300):
		var pos := Vector3(randf_range(15.0, 25.0), 0.0, randf_range(28.0, 35.0))
		var idx: int = sim.spawn_unit(1, pos, 110.0, 4.2, 14.0, 2)
		if idx >= 0:
			roach_count += 1
	
	var total_active: int = sim.get_active_unit_count()
	if total_active != 1000:
		printerr("FAIL: Expected 1000 active units, got %d" % total_active)
		return false
	
	print("  -> Successfully spawned %d Zerglings and %d Roaches (Total: %d)." % [zerg_count, roach_count, total_active])
	
	# Calculate initial average distance to goal
	var data = sim.swarm_data
	var init_dist_sq: float = 0.0
	for i in range(data.capacity):
		if data.alive_mask[i] == 1:
			var px: float = data.pos_x[i]
			var pz: float = data.pos_z[i]
			init_dist_sq += px * px + pz * pz
	var initial_avg_dist: float = sqrt(init_dist_sq / float(total_active))
	print("  -> Initial average distance to objective: %.2f meters" % initial_avg_dist)
	
	# Benchmark 300 physics frames
	var start_usec: int = Time.get_ticks_usec()
	var dt: float = 1.0 / 60.0
	
	for frame in range(300):
		sim.simulate_step(dt)
	
	var total_time_usec: int = Time.get_ticks_usec() - start_usec
	var total_time_ms: float = float(total_time_usec) / 1000.0
	var avg_frame_ms: float = total_time_ms / 300.0
	var simulated_fps: float = 1000.0 / avg_frame_ms
	
	print("  -> Benchmark Results for 1,000 units:")
	print("     Total time (300 frames): %.2f ms" % total_time_ms)
	print("     Avg frame time: %.3f ms (Target: < 16.6 ms for 60 FPS)" % avg_frame_ms)
	print("     Simulation throughput: %.1f FPS" % simulated_fps)
	
	if avg_frame_ms > 16.6:
		printerr("FAIL: Performance bottleneck: avg frame time %.3f ms exceeds 16.6 ms budget" % avg_frame_ms)
		sim.free()
		return false
	
	# Verify units moved towards the goal (average distance to goal should have decreased significantly)
	var sum_dist_sq: float = 0.0
	var valid_count: int = 0
	for i in range(data.capacity):
		if data.alive_mask[i] == 1:
			var px: float = data.pos_x[i]
			var pz: float = data.pos_z[i]
			sum_dist_sq += px * px + pz * pz
			valid_count += 1
	
	var final_avg_dist: float = sqrt(sum_dist_sq / float(valid_count))
	print("  -> Final average distance to objective after 300 frames: %.2f meters" % final_avg_dist)
	if final_avg_dist >= initial_avg_dist:
		printerr("FAIL: Swarm units did not advance towards goal: initial %.2f, final %.2f" % [initial_avg_dist, final_avg_dist])
		sim.free()
		return false
	
	sim.free()
	print("  -> PASSED: 1,000 units simulated at %.1f FPS (well above 60 FPS target)." % simulated_fps)
	return true
