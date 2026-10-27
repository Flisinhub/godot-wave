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
	for dir_path in ["res://tests/integration", "res://tests/unit", "res://tests/smoke"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var files: Array[String] = []
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if not dir.current_is_dir() and f.begins_with("test_") and f.ends_with(".gd"):
				files.append(f)
			f = dir.get_next()
		dir.list_dir_end()
		files.sort()
		for file_name in files:
			var script_path := "%s/%s" % [dir_path, file_name]
			var script: GDScript = load(script_path)
			if script and script.can_instantiate():
				var suite_instance = script.new()
				var display_name: String = file_name.get_basename().replace("test_", "").replace("_", " ").capitalize()
				_run_suite(display_name, suite_instance)

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
