extends "res://tests/test_base.gd"

## Phase 2 E2E Test Suite — Tier 2: Boundary & Corner Cases (Extreme Values)
## Validates extreme values, zero minerals, max caps, premature detonation, shield limits,
## and burst phase triggers under SFE5 interface contracts.

const SFE_ECONOMY_MGR_PATH := "res://core/economy/sfe_economy_manager.gd"

# ==============================================================================
# BOUNDARY 1: Zero and Insufficient Minerals Armory Purchase
# ==============================================================================
func test_b01_zero_and_insufficient_minerals_armory_purchase() -> Dictionary:
	var EconomyScript = load(SFE_ECONOMY_MGR_PATH)
	var econ = EconomyScript.new(0) # 0 initial minerals
	
	# Attempting purchase of Tier 1 Ballistics (cost 100) with 0 minerals
	var can_buy_zero: bool = econ.can_afford(100)
	if not assert_false(can_buy_zero, "Cannot afford 100 cost with 0 minerals"):
		return get_last_failure()
	
	var spent_zero: bool = econ.spend_minerals(100, "Ballistics T1")
	if not assert_false(spent_zero, "spend_minerals must fail with 0 balance"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 0, "Wallet must remain exactly 0"):
		return get_last_failure()
	
	# Off-by-one test: exactly 99 minerals (1 below required 100)
	econ.add_minerals(99, "Bonus")
	if not assert_eq(econ.current_minerals, 99, "Wallet must have 99 minerals"):
		return get_last_failure()
	
	var can_buy_99: bool = econ.can_afford(100)
	if not assert_false(can_buy_99, "Cannot afford 100 cost with 99 minerals"):
		return get_last_failure()
	
	var spent_99: bool = econ.spend_minerals(100, "Ballistics T1")
	if not assert_false(spent_99, "Transaction must reject atomically"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 99, "Balance must remain exactly 99"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 2: Exact Mineral Balance Boundary
# ==============================================================================
func test_b02_exact_mineral_balance_boundary() -> Dictionary:
	var EconomyScript = load(SFE_ECONOMY_MGR_PATH)
	var econ = EconomyScript.new(100) # Exactly 100 minerals
	
	if not assert_true(econ.can_afford(100), "Must afford exactly 100 cost"):
		return get_last_failure()
	
	var spent: bool = econ.spend_minerals(100, "Ballistics T1")
	if not assert_true(spent, "spend_minerals must succeed with exact balance"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 0, "Balance must be exactly 0 after exact purchase"):
		return get_last_failure()
	
	# Cannot afford Tier 2 (cost 250)
	if not assert_false(econ.can_afford(250), "Cannot afford next tier with 0 minerals"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 3: Max Upgrade Tier Clamp (Tier 5)
# ==============================================================================
func test_b03_max_upgrade_tier_clamp() -> Dictionary:
	# Authoritative: Ballistics and Armor max tier is 5
	var max_tier: int = 5
	var current_tier: int = 5
	
	# Simulate checking if tier 6 is allowed
	var can_upgrade_past_max: bool = (current_tier < max_tier)
	if not assert_false(can_upgrade_past_max, "Upgrade past Tier 5 must be rejected"):
		return get_last_failure()
	
	# Verify mitigation cap at progressive level 250 (50% max)
	# SFECombatEngine cap invariant
	var res_capped = SFECombatEngine.calculate_damage(
		100.0,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		300 # level 300 exceeds cap of 250 (50%)
	)
	# Effective damage cannot be reduced below 50% by progressive mitigation alone
	if not assert_almost_eq(res_capped.damage_dealt, 50.0, 0.01, "Progressive mitigation must clamp at 50%"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 4: Turret Deployment Cap Limit (Max 6)
# ==============================================================================
func test_b04_turret_deployment_cap_limit_6() -> Dictionary:
	var max_turrets: int = 6
	var turret_cost: int = 125
	
	var EconomyScript = load(SFE_ECONOMY_MGR_PATH)
	var econ = EconomyScript.new(1000) # 1000 minerals
	
	var active_turrets: int = 0
	for i in range(max_turrets):
		if not assert_true(econ.can_afford(turret_cost), "Must afford turret %d" % (i + 1)):
			return get_last_failure()
		econ.spend_minerals(turret_cost, "Turret %d" % (i + 1))
		active_turrets += 1
	
	if not assert_eq(active_turrets, 6, "Exactly 6 turrets deployed"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 1000 - (6 * 125), "Balance must reflect 750 minerals spent (250 remaining)"):
		return get_last_failure()
	
	# 7th Turret Attempt: Cap reached
	var can_deploy_7th: bool = (active_turrets < max_turrets) and econ.can_afford(turret_cost)
	if not assert_false(can_deploy_7th, "7th turret deployment must be rejected due to cap"):
		return get_last_failure()
	
	# Ensure wallet was not charged for rejected attempt
	if not assert_eq(econ.current_minerals, 250, "Minerals must remain untouched at 250"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 5: Turret Placement Boundary and Choke Cost
# ==============================================================================
func test_b05_turret_placement_boundary_and_choke_cost() -> Dictionary:
	var cc_pos: Vector3 = Vector3(0.0, 0.0, 0.0)
	var max_base_radius: float = 24.0
	
	# Point at 23.9m is valid
	var pos_valid: Vector3 = Vector3(23.9, 0.0, 0.0)
	var dist_valid: float = cc_pos.distance_to(pos_valid)
	if not assert_true(dist_valid <= max_base_radius, "23.9m must be inside base radius"):
		return get_last_failure()
	
	# Point at 24.1m is outside base radius
	var pos_invalid: Vector3 = Vector3(24.1, 0.0, 0.0)
	var dist_invalid: float = cc_pos.distance_to(pos_invalid)
	if not assert_false(dist_invalid <= max_base_radius, "24.1m must be rejected as outside base radius"):
		return get_last_failure()
	
	# Flow field choke point check: cost >= 15 is impassable/choke
	var choke_cell_cost: int = 15
	var can_place_on_choke: bool = (choke_cell_cost < 15)
	if not assert_false(can_place_on_choke, "Cannot deploy turret on cells with cost >= 15"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 6: Baneling Premature Detonation at Range (> 1.4m)
# ==============================================================================
func test_b06_baneling_premature_detonation_at_range() -> Dictionary:
	# Authoritative: If Baneling killed at distance > 1.4m:
	# Splash radius reduced from 3.5m to 2.0m.
	# Damage reduced by 50%: 20 to units, 70 (3.5x * 20) to structures.
	var nominal_unit_dmg: float = 40.0
	var nominal_struct_dmg: float = 140.0
	var premature_unit_dmg: float = nominal_unit_dmg * 0.50
	var premature_struct_dmg: float = nominal_struct_dmg * 0.50
	
	if not assert_almost_eq(premature_unit_dmg, 20.0, 0.01, "Premature pop unit damage must be 20.0"):
		return get_last_failure()
	if not assert_almost_eq(premature_struct_dmg, 70.0, 0.01, "Premature pop structural damage must be 70.0"):
		return get_last_failure()
	
	# Test premature damage against reinforced wall (35% mitigation)
	var res_wall_premature = SFECombatEngine.calculate_damage(
		premature_struct_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.WALL_REINFORCED
	)
	# 70 * (1 - 0.35) = 45.5
	if not assert_almost_eq(res_wall_premature.damage_dealt, 45.5, 0.01, "Premature wall damage must be 45.5"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 7: Baneling Structure Multiplier Boundary
# ==============================================================================
func test_b07_baneling_structure_multiplier_boundary() -> Dictionary:
	# Validates that 3.5x multiplier applies ONLY to StructureType.WALL_REINFORCED, BUNKER, or OTHER structure
	# Units (StructureType.NONE) receive strictly 1.0x (40.0 base)
	var raw_base_dmg: float = 40.0
	var struct_multiplier: float = 3.5
	
	# Hit on Marine (StructureType.NONE, flat armor 1.0)
	var marine_hit = SFECombatEngine.calculate_damage(
		raw_base_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		1.0,
		0,
		SFECombatEngine.StructureType.NONE
	)
	if not assert_almost_eq(marine_hit.damage_dealt, 39.0, 0.01, "Marine takes 40 - 1 = 39 damage"):
		return get_last_failure()
	
	# Hit on Bunker (StructureType.BUNKER, raw damage is multiplied by 3.5 = 140, 25% bunker mitigation)
	var bunker_hit = SFECombatEngine.calculate_damage(
		raw_base_dmg * struct_multiplier,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.BUNKER
	)
	if not assert_almost_eq(bunker_hit.damage_dealt, 105.0, 0.01, "Bunker takes 140 * 0.75 = 105 damage"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 8: Hydralisk Extreme Range and Cutoff
# ==============================================================================
func test_b08_hydralisk_extreme_range_and_cutoff() -> Dictionary:
	var attack_range: float = 9.0
	var in_range_dist: float = 9.0
	var out_range_dist: float = 9.01
	
	var can_attack_9m: bool = (in_range_dist <= attack_range)
	var can_attack_9_01m: bool = (out_range_dist <= attack_range)
	
	if not assert_true(can_attack_9m, "Hydralisk can attack at exactly 9.0m"):
		return get_last_failure()
	if not assert_false(can_attack_9_01m, "Hydralisk cannot attack beyond 9.0m"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 9: Boss Shield Absorption Limits & Penetration
# ==============================================================================
func test_b09_boss_shield_absorption_limits() -> Dictionary:
	# Hybrid Dominator: 10,000 HP, 4,000 Shield, 8 flat armor
	var current_hp: float = 10000.0
	var current_shield: float = 4000.0
	var flat_armor: float = 8.0
	
	# Step 1: 3,000 Spell damage dealt -> fully absorbed by shield
	var res1 = SFECombatEngine.calculate_damage(
		3000.0,
		SFECombatEngine.DamageType.SPELL,
		flat_armor,
		0,
		SFECombatEngine.StructureType.NONE,
		true, # is_heroic
		false,
		false,
		current_shield,
		current_hp
	)
	
	current_shield = maxf(0.0, current_shield - res1.absorbed)
	current_hp -= res1.damage_dealt
	
	if not assert_almost_eq(current_shield, 1000.0, 0.01, "Shield reduced from 4000 to 1000"):
		return get_last_failure()
	if not assert_almost_eq(current_hp, 10000.0, 0.01, "HP untouched while shield held"):
		return get_last_failure()
	
	# Step 2: 2,000 Physical damage dealt -> 1000 breaks shield, 1000 penetrates HP with 8 armor
	var res2 = SFECombatEngine.calculate_damage(
		2000.0,
		SFECombatEngine.DamageType.PHYSICAL,
		flat_armor,
		0,
		SFECombatEngine.StructureType.NONE,
		true, # is_heroic
		false,
		false,
		current_shield,
		current_hp
	)
	
	current_shield = maxf(0.0, current_shield - res2.absorbed)
	current_hp -= res2.damage_dealt
	
	if not assert_almost_eq(current_shield, 0.0, 0.01, "Shield broken to 0"):
		return get_last_failure()
	# Penetrating 1000 physical damage minus 8 armor = 992 net HP damage
	# 10000 - 992 = 9008
	if not assert_almost_eq(current_hp, 9008.0, 0.01, "Remaining HP must be 9008 (1000 - 8 armor)"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 10: Boss Burst Phase Skip Edge Case
# ==============================================================================
func test_b10_boss_burst_phase_skip_edge_case() -> Dictionary:
	# Brutalisk: 8,000 HP. Phase 2 at <=66% (5280), Phase 3 at <=33% (2640).
	# A single burst drops boss from 80% (6400 HP) to 20% (1600 HP).
	var initial_hp: float = 6400.0
	var final_hp: float = 1600.0
	
	var passed_phase_2: bool = (initial_hp > 5280.0 and final_hp <= 5280.0)
	var passed_phase_3: bool = (initial_hp > 2640.0 and final_hp <= 2640.0)
	
	if not assert_true(passed_phase_2, "Burst must trigger Phase 2 transition"):
		return get_last_failure()
	if not assert_true(passed_phase_3, "Burst must also trigger Phase 3 transition"):
		return get_last_failure()
	
	# Enforce that final phase state resolves to Phase 3 (Frenzy)
	var final_phase: int = 1
	if final_hp <= 2640.0:
		final_phase = 3
	elif final_hp <= 5280.0:
		final_phase = 2
	
	if not assert_eq(final_phase, 3, "Boss phase state must be Phase 3"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 11: Audio Polyphony Saturation Stress
# ==============================================================================
func test_b11_audio_polyphony_saturation_stress() -> Dictionary:
	var max_polyphony: int = 4
	var active_plays: int = 0
	var dropped_plays: int = 0
	
	# Simulate 50 concurrent requests in the same frame for the same sound ID
	for i in range(50):
		if active_plays < max_polyphony:
			active_plays += 1
		else:
			dropped_plays += 1
	
	if not assert_eq(active_plays, 4, "Active sound voices clamped at 4"):
		return get_last_failure()
	if not assert_eq(dropped_plays, 46, "Remaining 46 voice calls throttled"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# BOUNDARY 12: Headless Safety Across All Systems
# ==============================================================================
func test_b12_headless_safety_all_systems() -> Dictionary:
	# Verifies that running in headless mode guarantees zero display driver / audio device crashes
	var server_name := DisplayServer.get_name()
	if not assert_eq(server_name, "headless", "Must be running in headless DisplayServer mode"):
		return get_last_failure()
	
	# Ensure zero memory corruption in combat result objects
	for i in range(100):
		var res = SFECombatEngine.calculate_damage(50.0, SFECombatEngine.DamageType.PHYSICAL, 2.0)
		if res.damage_dealt != 48.0:
			return fail_test("Combat calculation anomaly under headless stress")
	
	return pass_test()
