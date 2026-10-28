extends "res://tests/test_base.gd"

## TestSFE5SprintD - Comprehensive test suite for Sprint D (Cohesion and Meta-Progression):
## 1. Maxima Experiencia (Level 100) refund and 4-attributes progression.
## 2. Racial upgrades effects: attack range (cloak), ability power bonus (storm), concussion slow, nano healing.
## 3. Game mode configuration: Torment, Hardcore, Nightmare, Mutation, Split Income.
## 4. RankSystem progression formulas and PlayerProfileStats career persistence.
## 5. SFESettingsModal controls (volumes, edge scroll, colorblindness).
## 6. SFEStartModal profile telemetry and SecretHeroManager eligibility.

const PlayerConsole = preload("res://ui/player_console.gd")
const StatsComponent = preload("res://core/components/stats_component.gd")
const BuffComponent = preload("res://core/components/buff_component.gd")
const ExperienceComponent = preload("res://core/components/experience_component.gd")
const EliteComponent = preload("res://core/components/elite_component.gd")
const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")
const GameModeManager = preload("res://core/modes/game_mode_manager.gd")
const ModeData = preload("res://core/data/mode_data.gd")
const RankSystem = preload("res://core/meta/rank_system.gd")
const AchievementSystem = preload("res://core/meta/achievement_system.gd")
const PlayerProfileStats = preload("res://core/meta/player_profile_stats.gd")
const SecretHeroManager = preload("res://core/meta/secret_hero_manager.gd")
const SFESettingsModal = preload("res://ui/sfe_settings_modal.gd")
const SFEGameOverModal = preload("res://ui/sfe_game_over_modal.gd")
const SFEStartModal = preload("res://ui/sfe_start_modal.gd")
const AccessibilityManager = preload("res://core/ui/accessibility_and_color_manager.gd")
const BankManager = preload("res://core/persistence/bank_manager.gd")


## 1. Test Maxima Experiencia (Level 100) Refund & 4-Attribute Growth
func test_maxima_experiencia_level_100_refund_and_stat_growth() -> Dictionary:
	var hero := HeroUnit3D.new()
	var h_data := HeroData.new()
	h_data.xp_level = 10
	hero.hero_data = h_data

	var exp_comp := ExperienceComponent.new()
	exp_comp.current_level = 10
	hero.experience_component = exp_comp
	hero.add_child(exp_comp)

	var stats_comp := StatsComponent.new()
	stats_comp.strength = 10
	stats_comp.dexterity = 10
	stats_comp.intelligence = 10
	stats_comp.endurance = 10
	hero.stats_component = stats_comp
	hero.add_child(stats_comp)

	var buff_comp := BuffComponent.new()
	hero.buff_component = buff_comp
	hero.add_child(buff_comp)

	var eco := SFEEconomyManager.new()
	eco.reset(100000)

	var console := PlayerConsole.new()
	console.target_unit = hero
	console.stats_comp = stats_comp
	console.buff_comp = buff_comp
	console.economy_manager = eco

	# Level 10 refund: 750 * 10 = 7,500. Cost = 75,000 - 7,500 = 67,500
	console._on_buy_supreme_pressed("maxima_experiencia", 75000)

	if not assert_eq(eco.current_minerals, 100000 - 67500, "Economy deducted exact discounted cost (67,500)"):
		hero.free()
		console.free()
		return get_last_failure()

	if not assert_eq(exp_comp.current_level, 100, "ExperienceComponent level raised to 100"):
		hero.free()
		console.free()
		return get_last_failure()

	if not assert_eq(h_data.xp_level, 100, "HeroData xp_level raised to 100"):
		hero.free()
		console.free()
		return get_last_failure()

	# Attribute bonus: (100 - 10) * 2 = 180 points added to each attribute
	var expected_attr: int = 10 + 180
	if not assert_eq(stats_comp.strength, expected_attr, "Strength gained +180 points"):
		hero.free()
		console.free()
		return get_last_failure()

	if not assert_eq(stats_comp.dexterity, expected_attr, "Dexterity gained +180 points"):
		hero.free()
		console.free()
		return get_last_failure()

	if not assert_eq(stats_comp.intelligence, expected_attr, "Intelligence gained +180 points"):
		hero.free()
		console.free()
		return get_last_failure()

	if not assert_eq(stats_comp.endurance, expected_attr, "Endurance gained +180 points"):
		hero.free()
		console.free()
		return get_last_failure()

	var bank := BankManager.load_bank()
	var unlocked: Array = bank.get("achievements_unlocked", [])
	if not assert_true(unlocked.has("ach_hero_ascendance"), "ach_hero_ascendance achievement unlocked in bank"):
		hero.free()
		console.free()
		return get_last_failure()

	hero.free()
	console.free()
	return pass_test()


## 2. Test Racial Upgrades Effects (Cloak, Storm, Concussion, Nano)
func test_racial_upgrades_effects() -> Dictionary:
	var hero := HeroUnit3D.new()
	var h_data := HeroData.new()
	h_data.attack_range = 10.0
	h_data.max_shield = 0.0
	h_data.current_shield = 0.0
	hero.hero_data = h_data
	hero.attack_range = 10.0

	var stats_comp := StatsComponent.new()
	hero.stats_component = stats_comp
	hero.add_child(stats_comp)

	var eco := SFEEconomyManager.new()
	eco.reset(50000)

	var console := PlayerConsole.new()
	console.target_unit = hero
	console.stats_comp = stats_comp
	console.economy_manager = eco

	# 1. Unit Cloak (+1.5 range and +30 energy)
	console._apply_racial_upgrade_effects("unit_cloak", 2)
	if not assert_almost_eq(hero.attack_range, 13.0, 0.01, "Hero attack_range increased by +3.0 (2 stacks of 1.5)"):
		hero.free()
		console.free()
		return get_last_failure()
	if not assert_almost_eq(h_data.attack_range, 13.0, 0.01, "HeroData attack_range increased by +3.0"):
		hero.free()
		console.free()
		return get_last_failure()

	# 2. Unit Storm (+0.20 AP bonus and shield)
	var ap_before: float = stats_comp.get_effective_ability_power()
	console._apply_racial_upgrade_effects("unit_storm", 2)
	var ap_after: float = stats_comp.get_effective_ability_power()
	if not assert_almost_eq(ap_after - ap_before, 0.40, 0.01, "Ability power increased by +40% (2 stacks of 20%)"):
		hero.free()
		console.free()
		return get_last_failure()
	if not assert_almost_eq(h_data.max_shield, 30.0, 0.01, "HeroData max_shield increased by +30"):
		hero.free()
		console.free()
		return get_last_failure()

	# 3. Unit Concussion (concussive_slow active)
	console._apply_racial_upgrade_effects("unit_concussion", 1)
	if not assert_true(hero.concussive_slow or hero.get_meta("concussive_slow", false), "Concussive slow flag activated on hero"):
		hero.free()
		console.free()
		return get_last_failure()

	# 4. Unit Nano (healing power bonus)
	console._apply_racial_upgrade_effects("unit_nano", 2)
	if not assert_almost_eq(hero.get_meta("healing_power_bonus", 0.0), 0.50, 0.01, "Healing power bonus metadata set to +0.50"):
		hero.free()
		console.free()
		return get_last_failure()

	hero.free()
	console.free()
	return pass_test()


## 3. Test Game Modes and Mutators Application
func test_game_modes_and_mutators_application() -> Dictionary:
	# Hardcore mode
	var hc_mode: ModeData = load("res://data/modes/hardcore.tres")
	var hc_mgr := GameModeManager.new(hc_mode)
	if not assert_false(hc_mgr.allow_buff_purchase, "Hardcore disallows buff purchase"):
		return get_last_failure()
	if not assert_false(hc_mgr.allow_protoss_phases, "Hardcore disallows Protoss phases"):
		return get_last_failure()
	var roster: Array[Dictionary] = hc_mgr.get_hardcore_starting_roster()
	var total_roster_units: int = 0
	for entry in roster:
		total_roster_units += int(entry.get("count", 0))
	if not assert_eq(total_roster_units, 12, "Hardcore starting roster contains exactly 12 elite units"):
		return get_last_failure()

	# Torment mode
	var torment_mode: ModeData = load("res://data/modes/torment.tres")
	var torment_mgr := GameModeManager.new(torment_mode)
	if not assert_true(torment_mgr.is_permadeath, "Torment enforces permadeath"):
		return get_last_failure()

	# Nightmare mode
	var nm_mode: ModeData = load("res://data/modes/nightmare.tres")
	var nm_mgr := GameModeManager.new(nm_mode)
	if not assert_true(nm_mgr.is_nightmare, "Nightmare mode active"):
		return get_last_failure()
	var wave1 := nm_mgr.advance_nightmare_wave()
	if not assert_eq(wave1.get("level"), 1, "Nightmare wave 1 is at level 1"):
		return get_last_failure()
	if not assert_eq(wave1.get("cycle_slot"), 2, "Nightmare advanced to cycle slot 2"):
		return get_last_failure()

	# Advance 10 waves to reach level 2
	for i in range(10):
		nm_mgr.advance_nightmare_wave()
	if not assert_ge(nm_mgr.nightmare_level, 2, "Nightmare reached level 2 after full cycle"):
		return get_last_failure()

	# Split income mode
	var split_mode: ModeData = load("res://data/modes/split_income.tres")
	var split_mgr := GameModeManager.new(split_mode)
	if not assert_true(split_mgr.is_split_income, "Split income flag active"):
		return get_last_failure()

	return pass_test()


## 4. Test RankSystem Progression & PlayerProfileStats Lifetime Persistence
func test_rank_progression_and_player_profile_stats_persistence() -> Dictionary:
	# Rank outcomes
	var vic_outcome := RankSystem.calculate_match_outcome("victory", 4, 1, 3)
	if not assert_gt(vic_outcome.get("delta", 0), 18000, "Torment solo victory with 3 bosses gives > 18000 points"):
		return get_last_failure()

	var def_outcome := RankSystem.calculate_match_outcome("defeat", 1, 1, 0)
	if not assert_eq(def_outcome.get("delta", 0), -6000, "Defeat gives exactly -6000 points"):
		return get_last_failure()

	# Rank strings
	if not assert_eq(RankSystem.get_rank_string(-1), "R", "Negative points returns Recruit (R)"):
		return get_last_failure()
	if not assert_eq(RankSystem.get_rank_string(0), "D-1", "0 points returns D-1"):
		return get_last_failure()

	# PlayerProfileStats
	var stats := PlayerProfileStats.new()
	var initial_games := stats.games_played
	var initial_wins := stats.victories
	stats.record_game_finished(true, 3, 25000, 150, 2, 1)

	if not assert_eq(stats.games_played, initial_games + 1, "Games played incremented"):
		return get_last_failure()
	if not assert_eq(stats.victories, initial_wins + 1, "Victories incremented"):
		return get_last_failure()
	if not assert_ge(stats.highest_difficulty_won, 3, "Highest difficulty won tracked as Brutal (3)"):
		return get_last_failure()

	# GameOverModal telemetry setup
	var modal := SFEGameOverModal.new()
	modal.setup(
		true,
		185.0,
		120,
		45000,
		6,
		10,
		"Brutal",
		12345,
		"C-3",
		8900,
		["Primera Sangre", "Conquistador Brutal"]
	)
	if not assert_eq(modal.rank_string, "C-3", "GameOverModal received rank string"):
		modal.free()
		return get_last_failure()
	if not assert_eq(modal.rank_delta, 8900, "GameOverModal received rank delta"):
		modal.free()
		return get_last_failure()
	if not assert_eq(modal.session_achievements.size(), 2, "GameOverModal received 2 session achievements"):
		modal.free()
		return get_last_failure()

	modal.free()
	return pass_test()


## 5. Test SFESettingsModal Controls & Accessibility
func test_pause_settings_modal_controls() -> Dictionary:
	var modal := SFESettingsModal.new()
	modal._ready()

	if not assert_not_null(modal.settings, "GameSettings instance initialized"):
		modal.free()
		return get_last_failure()
	if not assert_not_null(modal.accessibility, "AccessibilityManager instance initialized"):
		modal.free()
		return get_last_failure()
	if not assert_not_null(modal.master_slider, "Master volume slider created"):
		modal.free()
		return get_last_failure()
	if not assert_not_null(modal.edge_scroll_check, "Edge scroll checkbox created"):
		modal.free()
		return get_last_failure()
	if not assert_not_null(modal.colorblind_option, "Colorblind option button created"):
		modal.free()
		return get_last_failure()

	# Test slider change
	modal.master_slider.value_changed.emit(0.5)
	if not assert_almost_eq(modal.settings.master_volume, 0.5, 0.01, "Settings master_volume updated to 0.5"):
		modal.free()
		return get_last_failure()

	# Test edge scroll toggle
	modal.edge_scroll_check.button_pressed = false
	if not assert_false(modal.settings.edge_scroll_enabled, "Edge scroll toggle updated to false"):
		modal.free()
		return get_last_failure()

	# Test colorblind mode
	modal.colorblind_option.selected = AccessibilityManager.ColorblindMode.PROTANOPIA
	modal.colorblind_option.item_selected.emit(AccessibilityManager.ColorblindMode.PROTANOPIA)
	if not assert_eq(modal.accessibility.colorblind_mode, AccessibilityManager.ColorblindMode.PROTANOPIA, "Colorblind mode set to Protanopia"):
		modal.free()
		return get_last_failure()

	modal.free()
	return pass_test()


## 6. Test Start Modal Profile Display & Secret Hero Eligibility
func test_start_modal_profile_display_and_secret_hero_roll() -> Dictionary:
	var modal := SFEStartModal.new()
	modal._ready()

	if not assert_not_null(modal.profile_label, "Profile label created in start modal"):
		modal.free()
		return get_last_failure()
	if not assert_true(modal.profile_label.text.contains("RANGO:"), "Profile label shows RANGO notation"):
		modal.free()
		return get_last_failure()
	if not assert_true(modal.profile_label.text.contains("LOGROS:"), "Profile label shows LOGROS score"):
		modal.free()
		return get_last_failure()

	# Secret hero eligibility (< 3000 pts -> ineligible)
	if not assert_false(SecretHeroManager.evaluate_secret_hero_eligibility(1500, 1), "1500 pts is ineligible for secret heroes"):
		modal.free()
		return get_last_failure()
	# (>= 3000 pts and difficulty 1 -> eligible)
	if not assert_true(SecretHeroManager.evaluate_secret_hero_eligibility(3500, 1), "3500 pts at Normal is eligible for secret heroes"):
		modal.free()
		return get_last_failure()
	# (>= 3000 pts but difficulty Torment 4 -> ineligible)
	if not assert_false(SecretHeroManager.evaluate_secret_hero_eligibility(3500, 4), "Torment (4) difficulty forbids secret heroes"):
		modal.free()
		return get_last_failure()

	modal.free()
	return pass_test()
