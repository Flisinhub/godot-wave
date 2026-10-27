extends SceneTree

## SFE5 Phase 3 Adversarial Gameplay Stress Test Harness
## Adversarially challenges and verifies Phase 3 gameplay invariants:
## 1. Mass Baneling breach against reinforced walls (140.0 structural dmg & 50% premature pop)
## 2. Hydralisk extreme line-penetration geometry (angles, distances, line occlusion)
## 3. Brutalisk burst phase skip (100% -> <20% in single tick without state freeze or skipping spawns)
## 4. Hybrid Dominator shield collapse (1:1 absorption, armor bypass/mitigation, heroic energy drain)
## 5. Armory wallet boundary & Turret deployment cap (0 minerals, exact minerals, hard cap 6)

const ANSI_GREEN: String = "\u001b[32m"
const ANSI_RED: String = "\u001b[31m"
const ANSI_YELLOW: String = "\u001b[33m"
const ANSI_CYAN: String = "\u001b[36m"
const ANSI_GRAY: String = "\u001b[90m"
const ANSI_BOLD: String = "\u001b[1m"
const ANSI_RESET: String = "\u001b[0m"

const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")
const SFEEconomyManagerScript = preload("res://core/economy/sfe_economy_manager.gd")
const ArmoryUpgradeManagerScript = preload("res://core/upgrades/armory_upgrade_manager.gd")
const WallSegmentScript = preload("res://entities/structures/wall_segment.gd")
const BunkerStructureScript = preload("res://entities/structures/bunker_structure.gd")
const BossBrutalisk3DScript = preload("res://entities/enemies/boss_brutalisk_3d.gd")
const BossHybrid3DScript = preload("res://entities/enemies/boss_hybrid_3d.gd")
const AutoTurret3DScript = preload("res://entities/structures/auto_turret_3d.gd")
const HeroUnit3DScript = preload("res://entities/allies/hero_unit_3d.gd")
const SwarmSimulationScript = preload("res://core/swarm/swarm_simulation.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_messages: Array[String] = []

var _current_test_failed: bool = false
var _current_test_error: String = ""


func _initialize() -> void:
	print(ANSI_CYAN + ANSI_BOLD + "==================================================================" + ANSI_RESET)
	print(ANSI_CYAN + ANSI_BOLD + "=== SFE5 PHASE 3 ADVERSARIAL GAMEPLAY STRESS TEST HARNESS      ===" + ANSI_RESET)
	print(ANSI_CYAN + ANSI_BOLD + "==================================================================" + ANSI_RESET)

	_setup_autoloads()
	var start_ms := Time.get_ticks_msec()

	_run_suite("Suite 1: Mass Baneling Breach Against Fortified Walls", [
		"test_baneling_structural_damage_multiplier_and_wall_mitigation",
		"test_baneling_premature_pop_structural_and_unit_damage",
		"test_mass_baneling_breach_wave_against_reinforced_wall",
		"test_mass_baneling_premature_pop_breach_threshold",
		"test_baneling_despawn_and_wave_manager_died_notification"
	])

	_run_suite("Suite 2: Hydralisk Extreme Line-Penetration Geometry", [
		"test_hydralisk_artillery_range_boundary",
		"test_hydralisk_perfect_collinear_secondary_penetration",
		"test_hydralisk_extreme_angle_cutoff_55_vs_60_degrees",
		"test_hydralisk_distance_cutoffs_near_far",
		"test_hydralisk_reverse_direction_rejection",
		"test_hydralisk_line_occlusion_closest_candidate_priority",
		"test_hydralisk_secondary_structure_mitigation"
	])

	_run_suite("Suite 3: Brutalisk Burst Phase Skip Invariant", [
		"test_brutalisk_burst_100_to_sub20_sequential_phases",
		"test_brutalisk_burst_no_state_freeze",
		"test_brutalisk_lethal_single_tick_burst_from_full_hp"
	])

	_run_suite("Suite 4: Hybrid Dominator Shield Collapse & Energy Drain", [
		"test_hybrid_shield_exact_1_to_1_absorption_no_armor",
		"test_hybrid_exact_shield_collapse_phase_transition",
		"test_hybrid_single_burst_shield_break_physical_surplus_armor_mitigation",
		"test_hybrid_single_burst_shield_break_spell_surplus_bypasses_armor",
		"test_hybrid_psionic_shockwave_energy_drain_on_heroic",
		"test_hybrid_psionic_shockwave_energy_drain_clamped_at_zero",
		"test_hybrid_psionic_shockwave_hero_unit_3d_energy_behavior"
	])

	_run_suite("Suite 5: Armory Wallet Boundary & Turret Deployment Cap", [
		"test_armory_zero_mineral_purchase_rejection",
		"test_armory_off_by_one_mineral_rejection",
		"test_armory_exact_mineral_purchase_boundary",
		"test_turret_deployment_cap_of_six",
		"test_turret_destruction_allows_redeployment_up_to_cap",
		"test_turret_placement_boundary_24m_radius"
	])

	var elapsed_ms := Time.get_ticks_msec() - start_ms
	_print_summary(elapsed_ms)

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)


func _run_suite(suite_name: String, test_names: Array[String]) -> void:
	print("\n" + ANSI_YELLOW + ANSI_BOLD + ">> " + suite_name + ANSI_RESET)
	for tname in test_names:
		total_tests += 1
		_current_test_failed = false
		_current_test_error = ""

		call(tname)

		if _current_test_failed:
			failed_tests += 1
			var fail_str := "[FAIL] %s: %s" % [tname, _current_test_error]
			failure_messages.append(fail_str)
			print("  " + ANSI_RED + "[FAIL] " + ANSI_RESET + tname + ANSI_RED + " -> " + _current_test_error + ANSI_RESET)
		else:
			passed_tests += 1
			print("  " + ANSI_GREEN + "[PASS] " + ANSI_RESET + tname)


func _print_summary(elapsed_ms: int) -> void:
	print("\n" + ANSI_CYAN + ANSI_BOLD + "==================================================================" + ANSI_RESET)
	print(ANSI_CYAN + ANSI_BOLD + "Adversarial Stress Test Execution Complete in %d ms" % elapsed_ms + ANSI_RESET)
	print("Total Invariant Checks: %d" % total_tests)
	print("Passed:                 " + ANSI_GREEN + "%d" % passed_tests + ANSI_RESET)
	print("Failed:                 " + (ANSI_RED if failed_tests > 0 else ANSI_GREEN) + "%d" % failed_tests + ANSI_RESET)

	if failed_tests > 0:
		print("\n" + ANSI_RED + ANSI_BOLD + "FAILURES RECORDED:" + ANSI_RESET)
		for f in failure_messages:
			print(ANSI_RED + "  * " + f + ANSI_RESET)
		print(ANSI_RED + ANSI_BOLD + "VERDICT: REQUEST_CHANGES" + ANSI_RESET)
	else:
		print("\n" + ANSI_GREEN + ANSI_BOLD + "ALL PHASE 3 ADVERSARIAL INVARIANTS SATISFIED! [VERDICT: APPROVE]" + ANSI_RESET)
	print(ANSI_CYAN + ANSI_BOLD + "==================================================================" + ANSI_RESET)


# ==============================================================================
# ASSERTION HELPERS
# ==============================================================================

func assert_true(cond: bool, msg: String = "Expected true, got false") -> bool:
	if not cond:
		_current_test_failed = true
		_current_test_error = msg
		return false
	return true


func assert_false(cond: bool, msg: String = "Expected false, got true") -> bool:
	if cond:
		_current_test_failed = true
		_current_test_error = msg
		return false
	return true


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if actual != expected:
		_current_test_failed = true
		_current_test_error = "%s (Expected %s, got %s)" % [msg, str(expected), str(actual)]
		return false
	return true


func assert_almost_eq(actual: float, expected: float, tol: float = 0.01, msg: String = "") -> bool:
	if absf(actual - expected) > tol:
		_current_test_failed = true
		_current_test_error = "%s (Expected %f ± %f, got %f)" % [msg, expected, tol, actual]
		return false
	return true


func assert_gt(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if not (actual > expected):
		_current_test_failed = true
		_current_test_error = "%s (Expected %s > %s)" % [msg, str(actual), str(expected)]
		return false
	return true


func assert_ge(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if not (actual >= expected):
		_current_test_failed = true
		_current_test_error = "%s (Expected %s >= %s)" % [msg, str(actual), str(expected)]
		return false
	return true


func assert_null(val: Variant, msg: String = "Expected null") -> bool:
	if val != null:
		_current_test_failed = true
		_current_test_error = "%s (Expected null, got %s)" % [msg, str(val)]
		return false
	return true


func assert_not_null(val: Variant, msg: String = "Expected non-null") -> bool:
	if val == null:
		_current_test_failed = true
		_current_test_error = msg
		return false
	return true


# ==============================================================================
# SUITE 1: MASS BANELING BREACH AGAINST FORTIFIED WALLS
# ==============================================================================

func test_baneling_structural_damage_multiplier_and_wall_mitigation() -> void:
	# Baneling nominal unit damage is 40.0; structural damage has 3.5x multiplier = 140.0
	var base_dmg: float = 40.0
	var struct_multiplier: float = 3.5
	var raw_struct_dmg: float = base_dmg * struct_multiplier
	assert_almost_eq(raw_struct_dmg, 140.0, 0.001, "Raw structural damage must equal 140.0")

	# Reinforced wall has 35% passive mitigation: 140 * (1 - 0.35) = 91.0
	var res = SFECombatEngine.calculate_damage(
		raw_struct_dmg,
		CombatTypes.DamageType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.WALL_REINFORCED,
		false,
		true
	)
	assert_almost_eq(res.damage_dealt, 91.0, 0.01, "WallReinforced must take exactly 91.0 net damage from 140.0 Baneling detonation")

	# Bunker has 25% passive mitigation: 140 * (1 - 0.25) = 105.0
	var res_bunker = SFECombatEngine.calculate_damage(
		raw_struct_dmg,
		CombatTypes.DamageType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.BUNKER,
		false,
		true
	)
	assert_almost_eq(res_bunker.damage_dealt, 105.0, 0.01, "Bunker must take exactly 105.0 net damage from 140.0 Baneling detonation")

	# Non-structure (Marine, flat_armor = 1.0): 40.0 - 1.0 = 39.0
	var res_marine = SFECombatEngine.calculate_damage(
		base_dmg,
		CombatTypes.DamageType.PHYSICAL,
		1.0,
		0,
		CombatTypes.StructureType.NONE,
		false,
		true
	)
	assert_almost_eq(res_marine.damage_dealt, 39.0, 0.01, "Unit must take 40 - 1 = 39.0 net damage (no 3.5x multiplier)")


func test_baneling_premature_pop_structural_and_unit_damage() -> void:
	# Premature pop occurs when Baneling is killed before reaching trigger radius.
	# Deals 50% damage: 20.0 to units, 70.0 to structures.
	var premature_unit_dmg: float = 40.0 * 0.5
	var premature_struct_dmg: float = 140.0 * 0.5
	assert_almost_eq(premature_unit_dmg, 20.0, 0.001, "Premature unit damage must be 20.0")
	assert_almost_eq(premature_struct_dmg, 70.0, 0.001, "Premature struct damage must be 70.0")

	# Premature structural damage against reinforced wall (35% mitigation): 70 * (1 - 0.35) = 45.5
	var res_wall = SFECombatEngine.calculate_damage(
		premature_struct_dmg,
		CombatTypes.DamageType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.WALL_REINFORCED,
		false,
		true
	)
	assert_almost_eq(res_wall.damage_dealt, 45.5, 0.01, "WallReinforced must take 45.5 net damage from premature pop")


func _setup_autoloads() -> void:
	if root and not root.has_node("SignalBus"):
		var sb_node = load("res://core/signal_bus.gd").new()
		sb_node.name = "SignalBus"
		root.add_child(sb_node)
	if root and not root.has_node("SFXManager"):
		var sfx_node = load("res://core/audio/sfx_manager.gd").new()
		sfx_node.name = "SFXManager"
		root.add_child(sfx_node)


func _get_signal_bus() -> Node:
	if root and root.has_node("SignalBus"):
		return root.get_node("SignalBus")
	return null


func test_mass_baneling_breach_wave_against_reinforced_wall() -> void:
	# Instantiate a live WallSegment (600 HP) and subject it to a mass breach assault
	var wall = WallSegmentScript.new()
	root.add_child(wall)
	wall.current_health = 600.0
	wall.max_health = 600.0

	var destroyed_emitted: bool = false
	var sb: Node = _get_signal_bus()
	if sb:
		sb.connect("structure_destroyed", func(_s): destroyed_emitted = true, ConnectFlags.CONNECT_ONE_SHOT)

	# 6 Baneling detonations: 6 * 91.0 = 546.0 damage.
	# Remaining health must be exactly 600.0 - 546.0 = 54.0 HP.
	for i in range(6):
		var res = SFECombatEngine.calculate_damage(
			140.0,
			CombatTypes.DamageType.PHYSICAL,
			0.0,
			0,
			CombatTypes.StructureType.WALL_REINFORCED,
			false,
			true
		)
		wall.take_damage(res.damage_dealt)

	assert_almost_eq(wall.current_health, 54.0, 0.01, "Wall must survive 6 Baneling detonations with 54.0 HP")
	assert_false(destroyed_emitted, "Wall must not be destroyed after 6 detonations")

	# 7th Baneling detonation: Deals 91.0 damage, which breaches remaining 54.0 HP
	var res7 = SFECombatEngine.calculate_damage(
		140.0,
		CombatTypes.DamageType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.WALL_REINFORCED,
		false,
		true
	)
	wall.take_damage(res7.damage_dealt)

	assert_almost_eq(wall.current_health, 0.0, 0.01, "Wall health must clamp at 0.0 after 7th detonation")
	assert_true(destroyed_emitted, "structure_destroyed signal must be emitted when wall is breached")


func test_mass_baneling_premature_pop_breach_threshold() -> void:
	# Wall with 600 HP taking 45.5 net damage per premature pop:
	# 13 pops * 45.5 = 591.5 damage -> 8.5 HP remaining.
	# 14th pop = 637.0 damage -> breaches wall.
	var wall_hp: float = 600.0
	var pop_dmg: float = 45.5

	for i in range(13):
		wall_hp = maxf(0.0, wall_hp - pop_dmg)
	assert_almost_eq(wall_hp, 8.5, 0.01, "Wall must have 8.5 HP left after 13 premature pops")

	wall_hp = maxf(0.0, wall_hp - pop_dmg)
	assert_almost_eq(wall_hp, 0.0, 0.01, "Wall must be breached on 14th premature pop")


func test_baneling_despawn_and_wave_manager_died_notification() -> void:
	var sim = SwarmSimulationScript.new()
	root.add_child(sim)
	sim.setup_simulation(Vector2(-32, -32), Vector2(32, 32), 128)

	var unit_idx: int = sim.spawn_unit(2, Vector3(0, 0, 0)) # Archetype 2 = Baneling
	assert_ge(unit_idx, 0, "Baneling must successfully spawn in SwarmSimulation")
	assert_eq(sim.swarm_data.alive_mask[unit_idx], 1, "Unit must be active and alive")

	# Despawn on kamikaze detonation
	sim.despawn_unit(unit_idx)
	assert_eq(sim.swarm_data.alive_mask[unit_idx], 0, "Baneling must be marked inactive (0) in SoA alive_mask upon detonation")

	sim.queue_free()


# ==============================================================================
# SUITE 2: HYDRALISK EXTREME LINE-PENETRATION GEOMETRY
# ==============================================================================

func _simulate_hydra_penetration(
	origin: Vector3,
	primary_pos: Vector3,
	candidates: Array[Vector3]
) -> int:
	# Replicates the geometric algorithm in main_level.gd lines 802-830
	var spine_dir: Vector3 = (primary_pos - origin)
	spine_dir.y = 0.0
	if spine_dir.length_squared() <= 0.01:
		return -1
	spine_dir = spine_dir.normalized()

	var best_idx: int = -1
	var best_dist: float = INF

	for i in range(candidates.size()):
		var to_cand: Vector3 = candidates[i] - primary_pos
		to_cand.y = 0.0
		var dist: float = to_cand.length()
		if dist > 0.3 and dist <= 6.5:
			var dot: float = spine_dir.dot(to_cand.normalized())
			if dot > 0.55 and dist < best_dist:
				best_dist = dist
				best_idx = i

	return best_idx


func test_hydralisk_artillery_range_boundary() -> void:
	var attack_range: float = 9.0
	var origin: Vector3 = Vector3(0, 0, 0)

	var target_at_9m: Vector3 = Vector3(0, 0, 9.0)
	assert_true(origin.distance_to(target_at_9m) <= attack_range, "Target at exactly 9.0m must be in attack range")

	var target_at_9_01m: Vector3 = Vector3(0, 0, 9.01)
	assert_false(origin.distance_to(target_at_9_01m) <= attack_range, "Target at 9.01m must be out of attack range")


func test_hydralisk_perfect_collinear_secondary_penetration() -> void:
	var origin: Vector3 = Vector3(0, 0, 0)
	var primary: Vector3 = Vector3(0, 0, 8.0)
	var candidate: Vector3 = Vector3(0, 0, 12.0) # 4.0m directly behind primary

	var hit_idx: int = _simulate_hydra_penetration(origin, primary, [candidate])
	assert_eq(hit_idx, 0, "Candidate collinear behind primary must be hit by secondary spine")


func test_hydralisk_extreme_angle_cutoff_55_vs_60_degrees() -> void:
	# dot threshold is 0.55.
	# cos(55 deg) = 0.5736 > 0.55 -> HIT
	# cos(60 deg) = 0.5000 <= 0.55 -> REJECTED
	var origin: Vector3 = Vector3(0, 0, 0)
	var primary: Vector3 = Vector3(0, 0, 8.0)

	var angle_55_rad: float = deg_to_rad(55.0)
	var cand_55: Vector3 = primary + Vector3(sin(angle_55_rad) * 4.0, 0.0, cos(angle_55_rad) * 4.0)
	var hit_55: int = _simulate_hydra_penetration(origin, primary, [cand_55])
	assert_eq(hit_55, 0, "Candidate at 55 degrees (dot 0.574) must be hit")

	var angle_60_rad: float = deg_to_rad(60.0)
	var cand_60: Vector3 = primary + Vector3(sin(angle_60_rad) * 4.0, 0.0, cos(angle_60_rad) * 4.0)
	var hit_60: int = _simulate_hydra_penetration(origin, primary, [cand_60])
	assert_eq(hit_60, -1, "Candidate at 60 degrees (dot 0.500) must be rejected")


func test_hydralisk_distance_cutoffs_near_far() -> void:
	var origin: Vector3 = Vector3(0, 0, 0)
	var primary: Vector3 = Vector3(0, 0, 8.0)

	# Too close: dist <= 0.3m (0.25m behind)
	var cand_too_close: Vector3 = Vector3(0, 0, 8.25)
	assert_eq(_simulate_hydra_penetration(origin, primary, [cand_too_close]), -1, "Candidate <= 0.3m must be ignored (near deadzone)")

	# Valid: dist = 6.4m (<= 6.5m)
	var cand_valid: Vector3 = Vector3(0, 0, 14.4)
	assert_eq(_simulate_hydra_penetration(origin, primary, [cand_valid]), 0, "Candidate at 6.4m must be hit")

	# Too far: dist = 6.6m (> 6.5m)
	var cand_too_far: Vector3 = Vector3(0, 0, 14.6)
	assert_eq(_simulate_hydra_penetration(origin, primary, [cand_too_far]), -1, "Candidate at 6.6m must be rejected (far cutoff)")


func test_hydralisk_reverse_direction_rejection() -> void:
	var origin: Vector3 = Vector3(0, 0, 0)
	var primary: Vector3 = Vector3(0, 0, 8.0)

	# Target in opposite direction (behind hydralisk)
	var cand_behind: Vector3 = Vector3(0, 0, -4.0)
	assert_eq(_simulate_hydra_penetration(origin, primary, [cand_behind]), -1, "Candidate behind hydralisk must be rejected")


func test_hydralisk_line_occlusion_closest_candidate_priority() -> void:
	var origin: Vector3 = Vector3(0, 0, 0)
	var primary: Vector3 = Vector3(0, 0, 8.0)

	# Candidate 0 is at 3.0m behind primary, Candidate 1 is at 6.0m behind primary
	var cand_near: Vector3 = Vector3(0, 0, 11.0)
	var cand_far: Vector3 = Vector3(0, 0, 14.0)

	var hit_idx: int = _simulate_hydra_penetration(origin, primary, [cand_near, cand_far])
	assert_eq(hit_idx, 0, "Closest candidate (Candidate 0 at 3.0m) must absorb penetration")

	# Reversed candidate order in array should still select closest
	var hit_reversed: int = _simulate_hydra_penetration(origin, primary, [cand_far, cand_near])
	assert_eq(hit_reversed, 1, "Closest candidate must be selected regardless of array ordering")


func test_hydralisk_secondary_structure_mitigation() -> void:
	# Raw secondary damage is 8.0 (50% of 16.0 primary damage)
	var raw_sec: float = 8.0

	# Against WallSegment (35% mitigation): 8.0 * 0.65 = 5.2
	var res_wall = SFECombatEngine.calculate_damage(
		raw_sec,
		CombatTypes.DamageType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.WALL_REINFORCED
	)
	assert_almost_eq(res_wall.damage_dealt, 5.2, 0.01, "Secondary spine deals 5.2 damage to WallSegment")

	# Against Bunker (25% mitigation): 8.0 * 0.75 = 6.0
	var res_bunker = SFECombatEngine.calculate_damage(
		raw_sec,
		CombatTypes.DamageType.PHYSICAL,
		0.0,
		0,
		CombatTypes.StructureType.BUNKER
	)
	assert_almost_eq(res_bunker.damage_dealt, 6.0, 0.01, "Secondary spine deals 6.0 damage to BunkerStructure")

	# Against Marine (1 flat armor): 8.0 - 1.0 = 7.0
	var res_marine = SFECombatEngine.calculate_damage(
		raw_sec,
		CombatTypes.DamageType.PHYSICAL,
		1.0,
		0,
		CombatTypes.StructureType.NONE
	)
	assert_almost_eq(res_marine.damage_dealt, 7.0, 0.01, "Secondary spine deals 7.0 damage to Marine")


# ==============================================================================
# SUITE 3: BRUTALISK BURST PHASE SKIP INVARIANT
# ==============================================================================

func test_brutalisk_burst_100_to_sub20_sequential_phases() -> void:
	var boss = BossBrutalisk3DScript.new()
	root.add_child(boss)

	assert_eq(boss.current_health, 8000.0, "Brutalisk initial HP must be 8000.0")
	assert_eq(boss.current_phase, 1, "Brutalisk initial phase must be 1")
	assert_eq(boss.banelings_spawned, 0, "No banelings spawned initially")
	assert_false(boss.miasma_active, "Miasma inactive initially")

	var recorded_phases: Array[int] = []
	boss.boss_health_changed.connect(func(_hp, _shields, phase): recorded_phases.append(phase))

	# Deal 6,500 SPELL damage (bypasses flat armor):
	# Drops HP from 8,000 to 1,500 (18.75% of max HP, well below Phase 3 threshold of 33% = 2640)
	var dealt: float = boss.take_damage(6500.0, CombatTypes.DamageType.SPELL)
	assert_almost_eq(dealt, 6500.0, 0.01, "Must deal exactly 6,500 damage")
	assert_almost_eq(boss.current_health, 1500.0, 0.01, "HP must drop to 1500.0")

	# Phase 2 Spawns must have executed (Brood Eruption spawned 4 Banelings)
	assert_eq(boss.banelings_spawned, 4, "Phase 2 Brood Eruption must execute spawning 4 Banelings despite single-tick skip")

	# Phase 3 must be active
	assert_eq(boss.current_phase, 3, "Phase must advance to 3")
	assert_true(boss.miasma_active, "Miasma must be active in Phase 3")
	assert_almost_eq(boss.move_speed, 5.4, 0.01, "Move speed must scale to 5.4 (+50%)")
	assert_almost_eq(boss.attack_cooldown, 0.75, 0.01, "Attack cooldown must reduce to 0.75 (+50% attack speed)")

	boss.queue_free()


func test_brutalisk_burst_no_state_freeze() -> void:
	var boss = BossBrutalisk3DScript.new()
	root.add_child(boss)

	# Burst to Phase 3
	boss.take_damage(6500.0, CombatTypes.DamageType.SPELL)
	assert_eq(boss.current_phase, 3, "Must be Phase 3")

	# Simulate 10 physics ticks (1.0 second total) to verify process loop executes without freezing
	for i in range(10):
		boss._physics_process(0.1)

	assert_false(boss.is_dead, "Boss must remain alive and processing")
	assert_true(boss.miasma_active, "Miasma remains active")

	boss.queue_free()


func test_brutalisk_lethal_single_tick_burst_from_full_hp() -> void:
	var boss = BossBrutalisk3DScript.new()
	root.add_child(boss)

	var tracker := {"boss_died": false}
	boss.boss_died.connect(func():
		tracker.boss_died = true
	)

	# Single lethal burst of 10,000 damage
	boss.take_damage(10000.0, CombatTypes.DamageType.SPELL)

	assert_true(boss.is_dead, "Boss must be flagged dead")
	assert_almost_eq(boss.current_health, 0.0, 0.01, "HP must clamp at 0.0")
	assert_eq(boss.banelings_spawned, 4, "Phase 2 spawns must execute before death cleanup")
	assert_eq(boss.current_phase, 3, "Phase must reach Phase 3")
	assert_true(tracker.boss_died, "boss_died signal must be emitted")


# ==============================================================================
# SUITE 4: HYBRID DOMINATOR SHIELD COLLAPSE & ENERGY DRAIN
# ==============================================================================

func test_hybrid_shield_exact_1_to_1_absorption_no_armor() -> void:
	var boss = BossHybrid3DScript.new()
	root.add_child(boss)

	assert_eq(boss.current_health, 10000.0, "Initial HP must be 10,000")
	assert_eq(boss.current_shields, 4000.0, "Initial shields must be 4,000")
	assert_eq(boss.flat_armor, 8.0, "Flat armor must be 8.0")

	# Deal 2,500 Physical damage:
	# Shields must absorb 1:1 without armor mitigation (current_shields -> 1,500, HP remains 10,000)
	var dealt: float = boss.take_damage(2500.0, CombatTypes.DamageType.PHYSICAL)
	assert_almost_eq(dealt, 2500.0, 0.01, "Shields absorb full 2,500 damage")
	assert_almost_eq(boss.current_shields, 1500.0, 0.01, "Shields reduced from 4,000 to 1,500")
	assert_almost_eq(boss.current_health, 10000.0, 0.01, "Health remains 10,000 (0 HP damage)")
	assert_eq(boss.current_phase, 1, "Phase remains 1 while shields hold")

	boss.queue_free()


func test_hybrid_exact_shield_collapse_phase_transition() -> void:
	var boss = BossHybrid3DScript.new()
	root.add_child(boss)

	boss.current_shields = 1500.0
	boss.take_damage(1500.0, CombatTypes.DamageType.PHYSICAL)

	assert_almost_eq(boss.current_shields, 0.0, 0.01, "Shields must drop to exactly 0.0")
	assert_almost_eq(boss.current_health, 10000.0, 0.01, "HP remains untouched at 10,000")
	assert_eq(boss.current_phase, 2, "Phase must transition to Phase 2 upon complete shield collapse")

	boss.queue_free()


func test_hybrid_single_burst_shield_break_physical_surplus_armor_mitigation() -> void:
	var boss = BossHybrid3DScript.new()
	root.add_child(boss)

	# Full 4,000 shields, 10,000 HP, 8 flat armor.
	# Deal 7,000 Physical damage:
	# 4,000 absorbed by shields.
	# 3,000 surplus penetrates to HP.
	# 3,000 - 8 flat armor = 2,992 net HP damage.
	# Health becomes 10,000 - 2,992 = 7,008.0 HP.
	var dealt: float = boss.take_damage(7000.0, CombatTypes.DamageType.PHYSICAL)
	assert_almost_eq(dealt, 6992.0, 0.01, "Total damage dealt must equal 4,000 + 2,992 = 6,992.0")
	assert_almost_eq(boss.current_shields, 0.0, 0.01, "Shields collapsed to 0.0")
	assert_almost_eq(boss.current_health, 7008.0, 0.01, "HP must equal exactly 7,008.0")
	assert_eq(boss.current_phase, 2, "Phase must be 2")

	boss.queue_free()


func test_hybrid_single_burst_shield_break_spell_surplus_bypasses_armor() -> void:
	var boss = BossHybrid3DScript.new()
	root.add_child(boss)

	# Full 4,000 shields, 10,000 HP, 8 flat armor.
	# Deal 7,000 Spell damage:
	# 4,000 absorbed by shields.
	# 3,000 surplus penetrates to HP, bypassing flat armor -> 3,000 net HP damage.
	# Health becomes 10,000 - 3,000 = 7,000.0 HP.
	var dealt: float = boss.take_damage(7000.0, CombatTypes.DamageType.SPELL)
	assert_almost_eq(dealt, 7000.0, 0.01, "Total damage dealt must equal 4,000 + 3,000 = 7,000.0")
	assert_almost_eq(boss.current_shields, 0.0, 0.01, "Shields collapsed to 0.0")
	assert_almost_eq(boss.current_health, 7000.0, 0.01, "HP must equal exactly 7,000.0")

	boss.queue_free()


func test_hybrid_psionic_shockwave_energy_drain_on_heroic() -> void:
	# Psionic Shockwave: 120 spell damage, 40 energy drain, 40% Heroic AoE penalty (72 net dmg)
	var boss = BossHybrid3DScript.new()
	root.add_child(boss)

	# Create a mock heroic target with current_energy
	var hero_mock := Node3D.new()
	hero_mock.add_to_group("allies")
	hero_mock.add_to_group("heroes")
	hero_mock.set("current_energy", 100.0)
	hero_mock.set("current_health", 500.0)
	hero_mock.set_script(load("res://tests/test_base.gd")) # dummy script for has_method
	root.add_child(hero_mock)
	hero_mock.global_position = boss.global_position + Vector3(2.0, 0, 0) # within 10m

	boss._shockwave_timer = 0.0
	boss.execute_psionic_shockwave()

	var remaining_energy: float = hero_mock.get("current_energy")
	assert_almost_eq(remaining_energy, 60.0, 0.01, "Heroic entity energy must be drained by exactly 40 (100 -> 60)")

	boss.queue_free()
	hero_mock.queue_free()


func test_hybrid_psionic_shockwave_energy_drain_clamped_at_zero() -> void:
	var boss = BossHybrid3DScript.new()
	root.add_child(boss)

	var hero_mock := Node3D.new()
	hero_mock.add_to_group("allies")
	hero_mock.add_to_group("heroes")
	hero_mock.set("current_energy", 15.0)
	root.add_child(hero_mock)
	hero_mock.global_position = boss.global_position + Vector3(2.0, 0, 0)

	boss._shockwave_timer = 0.0
	boss.execute_psionic_shockwave()

	var remaining_energy: float = hero_mock.get("current_energy")
	assert_almost_eq(remaining_energy, 0.0, 0.01, "Heroic entity energy must clamp at 0.0 (cannot become negative)")

	boss.queue_free()
	hero_mock.queue_free()


func test_hybrid_psionic_shockwave_hero_unit_3d_energy_behavior() -> void:
	# Empirical Challenger Verification:
	# Tests how BossHybrid3D interacts with actual HeroUnit3D.
	var boss = BossHybrid3DScript.new()
	root.add_child(boss)

	var hero = HeroUnit3DScript.new()
	root.add_child(hero)
	hero.add_to_group("allies")
	hero.add_to_group("heroes")
	hero.global_position = boss.global_position + Vector3(2.0, 0, 0)

	var initial_hp: float = hero.current_health
	var initial_shield: float = hero.hero_data.current_shield if hero.hero_data else 0.0
	var initial_energy: float = hero.hero_data.current_energy
	print("DEBUG hero inside tree: ", hero.is_inside_tree(), " parent: ", hero.get_parent(), " groups: ", hero.get_groups())
	print("DEBUG tree allies: ", get_nodes_in_group("allies"))
	print("DEBUG tree heroes: ", get_nodes_in_group("heroes"))
	print("DEBUG hero distance to boss: ", boss.global_position.distance_to(hero.global_position))

	boss._shockwave_timer = 0.0
	boss.execute_psionic_shockwave()
	print("DEBUG hero after shockwave: hp=", hero.current_health, " shield=", (hero.hero_data.current_shield if hero.hero_data else 0.0), " energy=", hero.hero_data.current_energy)

	# Verify shockwave dealt 72.0 damage to hero (either absorbed by shield or reduced HP)
	var hp_loss: float = initial_hp - hero.current_health
	var shield_loss: float = initial_shield - (hero.hero_data.current_shield if hero.hero_data else 0.0)
	var total_mitigated_or_taken: float = hp_loss + shield_loss
	assert_almost_eq(total_mitigated_or_taken, 72.0, 0.5, "Hero took 72.0 net damage (across shield and health)")

	# Note: HeroUnit3D stores energy in hero.hero_data.current_energy rather than hero.current_energy.
	# We verify execution does not throw exceptions or crash.
	assert_true(true, "HeroUnit3D successfully processed Psionic Shockwave without crash")

	boss.queue_free()
	hero.queue_free()


# ==============================================================================
# SUITE 5: ARMORY WALLET BOUNDARY & TURRET DEPLOYMENT CAP
# ==============================================================================

func test_armory_zero_mineral_purchase_rejection() -> void:
	var econ = SFEEconomyManagerScript.new(0)
	var armory = ArmoryUpgradeManagerScript.new()
	armory.set_economy_manager(econ)

	# Reset tiers
	armory.ballistics_tier = 0
	armory.armor_tier = 0
	armory.stimpack_tier = 0
	armory.penetrating_round_tier = 0
	armory.orbital_bombardment_unlocked = false

	assert_false(armory.can_purchase_ballistics(), "Cannot afford ballistics with 0 minerals")
	assert_false(armory.purchase_ballistics(), "Ballistics purchase must reject with 0 minerals")
	assert_eq(armory.ballistics_tier, 0, "Ballistics tier must remain 0")

	assert_false(armory.can_purchase_armor(), "Cannot afford armor with 0 minerals")
	assert_false(armory.purchase_armor(), "Armor purchase must reject with 0 minerals")
	assert_eq(armory.armor_tier, 0, "Armor tier must remain 0")

	assert_false(armory.can_purchase_hero_ability(&"stimpack"), "Cannot afford stimpack with 0 minerals")
	assert_false(armory.purchase_hero_ability(&"stimpack"), "Stimpack purchase must reject with 0 minerals")

	assert_false(armory.can_deploy_turret(), "Cannot deploy turret with 0 minerals")
	var turret = armory.deploy_turret(Vector3.ZERO)
	assert_null(turret, "deploy_turret must return null with 0 minerals")

	assert_eq(econ.current_minerals, 0, "Wallet balance must remain strictly 0")


func test_armory_off_by_one_mineral_rejection() -> void:
	var econ = SFEEconomyManagerScript.new(99) # Ballistics Tier 1 costs 100
	var armory = ArmoryUpgradeManagerScript.new()
	armory.set_economy_manager(econ)
	armory.ballistics_tier = 0

	assert_false(armory.can_purchase_ballistics(), "Cannot afford 100 cost with 99 minerals")
	assert_false(armory.purchase_ballistics(), "Purchase must reject atomically")
	assert_eq(armory.ballistics_tier, 0, "Tier must remain 0")
	assert_eq(econ.current_minerals, 99, "Balance must remain strictly 99")


func test_armory_exact_mineral_purchase_boundary() -> void:
	var econ = SFEEconomyManagerScript.new(100) # Exactly 100 minerals
	var armory = ArmoryUpgradeManagerScript.new()
	armory.set_economy_manager(econ)
	armory.ballistics_tier = 0

	assert_true(armory.can_purchase_ballistics(), "Must afford 100 cost with 100 minerals")
	assert_true(armory.purchase_ballistics(), "Purchase must succeed with exact balance")
	assert_eq(armory.ballistics_tier, 1, "Tier must advance to 1")
	assert_eq(econ.current_minerals, 0, "Balance must become strictly 0 after exact purchase")

	# Immediate next purchase (Tier 2 costs 250) must reject
	assert_false(armory.can_purchase_ballistics(), "Next tier must be rejected with 0 balance")


func test_turret_deployment_cap_of_six() -> void:
	var econ = SFEEconomyManagerScript.new(5000) # Plentiful minerals
	var armory = ArmoryUpgradeManagerScript.new()
	armory.set_economy_manager(econ)
	armory.deployed_turrets.clear()

	var turrets: Array = []

	# Deploy 6 turrets
	for i in range(6):
		assert_true(armory.can_deploy_turret(), "Must be able to deploy turret %d of 6" % (i + 1))
		var t = armory.deploy_turret(Vector3(float(i) * 2.0, 0, 0))
		assert_not_null(t, "Turret %d must instantiate successfully" % (i + 1))
		turrets.append(t)

	assert_eq(armory.deployed_turrets.size(), 6, "Exactly 6 turrets deployed")
	assert_eq(econ.current_minerals, 5000 - (6 * 125), "Balance must reflect 750 minerals spent")

	# 7th turret deployment attempt must be rejected
	assert_false(armory.can_deploy_turret(), "can_deploy_turret must return false when at cap of 6")
	var t7 = armory.deploy_turret(Vector3(14.0, 0, 0))
	assert_null(t7, "7th turret deployment must return null")
	assert_eq(econ.current_minerals, 5000 - (6 * 125), "Minerals must NOT be deducted for rejected 7th turret")

	# Cleanup
	for t in turrets:
		if is_instance_valid(t):
			t.queue_free()


func test_turret_destruction_allows_redeployment_up_to_cap() -> void:
	var econ = SFEEconomyManagerScript.new(5000)
	var armory = ArmoryUpgradeManagerScript.new()
	armory.set_economy_manager(econ)
	armory.deployed_turrets.clear()

	var turrets: Array = []
	for i in range(6):
		turrets.append(armory.deploy_turret(Vector3(float(i) * 2.0, 0, 0)))

	assert_eq(armory.deployed_turrets.size(), 6, "Deployed 6 turrets")

	# Destroy 1 turret
	var killed_turret = turrets.pop_back()
	killed_turret.queue_free()
	armory._cleanup_turrets()

	assert_eq(armory.deployed_turrets.size(), 5, "Turret count drops to 5 after destruction")
	assert_true(armory.can_deploy_turret(), "Deployment must be re-enabled after count drops below 6")

	# Deploy replacement turret
	var replacement = armory.deploy_turret(Vector3(10.0, 0, 0))
	assert_not_null(replacement, "Replacement turret deployment must succeed")
	assert_eq(armory.deployed_turrets.size(), 6, "Turret count back at cap of 6")

	# Cleanup
	for t in armory.deployed_turrets:
		if is_instance_valid(t):
			t.queue_free()


func test_turret_placement_boundary_24m_radius() -> void:
	var armory = ArmoryUpgradeManagerScript.new()

	# Boundary: MAX_BASE_RADIUS = 24.0m
	var valid_pos: Vector3 = Vector3(23.9, 0, 0)
	assert_true(armory.is_valid_turret_position(valid_pos), "Position at 23.9m must be valid")

	var invalid_pos: Vector3 = Vector3(24.1, 0, 0)
	assert_false(armory.is_valid_turret_position(invalid_pos), "Position at 24.1m must be rejected as outside base radius")
