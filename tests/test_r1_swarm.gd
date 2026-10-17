extends "res://tests/test_base.gd"

## Test Suite for Requirement R1:
## Mass Swarm Simulation, SoA Data Engine, and Flow Field Navigation.

const SwarmDataScript = preload("res://core/swarm/swarm_data.gd")
const SwarmFlowFieldScript = preload("res://core/swarm/swarm_flow_field.gd")
const SwarmSpatialHashScript = preload("res://core/swarm/swarm_spatial_hash.gd")
const SwarmSimulationScript = preload("res://core/swarm/swarm_simulation.gd")

func test_cost_field_static_and_dynamic() -> Dictionary:
	var ff = SwarmFlowFieldScript.new(32, 32, 1.0, Vector2(-16.0, -16.0))
	
	# Default cells should be passable (cost 1)
	if not assert_eq(ff.get_cell_cost(0, 0), 1, "Default cell (0,0) should have cost 1"):
		return get_last_failure()
	if not assert_eq(ff.get_cell_cost(15, 15), 1, "Default cell (15,15) should have cost 1"):
		return get_last_failure()
		
	# Static cell cost modification
	ff.set_cell_cost(5, 5, 255)
	if not assert_eq(ff.get_cell_cost(5, 5), 255, "Modified cell (5,5) should have cost 255"):
		return get_last_failure()
		
	# Stamping dynamic obstacle AABB (e.g. bunker or wall footprint)
	ff.stamp_obstacle_aabb(Vector2(-2.0, -2.0), Vector2(2.0, 2.0), 255)
	var g_center := ff.world_to_grid(Vector2.ZERO)
	if not assert_eq(ff.get_cell_cost(g_center.x, g_center.y), 255, "Stamped obstacle center must be impassable (255)"):
		return get_last_failure()
		
	# Register and update dynamic obstacle (e.g. gate open/close)
	var gate_id := &"test_gate_1"
	ff.register_obstacle(gate_id, Vector2(5.0, 5.0), Vector2(7.0, 7.0), true)
	ff.rebuild_cost_field()
	var g_gate := ff.world_to_grid(Vector2(6.0, 6.0))
	if not assert_eq(ff.get_cell_cost(g_gate.x, g_gate.y), 255, "Registered blocking gate should be impassable"):
		return get_last_failure()
		
	# Open gate -> should become passable (cost 1)
	ff.update_obstacle(gate_id, false)
	ff.rebuild_cost_field()
	if not assert_eq(ff.get_cell_cost(g_gate.x, g_gate.y), 1, "Opened gate should be passable (cost 1)"):
		return get_last_failure()
		
	# Unregister obstacle
	ff.unregister_obstacle(gate_id)
	ff.rebuild_cost_field()
	if not assert_eq(ff.get_cell_cost(g_gate.x, g_gate.y), 1, "Unregistered gate should remain passable"):
		return get_last_failure()

	return pass_test()

func test_cost_field_boundary_values() -> Dictionary:
	var ff = SwarmFlowFieldScript.new(16, 16, 1.0, Vector2(-8.0, -8.0))
	
	# Clamping cost values
	ff.set_cell_cost(0, 0, -50)
	if not assert_eq(ff.get_cell_cost(0, 0), 1, "Negative cost should clamp to 1"):
		return get_last_failure()
		
	ff.set_cell_cost(1, 1, 999)
	if not assert_eq(ff.get_cell_cost(1, 1), 255, "Excessive cost should clamp to 255"):
		return get_last_failure()
		
	# Out of bounds queries should return COST_IMPASSABLE (255)
	if not assert_eq(ff.get_cell_cost(-1, 0), 255, "Out of bounds negative X should return 255"):
		return get_last_failure()
	if not assert_eq(ff.get_cell_cost(16, 0), 255, "Out of bounds positive X should return 255"):
		return get_last_failure()
	if not assert_eq(ff.get_cell_cost(0, -1), 255, "Out of bounds negative Z should return 255"):
		return get_last_failure()
	if not assert_eq(ff.get_cell_cost(0, 16), 255, "Out of bounds positive Z should return 255"):
		return get_last_failure()

	return pass_test()

func test_integration_field_dijkstra() -> Dictionary:
	var ff = SwarmFlowFieldScript.new(32, 32, 1.0, Vector2(-16.0, -16.0))
	
	# Goal at world center (0, 0)
	var goal_world := Vector2.ZERO
	var goal_grid := ff.world_to_grid(goal_world)
	ff.set_goals([goal_world])
	ff.compute_integration_field()
	
	# Goal cell integration value must be strictly 0
	var goal_idx: int = goal_grid.y * ff.width + goal_grid.x
	if not assert_eq(ff.integration_field[goal_idx], 0, "Goal cell integration cost must be 0"):
		return get_last_failure()
		
	# Orthogonal neighbors should have cost 10
	var east_idx: int = goal_grid.y * ff.width + (goal_grid.x + 1)
	if not assert_eq(ff.integration_field[east_idx], 10, "Orthogonal east neighbor should have cost 10"):
		return get_last_failure()
		
	# Diagonal neighbor should have cost 14
	var ne_idx: int = (goal_grid.y - 1) * ff.width + (goal_grid.x + 1)
	if not assert_eq(ff.integration_field[ne_idx], 14, "Diagonal NE neighbor should have cost 14"):
		return get_last_failure()
		
	# Integration gradient strictly increases as distance from goal increases
	var far_world := Vector2(8.0, 0.0)
	var far_grid := ff.world_to_grid(far_world)
	var far_idx: int = far_grid.y * ff.width + far_grid.x
	if not assert_gt(ff.integration_field[far_idx], ff.integration_field[east_idx], "Distant cell cost must be greater than near cell"):
		return get_last_failure()
		
	# Multi-goal integration: two goals at (-10, 0) and (10, 0)
	ff.set_goals([Vector2(-10.0, 0.0), Vector2(10.0, 0.0)])
	ff.compute_integration_field()
	var g1 := ff.world_to_grid(Vector2(-10.0, 0.0))
	var g2 := ff.world_to_grid(Vector2(10.0, 0.0))
	if not assert_eq(ff.integration_field[g1.y * ff.width + g1.x], 0, "Goal 1 must be 0"):
		return get_last_failure()
	if not assert_eq(ff.integration_field[g2.y * ff.width + g2.x], 0, "Goal 2 must be 0"):
		return get_last_failure()

	return pass_test()

func test_integration_field_unreachable_cells() -> Dictionary:
	var ff = SwarmFlowFieldScript.new(32, 32, 1.0, Vector2(-16.0, -16.0))
	
	# Goal outside
	ff.set_goals([Vector2(-10.0, -10.0)])
	
	# Create an impenetrable square perimeter box
	for x in range(10, 16):
		ff.set_cell_cost(x, 10, 255)
		ff.set_cell_cost(x, 15, 255)
	for z in range(10, 16):
		ff.set_cell_cost(10, z, 255)
		ff.set_cell_cost(15, z, 255)
		
	ff.compute_integration_field()
	
	# Inside the impenetrable box, cells must remain UNREACHABLE (999999)
	var inside_idx: int = 12 * ff.width + 12
	if not assert_eq(ff.integration_field[inside_idx], ff.UNREACHABLE, "Enclosed cells must be UNREACHABLE (999999)"):
		return get_last_failure()

	return pass_test()

func test_bilinear_flow_smoothness() -> Dictionary:
	var ff = SwarmFlowFieldScript.new(32, 32, 1.0, Vector2(-16.0, -16.0))
	ff.set_goals([Vector2.ZERO])
	ff.update()
	
	# Test sampling at integer coordinate vs fractional coordinates
	var sample_pos_1 := Vector2(5.0, 5.0)
	var flow_1 := ff.sample_flow_bilinear(sample_pos_1)
	if not assert_gt(flow_1.length_squared(), 0.1, "Flow vector at (5, 5) must be non-zero"):
		return get_last_failure()
	if not assert_almost_eq(flow_1.length(), 1.0, 0.01, "Sampled flow vector must be normalized"):
		return get_last_failure()
		
	# Sample intermediate fractional positions
	var sample_pos_2 := Vector2(5.25, 5.75)
	var flow_2 := ff.sample_flow_bilinear(sample_pos_2)
	if not assert_almost_eq(flow_2.length(), 1.0, 0.01, "Fractional sampled flow vector must be normalized"):
		return get_last_failure()
		
	# Direction should point generally towards world origin (negative X, negative Z)
	if not assert_lt(flow_2.x, 0.0, "Flow vector X should point towards origin (<0)"):
		return get_last_failure()
	if not assert_lt(flow_2.y, 0.0, "Flow vector Z should point towards origin (<0)"):
		return get_last_failure()

	return pass_test()

func test_soa_swarm_memory_layout() -> Dictionary:
	var cap: int = 128
	var data = SwarmDataScript.new(cap)
	
	if not assert_eq(data.capacity, cap, "Capacity should match requested 128"):
		return get_last_failure()
	if not assert_eq(data.active_count, 0, "Initial active count must be 0"):
		return get_last_failure()
	if not assert_eq(data.free_indices.size(), cap, "Free indices count should equal capacity"):
		return get_last_failure()
		
	# Spawn 5 units
	var spawned_indices: Array[int] = []
	for i in range(5):
		var idx: int = data.spawn_unit(0, Vector3(float(i * 2), 0.0, float(i * 3)), 35.0, 7.2, 5.0)
		if not assert_ge(idx, 0, "Spawn unit should return valid non-negative index"):
			return get_last_failure()
		spawned_indices.append(idx)
		
	if not assert_eq(data.active_count, 5, "Active count after 5 spawns must be 5"):
		return get_last_failure()
	if not assert_true(data.is_alive(spawned_indices[2]), "Unit at index 2 must be alive"):
		return get_last_failure()
		
	# Test O(1) slot recycling
	var freed_idx: int = spawned_indices[2]
	data.despawn_unit(freed_idx)
	if not assert_eq(data.active_count, 4, "Active count after despawn must be 4"):
		return get_last_failure()
	if not assert_false(data.is_alive(freed_idx), "Despawned unit must not be alive"):
		return get_last_failure()
		
	# Next spawn should reuse the freed index
	var recycled_idx: int = data.spawn_unit(1, Vector3(99.0, 0.0, 99.0), 50.0, 5.0, 10.0)
	if not assert_eq(recycled_idx, freed_idx, "Spawned unit must reuse free slot via O(1) recycling"):
		return get_last_failure()
		
	# Test damage and lethal blow
	var victim_idx: int = spawned_indices[0]
	var died: bool = data.apply_damage(victim_idx, 20.0)
	if not assert_false(died, "Non-lethal damage should not report death"):
		return get_last_failure()
	if not assert_almost_eq(data.current_hp[victim_idx], 15.0, 0.01, "Current HP should be reduced"):
		return get_last_failure()
		
	died = data.apply_damage(victim_idx, 20.0)
	if not assert_true(died, "Lethal damage should report death"):
		return get_last_failure()
	if not assert_false(data.is_alive(victim_idx), "Dead unit should be inactive"):
		return get_last_failure()

	return pass_test()

func test_spatial_hash_grid() -> Dictionary:
	var bounds_min := Vector2(-32.0, -32.0)
	var bounds_max := Vector2(32.0, 32.0)
	var hash_grid = SwarmSpatialHashScript.new(bounds_min, bounds_max, 2.0, 128)
	var data = SwarmDataScript.new(128)
	
	# Spawn units near each other
	var u0 := data.spawn_unit(0, Vector3(0.0, 0.0, 0.0), 35.0, 7.0, 5.0)
	var u1 := data.spawn_unit(0, Vector3(0.5, 0.0, 0.0), 35.0, 7.0, 5.0)  # 0.5m away
	var u2 := data.spawn_unit(0, Vector3(25.0, 0.0, 25.0), 35.0, 7.0, 5.0) # distant
	
	hash_grid.rebuild(data)
	
	# Query neighbors around u0
	var pos_u0 := data.get_position_2d(u0)
	var neighbors = hash_grid.query_radius(pos_u0, 1.5, data)
	if not assert_true(neighbors.has(u1), "u1 should be detected as neighbor of u0"):
		return get_last_failure()
	if not assert_false(neighbors.has(u2), "u2 is distant and should not be a neighbor"):
		return get_last_failure()
		
	# Test separation force calculation
	var sep_force: Vector2 = hash_grid.compute_separation_force(u0, data, 1.5)
	if not assert_gt(sep_force.length_squared(), 0.01, "Separation force should be non-zero when neighbor is close"):
		return get_last_failure()
	# u1 is at (0.5, 0), so force on u0 should push left (-X)
	if not assert_lt(sep_force.x, 0.0, "Separation force on u0 should push away from u1 (-X direction)"):
		return get_last_failure()

	return pass_test()

func test_1000_units_stress_performance() -> Dictionary:
	var sim = SwarmSimulationScript.new()
	sim.max_units = 1500
	sim.init_subsystems()
	
	# Set goal
	sim.register_goal(Vector3.ZERO)
	sim.flow_field.update()
	
	# Spawn 1,000 active units
	var spawn_count: int = 1000
	for i in range(spawn_count):
		var angle: float = float(i) * 0.1
		var radius: float = 15.0 + float(i % 20) * 0.5
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var idx := sim.spawn_unit(0, pos, 35.0, 7.2, 5.0)
		if not assert_ge(idx, 0, "Spawning unit up to 1000 must succeed"):
			return get_last_failure()
			
	if not assert_eq(sim.get_active_unit_count(), 1000, "Active unit count must reach exactly 1,000"):
		return get_last_failure()
		
	# Benchmark 100 simulation physics ticks
	var start_time: int = Time.get_ticks_usec()
	var tick_count: int = 100
	var delta: float = 0.01667 # 60 FPS tick
	
	for t in range(tick_count):
		sim.simulate_step(delta)
		
	var total_elapsed_usec: int = Time.get_ticks_usec() - start_time
	var avg_tick_ms: float = float(total_elapsed_usec) / (float(tick_count) * 1000.0)
	
	# All 1,000 units must still be alive and within map boundaries
	if not assert_eq(sim.get_active_unit_count(), 1000, "All 1,000 units must survive simulation step"):
		return get_last_failure()
		
	# Performance assertion: average tick budget < 16.0 ms
	if not assert_lt(avg_tick_ms, 16.0, "Average tick for 1,000 units must be under 16.0 ms (got %.2f ms)" % avg_tick_ms):
		sim.free()
		return get_last_failure()

	sim.free()
	return pass_test()

func test_flow_field_at_goal_is_zero() -> Dictionary:
	var ff = SwarmFlowFieldScript.new(16, 16, 1.0, Vector2(-8.0, -8.0))
	var goal_pos := Vector2.ZERO
	ff.set_goals([goal_pos])
	ff.update()
	
	# The goal cell itself has integration cost 0 and should produce Vector2.ZERO
	var g_flow := ff.sample_flow_nearest(goal_pos)
	if not assert_eq(g_flow, Vector2.ZERO, "Flow vector at goal cell must be Vector2.ZERO"):
		return get_last_failure()
	return pass_test()

func test_flow_field_multi_goal_nearest_routing() -> Dictionary:
	var ff = SwarmFlowFieldScript.new(32, 32, 1.0, Vector2(-16.0, -16.0))
	var goal_west := Vector2(-10.0, 0.0)
	var goal_east := Vector2(10.0, 0.0)
	ff.set_goals([goal_west, goal_east])
	ff.update()
	
	# Point at (-8, 0) should route towards west goal (negative X)
	var flow_w := ff.sample_flow_bilinear(Vector2(-8.0, 0.0))
	if not assert_lt(flow_w.x, 0.0, "Unit near west goal should flow westward (-X)"):
		return get_last_failure()
		
	# Point at (8, 0) should route towards east goal (positive X)
	var flow_e := ff.sample_flow_bilinear(Vector2(8.0, 0.0))
	if not assert_gt(flow_e.x, 0.0, "Unit near east goal should flow eastward (+X)"):
		return get_last_failure()
		
	return pass_test()

func test_soa_sparse_allocations_and_active_indices() -> Dictionary:
	var data = SwarmDataScript.new(64)
	var idx1 := data.spawn_unit(0, Vector3(1, 0, 1), 10.0, 5.0, 2.0)
	var idx2 := data.spawn_unit(0, Vector3(2, 0, 2), 10.0, 5.0, 2.0)
	var idx3 := data.spawn_unit(0, Vector3(3, 0, 3), 10.0, 5.0, 2.0)
	
	# Despawn middle unit
	data.despawn_unit(idx2)
	
	var active_indices := data.get_active_indices()
	if not assert_eq(active_indices.size(), 2, "Active indices must contain exactly 2 elements"):
		return get_last_failure()
	if not assert_true(active_indices.has(idx1), "Active indices must contain idx1"):
		return get_last_failure()
	if not assert_true(active_indices.has(idx3), "Active indices must contain idx3"):
		return get_last_failure()
	if not assert_false(active_indices.has(idx2), "Active indices must NOT contain despawned idx2"):
		return get_last_failure()
		
	return pass_test()

func test_soa_zero_damage_no_op() -> Dictionary:
	var data = SwarmDataScript.new(16)
	var idx := data.spawn_unit(0, Vector3.ZERO, 50.0, 5.0, 5.0)
	var died := data.apply_damage(idx, 0.0)
	if not assert_false(died, "Zero damage must not kill unit"):
		return get_last_failure()
	if not assert_almost_eq(data.current_hp[idx], 50.0, 0.01, "Zero damage must not reduce HP"):
		return get_last_failure()
	return pass_test()

func test_boids_separation_zero_radius() -> Dictionary:
	var hash_grid = SwarmSpatialHashScript.new(Vector2(-10, -10), Vector2(10, 10), 2.0, 16)
	var data = SwarmDataScript.new(16)
	var u0 := data.spawn_unit(0, Vector3(0, 0, 0), 10.0, 5.0, 1.0)
	data.spawn_unit(0, Vector3(0.1, 0, 0), 10.0, 5.0, 1.0)
	hash_grid.rebuild(data)
	
	var force := hash_grid.compute_separation_force(u0, data, 0.0)
	if not assert_eq(force, Vector2.ZERO, "Zero separation radius must return Vector2.ZERO"):
		return get_last_failure()
	return pass_test()

