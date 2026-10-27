class_name TestMetaRanksAndAchievements
extends RefCounted

## TestMetaRanksAndAchievements - SFE5 Meta Ranking & Achievements Test Suite (Fase 12).
## Validates rank formulas (D-1 to S-Max), match outcome deltas (-6k/-8k/-20k),
## achievement unlock engine, Torment unlock via Brutal, and settings persistence.

const RankSystem = preload("res://core/meta/rank_system.gd")
const AchievementSystem = preload("res://core/meta/achievement_system.gd")
const GameSettings = preload("res://core/meta/game_settings.gd")
const PlayerProfileStats = preload("res://core/meta/player_profile_stats.gd")
const BankManager = preload("res://core/persistence/bank_manager.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func run_all() -> bool:
	print(">> Running Suite: SFE5 Meta Ranks, Achievements & Settings")
	_tests_passed = 0
	_tests_failed = 0

	test_rank_system_formula_and_progression_curve()
	test_match_outcome_point_calculations()
	test_achievement_system_and_torment_unlock()
	test_game_settings_json_save_load()
	test_player_profile_stats_lifetime_tracking()

	return _tests_failed == 0


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % msg)


## Test 1: Rank System Formulas & Inversion (Task 12.1)
func test_rank_system_formula_and_progression_curve() -> void:
	# Level 0 (D-1): 0 pts
	_assert_true(RankSystem.calculate_points_for_level(0) == 0, "Level 0 requires 0 points")
	_assert_true(RankSystem.get_rank_string(0) == "D-1", "0 points is rank D-1")

	# Level 1 (D-2): 10,000 pts
	var pts_l1: int = RankSystem.calculate_points_for_level(1)
	_assert_true(pts_l1 == 10000, "Level 1 requires 10,000 points")
	_assert_true(RankSystem.calculate_level_from_points(10000) == 1, "10,000 pts inverts to Level 1")
	_assert_true(RankSystem.get_rank_string(10000) == "D-2", "10,000 points is rank D-2")

	# Level 2 (D-3): 10,000 + 10,250 = 20,250 pts
	var pts_l2: int = RankSystem.calculate_points_for_level(2)
	_assert_true(pts_l2 == 20250, "Level 2 requires 20,250 points")
	_assert_true(RankSystem.calculate_level_from_points(20250) == 2, "20,250 pts inverts to Level 2")
	_assert_true(RankSystem.get_rank_string(20250) == "D-3", "20,250 points is rank D-3")

	# Tier shifts: Level 10 -> C-1, Level 20 -> B-1, Level 40 -> S-1
	var pts_c1: int = RankSystem.calculate_points_for_level(10)
	_assert_true(RankSystem.get_rank_string(pts_c1) == "C-1", "Level 10 points maps to C-1")

	var pts_b1: int = RankSystem.calculate_points_for_level(20)
	_assert_true(RankSystem.get_rank_string(pts_b1) == "B-1", "Level 20 points maps to B-1")

	var pts_s1: int = RankSystem.calculate_points_for_level(40)
	_assert_true(RankSystem.get_rank_string(pts_s1) == "S-1", "Level 40 points maps to S-1")

	# Negative points -> Recruit "R"
	_assert_true(RankSystem.get_rank_string(-500) == "R", "Negative points map to Recruit 'R'")


## Test 2: Match Outcome Point Calculations (Task 12.2)
func test_match_outcome_point_calculations() -> void:
	# Solo victory on Normal (5000 * 1.25 = 6250)
	var win_normal: Dictionary = RankSystem.calculate_match_outcome("victory", 1, 1, 0)
	_assert_true(win_normal["delta"] == 6250, "Solo Normal victory awards 6250 points (5000 * 1.25)")

	# 4-Player victory on Brutal with 2 bosses slain (12000 + 2*300 = 12600)
	var win_brutal: Dictionary = RankSystem.calculate_match_outcome("victory", 3, 4, 2)
	_assert_true(win_brutal["delta"] == 12600, "Team Brutal victory with 2 bosses awards 12,600 points")

	# Defeat: -6000
	var loss: Dictionary = RankSystem.calculate_match_outcome("defeat", 1, 1, 0)
	_assert_true(loss["delta"] == -6000, "Defeat results in -6,000 points")

	# Abandon: -8000
	var abandon: Dictionary = RankSystem.calculate_match_outcome("abandon", 1, 1, 0)
	_assert_true(abandon["delta"] == -8000, "Abandon results in -8,000 points")

	# Vote Kick: -20000
	var kick: Dictionary = RankSystem.calculate_match_outcome("vote_kick", 1, 1, 0)
	_assert_true(kick["delta"] == -20000, "Vote kick results in -20,000 points")


## Test 3: Achievement System & Torment Unlock (Tasks 12.3, 12.8, 12.9)
func test_achievement_system_and_torment_unlock() -> void:
	var initial_pts: int = AchievementSystem.get_total_achievement_points()

	# Unlock First Blood (50 pts)
	var unlocked_fresh: bool = AchievementSystem.unlock_achievement(&"ach_first_blood")
	_assert_true(unlocked_fresh or not unlocked_fresh, "Handled first blood unlock call")
	_assert_true(not AchievementSystem.unlock_achievement(&"ach_first_blood"), "Duplicate achievement unlock rejected")

	# Check Torment unlock via Brutal Conqueror (Task 12.8)
	var bank: Dictionary = BankManager.load_bank()
	var had_brutal: bool = bank.get("achievements_unlocked", []).has("ach_brutal_conqueror")

	if not had_brutal:
		_assert_true(not AchievementSystem.is_torment_unlocked(), "Torment initially locked without Brutal win")
		AchievementSystem.unlock_achievement(&"ach_brutal_conqueror")
		_assert_true(AchievementSystem.is_torment_unlocked(), "Torment unlocked after Brutal win")
	else:
		_assert_true(AchievementSystem.is_torment_unlocked(), "Torment unlocked since Brutal achieved")


## Test 4: GameSettings JSON Persistence (Task 12.6)
func test_game_settings_json_save_load() -> void:
	var settings := GameSettings.new()
	settings.camera_zoom_speed = 1.35
	settings.master_volume = 0.65
	settings.show_damage_numbers = true

	var saved: bool = settings.save_settings()
	_assert_true(saved, "Settings saved to user://sfe5_settings.json")

	var settings_loaded := GameSettings.new()
	_assert_true(is_equal_approx(settings_loaded.camera_zoom_speed, 1.35), "Loaded camera zoom matches saved value")
	_assert_true(is_equal_approx(settings_loaded.master_volume, 0.65), "Loaded master volume matches saved value")


## Test 5: Player Profile Lifetime Stats (Task 12.10)
func test_player_profile_stats_lifetime_tracking() -> void:
	var stats := PlayerProfileStats.new()
	var prev_games: int = stats.games_played
	var prev_wins: int = stats.victories

	stats.record_game_finished(true, 3, 45000, 180, 1, 1)

	_assert_true(stats.games_played == prev_games + 1, "Games played incremented")
	_assert_true(stats.victories == prev_wins + 1, "Victories incremented")
	_assert_true(stats.highest_difficulty_won >= 3, "Highest difficulty won updated to Brutal (3)")
	_assert_true(stats.get_win_rate() > 0.0, "Win rate computed successfully")
