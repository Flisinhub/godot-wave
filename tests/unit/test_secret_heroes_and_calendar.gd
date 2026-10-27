class_name TestSecretHeroesAndCalendar
extends RefCounted

## TestSecretHeroesAndCalendar - SFE5 Secret Heroes & Calendar Events Suite (Fase 16).
## Tests eligibility criteria, probability formulas, achievement disable flag,
## the 6 original secret heroes catalog, and real-date calendar holiday triggers.

const SecretHeroManager = preload("res://core/meta/secret_hero_manager.gd")
const CalendarEventManager = preload("res://core/events/calendar_event_manager.gd")
const SecretManager = preload("res://core/events/secret_manager.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func run_all() -> bool:
	print(">> Running Suite: SFE5 Secret Heroes & Calendar Events")
	_tests_passed = 0
	_tests_failed = 0

	test_secret_hero_eligibility_criteria()
	test_secret_hero_probability_scaling()
	test_secret_hero_achievement_lock_and_roll()
	test_six_original_secret_heroes_catalog()
	test_calendar_holiday_events_detection()
	test_easter_eggs_and_harbinger_secret()

	return _tests_failed == 0


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % msg)


## Test 1: Secret Hero Eligibility Thresholds (Task 16.1)
func test_secret_hero_eligibility_criteria() -> void:
	# Requires >= 3000 achievement points and difficulty < Torment (0..3)
	_assert_true(not SecretHeroManager.evaluate_secret_hero_eligibility(2999, 1), "Ineligible with 2999 points")
	_assert_true(SecretHeroManager.evaluate_secret_hero_eligibility(3000, 1), "Eligible with exactly 3000 points on Normal")
	_assert_true(SecretHeroManager.evaluate_secret_hero_eligibility(5000, 3), "Eligible with 5000 points on Brutal (3)")
	_assert_true(not SecretHeroManager.evaluate_secret_hero_eligibility(5000, 4), "Ineligible on Torment (4)")
	_assert_true(not SecretHeroManager.evaluate_secret_hero_eligibility(8000, 5), "Ineligible on Impossible (5)")


## Test 2: Probability Scaling Formula: (6 - difficulty)% (Task 16.1)
func test_secret_hero_probability_scaling() -> void:
	# Casual (0) -> 6%
	_assert_true(is_equal_approx(SecretHeroManager.get_activation_probability(0), 0.06), "Casual probability is 0.06 (6%)")
	# Normal (1) -> 5%
	_assert_true(is_equal_approx(SecretHeroManager.get_activation_probability(1), 0.05), "Normal probability is 0.05 (5%)")
	# Hard (2) -> 4%
	_assert_true(is_equal_approx(SecretHeroManager.get_activation_probability(2), 0.04), "Hard probability is 0.04 (4%)")
	# Brutal (3) -> 3%
	_assert_true(is_equal_approx(SecretHeroManager.get_activation_probability(3), 0.03), "Brutal probability is 0.03 (3%)")
	# Torment (4) -> 0%
	_assert_true(is_equal_approx(SecretHeroManager.get_activation_probability(4), 0.0), "Torment probability is 0.0 (0%)")


## Test 3: Secret Hero Activation Disables Achievements (Task 16.1)
func test_secret_hero_achievement_lock_and_roll() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# Deterministic winning roll for Casual (e.g. force roll < 0.06)
	var win_roll: float = 0.02
	# Test rolling with mock
	_assert_true(win_roll < SecretHeroManager.get_activation_probability(0), "Win roll is strictly within Casual threshold")

	var result: Dictionary = SecretHeroManager.roll_secret_hero_activation(3500, 0, rng)
	# Whether it rolls or not, when activated achievements_enabled MUST be false
	if result["activated"]:
		_assert_true(result["achievements_enabled"] == false, "Playing secret hero disables achievements")
		_assert_true(result["hero_data"] != null, "Secret hero data returned")
		_assert_true(result["hero_data"].is_secret == true, "Hero marked as secret archetype")
	else:
		_assert_true(result["achievements_enabled"] == true, "Standard game keeps achievements enabled")


## Test 4: Catalog of 6 Original Sci-Fi Secret Heroes (Task 16.2 / ADR-06)
func test_six_original_secret_heroes_catalog() -> void:
	var heroes: Dictionary = SecretHeroManager.get_all_secret_heroes()
	_assert_true(heroes.size() == 6, "Exactly 6 canonical original secret heroes registered")

	_assert_true(heroes.has(&"harbinger"), "Harbinger registered")
	_assert_true(heroes.has(&"void_arbiter"), "Void Arbiter registered")
	_assert_true(heroes.has(&"phantom_spectre"), "Phantom Spectre registered")
	_assert_true(heroes.has(&"apex_ravager"), "Apex Ravager registered")
	_assert_true(heroes.has(&"archon_solitude"), "Archon of Solitude registered")
	_assert_true(heroes.has(&"chronos_vanguard"), "Chronos Vanguard registered")

	# Verify stats and secret flag
	var arbiter: HeroData = heroes[&"void_arbiter"]
	_assert_true(arbiter.is_secret, "Void Arbiter is secret")
	_assert_true(arbiter.base_hp >= 600.0, "Void Arbiter has high base HP")


## Test 5: Real-World Date Driven Calendar Events (Task 16.3)
func test_calendar_holiday_events_detection() -> void:
	# Christmas (Dec 25)
	var x_mgr := CalendarEventManager.new({"month": 12, "day": 25})
	_assert_true(x_mgr.current_theme == CalendarEventManager.EventTheme.CHRISTMAS, "Dec 25 activates Christmas event")
	_assert_true(is_equal_approx(x_mgr.mineral_multiplier, 1.10), "Christmas grants +10% passive minerals")

	# New Year (Jan 1)
	var ny_mgr := CalendarEventManager.new({"month": 1, "day": 1})
	_assert_true(ny_mgr.current_theme == CalendarEventManager.EventTheme.NEW_YEAR, "Jan 1 activates New Year event")
	_assert_true(is_equal_approx(ny_mgr.score_multiplier, 1.15), "New Year grants +15% victory points")

	# April Fools (Apr 1)
	var af_mgr := CalendarEventManager.new({"month": 4, "day": 1})
	_assert_true(af_mgr.current_theme == CalendarEventManager.EventTheme.APRIL_FOOLS, "Apr 1 activates April Fools")

	# Halloween (Oct 31)
	var hw_mgr := CalendarEventManager.new({"month": 10, "day": 31})
	_assert_true(hw_mgr.current_theme == CalendarEventManager.EventTheme.HALLOWEEN, "Oct 31 activates Halloween")
	_assert_true(is_equal_approx(hw_mgr.enemy_speed_modifier, 1.05), "Halloween grants +5% enemy speed")

	# Normal day (July 15)
	var norm_mgr := CalendarEventManager.new({"month": 7, "day": 15})
	_assert_true(norm_mgr.current_theme == CalendarEventManager.EventTheme.NONE, "July 15 is Normal standard gameplay")
	_assert_true(not norm_mgr.is_holiday_event_active(), "Holiday inactive on normal day")


## Test 6: Easter Eggs & Harbinger Secret Roll (Task 16.4 & 16.5)
func test_easter_eggs_and_harbinger_secret() -> void:
	var sec_mgr := SecretManager.new(99999)
	var supply_granted: bool = sec_mgr.trigger_outhouse_secret()
	_assert_true(supply_granted, "Outhouse secret successfully activated")
	_assert_true(sec_mgr.outhouse_unlocked, "Outhouse state persisted as unlocked")

	var lizard_reward: int = sec_mgr.trigger_lucky_lizard()
	_assert_true(lizard_reward == 3000, "Lucky Lizard awards 3000 flat minerals")

	# Harbinger 1.0% threshold check (Task 16.5)
	_assert_true(SecretHeroManager.is_harbinger_roll(0.005), "Roll 0.005 triggers Harbinger (< 0.01)")
	_assert_true(not SecretHeroManager.is_harbinger_roll(0.015), "Roll 0.015 does not trigger Harbinger (>= 0.01)")
