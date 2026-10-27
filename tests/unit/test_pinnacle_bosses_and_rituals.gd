class_name TestPinnacleBossesAndRituals
extends RefCounted

## TestPinnacleBossesAndRituals - SFE5 Pinnacle Bosses & Awakening Rituals Suite (Fase 10).
## Validates the 11 canonical bosses, ritual controllers, phase transitions,
## 100k minerals / 300 rank points rewards, Torment permanent unlocks, and x6/x2 category multipliers.

const PinnacleBossCatalog = preload("res://core/bosses/pinnacle_boss_catalog.gd")
const SummoningRitual = preload("res://core/bosses/summoning_ritual.gd")
const PinnacleBossBase = preload("res://core/bosses/pinnacle_boss_base.gd")
const BossRewardManager = preload("res://core/bosses/boss_reward_manager.gd")
const BankManager = preload("res://core/persistence/bank_manager.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func run_all() -> bool:
	print(">> Running Suite: SFE5 Pinnacle Bosses & Rituals")
	_tests_passed = 0
	_tests_failed = 0

	test_pinnacle_boss_catalog_all_11_bosses()
	test_summoning_ritual_advancement_and_fulfillment()
	test_summoning_ritual_hold_position_and_decay()
	test_pinnacle_boss_base_phases_and_channeling()
	test_boss_rewards_and_bank_persistence()
	test_boss_category_income_multipliers()

	return _tests_failed == 0


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % msg)


## Test 1: The 11 Canonical Pinnacle Bosses Catalog (Tasks 10.6 - 10.16)
func test_pinnacle_boss_catalog_all_11_bosses() -> void:
	var boss_ids: Array[StringName] = PinnacleBossCatalog.get_all_boss_ids()
	_assert_true(boss_ids.size() == 11, "Catalog registers exactly 11 canonical bosses")

	var expected: Array[StringName] = [
		&"odin", &"gorgon", &"diablo", &"chaindog", &"hybrid_behemoth",
		&"hybrid_experimented", &"eclipse", &"hells_gate", &"general_clinton",
		&"celestial_kerrigan", &"narud"
	]

	for expected_id in expected:
		_assert_true(boss_ids.has(expected_id), "Boss catalog contains canonical boss: %s" % expected_id)
		var info: Dictionary = PinnacleBossCatalog.get_boss_info(expected_id)
		_assert_true(info.get("hp", 0.0) >= 12000.0, "%s has at least 12,000 HP" % expected_id)
		_assert_true(info.get("armor", 0.0) >= 12.0, "%s has high boss armor" % expected_id)
		_assert_true(info.has("secret_unit"), "%s specifies secret unit unlock" % expected_id)


## Test 2: Summoning Ritual Advancement & Fulfillment (Task 10.2, 10.5)
func test_summoning_ritual_advancement_and_fulfillment() -> void:
	var ritual: SummoningRitual = PinnacleBossCatalog.create_ritual_for_boss(&"odin")
	_assert_true(ritual != null, "Ritual created for Odin, Titan of Armageddon")
	_assert_true(ritual.required_count == 3, "Odin requires stepping on 3 beacons")
	_assert_true(not ritual.is_completed, "Ritual starts incomplete")

	var fulfilled_state := {"fulfilled": false, "spawn_pos": Vector3.ZERO}
	ritual.ritual_fulfilled.connect(func(boss: StringName, spawn: Vector3) -> void:
		if boss == &"odin":
			fulfilled_state["fulfilled"] = true
			fulfilled_state["spawn_pos"] = spawn
	)

	ritual.advance_progress(1)
	_assert_true(ritual.current_progress == 1 and not ritual.is_completed, "Step 1 advanced (1/3)")

	ritual.advance_progress(1)
	_assert_true(ritual.current_progress == 2 and not ritual.is_completed, "Step 2 advanced (2/3)")

	ritual.advance_progress(1)
	_assert_true(ritual.current_progress == 3 and ritual.is_completed, "Step 3 completed (3/3)")
	_assert_true(fulfilled_state["fulfilled"], "ritual_fulfilled signal dispatched upon completion")


## Test 3: Summoning Ritual Hold Position & Decay (Task 10.2, 10.5)
func test_summoning_ritual_hold_position_and_decay() -> void:
	var ritual := SummoningRitual.new(&"chaindog", SummoningRitual.RitualType.HOLD_POSITION, 5)
	ritual.hold_time_required = 10.0 # 10s hold zone

	# Hold for 5s
	ritual.process_hold_time(5.0, true)
	_assert_true(is_equal_approx(ritual.hold_time_current, 5.0), "Zone held for 5 seconds")
	_assert_true(not ritual.is_completed, "Zone hold not completed at 5/10s")

	# Abandon zone for 2s (decays by 0.5x rate = 1.0s)
	ritual.process_hold_time(2.0, false)
	_assert_true(is_equal_approx(ritual.hold_time_current, 4.0), "Zone hold decayed to 4.0s when abandoned")

	# Hold zone for remaining 6.0s
	ritual.process_hold_time(6.0, true)
	_assert_true(ritual.is_completed, "Zone hold fulfilled at 10.0s")


## Test 4: PinnacleBossBase Multi-phase & Channeling (Tasks 10.1, 10.3)
func test_pinnacle_boss_base_phases_and_channeling() -> void:
	var boss := PinnacleBossBase.new()
	boss.boss_id = &"odin"
	boss.max_health = 10000.0
	boss.current_health = 10000.0
	boss.flat_armor = 20.0

	var phases_detected: Array[int] = []
	boss.phase_transitioned.connect(func(p: int, _n: String) -> void:
		phases_detected.append(p)
	)

	# Physical damage: 520 dmg - 20 armor = 500 net dmg
	var net: float = boss.take_damage(520.0, false)
	_assert_true(is_equal_approx(net, 500.0), "Physical damage mitigated by flat armor (520 - 20 = 500)")
	_assert_true(is_equal_approx(boss.current_health, 9500.0), "Boss HP updated to 9500")

	# Reduce below 66% (< 6600)
	boss.take_damage(3520.0, false) # net 3500 -> HP 6000 (60%)
	_assert_true(boss.current_phase == 2, "Boss transitioned to Phase 2 at 60% HP")
	_assert_true(phases_detected.has(2), "Phase 2 transition signal emitted")

	# Reduce below 33% (< 3300)
	boss.take_damage(3520.0, false) # net 3500 -> HP 2500 (25%)
	_assert_true(boss.current_phase == 3, "Boss transitioned to Phase 3 at 25% HP")
	_assert_true(phases_detected.has(3), "Phase 3 transition signal emitted")

	# Channeling ability test
	var channeled: Array[String] = []
	boss.channeling_completed.connect(func(s: String) -> void:
		channeled.append(s)
	)

	boss.start_channeling("Armageddon Cannon", 3.0)
	_assert_true(boss.is_channeling, "Boss channeling active")
	_assert_true(not boss.process_channeling(1.5), "Channeling in progress after 1.5s")
	_assert_true(boss.process_channeling(1.5), "Channeling finished after 3.0s total")
	_assert_true(channeled.has("Armageddon Cannon"), "Channeling completed signal fired")


## Test 5: Boss Rewards & Bank Persistence (Tasks 10.4, 10.18)
func test_boss_rewards_and_bank_persistence() -> void:
	var econ := SFEEconomyManager.new()
	econ.reset(5000)

	var initial_bank: Dictionary = BankManager.load_bank()
	var initial_rank: int = initial_bank.get("rank_points", 0)

	# Defeat Odin on Normal (tier 1) -> temporary unlock
	var res_normal: Dictionary = BossRewardManager.process_pinnacle_victory(&"odin", econ, 1, &"thor_ace")
	_assert_true(res_normal["minerals"] == 100000, "Awards 100,000 minerals")
	_assert_true(res_normal["rank_points"] == 300, "Awards 300 rank points")
	_assert_true(econ.current_minerals == 105000, "Economy balance updated with 100,000 minerals")
	_assert_true(not res_normal["is_permanent_unlock"], "Secret unit unlock is session-only on Normal")

	var mid_bank: Dictionary = BankManager.load_bank()
	_assert_true(mid_bank.get("rank_points", 0) == initial_rank + 300, "Bank rank points increased by +300")

	# Defeat Gorgon on Torment (tier 4) -> permanent unlock (Task 10.18)
	var res_torment: Dictionary = BossRewardManager.process_pinnacle_victory(&"gorgon", econ, 4, &"battlecruiser_ace")
	_assert_true(res_torment["is_permanent_unlock"], "Secret unit permanently unlocked on Torment")

	var final_bank: Dictionary = BankManager.load_bank()
	var secrets: Array = final_bank.get("unlocked_secret_units", [])
	_assert_true(secrets.has("battlecruiser_ace"), "Bank stores permanently unlocked secret unit: battlecruiser_ace")


## Test 6: Boss Category Income Multipliers (Task 10.19)
func test_boss_category_income_multipliers() -> void:
	var mult_main: float = BossRewardManager.get_boss_category_multiplier(true)
	var mult_summoned: float = BossRewardManager.get_boss_category_multiplier(false)

	_assert_true(is_equal_approx(mult_main, 6.0), "Pinnacle main boss has x6 category multiplier")
	_assert_true(is_equal_approx(mult_summoned, 2.0), "Summoned boss has x2 category multiplier")
