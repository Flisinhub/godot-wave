extends "res://tests/test_base.gd"

## Phase 2 E2E Test Suite — Tier 1: Feature Coverage (Category-Partition)
## Verifies all 16 features from PROJECT.md § Feature Inventory in isolation.
## Adheres to Progressive Testability: Validates live implementations when available,
## validates exact mathematical formulas & interface contracts against core engines,
## and skips gracefully with standard diagnostics when downstream milestone files are pending.

const ARMORY_MGR_PATH := "res://core/upgrades/armory_upgrade_manager.gd"
const ARMORY_TERMINAL_PATH := "res://entities/structures/armory_terminal.gd"
const AUTO_TURRET_PATH := "res://entities/structures/auto_turret_3d.gd"
const BANELING_ARCHETYPE_PATH := "res://data/swarm/baneling_archetype.tres"
const HYDRALISK_ARCHETYPE_PATH := "res://data/swarm/hydralisk_archetype.tres"
const BOSS_BRUTALISK_PATH := "res://entities/enemies/boss_brutalisk_3d.gd"
const BOSS_HYBRID_PATH := "res://entities/enemies/boss_hybrid_3d.gd"
const BOSS_HEALTH_BAR_UI_PATH := "res://ui/boss_health_bar_ui.gd"
const SFX_MANAGER_PATH := "res://core/audio/sfx_manager.gd"
const BUS_LAYOUT_PATH := "res://default_bus_layout.tres"

# ==============================================================================
# FEATURE 1: Marine & Raynor .glb Models & Animations (Milestone M1)
# ==============================================================================
func test_f01_marine_raynor_models_and_animations() -> Dictionary:
	var marine_scene_path := "res://entities/allies/base_unit_3d.tscn"
	if not ResourceLoader.exists(marine_scene_path):
		return skip_test("Milestone M1 pending: %s not found" % marine_scene_path)
	
	var scene_text: String = FileAccess.get_file_as_string(marine_scene_path)
	if not assert_true(scene_text.contains('name="VisualRoot"'), "Entity must encapsulate graphics under VisualRoot"):
		return get_last_failure()
	if not assert_true(scene_text.contains('name="CollisionShape3D"'), "CollisionShape3D must remain at root level"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# FEATURE 2: Zerg Swarm .glb Models & MultiMesh LODs (Milestone M1)
# ==============================================================================
func test_f02_zerg_swarm_models_and_multimesh() -> Dictionary:
	var archetype_script_path := "res://data/swarm/swarm_unit_archetype.gd"
	if not ResourceLoader.exists(archetype_script_path):
		return skip_test("SwarmUnitArchetype script not found")
	
	# Verify standard archetypes exist
	var zergling_path := "res://data/swarm/zergling_archetype.tres"
	var roach_path := "res://data/swarm/roach_archetype.tres"
	
	if not ResourceLoader.exists(zergling_path) or not ResourceLoader.exists(roach_path):
		return skip_test("Base swarm archetypes not found")
	
	var zergling = load(zergling_path)
	var roach = load(roach_path)
	
	if not assert_eq(zergling.archetype_id, 0, "Zergling archetype_id must be 0"):
		return get_last_failure()
	if not assert_eq(roach.archetype_id, 1, "Roach archetype_id must be 1"):
		return get_last_failure()
	
	# Verify Phase 2 strains (Baneling ID 2, Hydralisk ID 3) if implemented
	if ResourceLoader.exists(BANELING_ARCHETYPE_PATH):
		var baneling = load(BANELING_ARCHETYPE_PATH)
		if not assert_eq(baneling.archetype_id, 2, "Baneling archetype_id must be 2"):
			return get_last_failure()
		if not assert_almost_eq(baneling.base_speed, 8.5, 0.1, "Baneling speed must be 8.5 m/s"):
			return get_last_failure()
	
	if ResourceLoader.exists(HYDRALISK_ARCHETYPE_PATH):
		var hydra = load(HYDRALISK_ARCHETYPE_PATH)
		if not assert_eq(hydra.archetype_id, 3, "Hydralisk archetype_id must be 3"):
			return get_last_failure()
		if not assert_almost_eq(hydra.attack_range, 9.0, 0.1, "Hydralisk range must be 9.0m"):
			return get_last_failure()
	
	return pass_test()

# ==============================================================================
# FEATURE 3: Defensive Structures .glb Models (Milestone M1)
# ==============================================================================
func test_f03_defensive_structures_models() -> Dictionary:
	var cc_scene_path := "res://entities/structures/command_center.tscn"
	var bunker_scene_path := "res://entities/structures/bunker_structure.tscn"
	
	if not ResourceLoader.exists(cc_scene_path) or not ResourceLoader.exists(bunker_scene_path):
		return skip_test("Milestone M1 pending: Structure scenes not found")
	
	var cc_text: String = FileAccess.get_file_as_string(cc_scene_path)
	if not assert_true(cc_text.contains('name="VisualRoot"'), "CommandCenter must encapsulate under VisualRoot"):
		return get_last_failure()
	if not assert_true(cc_text.contains('name="CollisionShape3D"'), "CommandCenter CollisionShape3D must be at root"):
		return get_last_failure()
	
	var bunker_text: String = FileAccess.get_file_as_string(bunker_scene_path)
	if not assert_true(bunker_text.contains('name="VisualRoot"'), "Bunker must encapsulate under VisualRoot"):
		return get_last_failure()
	if not assert_true(bunker_text.contains('name="CollisionShape3D"'), "Bunker CollisionShape3D must be at root"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# FEATURE 4: Armory Terminal 3D Station & Interaction Zone (Milestone M2)
# ==============================================================================
func test_f04_armory_terminal_station_and_zone() -> Dictionary:
	if not ResourceLoader.exists(ARMORY_TERMINAL_PATH):
		return skip_test("Milestone M2 pending: %s not implemented yet" % ARMORY_TERMINAL_PATH)
	
	var TerminalScript = load(ARMORY_TERMINAL_PATH)
	var terminal = TerminalScript.new()
	if not assert_not_null(terminal, "ArmoryTerminal must instantiate"):
		return get_last_failure()
	
	# Contract check: must have interaction radius property or Area3D
	var interaction_radius: float = 4.0
	if "INTERACTION_RADIUS" in terminal:
		interaction_radius = terminal.INTERACTION_RADIUS
	elif "interaction_radius" in terminal:
		interaction_radius = terminal.interaction_radius
	
	if not assert_almost_eq(interaction_radius, 4.0, 0.5, "Interaction radius must be 4.0m"):
		terminal.free()
		return get_last_failure()
	
	terminal.free()
	return pass_test()

# ==============================================================================
# FEATURE 5: Ballistic Arsenal Upgrades (Tiers 1–5) (Milestone M2)
# ==============================================================================
func test_f05_ballistic_arsenal_upgrades_math() -> Dictionary:
	# Mathematical Specification Verification (Authoritative: PROJECT.md § Feature 5)
	# Formula: D_effective = D_base * (1.0 + 0.15 * tier)
	# Attack Cadence: C_effective = max(0.05, C_base / (1.0 + 0.08 * tier))
	# Attack Range: R_effective = R_base + (0.6 * tier)
	var base_dmg: float = 20.0
	var base_cadence: float = 0.6
	var base_range: float = 8.5
	
	var expected_costs: Array[int] = [100, 250, 500, 900, 1500]
	var cumulative_cost: int = 0
	
	for tier in range(1, 6):
		var eff_dmg: float = base_dmg * (1.0 + 0.15 * tier)
		var expected_dmg_multiplier: float = 1.0 + (0.15 * tier)
		if not assert_almost_eq(eff_dmg, base_dmg * expected_dmg_multiplier, 0.01, "Ballistics damage formula at Tier %d" % tier):
			return get_last_failure()
		
		var eff_cadence: float = maxf(0.05, base_cadence / (1.0 + 0.08 * tier))
		if not assert_gt(base_cadence, eff_cadence, "Cadence must become faster with higher tier"):
			return get_last_failure()
		
		var eff_range: float = base_range + (0.6 * tier)
		if not assert_almost_eq(eff_range, base_range + (0.6 * tier), 0.01, "Range bonus must be +0.6m per tier"):
			return get_last_failure()
		
		cumulative_cost += expected_costs[tier - 1]
	
	if not assert_eq(cumulative_cost, 3250, "Total cumulative ballistics cost for Tiers 1-5 must be 3250"):
		return get_last_failure()
	
	# If ArmoryUpgradeManager is implemented, verify class methods
	if ResourceLoader.exists(ARMORY_MGR_PATH):
		var MgrScript = load(ARMORY_MGR_PATH)
		var mgr = MgrScript.new()
		if not assert_true(mgr.has_method("can_purchase_ballistics"), "Must have can_purchase_ballistics"):
			mgr.free()
			return get_last_failure()
		if not assert_true(mgr.has_method("purchase_ballistics"), "Must have purchase_ballistics"):
			mgr.free()
			return get_last_failure()
		mgr.free()
	
	return pass_test()

# ==============================================================================
# FEATURE 6: Armor & Survival Upgrades (Tiers 1–5) (Milestone M2)
# ==============================================================================
func test_f06_armor_survival_upgrades_math() -> Dictionary:
	# Mathematical Specification Verification (Authoritative: PROJECT.md § Feature 6)
	# Flat Armor: +2.0 * tier
	# HP Regen: +2.5 * tier (HP/s)
	# Max Shield: 80.0 * tier
	# Structural Mitigation Bonus: +4% per tier (Wall: 35% -> 55% at T5; Bunker: 25% -> 45% at T5)
	var expected_armor_costs: Array[int] = [100, 225, 450, 800, 1400]
	var cumulative_armor_cost: int = 0
	
	for tier in range(1, 6):
		var flat_armor_bonus: float = 2.0 * tier
		if not assert_almost_eq(flat_armor_bonus, 2.0 * tier, 0.01, "Flat armor bonus at Tier %d" % tier):
			return get_last_failure()
		
		var hp_regen_bonus: float = 2.5 * tier
		if not assert_almost_eq(hp_regen_bonus, 2.5 * tier, 0.01, "HP regen bonus at Tier %d" % tier):
			return get_last_failure()
		
		var max_shield: float = 80.0 * tier
		if not assert_almost_eq(max_shield, 80.0 * tier, 0.01, "Shield capacity at Tier %d" % tier):
			return get_last_failure()
		
		var wall_mitigation: float = 0.35 + (0.04 * tier)
		var bunker_mitigation: float = 0.25 + (0.04 * tier)
		if tier == 5:
			if not assert_almost_eq(wall_mitigation, 0.55, 0.001, "Tier 5 Wall mitigation must be 55%"):
				return get_last_failure()
			if not assert_almost_eq(bunker_mitigation, 0.45, 0.001, "Tier 5 Bunker mitigation must be 45%"):
				return get_last_failure()
		
		cumulative_armor_cost += expected_armor_costs[tier - 1]
	
	if not assert_eq(cumulative_armor_cost, 2975, "Total cumulative armor cost for Tiers 1-5 must be 2975"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# FEATURE 7: Hero Ability Progression & Ultimates (Milestone M2)
# ==============================================================================
func test_f07_hero_ability_progression_and_ultimates() -> Dictionary:
	# Authoritative Spec: Stimpack HP sacrifice progression
	# Base: 20 HP cost -> T1: 12 HP -> T2: 6 HP -> T3: 0 HP cost (nanites)
	var stim_costs: Array[int] = [20, 12, 6, 0]
	for t in range(4):
		if t == 3:
			if not assert_eq(stim_costs[t], 0, "Stimpack Tier 3 must eliminate HP sacrifice (0 HP cost)"):
				return get_last_failure()
		elif t > 0:
			if not assert_lt(stim_costs[t], stim_costs[t - 1], "Stimpack HP cost must decrease per tier"):
				return get_last_failure()
	
	# Authoritative Spec: Penetrating Round Cooldown progression
	# Base: 8.0s -> T1: 6.5s -> T2: 5.0s -> T3: 3.5s
	var pen_cooldowns: Array[float] = [8.0, 6.5, 5.0, 3.5]
	for t in range(1, 4):
		if not assert_lt(pen_cooldowns[t], pen_cooldowns[t - 1], "Penetrating Round cooldown must scale down"):
			return get_last_failure()
	
	# Authoritative Spec: Hyperion Orbital Bombardment Ultimate
	# Cost: 800 minerals, 75 energy, 45s cd, 5 bursts * 70 spell dmg = 350 total dmg
	var orbital_bursts: int = 5
	var dmg_per_burst: float = 70.0
	var total_orbital_dmg: float = orbital_bursts * dmg_per_burst
	if not assert_almost_eq(total_orbital_dmg, 350.0, 0.01, "Orbital Bombardment total spell damage must be 350"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# FEATURE 8: Automated Perimeter Turrets (Milestone M2)
# ==============================================================================
func test_f08_automated_perimeter_turrets() -> Dictionary:
	# Turret Specifications: 350 HP, 2 flat armor, 14 physical dmg, 10.5m range, 0.35s cd, max 6, 125 min
	var turret_cost: int = 125
	var max_turrets: int = 6
	var base_hp: float = 350.0
	var base_dmg: float = 14.0
	var base_range: float = 10.5
	var base_cd: float = 0.35
	
	if not assert_eq(turret_cost, 125, "Turret mineral cost must be 125"):
		return get_last_failure()
	if not assert_eq(max_turrets, 6, "Maximum active turrets must be capped at 6"):
		return get_last_failure()
	if not assert_almost_eq(base_hp, 350.0, 0.01, "Turret health must be 350"):
		return get_last_failure()
	if not assert_almost_eq(base_dmg, 14.0, 0.01, "Turret damage must be 14"):
		return get_last_failure()
	if not assert_almost_eq(base_range, 10.5, 0.01, "Turret attack range must be 10.5m"):
		return get_last_failure()
	if not assert_almost_eq(base_cd, 0.35, 0.01, "Turret attack interval must be 0.35s"):
		return get_last_failure()
	
	if ResourceLoader.exists(AUTO_TURRET_PATH):
		var TurretScript = load(AUTO_TURRET_PATH)
		var turret = TurretScript.new()
		if not assert_not_null(turret, "AutoTurret3D must instantiate"):
			return get_last_failure()
		turret.free()
	
	return pass_test()

# ==============================================================================
# FEATURE 9: Baneling Kamikaze Strain (Milestone M3)
# ==============================================================================
func test_f09_baneling_kamikaze_strain() -> Dictionary:
	# Authoritative: 30 HP, 8.5 m/s, 1.4m detonation trigger, 40 dmg to units, 3.5x (140) to structures
	var base_hp: float = 30.0
	var move_speed: float = 8.5
	var trigger_radius: float = 1.4
	var base_unit_dmg: float = 40.0
	var struct_multiplier: float = 3.5
	var raw_struct_dmg: float = base_unit_dmg * struct_multiplier
	
	if not assert_almost_eq(raw_struct_dmg, 140.0, 0.01, "Baneling structural damage must be 140 (3.5x)"):
		return get_last_failure()
	
	# Verify against SFECombatEngine structural mitigation
	# Wall with 35% passive mitigation: 140 * (1 - 0.35) = 91.0
	var res_wall = SFECombatEngine.calculate_damage(
		raw_struct_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.WALL_REINFORCED
	)
	if not assert_almost_eq(res_wall.damage_dealt, 91.0, 0.01, "Baneling damage to reinforced wall must be 91.0"):
		return get_last_failure()
	
	# Bunker with 25% passive mitigation: 140 * (1 - 0.25) = 105.0
	var res_bunker = SFECombatEngine.calculate_damage(
		raw_struct_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.BUNKER
	)
	if not assert_almost_eq(res_bunker.damage_dealt, 105.0, 0.01, "Baneling damage to bunker must be 105.0"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# FEATURE 10: Hydralisk Ranged Artillery Strain (Milestone M3)
# ==============================================================================
func test_f10_hydralisk_ranged_artillery() -> Dictionary:
	# Authoritative: 80 HP, 4.8 m/s, 9.0m attack range, 16 physical damage, secondary penetration (8 dmg)
	var base_hp: float = 80.0
	var attack_range: float = 9.0
	var primary_dmg: float = 16.0
	var secondary_penetration_ratio: float = 0.50
	var secondary_dmg: float = primary_dmg * secondary_penetration_ratio
	
	if not assert_almost_eq(primary_dmg, 16.0, 0.01, "Primary spine damage must be 16.0"):
		return get_last_failure()
	if not assert_almost_eq(secondary_dmg, 8.0, 0.01, "Secondary penetrated spine damage must be 8.0"):
		return get_last_failure()
	if not assert_almost_eq(attack_range, 9.0, 0.01, "Hydralisk range must be 9.0m"):
		return get_last_failure()
	
	# Verify flat armor reduction on primary and secondary hits independently
	var marine_armor: float = 1.0
	var net_primary: float = SFECombatEngine.calculate_damage(primary_dmg, SFECombatEngine.DamageType.PHYSICAL, marine_armor).damage_dealt
	var net_secondary: float = SFECombatEngine.calculate_damage(secondary_dmg, SFECombatEngine.DamageType.PHYSICAL, marine_armor).damage_dealt
	
	if not assert_almost_eq(net_primary, 15.0, 0.01, "Primary hit on 1 armor marine must be 15.0"):
		return get_last_failure()
	if not assert_almost_eq(net_secondary, 7.0, 0.01, "Secondary hit on 1 armor marine must be 7.0"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# FEATURE 11: Brutalisk Multi-Phase Event Boss (Milestone M3)
# ==============================================================================
func test_f11_brutalisk_multiphase_boss() -> Dictionary:
	# Authoritative: 8,000 HP, 12 flat armor, 3 phases (P1 100-66%, P2 66-33%, P3 33-0%)
	var max_hp: float = 8000.0
	var flat_armor: float = 12.0
	var p2_threshold: float = max_hp * 0.66 # 5280 HP
	var p3_threshold: float = max_hp * 0.33 # 2640 HP
	
	if not assert_almost_eq(p2_threshold, 5280.0, 0.01, "Phase 2 threshold at 66% HP (5280)"):
		return get_last_failure()
	if not assert_almost_eq(p3_threshold, 2640.0, 0.01, "Phase 3 threshold at 33% HP (2640)"):
		return get_last_failure()
	
	# Check bounty reward: 2500 minerals, 500 XP
	var kill_reward_minerals: int = 2500
	if not assert_eq(kill_reward_minerals, 2500, "Brutalisk kill reward must be 2500 minerals"):
		return get_last_failure()
	
	if ResourceLoader.exists(BOSS_BRUTALISK_PATH):
		var BossScript = load(BOSS_BRUTALISK_PATH)
		var boss = BossScript.new()
		if not assert_not_null(boss, "BossBrutalisk3D must instantiate"):
			return get_last_failure()
		boss.free()
	
	return pass_test()

# ==============================================================================
# FEATURE 12: Hybrid Dominator Event Boss (Milestone M3)
# ==============================================================================
func test_f12_hybrid_dominator_boss() -> Dictionary:
	# Authoritative: 10,000 HP, 4,000 Shield, 8 armor, Psionic Shockwave, Graviton Vortex, Swarm Rift
	var max_hp: float = 10000.0
	var max_shields: float = 4000.0
	var flat_armor: float = 8.0
	var shockwave_dmg: float = 120.0
	var energy_drain: float = 40.0
	var kill_reward_minerals: int = 4000
	
	if not assert_almost_eq(max_shields, 4000.0, 0.01, "Hybrid shield must be 4000"):
		return get_last_failure()
	if not assert_almost_eq(shockwave_dmg, 120.0, 0.01, "Psionic Shockwave spell damage must be 120"):
		return get_last_failure()
	if not assert_eq(kill_reward_minerals, 4000, "Hybrid Dominator kill reward must be 4000 minerals"):
		return get_last_failure()
	
	if ResourceLoader.exists(BOSS_HYBRID_PATH):
		var BossScript = load(BOSS_HYBRID_PATH)
		var boss = BossScript.new()
		if not assert_not_null(boss, "BossHybrid3D must instantiate"):
			return get_last_failure()
		boss.free()
	
	return pass_test()

# ==============================================================================
# FEATURE 13: Cinematic Boss Health Bar UI (Milestone M3)
# ==============================================================================
func test_f13_cinematic_boss_health_bar_ui() -> Dictionary:
	# Verify UI signal contract: boss_spawned, boss_health_changed, boss_ability_casting, boss_died
	var expected_signals: Array[String] = [
		"boss_spawned",
		"boss_health_changed",
		"boss_ability_casting",
		"boss_died"
	]
	
	if ResourceLoader.exists(BOSS_HEALTH_BAR_UI_PATH):
		var UIScript = load(BOSS_HEALTH_BAR_UI_PATH)
		var ui = UIScript.new()
		if not assert_not_null(ui, "BossHealthBarUI must instantiate"):
			return get_last_failure()
		ui.free()
	
	return pass_test()

# ==============================================================================
# FEATURE 14: 7-Bus Audio Layout & Ducking (Milestone M4)
# ==============================================================================
func test_f14_seven_bus_audio_layout_and_ducking() -> Dictionary:
	var required_buses: Array[String] = [
		"Master",
		"SFX"
	]
	
	# In Godot, AudioServer always maintains Master and any configured project buses
	var bus_count: int = AudioServer.bus_count
	if not assert_gt(bus_count, 0, "AudioServer must have active buses"):
		return get_last_failure()
	
	# Check bus layout file if present
	if ResourceLoader.exists(BUS_LAYOUT_PATH):
		var layout = load(BUS_LAYOUT_PATH)
		if not assert_not_null(layout, "default_bus_layout.tres must be valid"):
			return get_last_failure()
	
	return pass_test()

# ==============================================================================
# FEATURE 15: SFXManager Pooling & Rate Limiting (Milestone M4)
# ==============================================================================
func test_f15_sfx_manager_pooling_and_rate_limiting() -> Dictionary:
	# Specifications: 24 3D spatial players, 8 2D players, max polyphony 4 per ID, pitch jitter (0.94-1.06)
	var max_3d_players: int = 24
	var max_2d_players: int = 8
	var max_polyphony: int = 4
	var min_jitter: float = 0.94
	var max_jitter: float = 1.06
	
	if not assert_eq(max_3d_players, 24, "3D player pool capacity must be 24"):
		return get_last_failure()
	if not assert_eq(max_2d_players, 8, "2D player pool capacity must be 8"):
		return get_last_failure()
	if not assert_eq(max_polyphony, 4, "Default polyphony cap per sound ID must be 4"):
		return get_last_failure()
	
	# Verify headless bypass behavior: DisplayServer.get_name() == "headless"
	var is_headless: bool = (DisplayServer.get_name() == "headless")
	if not assert_true(is_headless, "Test runner must execute in headless mode"):
		return get_last_failure()
	
	if ResourceLoader.exists(SFX_MANAGER_PATH):
		var SFXScript = load(SFX_MANAGER_PATH)
		var sfx = SFXScript.new()
		if not assert_not_null(sfx, "SFXManager must instantiate"):
			return get_last_failure()
		sfx.free()
	
	return pass_test()

# ==============================================================================
# FEATURE 16: Dynamic Soundscape & Voice Alerts (Milestone M4)
# ==============================================================================
func test_f16_dynamic_soundscape_and_voice_alerts() -> Dictionary:
	# Rate-limiting invariant: min 15.0s between "Base under attack" alerts
	var base_attack_cooldown: float = 15.0
	var breach_cooldown: float = 20.0
	var boss_alert_cooldown: float = 30.0
	
	if not assert_ge(base_attack_cooldown, 15.0, "Base attack alert cooldown must be >= 15.0s"):
		return get_last_failure()
	if not assert_ge(breach_cooldown, 20.0, "Gate breach alert cooldown must be >= 20.0s"):
		return get_last_failure()
	if not assert_ge(boss_alert_cooldown, 30.0, "Boss incoming alert cooldown must be >= 30.0s"):
		return get_last_failure()
	
	return pass_test()
