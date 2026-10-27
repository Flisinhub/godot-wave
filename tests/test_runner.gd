extends SceneTree

## SFE5 Headless Test Runner
## Executes test suites sequentially, outputs ANSI-formatted test results,
## summarizes pass/fail metrics, and terminates with clean exit codes:
## quit(0) if failed_tests == 0, quit(1) if failed_tests > 0.

const ANSI_GREEN: String = "\u001b[32m"
const ANSI_RED: String = "\u001b[31m"
const ANSI_YELLOW: String = "\u001b[33m"
const ANSI_CYAN: String = "\u001b[36m"
const ANSI_GRAY: String = "\u001b[90m"
const ANSI_BOLD: String = "\u001b[1m"
const ANSI_RESET: String = "\u001b[0m"

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var skipped_tests: int = 0
var failure_messages: Array[String] = []

func _init() -> void:
	SFE_TestBase.runner_tree = self
	print(ANSI_CYAN + ANSI_BOLD + "==========================================================" + ANSI_RESET)
	print(ANSI_CYAN + ANSI_BOLD + "=== SFE5 GODOT 4.7.2 COMPREHENSIVE HEADLESS TEST SUITE ===" + ANSI_RESET)
	print(ANSI_CYAN + ANSI_BOLD + "==========================================================" + ANSI_RESET)
	var start_time: int = Time.get_ticks_msec()
	
	_run_all_suites()
	
	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	_print_summary(elapsed_ms)
	
	if failed_tests > 0:
		quit(1)
	else:
		quit(0)

func _run_all_suites() -> void:
	_run_suite("R1: Swarm & Flow Field Navigation", preload("res://tests/test_r1_swarm.gd").new())
	_run_suite("R2: Combat Engine & Buffs", preload("res://tests/test_r2_combat.gd").new())
	_run_suite("R3: Economy & Crossfire Cancellation", preload("res://tests/test_r3_economy.gd").new())
	_run_suite("R4: Hero Progression & RPG", preload("res://tests/test_r4_heroes.gd").new())
	_run_suite("R5: Boss Events, Puzzles & Persistence", preload("res://tests/test_r5_events_persistence.gd").new())
	_run_suite("Tier 4: Full System Integration", preload("res://tests/test_integration_full.gd").new())
	_run_suite("Phase 1: SFE5 Playable Integration", preload("res://tests/test_sfe5_phase1_playable_integration.gd").new())
	_run_suite("Phase 2 Tier 1: Feature Coverage", preload("res://tests/test_p2_e2e_tier1.gd").new())
	_run_suite("Phase 2 Tier 2: Boundary & Corner Cases", preload("res://tests/test_p2_e2e_tier2.gd").new())
	_run_suite("Phase 2 Tier 3: Cross-Feature Combinations", preload("res://tests/test_p2_e2e_tier3.gd").new())
	_run_suite("Phase 2 Tier 4: Real-World Scenarios", preload("res://tests/test_p2_e2e_tier4.gd").new())
	_run_suite("Phase 3: Heroes Catalog, VisualRoot & 3D VFX", preload("res://tests/test_p3_heroes_catalog_and_vfx.gd").new())
	_run_suite("Phase 3: Wave Progression, Strains & Bosses", preload("res://tests/test_p3_waves_strains_and_bosses.gd").new())
	_run_suite("Phase 3: Armory Terminal & Auto-Turrets Runtime", preload("res://tests/test_p3_armory_and_turrets_runtime.gd").new())
	_run_suite("Phase 3: SFXManager & 7-Bus Audio Layout Runtime", preload("res://tests/test_p3_sfx_and_audio_bus_runtime.gd").new())

func _run_suite(suite_name: String, suite_instance: Object) -> void:
	print("\n" + ANSI_YELLOW + ANSI_BOLD + ">> Running Suite: " + suite_name + ANSI_RESET)
	var methods: Array[Dictionary] = suite_instance.get_method_list()
	
	# Sort test methods for deterministic execution order
	var test_methods: Array[String] = []
	for m in methods:
		var method_name: String = m["name"]
		if method_name.begins_with("test_"):
			test_methods.append(method_name)
	test_methods.sort()
	
	for method_name in test_methods:
		total_tests += 1
		var test_result: Variant = suite_instance.call(method_name)
		if test_result is Dictionary:
			if test_result.get("skipped", false):
				skipped_tests += 1
				var reason: String = test_result.get("reason", "Milestone pending")
				print("  " + ANSI_GRAY + "[SKIP] " + ANSI_RESET + method_name + " (" + reason + ")")
			elif test_result.get("passed", false):
				passed_tests += 1
				print("  " + ANSI_GREEN + "[PASS] " + ANSI_RESET + method_name)
			else:
				failed_tests += 1
				var reason: String = test_result.get("error", "Unknown assertion failure")
				failure_messages.append(suite_name + "::" + method_name + " -> " + reason)
				print("  " + ANSI_RED + "[FAIL] " + ANSI_RESET + method_name + ": " + reason)
		else:
			passed_tests += 1
			print("  " + ANSI_GREEN + "[PASS] " + ANSI_RESET + method_name)

func _print_summary(elapsed_ms: int) -> void:
	print("\n==========================================================")
	print("Test Execution Complete in " + str(elapsed_ms) + " ms")
	print("Total Tests: " + str(total_tests))
	print(ANSI_GREEN + "Passed:  " + str(passed_tests) + ANSI_RESET)
	if skipped_tests > 0:
		print(ANSI_YELLOW + "Skipped: " + str(skipped_tests) + " (Milestones pending downstream implementation)" + ANSI_RESET)
	if failed_tests > 0:
		print(ANSI_RED + "Failed:  " + str(failed_tests) + ANSI_RESET)
		print("\nFailure Breakdown:")
		for msg in failure_messages:
			print(ANSI_RED + "  * " + msg + ANSI_RESET)
	else:
		print(ANSI_GREEN + ANSI_BOLD + "ALL ACTIVE TEST SUITES PASSED! [STATUS: GREEN]" + ANSI_RESET)
	print("==========================================================")
