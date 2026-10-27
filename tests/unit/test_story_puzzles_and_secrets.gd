class_name TestStoryPuzzlesAndSecrets
extends RefCounted

## TestStoryPuzzlesAndSecrets - SFE5 Story Phases, Pedestal Solver & Secrets Test Suite (Fase 9).
## Validates F2 Gaussian elimination, all 256 configurations analysis,
## StoryPhaseManager progression, Xel'Naga crystals, Outhouse secret (+10 supply),
## Mystery Boxes, Lucky Lizard, and MatchCodeReader.

const F2Solver = preload("res://core/puzzles/f2_solver.gd")
const PedestalPuzzleManager = preload("res://core/puzzles/pedestal_puzzle_manager.gd")
const StoryPhaseManager = preload("res://core/story/story_phase_manager.gd")
const SecretManager = preload("res://core/events/secret_manager.gd")
const MatchCodeReader = preload("res://core/events/match_code_reader.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func run_all() -> bool:
	print(">> Running Suite: SFE5 Story Phases, Puzzles & Secrets")
	_tests_passed = 0
	_tests_failed = 0

	test_f2_solver_circulant_matrix_and_gaussian_elimination()
	test_f2_solver_all_256_configurations()
	test_pedestal_puzzle_manager_lights_out_integration()
	test_story_phase_manager_progression()
	test_secret_manager_and_outhouse_bonus()
	test_match_code_reader_format()

	return _tests_failed == 0


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % msg)


## Test 1: F2 Solver Circulant Matrix and Gaussian Elimination (Task 9.7)
func test_f2_solver_circulant_matrix_and_gaussian_elimination() -> void:
	var matrix: Array[Array] = F2Solver.get_c8_matrix()
	_assert_true(matrix.size() == 8 and matrix[0].size() == 8, "Circulant matrix is 8x8")

	# Row 0 must have neighbors at 7, 0, 1
	_assert_true(matrix[0][0] == 1 and matrix[0][1] == 1 and matrix[0][7] == 1, "Row 0 has 1s at [0, 1, 7]")
	_assert_true(matrix[0][2] == 0 and matrix[0][3] == 0, "Row 0 has 0s for non-neighbors")

	# Target is [1, 1, 1, 1, 1, 1, 1, 1]
	# If we start from [0, 0, 1, 1, 1, 1, 1, 0] (toggled by pedestal 0), solution should be [1, 0, 0, 0, 0, 0, 0, 0]
	var test_state: Array[int] = [0, 0, 1, 1, 1, 1, 1, 0]
	var result: Dictionary = F2Solver.solve_c8(test_state)

	_assert_true(result["solvable"], "Single-toggle state is solvable")
	_assert_true(result["press_count"] == 1, "Exact 1 toggle required to solve")
	_assert_true(result["solution"][0] == 1, "Solution correctly identifies pedestal 0")
	_assert_true(F2Solver.verify_solution(test_state, result["solution"]), "Verification confirms state reaches all 1s")


## Test 2: All 256 Configurations Analysis & Deterministic Generation (Tasks 9.10, 9.11)
func test_f2_solver_all_256_configurations() -> void:
	var stats: Dictionary = F2Solver.test_all_256_configurations()
	_assert_true(stats["total"] == 256, "Tested all 256 possible 8-bit configurations")
	_assert_true(stats["solvable"] > 0, "Solvable configurations found")
	_assert_true(stats["solvable"] == stats["verified"], "100% of solvable configurations verified by simulation")

	# Test deterministic generator (Task 9.10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var gen_state: Array[int] = F2Solver.generate_solvable_state(rng, 2)
	_assert_true(gen_state.size() == 8, "Generated state is 8 elements")

	var sol: Dictionary = F2Solver.solve_c8(gen_state)
	_assert_true(sol["solvable"], "Generated state is guaranteed solvable by F2 solver")
	_assert_true(F2Solver.verify_solution(gen_state, sol["solution"]), "Solution solves generated state to all 1s")


## Test 3: PedestalPuzzleManager Lights Out & Hints (Tasks 9.6, 9.8, 9.9)
func test_pedestal_puzzle_manager_lights_out_integration() -> void:
	var mgr := PedestalPuzzleManager.new()
	mgr.mode = PedestalPuzzleManager.PuzzleMode.LIGHTS_OUT_C8
	mgr.setup_deterministic_initial_state(888)

	_assert_true(not mgr.is_solved, "Puzzle initially unsolved")
	var hints: Array[int] = mgr.get_solver_hints()
	_assert_true(not hints.is_empty(), "Solver hints generated for current state")

	var solved_payload := {"was_solved": false, "bonus": 0}
	mgr.puzzle_solved.connect(func(reward: Dictionary) -> void:
		solved_payload["was_solved"] = true
		solved_payload["bonus"] = reward.get("pedestal_bonus", 0)
	)

	# Execute hints sequentially
	for hint in hints:
		mgr.toggle_c8(hint)

	_assert_true(mgr.is_solved, "Executing solver hints completely solves the puzzle")
	_assert_true(solved_payload["was_solved"], "puzzle_solved signal emitted upon completion")
	_assert_true(solved_payload["bonus"] == 25, "Pedestal bonus (+25) included in reward payload")


## Test 4: StoryPhaseManager Progression & Xel'Naga Crystals (Tasks 9.1, 9.2, 9.4, 9.5)
func test_story_phase_manager_progression() -> void:
	var story := StoryPhaseManager.new(2, 2) # Goals: 2 Zerg, 2 Protoss
	_assert_true(story.current_phase == StoryPhaseManager.StoryPhase.ZERG, "Initial phase is Zerg")

	# Clear 1 Zerg spawner -> Remains Zerg
	story.report_spawner_cleared(&"zerg")
	_assert_true(story.current_phase == StoryPhaseManager.StoryPhase.ZERG, "Still in Zerg phase at 1/2 spawners")

	# Clear 2nd Zerg spawner -> Advances to Protoss 1 (Task 9.2)
	story.report_spawner_cleared(&"zerg")
	_assert_true(story.current_phase == StoryPhaseManager.StoryPhase.PROTOSS_1, "Advances to Protoss 1 after 2 Zerg spawners")

	# Clear 2 Protoss spawners -> Advances to Protoss 2
	story.report_spawner_cleared(&"protoss")
	story.report_spawner_cleared(&"protoss")
	_assert_true(story.current_phase == StoryPhaseManager.StoryPhase.PROTOSS_2, "Advances to Protoss 2 after 2 Protoss spawners")

	# Harmonize Xel'Naga Crystals (Task 9.4)
	_assert_true(story.harmonize_xelnaga_crystal(0) == false, "Crystal 1 harmonized (1/3)")
	_assert_true(story.harmonize_xelnaga_crystal(1) == false, "Crystal 2 harmonized (2/3)")
	var reached_bosses: bool = story.harmonize_xelnaga_crystal(2)
	_assert_true(reached_bosses, "Crystal 3 harmonized -> Unlocks Pinnacle Bosses phase")
	_assert_true(story.current_phase == StoryPhaseManager.StoryPhase.PINNACLE_BOSSES, "Current phase is Pinnacle Bosses")
	_assert_true(story.pinnacle_bosses_unlocked, "Pinnacle bosses marked unlocked")

	# Ambient lighting presets (Task 9.5)
	var zerg_col: Color = story.get_ambient_lighting_color(StoryPhaseManager.StoryPhase.ZERG)
	var boss_col: Color = story.get_ambient_lighting_color(StoryPhaseManager.StoryPhase.PINNACLE_BOSSES)
	_assert_true(zerg_col != boss_col, "Distinct ambient lighting tints for story phases")


## Test 5: SecretManager & Outhouse Supply Bonus (Tasks 9.12, 9.13, 9.14)
func test_secret_manager_and_outhouse_bonus() -> void:
	var secrets := SecretManager.new(999)

	# Mock GameSession
	var mock_session := {"outhouse_secret_discovered": false}
	var outhouse_res: bool = secrets.trigger_outhouse_secret(mock_session)
	_assert_true(outhouse_res, "Outhouse secret successfully triggered")
	_assert_true(mock_session["outhouse_secret_discovered"], "Outhouse bonus (+10 supply) set in GameSession")
	_assert_true(not secrets.trigger_outhouse_secret(mock_session), "Outhouse cannot be activated more than once")

	# Lucky Lizard (Task 9.12)
	var lizard_reward: int = secrets.trigger_lucky_lizard()
	_assert_true(lizard_reward == 3000, "Lucky Lizard awards 3000 minerals")
	_assert_true(secrets.trigger_lucky_lizard() == 0, "Lucky Lizard reward only claimed once")

	# Mystery Boxes (Task 9.12)
	var box0: Dictionary = secrets.open_mystery_box(0)
	_assert_true(box0.has("type") and box0.has("amount"), "Mystery box yields valid loot payload")
	_assert_true(secrets.open_mystery_box(0).is_empty(), "Opened mystery box cannot be reopened")

	# Fueling Station (Task 9.14)
	var fuel_reward: int = secrets.complete_fueling_station()
	_assert_true(fuel_reward == 4000, "Fueling station event awards 4000 minerals")


## Test 6: MatchCodeReader (Task 9.16)
func test_match_code_reader_format() -> void:
	var code: String = MatchCodeReader.generate_match_code(987654, "HC")
	_assert_true(code == "SFE5-987654-HC", "Match code generated in standard format: SFE5-987654-HC")

	var parsed: Dictionary = MatchCodeReader.parse_match_code(code)
	_assert_true(parsed["is_valid"], "Match code parsed successfully")
	_assert_true(parsed["seed"] == 987654, "Parsed seed matches original: 987654")
	_assert_true(parsed["mode"] == "HC", "Parsed mode matches original: HC")

	var invalid_res: Dictionary = MatchCodeReader.parse_match_code("INVALID-CODE")
	_assert_true(not invalid_res["is_valid"], "Malformed match code correctly rejected")
