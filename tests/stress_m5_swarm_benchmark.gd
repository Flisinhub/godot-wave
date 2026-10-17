extends SceneTree

# stress_m5_swarm_benchmark.gd
# Empirical Challenger 1 profiling & benchmark harness for Milestone 5

const SwarmSimulation = preload("res://core/swarm/swarm_simulation.gd")
const SwarmUnitArchetype = preload("res://data/swarm/swarm_unit_archetype.gd")

func _init() -> void:
	print("\n============================================================")
	print("=== EMPIRICAL CHALLENGER 1: SWARM BENCHMARK & PROFILER ===")
	print("============================================================\n")
	
	_profile_1000_breakdown()
	_benchmark_scales()
	quit(0)

func _profile_1000_breakdown() -> void:
	print("--- PROFILING SIMULATE_STEP BREAKDOWN (1,000 UNITS) ---")
	var sim := SwarmSimulation.new()
	sim.setup_simulation(Vector2(-64, -64), Vector2(64, 64), 2048)
	sim.register_goal(Vector3.ZERO)
	
	var zerg_arch: SwarmUnitArchetype = load("res://data/swarm/zergling_archetype.tres") as SwarmUnitArchetype
	if zerg_arch:
		sim.register_archetype(zerg_arch)
		
	sim.spawn_wave(0, 1000, Vector3(0, 0, 30), 20.0)
	
	# Warmup
	for w in range(10):
		sim.simulate_step(0.016)
		
	var t_ff: int = 0
	var t_hash_rebuild: int = 0
	var t_flow_sample: int = 0
	var t_sep_force: int = 0
	var t_unit_math: int = 0
	var t_resolve_overlaps: int = 0
	var t_total: int = 0
	
	var steps: int = 50
	var delta: float = 0.01667
	
	for s in range(steps):
		var t0: int = Time.get_ticks_usec()
		
		# Step 1: Flow Field Update
		var t_step_start: int = Time.get_ticks_usec()
		if sim.flow_field:
			sim.flow_field.update()
		t_ff += (Time.get_ticks_usec() - t_step_start)
		
		# Step 2: Spatial Hash Rebuild
		t_step_start = Time.get_ticks_usec()
		if sim.spatial_hash and sim.swarm_data:
			sim.spatial_hash.rebuild(sim.swarm_data)
		t_hash_rebuild += (Time.get_ticks_usec() - t_step_start)
		
		# Step 3: Unit Loop
		var cap: int = sim.swarm_data.capacity
		var alive: PackedByteArray = sim.swarm_data.alive_mask
		var px: PackedFloat32Array = sim.swarm_data.pos_x
		var pz: PackedFloat32Array = sim.swarm_data.pos_z
		var vx: PackedFloat32Array = sim.swarm_data.vel_x
		var vz: PackedFloat32Array = sim.swarm_data.vel_z
		var headings: PackedFloat32Array = sim.swarm_data.headings
		var speeds: PackedFloat32Array = sim.swarm_data.move_speeds
		var arch_ids: PackedInt32Array = sim.swarm_data.archetype_ids
		var min_bound_x: float = sim.map_bounds_min.x + 0.5
		var max_bound_x: float = sim.map_bounds_max.x - 0.5
		var min_bound_z: float = sim.map_bounds_min.y + 0.5
		var max_bound_z: float = sim.map_bounds_max.y - 0.5
		var accel_delta: float = sim.acceleration * delta
		var turn_weight: float = clampf(sim.turn_speed * delta, 0.0, 1.0)
		var active_limit: int = sim.swarm_data.active_count
		var processed: int = 0
		var f_weight: float = sim.flow_weight
		var s_weight: float = sim.separation_weight
		var def_sep_rad: float = sim.default_separation_radius
		var cached_sep := sim._cached_sep_radius
		var cached_sep_size := cached_sep.size()
		
		for i in range(cap):
			if alive[i] == 0:
				continue
			var cur_px: float = px[i]
			var cur_pz: float = pz[i]
			
			var t_sub := Time.get_ticks_usec()
			var flow_vec: Vector2 = sim.flow_field.sample_flow_bilinear_coords(cur_px, cur_pz) if sim.flow_field else Vector2.ZERO
			t_flow_sample += (Time.get_ticks_usec() - t_sub)
			
			var a_id: int = arch_ids[i]
			var sep_radius: float = cached_sep[a_id] if (a_id >= 0 and a_id < cached_sep_size) else def_sep_rad
			
			t_sub = Time.get_ticks_usec()
			var sep_force: Vector2 = sim.spatial_hash.compute_separation_force(i, sim.swarm_data, sep_radius, 8) if sim.spatial_hash else Vector2.ZERO
			t_sep_force += (Time.get_ticks_usec() - t_sub)
			
			t_sub = Time.get_ticks_usec()
			var sep_len_sq: float = sep_force.x * sep_force.x + sep_force.y * sep_force.y
			var des_x: float = flow_vec.x * f_weight + sep_force.x * s_weight
			var des_z: float = flow_vec.y * f_weight + sep_force.y * s_weight
			var des_len_sq: float = des_x * des_x + des_z * des_z
			if des_len_sq > 0.001:
				var inv_des_len: float = 1.0 / sqrt(des_len_sq)
				des_x *= inv_des_len
				des_z *= inv_des_len
			elif flow_vec.length_squared() > 0.001:
				des_x = flow_vec.x
				des_z = flow_vec.y
			else:
				des_x = 0.0
				des_z = 0.0
			var spd: float = speeds[i]
			var cur_vx: float = vx[i]
			var cur_vz: float = vz[i]
			var target_vx: float = des_x * spd
			var target_vz: float = des_z * spd
			var diff_x: float = target_vx - cur_vx
			var diff_z: float = target_vz - cur_vz
			var diff_sq: float = diff_x * diff_x + diff_z * diff_z
			var eff_accel_delta: float = accel_delta * 2.5 if sep_len_sq > 4.0 else accel_delta
			var eff_accel_sq: float = eff_accel_delta * eff_accel_delta
			var new_vx: float = target_vx
			var new_vz: float = target_vz
			if diff_sq > eff_accel_sq:
				var inv_diff: float = eff_accel_delta / sqrt(diff_sq)
				new_vx = cur_vx + diff_x * inv_diff
				new_vz = cur_vz + diff_z * inv_diff
			vx[i] = new_vx
			vz[i] = new_vz
			var next_x: float = cur_px + new_vx * delta
			var next_z: float = cur_pz + new_vz * delta
			px[i] = clampf(next_x, min_bound_x, max_bound_x)
			pz[i] = clampf(next_z, min_bound_z, max_bound_z)
			var move_sq: float = new_vx * new_vx + new_vz * new_vz
			if move_sq > 0.05:
				var target_heading: float = atan2(-new_vx, -new_vz)
				headings[i] = lerp_angle(headings[i], target_heading, turn_weight)
			t_unit_math += (Time.get_ticks_usec() - t_sub)
			
			processed += 1
			if processed >= active_limit:
				break
				
		# Step 4: Resolve overlaps
		t_step_start = Time.get_ticks_usec()
		if sim.spatial_hash and sim.swarm_data:
			sim.spatial_hash.resolve_unit_overlaps(sim.swarm_data, 0.095, 2)
		t_resolve_overlaps += (Time.get_ticks_usec() - t_step_start)
		
		t_total += (Time.get_ticks_usec() - t0)
		
	print("Profile Results across %d steps (1,000 units):" % steps)
	print("  Total Step Avg:      %.2f ms" % (float(t_total) / float(steps) / 1000.0))
	print("  - Flow Field Update: %.2f ms" % (float(t_ff) / float(steps) / 1000.0))
	print("  - Spatial Hash Rebld:%.2f ms" % (float(t_hash_rebuild) / float(steps) / 1000.0))
	print("  - Flow Sampling:     %.2f ms" % (float(t_flow_sample) / float(steps) / 1000.0))
	print("  - Compute Sep Force: %.2f ms" % (float(t_sep_force) / float(steps) / 1000.0))
	print("  - Unit Math/Clamp:   %.2f ms" % (float(t_unit_math) / float(steps) / 1000.0))
	print("  - Resolve Overlaps:  %.2f ms" % (float(t_resolve_overlaps) / float(steps) / 1000.0))
	print("")
	sim.free()

func _benchmark_scales() -> void:
	print("--- BENCHMARK AT MULTIPLE UNIT SCALES (Standard simulate_step) ---")
	for unit_count in [500, 1000, 1500, 2000]:
		var sim := SwarmSimulation.new()
		sim.setup_simulation(Vector2(-64, -64), Vector2(64, 64), 2500)
		sim.register_goal(Vector3.ZERO)
		var zerg_arch: SwarmUnitArchetype = load("res://data/swarm/zergling_archetype.tres") as SwarmUnitArchetype
		if zerg_arch:
			sim.register_archetype(zerg_arch)
		sim.spawn_wave(0, unit_count, Vector3(0, 0, 30), 20.0)
		
		# Warmup 10 ticks
		for w in range(10):
			sim.simulate_step(0.01667)
			
		var ticks: Array[int] = []
		var total_usec: int = 0
		var steps: int = 100
		for s in range(steps):
			var t0: int = Time.get_ticks_usec()
			sim.simulate_step(0.01667)
			var dt: int = Time.get_ticks_usec() - t0
			ticks.append(dt)
			total_usec += dt
			
		ticks.sort()
		var avg_ms: float = (float(total_usec) / float(steps)) / 1000.0
		var p95_ms: float = float(ticks[int(steps * 0.95)]) / 1000.0
		var max_ms: float = float(ticks[steps - 1]) / 1000.0
		var min_ms: float = float(ticks[0]) / 1000.0
		print("[%4d Units, 100 steps] Avg: %5.2f ms | P95: %5.2f ms | Max: %5.2f ms | Min: %5.2f ms | Budget <16ms: %s" % [
			unit_count, avg_ms, p95_ms, max_ms, min_ms, "PASS" if avg_ms < 16.0 else "FAIL"
		])
		sim.free()
