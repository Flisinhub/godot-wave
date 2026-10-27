extends SceneTree

## stress_p3_main_level_headless.gd
## Empirical stress harness for clean execution of main_level.tscn for 300+ frames in headless mode.
## Verifies:
## 1. Clean scene instantiation into active SceneTree without null errors or warnings.
## 2. 350 frames continuous simulation execution under Forward+ / Headless DisplayServer.
## 3. Frame time performance profiling (Avg, P95, Max, Min, FPS).
## 4. Scene node integrity (Hero, CommandCenter, SwarmSimulation, SC2HUDRoot).
## 5. Memory stability (no leak divergence across 350 frames).

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_reasons: Array[String] = []

var _level_node: Node = null
var _frame_times_usec: Array[int] = []

func _init() -> void:
	print("\n================================================================================")
	print("=== EMPIRICAL CHALLENGER: MAIN_LEVEL.TSCN 350-FRAME HEADLESS STABILITY ===")
	print("================================================================================\n")
	
	call_deferred("_run_test")

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

func _run_test() -> void:
	print(">> [1/4] Loading res://levels/main_level.tscn into active SceneTree...")
	var scene_res := load("res://levels/main_level.tscn") as PackedScene
	_assert(scene_res != null, "main_level.tscn loaded successfully", "PackedScene is null")
	
	_level_node = scene_res.instantiate()
	_assert(_level_node != null, "main_level.tscn instantiated", "Instantiated node is null")
	root.add_child(_level_node)
	
	# Wait 1 frame for ready
	await process_frame
	
	# Initial memory baseline AFTER entire level and assets have loaded into memory
	var initial_mem: int = OS.get_static_memory_usage()
	
	# Verify Scene Subsystem Integrity
	print("\n>> [2/4] Verifying Critical Scene Subsystems...")
	var cc = _level_node.get("command_center")
	var hero = _level_node.get("active_hero")
	var sim = _level_node.get("swarm_simulation")
	var hud = _level_node.get("sc2_hud_root")
	var econ = _level_node.get("economy_manager")
	
	_assert(cc != null, "CommandCenter present and bound", "CommandCenter is null")
	_assert(hero != null, "Allied Hero present and bound", "Hero is null")
	_assert(sim != null, "SwarmSimulation present and bound", "SwarmSimulation is null")
	_assert(hud != null, "SC2HUDRoot UI present and bound", "SC2HUDRoot is null")
	_assert(econ != null, "EconomyManager present and bound", "EconomyManager is null")
	
	# Step through 350 frames
	print("\n>> [3/4] Stepping 350 Frames in Headless Mode...")
	var target_frames: int = 350
	
	for f in range(target_frames):
		var t0: int = Time.get_ticks_usec()
		await process_frame
		var dt: int = Time.get_ticks_usec() - t0
		_frame_times_usec.append(dt)
	
	var final_mem: int = OS.get_static_memory_usage()
	var mem_delta_kb: float = float(final_mem - initial_mem) / 1024.0
	
	# 4. Performance profiling
	print("\n>> [4/4] Computing Frame-Time Profiling Telemetry across 350 Frames...")
	_frame_times_usec.sort()
	var sum_usec: int = 0
	for t in _frame_times_usec:
		sum_usec += t
	var avg_ms: float = float(sum_usec) / float(target_frames) / 1000.0
	var p95_ms: float = float(_frame_times_usec[int(target_frames * 0.95)]) / 1000.0
	var p99_ms: float = float(_frame_times_usec[int(target_frames * 0.99)]) / 1000.0
	var max_ms: float = float(_frame_times_usec[target_frames - 1]) / 1000.0
	var min_ms: float = float(_frame_times_usec[0]) / 1000.0
	var effective_fps: float = 1000.0 / avg_ms if avg_ms > 0.0 else 0.0
	
	print("\n================================================================================")
	print("--- MAIN_LEVEL.TSCN 350-FRAME PROFILING REPORT ---")
	print("================================================================================")
	print("Frames Stepped:              %d frames" % target_frames)
	print("Average Frame Time:          %.2f ms (Equivalent: %.1f FPS)" % [avg_ms, effective_fps])
	print("95th Percentile (P95):       %.2f ms" % p95_ms)
	print("99th Percentile (P99):       %.2f ms" % p99_ms)
	print("Min / Max Frame Time:        %.2f ms / %.2f ms" % [min_ms, max_ms])
	print("Static Memory Delta:         %.1f KB" % mem_delta_kb)
	print("60 FPS Target (< 16.67 ms):  %s" % ("SATISFIED" if avg_ms < 16.67 else "EXCEEDED"))
	print("================================================================================")
	
	_assert(_frame_times_usec.size() == target_frames, "Successfully executed 350+ frames", "Stepped %d frames" % _frame_times_usec.size())
	_assert(avg_ms < 16.67, "Average headless frame time < 16.67 ms (60+ FPS)", "Avg was %.2f ms" % avg_ms)
	_assert(p95_ms < 33.33, "P95 frame time < 33.33 ms (30+ FPS floor)", "P95 was %.2f ms" % p95_ms)
	_assert(mem_delta_kb < 8192.0, "Static memory growth bounded (< 8 MB)", "Grew by %.1f KB" % mem_delta_kb)
	
	# Cleanup
	_level_node.queue_free()
	
	print("\n================================================================================")
	print("MAIN LEVEL HEADLESS STABILITY RESULTS:")
	print("Total Invariants Tested: %d" % total_tests)
	print("Passed:                  %d" % passed_tests)
	print("Failed:                  %d" % failed_tests)
	
	if failed_tests > 0:
		print("\u001b[31m[VERDICT: REQUEST_CHANGES] MAIN LEVEL STABILITY DEFECTS DETECTED:\u001b[0m")
		for r in failure_reasons:
			print("  - %s" % r)
		print("================================================================================")
		quit(1)
	else:
		print("\u001b[32m[VERDICT: APPROVE] MAIN LEVEL 350-FRAME HEADLESS STABILITY VERIFIED!\u001b[0m")
		print("================================================================================")
		quit(0)
