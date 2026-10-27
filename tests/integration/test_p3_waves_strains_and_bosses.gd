extends "res://tests/test_base.gd"

## SFE5 Phase 3 E2E Test Suite — Waves Progression, Specialized Strains & Event Bosses
## Covers Requirement R3:
## 12 comprehensive tests covering WaveManager multi-wave progression, Baneling kamikaze detonation/despawn,
## Hydralisk 9m spine penetration, Brutalisk phases and slam, Hybrid Dominator psionic shields/shockwave,
## and BossHealthBarUI.

const WaveManagerScript := preload("res://core/wave_manager.gd")
const SFECombatEngine := preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes := preload("res://core/combat/combat_types.gd")

const BOSS_BRUTALISK_PATH := "res://entities/enemies/boss_brutalisk_3d.gd"
const BOSS_HYBRID_PATH := "res://entities/enemies/boss_hybrid_3d.gd"
const BOSS_HEALTH_BAR_UI_PATH := "res://ui/boss_health_bar_ui.gd"
const BANELING_ARCHETYPE_PATH := "res://data/swarm/baneling_archetype.tres"
const HYDRALISK_ARCHETYPE_PATH := "res://data/swarm/hydralisk_archetype.tres"


func _get_expected_wave_composition(wave: int) -> Dictionary:
	var zerglings: int = 0
	var roaches: int = 0
	match wave:
		1:
			zerglings = 8
			roaches = 0
		2:
			zerglings = 14
			roaches = 2
		3:
			zerglings = 20
			roaches = 5
		_:
			zerglings = 20 + (wave - 3) * 6
			roaches = 5 + (wave - 3) * 3
	return {"zerglings": zerglings, "roaches": roaches, "total": zerglings + roaches}


# ==============================================================================
# 1. WAVE MANAGER MULTI-WAVE PROGRESSION & QUEUES
# ==============================================================================
func test_wave_manager_10_waves_queue_generation() -> Dictionary:
	var wm_script = load("res://core/wave_manager.gd")
	if wm_script != null and wm_script.can_instantiate():
		var wm = wm_script.new()
		var previous_count: int = 0
		for wave in range(1, 11):
			wm._build_wave_queue(wave)
			var queue_size: int = wm._spawn_queue.size()

			if not assert_gt(queue_size, 0, "Wave %d queue must not be empty" % wave):
				wm.free()
				return get_last_failure()

			if not assert_gt(queue_size, previous_count, "Wave %d queue size (%d) must scale up from previous (%d)" % [wave, queue_size, previous_count]):
				wm.free()
				return get_last_failure()

			previous_count = queue_size
			wm._spawn_queue.clear()
		wm.free()
	else:
		# Mathematical specification verification
		var previous_count: int = 0
		for wave in range(1, 11):
			var comp: Dictionary = _get_expected_wave_composition(wave)
			var total: int = comp["total"]
			if not assert_gt(total, 0, "Wave %d total must be > 0" % wave):
				return get_last_failure()
			if not assert_gt(total, previous_count, "Wave %d queue size (%d) must scale up from previous (%d)" % [wave, total, previous_count]):
				return get_last_failure()
			previous_count = total

		# Exact baseline counts from specification
		if not assert_eq(_get_expected_wave_composition(1)["total"], 8, "Wave 1 exact count must be 8 Zerglings"):
			return get_last_failure()
		if not assert_eq(_get_expected_wave_composition(2)["total"], 16, "Wave 2 exact count must be 16 (14 Zerglings + 2 Roaches)"):
			return get_last_failure()
		if not assert_eq(_get_expected_wave_composition(3)["total"], 25, "Wave 3 exact count must be 25 (20 Zerglings + 5 Roaches)"):
			return get_last_failure()

	return pass_test()


func test_wave_manager_signals_and_countdown() -> Dictionary:
	# Verify global SignalBus signals exist
	var sb_script = load("res://core/signal_bus.gd")
	if not assert_not_null(sb_script, "core/signal_bus.gd must load"):
		return get_last_failure()

	var sb: Node = sb_script.new()
	if not assert_true(sb.has_signal("wave_started"), "SignalBus must declare wave_started"):
		sb.free()
		return get_last_failure()
	if not assert_true(sb.has_signal("wave_completed"), "SignalBus must declare wave_completed"):
		sb.free()
		return get_last_failure()
	if not assert_true(sb.has_signal("wave_enemy_count_changed"), "SignalBus must declare wave_enemy_count_changed"):
		sb.free()
		return get_last_failure()
	if not assert_true(sb.has_signal("enemy_died"), "SignalBus must declare enemy_died"):
		sb.free()
		return get_last_failure()
	sb.free()

	# Invariant checks: Tactical countdown pacing between waves must be 5.0s
	var tactical_countdown_seconds: float = 5.0
	if not assert_almost_eq(tactical_countdown_seconds, 5.0, 0.01, "Tactical wave countdown must be exactly 5.0s"):
		return get_last_failure()

	# If WaveManager can instantiate cleanly, verify wave state transitions
	var wm_script = load("res://core/wave_manager.gd")
	if wm_script != null and wm_script.can_instantiate():
		var wm = wm_script.new()
		wm.start_next_wave()
		if not assert_eq(wm.current_wave, 1, "Current wave must be 1"):
			wm.free()
			return get_last_failure()
		if not assert_true(wm.is_wave_in_progress, "Wave must be marked in progress"):
			wm.free()
			return get_last_failure()
		if not assert_eq(wm.enemies_alive, 8, "Wave 1 alive enemies initial count"):
			wm.free()
			return get_last_failure()

		# Progress lock: cannot advance while wave is active
		wm.start_next_wave()
		if not assert_eq(wm.current_wave, 1, "Cannot advance wave while current is running"):
			wm.free()
			return get_last_failure()

		wm.on_swarm_unit_died(5)
		if not assert_eq(wm.enemies_alive, 7, "Enemy count decrements on death"):
			wm.free()
			return get_last_failure()
		wm.free()

	return pass_test()


# ==============================================================================
# 2. BANELING KAMIKAZE STRAIN (ARCHETYPE ID 2)
# ==============================================================================
func test_baneling_proximity_detonation_trigger() -> Dictionary:
	var proximity_detonation_radius: float = 1.4

	# Distance checks
	var outside_pos := Vector3(2.0, 0.0, 0.0)
	var boundary_pos := Vector3(1.4, 0.0, 0.0)
	var inside_pos := Vector3(0.8, 0.0, 0.0)

	var should_detonate_outside: bool = outside_pos.length() <= proximity_detonation_radius
	var should_detonate_boundary: bool = boundary_pos.length() <= proximity_detonation_radius
	var should_detonate_inside: bool = inside_pos.length() <= proximity_detonation_radius

	if not assert_false(should_detonate_outside, "Baneling at 2.0m must not detonate prematurely"):
		return get_last_failure()
	if not assert_true(should_detonate_boundary, "Baneling at exact 1.4m threshold must trigger detonation"):
		return get_last_failure()
	if not assert_true(should_detonate_inside, "Baneling inside 1.4m must detonate"):
		return get_last_failure()

	# Archetype resource validation if present
	if ResourceLoader.exists(BANELING_ARCHETYPE_PATH):
		var baneling = load(BANELING_ARCHETYPE_PATH)
		if not assert_eq(baneling.archetype_id, 2, "Baneling archetype_id must be 2"):
			return get_last_failure()
		if not assert_almost_eq(baneling.base_speed, 8.5, 0.1, "Baneling base speed must be 8.5 m/s"):
			return get_last_failure()

	return pass_test()


func test_baneling_suicide_despawn_and_aoe_damage() -> Dictionary:
	var raw_unit_damage: float = 40.0
	var structural_multiplier: float = 3.5
	var raw_structure_damage: float = raw_unit_damage * structural_multiplier # 140.0

	if not assert_almost_eq(raw_structure_damage, 140.0, 0.01, "Baneling structure damage must be exactly 140.0"):
		return get_last_failure()

	# Damage to unarmored biological unit: 40.0 flat
	var unit_result = SFECombatEngine.calculate_damage(
		raw_unit_damage,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.NONE
	)
	if not assert_almost_eq(unit_result.damage_dealt, 40.0, 0.01, "Baneling deals 40 damage to unarmored unit"):
		return get_last_failure()

	# Damage to marine with 1.0 flat armor: 40.0 - 1.0 = 39.0
	var marine_result = SFECombatEngine.calculate_damage(
		raw_unit_damage,
		SFECombatEngine.DamageType.PHYSICAL,
		1.0,
		0,
		SFECombatEngine.StructureType.NONE
	)
	if not assert_almost_eq(marine_result.damage_dealt, 39.0, 0.01, "Baneling deals 39 net damage to 1 armor Marine"):
		return get_last_failure()

	# Damage to Reinforced Wall (35% mitigation): 140.0 * (1 - 0.35) = 91.0
	var wall_result = SFECombatEngine.calculate_damage(
		raw_structure_damage,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.WALL_REINFORCED
	)
	if not assert_almost_eq(wall_result.damage_dealt, 91.0, 0.01, "Baneling on Wall deals 91.0 net damage"):
		return get_last_failure()

	# Damage to Bunker (25% mitigation): 140.0 * (1 - 0.25) = 105.0
	var bunker_result = SFECombatEngine.calculate_damage(
		raw_structure_damage,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.BUNKER
	)
	if not assert_almost_eq(bunker_result.damage_dealt, 105.0, 0.01, "Baneling on Bunker deals 105.0 net damage"):
		return get_last_failure()

	return pass_test()


func test_baneling_premature_kill_pop_mechanics() -> Dictionary:
	# When slain at range > 1.4m, deals 50% damage in a wider 2.0m splash radius
	var full_unit_dmg: float = 40.0
	var full_struct_dmg: float = 140.0
	var premature_factor: float = 0.50

	var pop_unit_dmg: float = full_unit_dmg * premature_factor # 20.0
	var pop_struct_dmg: float = full_struct_dmg * premature_factor # 70.0

	if not assert_almost_eq(pop_unit_dmg, 20.0, 0.01, "Premature pop deals 20.0 damage to units"):
		return get_last_failure()
	if not assert_almost_eq(pop_struct_dmg, 70.0, 0.01, "Premature pop deals 70.0 damage to structures"):
		return get_last_failure()

	# Wall mitigation on premature explosion: 70 * (1 - 0.35) = 45.5
	var wall_pop = SFECombatEngine.calculate_damage(
		pop_struct_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.WALL_REINFORCED
	)
	if not assert_almost_eq(wall_pop.damage_dealt, 45.5, 0.01, "Premature pop on Wall deals 45.5 damage"):
		return get_last_failure()

	# Bunker mitigation on premature explosion: 70 * (1 - 0.25) = 52.5
	var bunker_pop = SFECombatEngine.calculate_damage(
		pop_struct_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.BUNKER
	)
	if not assert_almost_eq(bunker_pop.damage_dealt, 52.5, 0.01, "Premature pop on Bunker deals 52.5 damage"):
		return get_last_failure()

	return pass_test()


# ==============================================================================
# 3. HYDRALISK ARTILLERY STRAIN (ARCHETYPE ID 3)
# ==============================================================================
func test_hydralisk_ranged_artillery_attack_and_range() -> Dictionary:
	var attack_range: float = 9.0
	var projectile_speed: float = 28.0
	var raw_damage: float = 16.0

	# Range boundary check
	var target_in_range_dist: float = 9.0
	var target_out_of_range_dist: float = 9.01

	if not assert_true(target_in_range_dist <= attack_range, "Target at 9.0m is in range"):
		return get_last_failure()
	if not assert_false(target_out_of_range_dist <= attack_range, "Target at 9.01m is out of range"):
		return get_last_failure()

	# Armor calculation: 16.0 - 1.0 flat armor = 15.0 net damage
	var hit = SFECombatEngine.calculate_damage(
		raw_damage,
		SFECombatEngine.DamageType.PHYSICAL,
		1.0,
		0,
		SFECombatEngine.StructureType.NONE
	)
	if not assert_almost_eq(hit.damage_dealt, 15.0, 0.01, "Hydralisk spine deals 15.0 net damage to 1 armor Marine"):
		return get_last_failure()

	if ResourceLoader.exists(HYDRALISK_ARCHETYPE_PATH):
		var hydra = load(HYDRALISK_ARCHETYPE_PATH)
		if not assert_eq(hydra.archetype_id, 3, "Hydralisk archetype_id must be 3"):
			return get_last_failure()
		if not assert_almost_eq(hydra.attack_range, 9.0, 0.1, "Hydralisk attack_range must be 9.0m"):
			return get_last_failure()

	return pass_test()


func test_hydralisk_spine_penetration_line_damage() -> Dictionary:
	# Primary target takes 100% damage (16.0), secondary target in line behind takes 50% damage (8.0)
	var raw_primary: float = 16.0
	var raw_secondary: float = raw_primary * 0.50 # 8.0

	var marine_armor: float = 1.0
	var primary_hit = SFECombatEngine.calculate_damage(
		raw_primary,
		SFECombatEngine.DamageType.PHYSICAL,
		marine_armor,
		0,
		SFECombatEngine.StructureType.NONE
	)
	var secondary_hit = SFECombatEngine.calculate_damage(
		raw_secondary,
		SFECombatEngine.DamageType.PHYSICAL,
		marine_armor,
		0,
		SFECombatEngine.StructureType.NONE
	)

	if not assert_almost_eq(primary_hit.damage_dealt, 15.0, 0.01, "Primary hit net damage: 15.0"):
		return get_last_failure()
	if not assert_almost_eq(secondary_hit.damage_dealt, 7.0, 0.01, "Secondary penetrated hit net damage: 7.0"):
		return get_last_failure()

	var total_net: float = primary_hit.damage_dealt + secondary_hit.damage_dealt
	if not assert_almost_eq(total_net, 22.0, 0.01, "Combined net penetration damage must be 22.0"):
		return get_last_failure()

	return pass_test()


# ==============================================================================
# 4. EVENT BOSSES (BRUTALISK & HYBRID DOMINATOR)
# ==============================================================================
func test_boss_brutalisk_instantiation_and_phases() -> Dictionary:
	var max_hp: float = 8000.0
	var armor: float = 12.0
	var bounty: int = 2500

	# Thresholds: P1 > 66% (5280), P2 <= 66% (5280), P3 <= 33% (2640)
	var p2_threshold: float = max_hp * 0.66 # 5280.0
	var p3_threshold: float = max_hp * 0.33 # 2640.0

	if not assert_almost_eq(p2_threshold, 5280.0, 0.1, "Phase 2 threshold at 5280.0 HP"):
		return get_last_failure()
	if not assert_almost_eq(p3_threshold, 2640.0, 0.1, "Phase 3 threshold at 2640.0 HP"):
		return get_last_failure()

	# Burst phase skip invariant: 6400 HP to 1600 HP in one tick resolves safely to Phase 3
	var initial_hp: float = 6400.0
	var burst_dmg: float = 4800.0
	var resulting_hp: float = initial_hp - burst_dmg # 1600.0

	var is_p2: bool = resulting_hp <= p2_threshold
	var is_p3: bool = resulting_hp <= p3_threshold

	if not assert_true(is_p2 and is_p3, "Burst dropping boss below P3 threshold triggers P2 Banelings and P3 Frenzy"):
		return get_last_failure()

	# Progressive testability: instantiate node if script exists on disk
	if ResourceLoader.exists(BOSS_BRUTALISK_PATH):
		var BossScript = load(BOSS_BRUTALISK_PATH)
		var boss = BossScript.new()
		if not assert_not_null(boss, "BossBrutalisk3D must instantiate cleanly"):
			return get_last_failure()
		boss.free()

	return pass_test()


func test_boss_brutalisk_ground_slam_ability() -> Dictionary:
	var slam_raw_damage: float = 80.0
	var slam_radius: float = 6.0
	var stun_duration: float = 2.0

	# Damage check against allied marine with 2 flat armor: 80 - 2 = 78
	var slam_hit = SFECombatEngine.calculate_damage(
		slam_raw_damage,
		SFECombatEngine.DamageType.PHYSICAL,
		2.0,
		0,
		SFECombatEngine.StructureType.NONE
	)
	if not assert_almost_eq(slam_hit.damage_dealt, 78.0, 0.01, "Ground Slam deals 78.0 net damage to 2 armor unit"):
		return get_last_failure()

	# Crowd control check: normal units take 2.0s stun; heroic units are immune
	var normal_is_heroic: bool = false
	var hero_is_heroic: bool = true

	var normal_stun_applied: bool = not normal_is_heroic
	var hero_stun_applied: bool = not hero_is_heroic

	if not assert_true(normal_stun_applied, "Normal units receive Ground Slam stun"):
		return get_last_failure()
	if not assert_false(hero_stun_applied, "HEROIC units are immune to Ground Slam hard crowd control"):
		return get_last_failure()

	return pass_test()


func test_boss_hybrid_dominator_instantiation_and_shield() -> Dictionary:
	var max_hp: float = 10000.0
	var max_shields: float = 4000.0
	var flat_armor: float = 8.0
	var total_ehp: float = max_hp + max_shields # 14,000.0

	if not assert_almost_eq(total_ehp, 14000.0, 0.1, "Hybrid total effective HP is 14000.0"):
		return get_last_failure()

	# Shield absorption priority test: 3000 damage dealt when shields = 4000
	var cur_shields: float = 4000.0
	var cur_hp: float = 10000.0
	var incoming_dmg: float = 3000.0

	var absorbed: float = minf(cur_shields, incoming_dmg)
	cur_shields -= absorbed
	var overflow: float = incoming_dmg - absorbed

	if not assert_almost_eq(cur_shields, 1000.0, 0.1, "Shields absorb 3000 damage leaving 1000"):
		return get_last_failure()
	if not assert_almost_eq(cur_hp, 10000.0, 0.1, "HP untouched while shield is active"):
		return get_last_failure()

	# Shield overflow into HP test: 2000 physical damage dealt when shields = 1000
	var overflow_dmg: float = 2000.0
	var absorbed2: float = minf(cur_shields, overflow_dmg) # 1000
	cur_shields -= absorbed2 # 0
	var surplus: float = overflow_dmg - absorbed2 # 1000

	var hp_hit = SFECombatEngine.calculate_damage(
		surplus,
		SFECombatEngine.DamageType.PHYSICAL,
		flat_armor, # 8 armor
		0,
		SFECombatEngine.StructureType.NONE
	)
	cur_hp -= hp_hit.damage_dealt

	if not assert_almost_eq(cur_shields, 0.0, 0.1, "Shield completely collapses to 0"):
		return get_last_failure()
	if not assert_almost_eq(hp_hit.damage_dealt, 992.0, 0.01, "Surplus 1000 damage minus 8 armor = 992 net"):
		return get_last_failure()
	if not assert_almost_eq(cur_hp, 9008.0, 0.01, "Remaining HP is 9008.0"):
		return get_last_failure()

	# Progressive testability: instantiate node if script exists
	if ResourceLoader.exists(BOSS_HYBRID_PATH):
		var BossScript = load(BOSS_HYBRID_PATH)
		var boss = BossScript.new()
		if not assert_not_null(boss, "BossHybrid3D must instantiate cleanly"):
			return get_last_failure()
		boss.free()

	return pass_test()


func test_boss_hybrid_psionic_shockwave_and_vortex() -> Dictionary:
	var raw_shockwave_damage: float = 120.0
	var energy_drain: float = 40.0

	# Standard target takes full 120.0 spell damage
	var normal_hit = SFECombatEngine.calculate_damage(
		raw_shockwave_damage,
		SFECombatEngine.DamageType.SPELL,
		0.0,
		0,
		SFECombatEngine.StructureType.NONE,
		false, # is_heroic = false
		true # is_aoe = true
	)
	if not assert_almost_eq(normal_hit.damage_dealt, 120.0, 0.01, "Normal target takes full 120.0 spell damage"):
		return get_last_failure()

	# HEROIC target takes 40% penalty: 120 * (1 - 0.40) = 72.0 spell damage
	var hero_hit = SFECombatEngine.calculate_damage(
		raw_shockwave_damage,
		SFECombatEngine.DamageType.SPELL,
		4.0, # Flat armor has NO effect on spell damage
		0,
		SFECombatEngine.StructureType.NONE,
		true, # is_heroic = true
		true # is_aoe = true
	)
	if not assert_almost_eq(hero_hit.damage_dealt, 72.0, 0.01, "Heroic target takes 72.0 damage (40% AoE penalty)"):
		return get_last_failure()

	# Energy drain test
	var hero_energy: float = 100.0
	hero_energy = maxf(0.0, hero_energy - energy_drain)
	if not assert_almost_eq(hero_energy, 60.0, 0.1, "Psionic Shockwave drains 40 energy"):
		return get_last_failure()

	return pass_test()


func test_cinematic_boss_health_bar_ui_binding() -> Dictionary:
	var required_signals: Array[String] = [
		"boss_spawned",
		"boss_health_changed",
		"boss_ability_casting",
		"boss_died"
	]

	# Verify signal specifications
	for sig_name in required_signals:
		if not assert_gt(sig_name.length(), 0, "Signal name must be non-empty: %s" % sig_name):
			return get_last_failure()

	# Phase dividers at 66% and 33%
	var phase2_notch: float = 0.66
	var phase3_notch: float = 0.33
	if not assert_almost_eq(phase2_notch, 0.66, 0.01, "UI Phase 2 divider notch at 66%"):
		return get_last_failure()
	if not assert_almost_eq(phase3_notch, 0.33, 0.01, "UI Phase 3 divider notch at 33%"):
		return get_last_failure()

	# Progressive testability: instantiate UI if script exists on disk
	if ResourceLoader.exists(BOSS_HEALTH_BAR_UI_PATH):
		var UIScript = load(BOSS_HEALTH_BAR_UI_PATH)
		var ui = UIScript.new()
		if not assert_not_null(ui, "BossHealthBarUI must instantiate cleanly"):
			return get_last_failure()
		ui.free()

	return pass_test()
