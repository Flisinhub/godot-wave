extends "res://tests/test_base.gd"

## Test Suite for Requirement R2:
## Advanced Combat Engine, Damage Typing, Flat Armor, Progressive & Structural Mitigations,
## Heroic Penalties, Buff Stacking (2 and 20), Invulnerability, and Lasting Empowerment.

const CombatTypes = preload("res://core/combat/combat_types.gd")
const CombatResult = preload("res://core/combat/combat_result.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const SFEBuffEngine = preload("res://core/combat/sfe_buff_engine.gd")
const ActiveBuff = preload("res://core/combat/active_buff.gd")
const SFEBuffDef = preload("res://core/combat/sfe_buff_def.gd")

func test_physical_flat_armor_reduction() -> Dictionary:
	var DType = CombatTypes.DamageType
	
	# 20.0 physical vs 5.0 armor -> 15.0 damage
	var res := SFECombatEngine.calculate_damage(20.0, DType.PHYSICAL, 5.0)
	if not assert_almost_eq(res.damage_dealt, 15.0, 0.001, "20.0 physical vs 5.0 armor should deal 15.0"):
		return get_last_failure()
	if not assert_almost_eq(res.mitigated_amount, 5.0, 0.001, "Mitigated amount should be 5.0"):
		return get_last_failure()
		
	# Flat armor exceeding raw damage -> floor at 1.0 damage
	var res_floor := SFECombatEngine.calculate_damage(5.0, DType.PHYSICAL, 10.0)
	if not assert_almost_eq(res_floor.damage_dealt, 1.0, 0.001, "Physical damage cannot be reduced below 1.0"):
		return get_last_failure()
	if not assert_almost_eq(res_floor.mitigated_amount, 4.0, 0.001, "Mitigated amount capped at raw - 1.0"):
		return get_last_failure()
		
	# Zero armor -> full raw damage
	var res_zero := SFECombatEngine.calculate_damage(12.5, DType.PHYSICAL, 0.0)
	if not assert_almost_eq(res_zero.damage_dealt, 12.5, 0.001, "Zero armor deals full damage"):
		return get_last_failure()

	return pass_test()

func test_spell_damage_bypasses_flat_armor() -> Dictionary:
	var DType = CombatTypes.DamageType
	
	# Spell attacks must completely ignore flat armor (0 reduction)
	var res := SFECombatEngine.calculate_damage(50.0, DType.SPELL, 20.0)
	if not assert_almost_eq(res.damage_dealt, 50.0, 0.001, "Spell damage must completely ignore flat armor"):
		return get_last_failure()
	if not assert_almost_eq(res.mitigated_amount, 0.0, 0.001, "No flat armor mitigation for spell damage"):
		return get_last_failure()

	return pass_test()

func test_upgrade_progressive_mitigation() -> Dictionary:
	var DType = CombatTypes.DamageType
	
	# Progressive rate: 0.2% per upgrade level (Level 50 = 10% reduction, multiplier 0.90)
	# Raw 25.0 physical vs 5.0 flat armor:
	# Step 1: flat armor -> 20.0
	# Step 2: progressive 10% -> 20.0 * 0.90 = 18.0
	var res_lvl50 := SFECombatEngine.calculate_damage(25.0, DType.PHYSICAL, 5.0, 50)
	if not assert_almost_eq(res_lvl50.damage_dealt, 18.0, 0.001, "Level 50 upgrade (10% mitigation) on 20.0 net physical = 18.0"):
		return get_last_failure()
		
	# Progressive mitigation cap at 50% (Level 250+)
	# 25.0 physical vs 5.0 flat armor with level 300:
	# 20.0 * (1 - 0.50) = 10.0 damage
	var res_capped := SFECombatEngine.calculate_damage(25.0, DType.PHYSICAL, 5.0, 300)
	if not assert_almost_eq(res_capped.damage_dealt, 10.0, 0.001, "Progressive mitigation should cap at 50%"):
		return get_last_failure()
		
	# Progressive mitigation also applies to spell damage
	# 100.0 spell damage, level 50 (10% mitigation) = 90.0
	var res_spell := SFECombatEngine.calculate_damage(100.0, DType.SPELL, 15.0, 50)
	if not assert_almost_eq(res_spell.damage_dealt, 90.0, 0.001, "Spell damage respects progressive percentage mitigation"):
		return get_last_failure()

	return pass_test()

func test_structural_passive_mitigation() -> Dictionary:
	var DType = CombatTypes.DamageType
	var SType = CombatTypes.StructureType
	
	# Reinforced wall: 35% passive mitigation (multiplier 0.65)
	var res_wall := SFECombatEngine.calculate_damage(100.0, DType.PHYSICAL, 0.0, 0, SType.WALL_REINFORCED)
	if not assert_almost_eq(res_wall.damage_dealt, 65.0, 0.001, "Reinforced wall should mitigate 35% of damage (deal 65.0)"):
		return get_last_failure()
		
	# Fortified bunker: 25% passive mitigation (multiplier 0.75)
	var res_bunker := SFECombatEngine.calculate_damage(100.0, DType.PHYSICAL, 0.0, 0, SType.BUNKER)
	if not assert_almost_eq(res_bunker.damage_dealt, 75.0, 0.001, "Bunker should mitigate 25% of damage (deal 75.0)"):
		return get_last_failure()
		
	# Generic structure: 0% reduction
	var res_gen := SFECombatEngine.calculate_damage(100.0, DType.PHYSICAL, 0.0, 0, SType.OTHER)
	if not assert_almost_eq(res_gen.damage_dealt, 100.0, 0.001, "Generic structure should have 0% passive mitigation"):
		return get_last_failure()
		
	# Worked numerical example from survey report (Case A):
	# Attacker: Zergling dealing 20.0 physical
	# Defender: Bunker (flat armor = 4.0, upgrade level = 25)
	# 1. Flat Armor: max(1.0, 20.0 - 4.0) = 16.0
	# 2. Progressive: 25 * 0.002 = 0.05 (5% red) -> 16.0 * 0.95 = 15.2
	# 3. Bunker: 25% red -> 15.2 * 0.75 = 11.4
	var res_case_a := SFECombatEngine.calculate_damage(20.0, DType.PHYSICAL, 4.0, 25, SType.BUNKER)
	if not assert_almost_eq(res_case_a.damage_dealt, 11.4, 0.001, "Worked Case A: 20 physical vs bunker (4 armor, lvl 25) = 11.4"):
		return get_last_failure()

	return pass_test()

func test_heroic_aoe_spell_penalties() -> Dictionary:
	var DType = CombatTypes.DamageType
	var SType = CombatTypes.StructureType
	var TargetTag = CombatTypes.TargetTag
	
	# Worked numerical example from survey report (Case B):
	# Attacker: Roach Acid Spray dealing 80.0 Spell damage (AoE = true)
	# Defender: Allied Hero (Tag HEROIC, flat armor = 10.0, upgrade level = 50)
	# 1. Flat Armor: Bypassed for SPELL -> 80.0
	# 2. Progressive: 50 * 0.002 = 0.10 (10% red) -> 72.0
	# 3. Structural: None (0%)
	# 4. Heroic AoE Penalty: 40% red -> 72.0 * (1 - 0.40) = 43.2
	var res_case_b := SFECombatEngine.calculate_damage(
		80.0,
		DType.SPELL,
		10.0,
		50,
		SType.NONE,
		true, # is_heroic
		true  # is_aoe
	)
	if not assert_almost_eq(res_case_b.damage_dealt, 43.2, 0.001, "Worked Case B: 80 spell AoE vs Hero (lvl 50) = 43.2"):
		return get_last_failure()
		
	# Non-AoE Spell vs Hero: does NOT trigger heroic penalty
	var res_single_spell := SFECombatEngine.calculate_damage(
		80.0,
		DType.SPELL,
		10.0,
		50,
		SType.NONE,
		true, # is_heroic
		false # is_aoe
	)
	if not assert_almost_eq(res_single_spell.damage_dealt, 72.0, 0.001, "Single-target spell does not suffer heroic AoE penalty"):
		return get_last_failure()
		
	# AoE Physical vs Hero: does NOT trigger heroic AoE spell penalty
	var res_aoe_phys := SFECombatEngine.calculate_damage(
		80.0,
		DType.PHYSICAL,
		10.0,
		50,
		SType.NONE,
		true, # is_heroic
		true  # is_aoe
	)
	# 80 - 10 = 70. 70 * 0.90 = 63.0
	if not assert_almost_eq(res_aoe_phys.damage_dealt, 63.0, 0.001, "AoE physical does not suffer heroic AoE spell penalty"):
		return get_last_failure()

	return pass_test()

func test_invulnerability_zero_damage() -> Dictionary:
	var DType = CombatTypes.DamageType
	
	# Active invulnerability must deal strictly 0.0 damage and set is_immune = true
	var res_invuln := SFECombatEngine.calculate_damage(
		99999.0,
		DType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.NONE,
		false,
		false,
		true # is_invulnerable
	)
	if not assert_almost_eq(res_invuln.damage_dealt, 0.0, 0.001, "Invulnerable entity receives strictly 0.0 damage"):
		return get_last_failure()
	if not assert_true(res_invuln.is_immune, "CombatResult.is_immune must be true for invulnerable entity"):
		return get_last_failure()
	if not assert_almost_eq(res_invuln.mitigated_amount, 99999.0, 0.001, "All incoming damage considered mitigated"):
		return get_last_failure()

	return pass_test()

func test_shield_absorption_and_overkill() -> Dictionary:
	var DType = CombatTypes.DamageType
	
	# Shield absorption: 50.0 damage vs 30.0 shield HP -> absorbed: 30.0, dealt: 20.0
	var res_shield := SFECombatEngine.calculate_damage(
		50.0,
		DType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.NONE,
		false,
		false,
		false,
		30.0 # shield_hp
	)
	if not assert_almost_eq(res_shield.absorbed, 30.0, 0.001, "Shield should absorb 30.0 damage"):
		return get_last_failure()
	if not assert_almost_eq(res_shield.damage_dealt, 20.0, 0.001, "Remaining 20.0 damage dealt to HP"):
		return get_last_failure()
		
	# Overkill: 50.0 damage dealt vs 15.0 current HP -> overkill: 35.0
	var res_over := SFECombatEngine.calculate_damage(
		50.0,
		DType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.NONE,
		false,
		false,
		false,
		0.0,
		15.0 # current_hp
	)
	if not assert_almost_eq(res_over.overkill, 35.0, 0.001, "Overkill should be 35.0"):
		return get_last_failure()

	return pass_test()

func test_buff_stack_clamping_default_2() -> Dictionary:
	var engine = SFEBuffEngine.new()
	var stim_def = SFEBuffDef.new(&"stimpack", "Stimpack", 5.0, 2)
	
	# 1st application -> 1 stack
	var b1 := engine.apply_buff(stim_def)
	if not assert_eq(engine.get_stacks(&"stimpack"), 1, "Initial buff application should have 1 stack"):
		return get_last_failure()
		
	# 2nd application -> 2 stacks
	var b2 := engine.apply_buff(stim_def)
	if not assert_eq(engine.get_stacks(&"stimpack"), 2, "Second buff application should have 2 stacks"):
		return get_last_failure()
		
	# 3rd application -> clamped at default 2 stacks
	var b3 := engine.apply_buff(stim_def)
	if not assert_eq(engine.get_stacks(&"stimpack"), 2, "Default buff must clamp at 2 stacks"):
		return get_last_failure()
	if not assert_almost_eq(b3.time_remaining, 5.0, 0.05, "3rd application refreshes duration to 5.0s"):
		return get_last_failure()

	return pass_test()

func test_buff_stack_extension_tychus_20() -> Dictionary:
	var engine = SFEBuffEngine.new()
	var tychus_def = SFEBuffDef.new(&"tychus_passive", "Minigun Spin-up", 4.0, 20)
	
	# Apply 25 consecutive stacks
	for i in range(25):
		engine.apply_buff(tychus_def, -1.0, 20)
		
	if not assert_eq(engine.get_stacks(&"tychus_passive"), 20, "Tychus passive should stack up to exactly 20"):
		return get_last_failure()

	return pass_test()

func test_buff_duration_and_expiration() -> Dictionary:
	var engine = SFEBuffEngine.new()
	var frenzy_def = SFEBuffDef.new(&"frenzy", "Frenzy", 3.0, 2)
	
	engine.apply_buff(frenzy_def)
	if not assert_true(engine.has_buff(&"frenzy"), "Buff should be active"):
		return get_last_failure()
		
	# Tick 1.5 seconds -> still active
	engine.tick(1.5)
	if not assert_true(engine.has_buff(&"frenzy"), "Buff should be active after 1.5s"):
		return get_last_failure()
	if not assert_almost_eq(engine.get_buff(&"frenzy").time_remaining, 1.5, 0.05, "1.5s remaining"):
		return get_last_failure()
		
	# Tick 2.0 seconds -> total 3.5s elapsed, should expire
	engine.tick(2.0)
	if not assert_false(engine.has_buff(&"frenzy"), "Buff must expire when duration reaches zero"):
		return get_last_failure()

	return pass_test()

func test_lasting_empowerment_mechanics() -> Dictionary:
	var engine = SFEBuffEngine.new()
	
	# Mechanic A: Percentage bonus on application (+40% = 0.40)
	engine.set_lasting_empowerment_bonus(0.40)
	var buff_def = SFEBuffDef.new(&"armor_boost", "Armor Boost", 5.0, 2)
	var active := engine.apply_buff(buff_def)
	
	# Base 5.0s * 1.40 = 7.0s duration
	if not assert_almost_eq(active.duration, 7.0, 0.05, "+40% Lasting Empowerment should extend 5.0s to 7.0s"):
		return get_last_failure()
		
	# Mechanic B: Active flat duration extension across all active buffs
	engine.extend_all_buffs(3.0)
	if not assert_almost_eq(active.time_remaining, 10.0, 0.05, "Flat extension adds 3.0s (7.0 + 3.0 = 10.0s)"):
		return get_last_failure()

	return pass_test()

func test_buff_stat_modifiers() -> Dictionary:
	var def = SFEBuffDef.new(&"empower", "Empower", 10.0, 5)
	def.stat_multipliers["attack_speed"] = 1.10 # +10% per stack
	def.flat_modifiers["flat_armor"] = 2.0      # +2 flat armor per stack
	
	var active = ActiveBuff.new(def, 10.0, 5)
	active.add_stack(2) # current_stacks = 3
	
	# Multiplier with 3 stacks: 1.0 + (0.10 * 3) = 1.30
	var speed_mult := active.get_stat_multiplier("attack_speed")
	if not assert_almost_eq(speed_mult, 1.30, 0.01, "3 stacks of +10% attack speed should yield 1.30x"):
		return get_last_failure()
		
	# Flat modifier with 3 stacks: 2.0 * 3 = 6.0
	var armor_flat := active.get_flat_modifier("flat_armor")
	if not assert_almost_eq(armor_flat, 6.0, 0.01, "3 stacks of +2.0 flat armor should yield +6.0"):
		return get_last_failure()

	return pass_test()

func test_progressive_mitigation_level_0() -> Dictionary:
	var res := SFECombatEngine.calculate_damage(50.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0)
	if not assert_almost_eq(res.damage_dealt, 50.0, 0.001, "Level 0 upgrade must apply 0% progressive mitigation"):
		return get_last_failure()
	return pass_test()

func test_flat_armor_negative_and_zero_raw_damage() -> Dictionary:
	var res_zero := SFECombatEngine.calculate_damage(0.0, CombatTypes.DamageType.PHYSICAL, 5.0)
	if not assert_almost_eq(res_zero.damage_dealt, 0.0, 0.001, "0.0 raw damage must yield 0.0 dealt"):
		return get_last_failure()
	var res_neg := SFECombatEngine.calculate_damage(-10.0, CombatTypes.DamageType.PHYSICAL, 5.0)
	if not assert_almost_eq(res_neg.damage_dealt, 0.0, 0.001, "Negative raw damage must yield 0.0 dealt"):
		return get_last_failure()
	return pass_test()

func test_heroic_non_aoe_spell_no_penalty() -> Dictionary:
	# Single target spell on hero: 100 raw, flat armor 10 (bypassed), upgrade lvl 0, heroic=true, aoe=false
	var res := SFECombatEngine.calculate_damage(
		100.0,
		CombatTypes.DamageType.SPELL,
		10.0,
		0,
		CombatTypes.StructureType.NONE,
		true, # heroic
		false # aoe = false
	)
	if not assert_almost_eq(res.damage_dealt, 100.0, 0.001, "Non-AoE spell against hero must not be penalized"):
		return get_last_failure()
	return pass_test()

func test_heroic_physical_aoe_no_penalty() -> Dictionary:
	# AoE physical on hero: 100 raw, flat armor 10, upgrade lvl 0, heroic=true, aoe=true
	var res := SFECombatEngine.calculate_damage(
		100.0,
		CombatTypes.DamageType.PHYSICAL,
		10.0,
		0,
		CombatTypes.StructureType.NONE,
		true, # heroic
		true  # aoe = true
	)
	# Physical gets mitigated by flat armor (100 - 10 = 90), but NOT by the 40% AoE spell penalty
	if not assert_almost_eq(res.damage_dealt, 90.0, 0.001, "AoE physical against hero must not get AoE spell penalty"):
		return get_last_failure()
	return pass_test()

func test_invulnerability_state_transition_signal() -> Dictionary:
	var engine = SFEBuffEngine.new()
	var invuln_signal_fired: Array[bool] = []
	engine.invulnerability_changed.connect(func(active: bool): invuln_signal_fired.append(active))
	
	var invuln_def = SFEBuffDef.new(&"divine_shield", "Divine Shield", 2.0, 1, true)
	engine.apply_buff(invuln_def)
	
	if not assert_true(engine.is_invulnerable(), "Engine must report invulnerable"):
		return get_last_failure()
	if not assert_true(invuln_signal_fired.has(true), "invulnerability_changed(true) signal should fire"):
		return get_last_failure()
		
	# Tick until expired
	engine.tick(2.5)
	if not assert_false(engine.is_invulnerable(), "Engine must report not invulnerable after expiration"):
		return get_last_failure()
	if not assert_true(invuln_signal_fired.has(false), "invulnerability_changed(false) signal should fire on expiry"):
		return get_last_failure()
	return pass_test()

func test_calculate_from_dict_helper() -> Dictionary:
	var dict_params := {
		"raw_damage": 30.0,
		"damage_type": CombatTypes.DamageType.PHYSICAL,
		"flat_armor": 5.0,
		"upgrade_level": 10,
		"structure_type": CombatTypes.StructureType.BUNKER
	}
	var res := SFECombatEngine.calculate_from_dict(dict_params)
	# 30 - 5 = 25. Level 10 = 2% red -> 25 * 0.98 = 24.5. Bunker 25% red -> 24.5 * 0.75 = 18.375
	if not assert_almost_eq(res.damage_dealt, 18.375, 0.001, "calculate_from_dict produces exact mitigation"):
		return get_last_failure()
	return pass_test()

