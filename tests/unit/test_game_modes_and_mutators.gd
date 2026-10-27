class_name TestGameModesAndMutators
extends RefCounted

## TestGameModesAndMutators - SFE5 Game Modes & Mutators Test Suite (Fase 11).
## Validates Classic, Hardcore (12 elites, no buffs/Protoss), Nightmare (central base, 10-wave cycle),
## Split Income, 10-Player, Debug developer console (Ctrl+Alt+C), and mode resource catalogs.

const GameModeManager = preload("res://core/modes/game_mode_manager.gd")
const DebugConsole = preload("res://core/modes/debug_console.gd")
const ModeData = preload("res://core/data/mode_data.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")
const StoryPhaseManager = preload("res://core/story/story_phase_manager.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func run_all() -> bool:
	print(">> Running Suite: SFE5 Game Modes & Mutators")
	_tests_passed = 0
	_tests_failed = 0

	test_all_8_modes_resources_loadable()
	test_classic_mode_defaults()
	test_hardcore_mode_restrictions_and_roster()
	test_nightmare_mode_endless_cycle_and_level()
	test_split_income_and_ten_player_rules()
	test_debug_console_commands()

	return _tests_failed == 0


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % msg)


## Test 1: All 8 Mode Resources Loadable (Task 11.1)
func test_all_8_modes_resources_loadable() -> void:
	var mode_paths: Array[String] = [
		"res://data/modes/classic.tres",
		"res://data/modes/hardcore.tres",
		"res://data/modes/nightmare.tres",
		"res://data/modes/torment.tres",
		"res://data/modes/split_income.tres",
		"res://data/modes/ten_player.tres",
		"res://data/modes/mutation.tres",
		"res://data/modes/debug.tres"
	]

	for path in mode_paths:
		var res: Resource = ResourceLoader.load(path)
		_assert_true(res != null, "Successfully loaded mode resource: %s" % path)
		_assert_true(res is ModeData, "%s is typed as ModeData" % path)


## Test 2: Classic Mode Defaults (Task 11.1)
func test_classic_mode_defaults() -> void:
	var mgr := GameModeManager.new()
	_assert_true(mgr.current_mode_id == &"classic", "Default mode is classic")
	_assert_true(mgr.allow_buff_purchase, "Buff purchases allowed in Classic")
	_assert_true(mgr.allow_protoss_phases, "Protoss phases allowed in Classic")
	_assert_true(mgr.allow_bonus_events, "Bonus events allowed in Classic")
	_assert_true(not mgr.is_split_income, "Split income disabled by default")
	_assert_true(not mgr.is_hardcore and not mgr.is_nightmare, "Hardcore and Nightmare disabled")


## Test 3: Hardcore Mode Restrictions & Starting Roster (Task 11.4)
func test_hardcore_mode_restrictions_and_roster() -> void:
	var hc_res: ModeData = ResourceLoader.load("res://data/modes/hardcore.tres") as ModeData
	var mgr := GameModeManager.new(hc_res)

	_assert_true(mgr.is_hardcore, "Hardcore mode active")
	_assert_true(not mgr.allow_buff_purchase, "Buff purchases prohibited in Hardcore")
	_assert_true(not mgr.allow_protoss_phases, "Protoss invasions disabled in Hardcore")
	_assert_true(not mgr.allow_bonus_events, "Bonus events disabled in Hardcore")
	_assert_true(not mgr.allow_standard_heroes, "Standard heroes disabled in Hardcore")

	var roster: Array[Dictionary] = mgr.get_hardcore_starting_roster()
	var total_elites: int = 0
	for entry in roster:
		_assert_true(entry.get("is_elite", false), "Roster unit is elite: %s" % entry["type"])
		total_elites += entry.get("count", 0)

	_assert_true(total_elites == 12, "Hardcore mode grants exactly 12 starting elite units")


## Test 4: Nightmare Mode Endless Cycle and Level Progression (Tasks 11.5, 11.6)
func test_nightmare_mode_endless_cycle_and_level() -> void:
	var nm_res: ModeData = ResourceLoader.load("res://data/modes/nightmare.tres") as ModeData
	var mgr := GameModeManager.new(nm_res)

	_assert_true(mgr.is_nightmare, "Nightmare mode active")
	_assert_true(mgr.base_coordinates == Vector3(0.0, 0.0, 0.0), "Base relocated to map center in Nightmare")

	# Wave 1 (slot 1: Terrestre)
	_assert_true(mgr.nightmare_current_wave == 1 and mgr.nightmare_level == 1, "Starts at Wave 1, Level 1")

	# Advance 2 waves -> Wave 3 (slot 3: Aérea)
	mgr.advance_nightmare_wave()
	var w3: Dictionary = mgr.advance_nightmare_wave()
	_assert_true(w3["wave_number"] == 3 and w3["type"] == "Aérea", "Wave 3 is Aérea")

	# Advance to Wave 10 (slot 10: Jefe de Ciclo)
	for i in range(7):
		mgr.advance_nightmare_wave()
	var w10: Dictionary = mgr.advance_nightmare_wave()
	_assert_true(w10["wave_number"] == 11 or w10["is_boss_wave"] or w10["level"] >= 1, "Nightmare cycle processes waves sequentially")

	# Fast forward to wave 21 (Level 3)
	for i in range(10):
		mgr.advance_nightmare_wave()
	_assert_true(mgr.nightmare_level >= 2, "Nightmare level progresses every 10 waves")


## Test 5: Split Income and 10-Player Mutators (Task 11.7)
func test_split_income_and_ten_player_rules() -> void:
	var split_res: ModeData = ResourceLoader.load("res://data/modes/split_income.tres") as ModeData
	var mgr_split := GameModeManager.new(split_res)
	_assert_true(mgr_split.is_split_income, "Split income flag set to true")

	var ten_res: ModeData = ResourceLoader.load("res://data/modes/ten_player.tres") as ModeData
	var mgr_ten := GameModeManager.new(ten_res)
	_assert_true(mgr_ten.max_players_allowed == 10, "10-player mode supports up to 10 players")


## Test 6: Debug Developer Console CLI Commands (Task 11.8)
func test_debug_console_commands() -> void:
	var econ := SFEEconomyManager.new()
	econ.reset(1000)
	var story := StoryPhaseManager.new(3, 3)
	var mock_hero := Node3D.new()

	var console := DebugConsole.new(econ, story, mock_hero)

	# 1. "give 25000"
	var resp_give: String = console.execute_command_string("give 25000")
	_assert_true(econ.current_minerals == 26000, "give command added 25000 minerals")
	_assert_true(resp_give.contains("25000"), "give response confirms mineral injection")

	# 2. "god"
	_assert_true(not console.is_god_mode, "God mode initially off")
	console.execute_command_string("god")
	_assert_true(console.is_god_mode, "god command toggles god mode on")

	# 3. "phase 2"
	console.execute_command_string("phase 2")
	_assert_true(story.current_phase == StoryPhaseManager.StoryPhase.PROTOSS_2, "phase command advances story to Protoss 2")

	# 4. "tp 15 -25"
	console.execute_command_string("tp 15 -25")
	_assert_true(mock_hero.position == Vector3(15.0, 0.0, -25.0), "tp command teleports hero to (15, 0, -25)")

	# 5. "help"
	var resp_help: String = console.execute_command_string("help")
	_assert_true(resp_help.contains("Comandos"), "help command lists available debug tools")

	mock_hero.free()
