class_name TestPerformanceAndQA
extends RefCounted

## TestPerformanceAndQA - Automated performance, benchmarking & soak verification suite (Fase 15).

const PerformanceBenchmarks = preload("res://core/qa/performance_benchmarks.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func run_all() -> bool:
	print(">> Running Suite: SFE5 Performance & QA Verification")
	_tests_passed = 0
	_tests_failed = 0

	test_reference_hardware_budget_invariants()
	test_swarm_simulation_benchmark_performance()
	test_combat_engine_throughput_benchmark()
	test_snapshot_compression_bandwidth()
	test_memory_recycling_soak_zero_leaks()

	return _tests_failed == 0


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % msg)


## Test 1: Hardware Budget & Target Invariants (Task 15.1)
func test_reference_hardware_budget_invariants() -> void:
	_assert_true(PerformanceBenchmarks.BUDGET_MAX_FRAME_MS <= 16.67, "Frame budget set to <= 16.67 ms (60 FPS)")
	_assert_true(PerformanceBenchmarks.BUDGET_MIN_SIMULATION_FPS >= 60.0, "Min simulation FPS target is 60.0")
	_assert_true(PerformanceBenchmarks.REFERENCE_TARGET_RAM_MB == 8192, "Target RAM reference is 8 GB")
	_assert_true(PerformanceBenchmarks.REFERENCE_TARGET_UNITS >= 1000, "Reference target units is at least 1,000")


## Test 2: Mass Swarm Simulation Stress Benchmark (Task 15.2 / 15.3)
func test_swarm_simulation_benchmark_performance() -> void:
	# Run 500 units for 60 frames in unit test to ensure fast, predictable CI time
	var result: Dictionary = PerformanceBenchmarks.benchmark_swarm_simulation(500, 60)
	_assert_true(result["passed"], "500 units simulated within frame budget (avg %.2f ms, %.1f FPS)" % [result["avg_frame_ms"], result["simulated_fps"]])
	_assert_true(result["unit_count"] == 500, "500 active units verified")


## Test 3: Combat Engine Calculations Throughput (Task 15.3)
func test_combat_engine_throughput_benchmark() -> void:
	var result: Dictionary = PerformanceBenchmarks.benchmark_combat_engine_throughput(5000)
	_assert_true(result["passed"], "5000 combat calculations achieved %.0f ops/sec (target >= 50k)" % result["ops_per_second"])


## Test 4: Snapshot Compression & Packaging (Task 15.3 / 15.5)
func test_snapshot_compression_bandwidth() -> void:
	var result: Dictionary = PerformanceBenchmarks.benchmark_snapshot_compression(200, 20)
	_assert_true(result["passed"], "200 units snapshot compressed at %.0f snapshots/sec (size %d bytes)" % [result["snapshots_per_second"], result["payload_bytes"]])


## Test 5: Memory Recycling Soak Zero-Leak Invariant (Task 15.4)
func test_memory_recycling_soak_zero_leaks() -> void:
	var result: Dictionary = PerformanceBenchmarks.benchmark_memory_recycling_soak(15, 100)
	_assert_true(result["passed"], "15 cycles of 100 units spawn/despawn executed with 0 slot leaks")
	_assert_true(result["leaks_detected"] == 0, "Zero memory or slot leaks detected")
