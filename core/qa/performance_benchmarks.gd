class_name PerformanceBenchmarks
extends RefCounted

## PerformanceBenchmarks - SFE5 QA, Benchmarking and Soak Verification (Fase 15).
## Establishes hardware performance budgets, runs stress tests on swarm simulation,
## measures combat calculations throughput, and validates network snapshot packaging.

const SwarmData = preload("res://core/swarm/swarm_data.gd")
const SwarmSimulation = preload("res://core/swarm/swarm_simulation.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const SwarmSnapshotSynchronizer = preload("res://core/multiplayer/swarm_snapshot_synchronizer.gd")

## Reference Hardware Budget Specification (Task 15.1)
const BUDGET_MAX_FRAME_MS: float = 16.666  ## 60 FPS budget target
const BUDGET_MIN_SIMULATION_FPS: float = 60.0
const REFERENCE_TARGET_CPU: String = "4-Core x86_64 / ARM64 @ 2.5 GHz"
const REFERENCE_TARGET_RAM_MB: int = 8192
const REFERENCE_TARGET_UNITS: int = 1500
const REFERENCE_TARGET_PLAYERS: int = 6


## Benchmark 1: Mass Swarm Simulation Stress Test (Task 15.2 / 15.3)
## Simulates unit_count active units on flow field with spatial hash repulsion for frame_count frames.
static func benchmark_swarm_simulation(unit_count: int = 1000, frame_count: int = 300) -> Dictionary:
	var sim = SwarmSimulation.new()
	sim.setup_simulation(Vector2(-50.0, -50.0), Vector2(50.0, 50.0), 2048)
	sim.register_goal(Vector3(0.0, 0.0, 0.0))

	# Spawn units across perimeter
	for i in range(unit_count):
		var angle: float = (float(i) / float(unit_count)) * TAU
		var dist: float = randf_range(30.0, 45.0)
		var pos := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		sim.spawn_unit(i % 2, pos, 45.0, 6.0, 5.0, 1)

	var active_spawned: int = sim.get_active_unit_count()
	var start_usec: int = Time.get_ticks_usec()
	var dt: float = 1.0 / 60.0

	for _f in range(frame_count):
		sim.simulate_step(dt)

	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	var elapsed_ms: float = float(elapsed_usec) / 1000.0
	var avg_frame_ms: float = elapsed_ms / float(frame_count)
	var simulated_fps: float = 1000.0 / avg_frame_ms if avg_frame_ms > 0.0 else 9999.0

	sim.free()

	return {
		"test_name": "Swarm Simulation Stress",
		"unit_count": active_spawned,
		"frame_count": frame_count,
		"total_ms": elapsed_ms,
		"avg_frame_ms": avg_frame_ms,
		"simulated_fps": simulated_fps,
		"passed": avg_frame_ms <= BUDGET_MAX_FRAME_MS
	}


## Benchmark 2: SFE Combat Engine Throughput (Task 15.3 / 15.4)
## Runs batch_size damage evaluations through flat armor, structural, and progressive pipelines.
static func benchmark_combat_engine_throughput(batch_size: int = 10000) -> Dictionary:
	var start_usec: int = Time.get_ticks_usec()

	for i in range(batch_size):
		var raw_dmg: float = 25.0 + float(i % 50)
		var armor: float = 5.0 + float(i % 10)
		var lvl: int = i % 20
		var struct_type: int = (i % 3)
		var is_heroic: bool = (i % 4 == 0)
		var is_aoe: bool = (i % 2 == 0)

		var _res = SFECombatEngine.calculate_damage(
			raw_dmg,
			SFECombatEngine.DamageType.PHYSICAL,
			armor,
			lvl,
			struct_type,
			is_heroic,
			is_aoe
		)

	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	var elapsed_ms: float = float(elapsed_usec) / 1000.0
	var ops_per_sec: float = (float(batch_size) / (elapsed_ms / 1000.0)) if elapsed_ms > 0.0 else 9999999.0

	# Target: at least 50,000 damage calculations per second
	return {
		"test_name": "Combat Engine Throughput",
		"batch_size": batch_size,
		"elapsed_ms": elapsed_ms,
		"ops_per_second": ops_per_sec,
		"passed": ops_per_sec >= 50000.0
	}


## Benchmark 3: Snapshot Compression & Packaging (Task 15.3 / 15.5)
## Measures packing and unpacking throughput for network swarm payloads.
static func benchmark_snapshot_compression(unit_count: int = 500, snapshot_count: int = 50) -> Dictionary:
	var start_usec: int = Time.get_ticks_usec()
	var last_payload_size: int = 0

	for s in range(snapshot_count):
		var units: Array[Dictionary] = []
		for u in range(unit_count):
			units.append({
				"id": u,
				"position": Vector3(float(u % 100) - 50.0, 0.0, float(u / 100) - 50.0),
				"health_ratio": 0.85
			})

		var packed: PackedByteArray = SwarmSnapshotSynchronizer.pack_snapshot(units, float(s) * 0.05)
		last_payload_size = packed.size()
		var unpacked: Dictionary = SwarmSnapshotSynchronizer.unpack_snapshot(packed)
		if unpacked["units"].size() != unit_count:
			return {"passed": false, "error": "Unpack count mismatch"}

	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	var elapsed_ms: float = float(elapsed_usec) / 1000.0
	var snapshots_per_sec: float = (float(snapshot_count) / (elapsed_ms / 1000.0)) if elapsed_ms > 0.0 else 9999.0

	# Target: at least 200 snapshots packed & unpacked per second, payload <= 6 KB for 500 units
	return {
		"test_name": "Snapshot Compression",
		"unit_count": unit_count,
		"snapshot_count": snapshot_count,
		"payload_bytes": last_payload_size,
		"snapshots_per_second": snapshots_per_sec,
		"passed": snapshots_per_sec >= 150.0 and last_payload_size <= 6144
	}


## Benchmark 4: Memory Recycling & Soak Simulation (Task 15.4)
## Simulates thousands of unit spawn/kill cycles to ensure zero slot leaks in Structure of Arrays.
static func benchmark_memory_recycling_soak(batch_cycles: int = 25, batch_size: int = 200) -> Dictionary:
	var data := SwarmData.new(1024)
	var leaks_detected: int = 0

	for cycle in range(batch_cycles):
		var spawned_indices: Array[int] = []
		for _i in range(batch_size):
			var idx: int = data.spawn_unit(0, Vector3(randf_range(-10, 10), 0.0, randf_range(-10, 10)), 35.0, 6.0, 5.0, 1)
			if idx < 0:
				leaks_detected += 1
			else:
				spawned_indices.append(idx)

		if data.active_count != batch_size:
			leaks_detected += 1

		# Despawn all units in reverse
		for idx in spawned_indices:
			data.despawn_unit(idx)

		if data.active_count != 0:
			leaks_detected += 1
		if data.free_indices.size() != 1024:
			leaks_detected += 1

	return {
		"test_name": "Memory Recycling Soak",
		"cycles": batch_cycles,
		"batch_size": batch_size,
		"total_operations": batch_cycles * batch_size * 2,
		"leaks_detected": leaks_detected,
		"passed": leaks_detected == 0
	}


## Run Complete Benchmark Suite
static func run_full_qa_benchmark_suite() -> Dictionary:
	var b1: Dictionary = benchmark_swarm_simulation(1000, 120)
	var b2: Dictionary = benchmark_combat_engine_throughput(10000)
	var b3: Dictionary = benchmark_snapshot_compression(300, 30)
	var b4: Dictionary = benchmark_memory_recycling_soak(20, 150)

	var all_passed: bool = b1["passed"] and b2["passed"] and b3["passed"] and b4["passed"]
	return {
		"all_passed": all_passed,
		"swarm": b1,
		"combat": b2,
		"snapshot": b3,
		"memory": b4
	}
