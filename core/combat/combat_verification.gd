extends SceneTree

## Standalone verification script for Milestone 2: Combat Engine & Buff System.
## Runs headlessly via:
## & "E:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://core/combat/combat_verification.gd

const CombatTypes = preload("res://core/combat/combat_types.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const SFEBuffDef = preload("res://core/combat/sfe_buff_def.gd")
const ActiveBuff = preload("res://core/combat/active_buff.gd")
const SFEBuffEngine = preload("res://core/combat/sfe_buff_engine.gd")
const CombatResult = preload("res://core/combat/combat_result.gd")

var total_asserts: int = 0
var failed_asserts: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("=== RUNNING MILESTONE 2: COMBAT ENGINE & BUFF TESTS ===")
	print("=======================================================\n")

	_test_combat_engine()
	_test_buff_engine()
	_test_buff_resources()
	_test_official_e2e_r2_suite()

	print("\n=======================================================")
	if failed_asserts == 0:
		print("MILESTONE 2 VERIFICATION: ALL %d ASSERTIONS PASSED! [STATUS: GREEN]" % total_asserts)
		print("=======================================================\n")
		quit(0)
	else:
		print("MILESTONE 2 VERIFICATION: %d/%d ASSERTIONS FAILED! [STATUS: RED]" % [failed_asserts, total_asserts])
		print("=======================================================\n")
		quit(1)

func assert_eq(actual: Variant, expected: Variant, test_name: String) -> void:
	total_asserts += 1
	if actual == expected:
		print("  [PASS] %s" % test_name)
	else:
		failed_asserts += 1
		print("  [FAIL] %s: Expected '%s', got '%s'" % [test_name, str(expected), str(actual)])

func assert_approx(actual: float, expected: float, test_name: String, tolerance: float = 0.001) -> void:
	total_asserts += 1
	if absf(actual - expected) <= tolerance:
		print("  [PASS] %s (%.4f ≈ %.4f)" % [test_name, actual, expected])
	else:
		failed_asserts += 1
		print("  [FAIL] %s: Expected ~%.4f, got %.4f (diff=%.6f)" % [test_name, expected, actual, absf(actual - expected)])

func assert_true(condition: bool, test_name: String) -> void:
	total_asserts += 1
	if condition:
		print("  [PASS] %s" % test_name)
	else:
		failed_asserts += 1
		print("  [FAIL] %s: Expected true, got false" % test_name)

func assert_false(condition: bool, test_name: String) -> void:
	total_asserts += 1
	if not condition:
		print("  [PASS] %s" % test_name)
	else:
		failed_asserts += 1
		print("  [FAIL] %s: Expected false, got true" % test_name)

func _test_combat_engine() -> void:
	print(">> Suite 1: SFECombatEngine Core Mathematical Calculator")

	# 1. Physical damage reduction by flat armor
	# 20 raw physical vs 5 flat armor -> 15 damage
	var res1: CombatResult = SFECombatEngine.calculate_damage(20.0, CombatTypes.DamageType.PHYSICAL, 5.0, 0)
	assert_approx(res1.damage_dealt, 15.0, "Physical damage: 20 raw - 5 flat armor = 15")
	assert_false(res1.is_immune, "Physical damage: entity is not immune")
	assert_approx(res1.mitigated_amount, 5.0, "Physical damage: mitigated amount is 5")

	# 2. Physical damage floor: minimum 1.0 damage floor when flat armor exceeds raw damage
	var res2: CombatResult = SFECombatEngine.calculate_damage(20.0, CombatTypes.DamageType.PHYSICAL, 25.0, 0)
	assert_approx(res2.damage_dealt, 1.0, "Physical damage floor: 20 raw vs 25 flat armor = 1.0 floor")

	# 3. Progressive upgrade mitigation: 0.2% per level (Level 50 = 10% reduction)
	var res3: CombatResult = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 50)
	assert_approx(res3.damage_dealt, 90.0, "Progressive mitigation: 100 raw, lvl 50 (10% reduction) = 90")

	# 4. Progressive upgrade mitigation cap: capped at 50% max
	var res4: CombatResult = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 300)
	assert_approx(res4.damage_dealt, 50.0, "Progressive mitigation cap: 100 raw, lvl 300 capped at 50% = 50")

	# 5. Spell damage completely bypasses flat armor
	var res5: CombatResult = SFECombatEngine.calculate_damage(80.0, CombatTypes.DamageType.SPELL, 20.0, 0)
	assert_approx(res5.damage_dealt, 80.0, "Spell damage bypasses flat armor: 80 raw vs 20 flat armor = 80")

	# 6. Spell damage respects progressive upgrade mitigation
	var res6: CombatResult = SFECombatEngine.calculate_damage(80.0, CombatTypes.DamageType.SPELL, 20.0, 50)
	assert_approx(res6.damage_dealt, 72.0, "Spell damage + progressive mitigation: 80 raw, lvl 50 = 72")

	# 7. Structural passive mitigation: WALL_REINFORCED (35% reduction)
	var res7: CombatResult = SFECombatEngine.calculate_damage(
		100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED
	)
	assert_approx(res7.damage_dealt, 65.0, "Structural mitigation: 100 raw vs WALL_REINFORCED (35% red) = 65")

	# 8. Structural passive mitigation: BUNKER (25% reduction)
	var res8: CombatResult = SFECombatEngine.calculate_damage(
		100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER
	)
	assert_approx(res8.damage_dealt, 75.0, "Structural mitigation: 100 raw vs BUNKER (25% red) = 75")

	# 9. Case A from Technical Specification:
	# Attacker: 20.0 Physical damage
	# Target: BUNKER, flat_armor = 4, upgrade_level = 25
	# Step 1: max(1.0, 20 - 4) = 16.0
	# Step 2: 25 * 0.002 = 0.05 -> 16.0 * 0.95 = 15.2
	# Step 3: Bunker 25% -> 15.2 * 0.75 = 11.4
	var res_case_a: CombatResult = SFECombatEngine.calculate_damage(
		20.0, CombatTypes.DamageType.PHYSICAL, 4.0, 25, CombatTypes.StructureType.BUNKER
	)
	assert_approx(res_case_a.damage_dealt, 11.4, "Case A: 20 phys vs Bunker (armor 4, lvl 25) = 11.4")

	# 10. Case B from Technical Specification:
	# Attacker: 80.0 Spell damage (AoE)
	# Target: HEROIC Allied Hero, flat_armor = 10, upgrade_level = 50
	# Step 1: Spell bypasses flat armor -> 80.0
	# Step 2: 50 * 0.002 = 0.10 -> 80.0 * 0.90 = 72.0
	# Step 3: Not a structure -> 72.0
	# Step 4: Heroic AoE penalty 40% -> 72.0 * 0.60 = 43.2
	var res_case_b: CombatResult = SFECombatEngine.calculate_damage(
		80.0, CombatTypes.DamageType.SPELL, 10.0, 50, CombatTypes.StructureType.NONE, true, true
	)
	assert_approx(res_case_b.damage_dealt, 43.2, "Case B: 80 spell AoE vs HEROIC (armor 10, lvl 50) = 43.2")

	# 11. HEROIC non-AoE spell does NOT receive AoE penalty
	var res_heroic_single: CombatResult = SFECombatEngine.calculate_damage(
		80.0, CombatTypes.DamageType.SPELL, 10.0, 50, CombatTypes.StructureType.NONE, true, false
	)
	assert_approx(res_heroic_single.damage_dealt, 72.0, "HEROIC single-target spell receives no AoE penalty = 72")

	# 12. Invulnerability: returns strictly 0.0 damage and is_immune = true
	var res_invuln: CombatResult = SFECombatEngine.calculate_damage(
		999.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.NONE, false, false, true
	)
	assert_approx(res_invuln.damage_dealt, 0.0, "Invulnerability: damage dealt is 0.0")
	assert_true(res_invuln.is_immune, "Invulnerability: is_immune flag is true")

	# 13. Shield absorption
	var res_shield: CombatResult = SFECombatEngine.calculate_damage(
		100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.NONE, false, false, false, 40.0
	)
	assert_approx(res_shield.damage_dealt, 60.0, "Shield absorption: 100 raw vs 40 shield = 60 dealt")
	assert_approx(res_shield.absorbed, 40.0, "Shield absorption: 40 damage absorbed")

	# 14. Overkill calculation
	var res_overkill: CombatResult = SFECombatEngine.calculate_damage(
		100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.NONE, false, false, false, 0.0, 30.0
	)
	assert_approx(res_overkill.damage_dealt, 100.0, "Overkill: 100 damage dealt to 30 hp target")
	assert_approx(res_overkill.overkill, 70.0, "Overkill: 70 excess damage")

func _test_buff_engine() -> void:
	print("\n>> Suite 2: SFEBuffEngine & ActiveBuff Mechanics")

	var engine := SFEBuffEngine.new()

	# 1. Standard Buff Stacking Clamping: max 2 stacks by default
	var stim_def := SFEBuffDef.new(&"test_stim", "Test Stimpack", 5.0, 2)
	var buff1 = engine.apply_buff(stim_def)
	assert_eq(buff1.current_stacks, 1, "First application: 1 stack")
	assert_approx(buff1.time_remaining, 5.0, "First application: 5.0s remaining")

	var buff2 = engine.apply_buff(stim_def)
	assert_eq(buff2.current_stacks, 2, "Second application: 2 stacks")

	var buff3 = engine.apply_buff(stim_def)
	assert_eq(buff3.current_stacks, 2, "Third application: CLAMPED at 2 stacks (default cap)")
	assert_eq(engine.get_stacks(&"test_stim"), 2, "engine.get_stacks returns 2")

	# 2. Configurable Stack Override: Tychus passive up to 20 stacks
	var tychus_def := SFEBuffDef.new(&"tychus_passive", "Tychus Minigun", 4.0, 20)
	for i in range(25):
		engine.apply_buff(tychus_def)
	assert_eq(engine.get_stacks(&"tychus_passive"), 20, "Tychus passive: CLAMPED at 20 stacks after 25 applications")

	# 3. Temporary Invulnerability Windows
	var invuln_def := SFEBuffDef.new(&"divine_shield", "Divine Shield", 3.0, 1, true)
	assert_false(engine.is_invulnerable(), "Before invulnerability buff: engine is not invulnerable")

	engine.apply_buff(invuln_def)
	assert_true(engine.is_invulnerable(), "With active invulnerability buff: engine is invulnerable")

	# Tick 2.0s -> 1.0s remaining
	engine.tick(2.0)
	assert_true(engine.is_invulnerable(), "After 2.0s tick (1.0s left): engine remains invulnerable")

	# Tick another 1.5s -> expires
	engine.tick(1.5)
	assert_false(engine.is_invulnerable(), "After full duration tick: invulnerability expired")
	assert_false(engine.has_buff(&"divine_shield"), "Expired buff automatically pruned")

	# 4. Lasting Empowerment Mechanic A: Percentage increase on apply
	engine.set_lasting_empowerment_bonus(0.40) # +40%
	var empowered_def := SFEBuffDef.new(&"empowered_buff", "Empowered Buff", 5.0, 2)
	var emp_buff = engine.apply_buff(empowered_def)
	assert_approx(emp_buff.time_remaining, 7.0, "Lasting Empowerment on apply (+40% on 5.0s) = 7.0s")
	engine.set_lasting_empowerment_bonus(0.0) # Reset to default

	# 5. Lasting Empowerment Mechanic B: Active flat duration extension
	var normal_def := SFEBuffDef.new(&"normal_buff", "Normal Buff", 6.0, 2)
	var norm_buff = engine.apply_buff(normal_def)
	assert_approx(norm_buff.time_remaining, 6.0, "Normal buff: 6.0s duration")

	var extended_count: int = engine.apply_lasting_empowerment_active(3.0)
	assert_true(extended_count >= 1, "apply_lasting_empowerment_active extended active buffs")
	assert_approx(norm_buff.time_remaining, 9.0, "Normal buff extended by flat +3.0s = 9.0s")

	# 6. Stat Multipliers & Flat Modifiers with Stacks
	var armor_def := SFEBuffDef.new(&"rock_armor", "Rock Armor", 10.0, 3, false, {}, {"flat_armor": 4.0})
	engine.apply_buff(armor_def)
	assert_approx(engine.get_total_flat_modifier("flat_armor"), 4.0, "1 stack rock armor = 4.0 flat armor")

	engine.apply_buff(armor_def)
	assert_approx(engine.get_total_flat_modifier("flat_armor"), 8.0, "2 stacks rock armor = 8.0 flat armor")

func _test_buff_resources() -> void:
	print("\n>> Suite 3: Standard Buff Resources (.tres)")

	var buff_paths: Dictionary = {
		"stimpack": "res://data/buffs/stimpack.tres",
		"frenzy": "res://data/buffs/frenzy.tres",
		"armor_boost": "res://data/buffs/armor_boost.tres",
		"tychus_passive": "res://data/buffs/tychus_passive.tres",
		"invulnerability_shield": "res://data/buffs/invulnerability_shield.tres"
	}

	for id in buff_paths.keys():
		var path: String = buff_paths[id]
		assert_true(ResourceLoader.exists(path), "Resource exists at '%s'" % path)
		var res = load(path)
		assert_true(res is SFEBuffDef, "Resource at '%s' is SFEBuffDef" % path)

	# Verify Stimpack
	var stim: SFEBuffDef = load(buff_paths["stimpack"]) as SFEBuffDef
	assert_eq(stim.buff_id, &"stimpack", "Stimpack buff_id is &\"stimpack\"")
	assert_eq(stim.default_max_stacks, 2, "Stimpack max stacks is 2")
	assert_approx(stim.default_duration, 10.0, "Stimpack default duration is 10.0")
	assert_approx(float(stim.stat_multipliers.get("attack_speed", 0.0)), 1.5, "Stimpack attack_speed = 1.5")
	assert_approx(float(stim.stat_multipliers.get("move_speed", 0.0)), 1.3, "Stimpack move_speed = 1.3")

	# Verify Frenzy
	var frenzy: SFEBuffDef = load(buff_paths["frenzy"]) as SFEBuffDef
	assert_eq(frenzy.buff_id, &"frenzy", "Frenzy buff_id is &\"frenzy\"")
	assert_eq(frenzy.default_max_stacks, 2, "Frenzy max stacks is 2")
	assert_approx(frenzy.default_duration, 8.0, "Frenzy default duration is 8.0")
	assert_approx(float(frenzy.stat_multipliers.get("attack_speed", 0.0)), 1.25, "Frenzy attack_speed = 1.25")

	# Verify ArmorBoost
	var armor: SFEBuffDef = load(buff_paths["armor_boost"]) as SFEBuffDef
	assert_eq(armor.buff_id, &"armor_boost", "ArmorBoost buff_id is &\"armor_boost\"")
	assert_eq(armor.default_max_stacks, 2, "ArmorBoost max stacks is 2")
	assert_approx(armor.default_duration, 12.0, "ArmorBoost default duration is 12.0")
	assert_approx(float(armor.flat_modifiers.get("flat_armor", 0.0)), 5.0, "ArmorBoost flat_armor = 5.0")

	# Verify TychusPassive
	var tychus: SFEBuffDef = load(buff_paths["tychus_passive"]) as SFEBuffDef
	assert_eq(tychus.buff_id, &"tychus_passive", "TychusPassive buff_id is &\"tychus_passive\"")
	assert_eq(tychus.default_max_stacks, 20, "TychusPassive max stacks is 20")
	assert_approx(tychus.default_duration, 4.0, "TychusPassive default duration is 4.0")

	# Verify InvulnerabilityShield
	var invuln: SFEBuffDef = load(buff_paths["invulnerability_shield"]) as SFEBuffDef
	assert_eq(invuln.buff_id, &"invulnerability_shield", "InvulnerabilityShield buff_id is &\"invulnerability_shield\"")
	assert_true(invuln.is_invulnerable, "InvulnerabilityShield is_invulnerable is true")
	assert_approx(invuln.default_duration, 3.0, "InvulnerabilityShield default duration is 3.0")

func _test_official_e2e_r2_suite() -> void:
	if not ResourceLoader.exists("res://tests/test_r2_combat.gd"):
		print("  [SKIP] res://tests/test_r2_combat.gd not found")
		return

	print("\n>> Suite 4: Official E2E Test Suite (res://tests/test_r2_combat.gd)")
	var suite_script = load("res://tests/test_r2_combat.gd")
	var suite_instance = suite_script.new()
	var methods = suite_script.get_script_method_list()
	for m in methods:
		var name: String = m["name"]
		if name.begins_with("test_"):
			var result: Dictionary = suite_instance.call(name)
			total_asserts += 1
			if result.get("passed", false):
				print("  [PASS] E2E::%s" % name)
			else:
				failed_asserts += 1
				print("  [FAIL] E2E::%s: %s" % [name, result.get("error", "unknown error")])
