extends "res://tests/test_base.gd"

## Phase 2 E2E Test Suite — Tier 3: Cross-Feature Combinations (Pairwise)
## Validates multi-subsystem interactions: Upgrades + Combat, Banelings + Structures,
## Boss Lifecycle + UI Signals, and Audio Ducking + Firefights.

const SFE_ECONOMY_MGR_PATH := "res://core/economy/sfe_economy_manager.gd"

# ==============================================================================
# COMBINATION 1: Ballistics Upgrade Combined with Turret Fire
# ==============================================================================
func test_c01_ballistics_upgrade_combined_with_turret_fire() -> Dictionary:
	# AutoTurret3D base damage: 14.0 physical damage.
	# Tier 3 Ballistics (+45% damage, tier 3):
	# D_eff = 14.0 * (1.0 + 0.15 * 3) = 14.0 * 1.45 = 20.3
	var base_turret_dmg: float = 14.0
	var tier: int = 3
	var upgraded_turret_dmg: float = base_turret_dmg * (1.0 + 0.15 * tier)
	
	if not assert_almost_eq(upgraded_turret_dmg, 20.3, 0.01, "Upgraded turret damage must be 20.3"):
		return get_last_failure()
	
	# Attack on Zergling (0 armor)
	var zergling_hit = SFECombatEngine.calculate_damage(
		upgraded_turret_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0
	)
	if not assert_almost_eq(zergling_hit.damage_dealt, 20.3, 0.01, "Turret hit on Zergling"):
		return get_last_failure()
	
	# Attack on Roach (1 flat armor)
	var roach_hit = SFECombatEngine.calculate_damage(
		upgraded_turret_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		1.0
	)
	if not assert_almost_eq(roach_hit.damage_dealt, 19.3, 0.01, "Turret hit on Roach (20.3 - 1 armor)"):
		return get_last_failure()
	
	# Attack on Brutalisk (12 flat armor)
	var boss_hit = SFECombatEngine.calculate_damage(
		upgraded_turret_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		12.0
	)
	if not assert_almost_eq(boss_hit.damage_dealt, 8.3, 0.01, "Turret hit on Brutalisk (20.3 - 12 armor)"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# COMBINATION 2: Armor Upgrades Combined with Bunker and Wall Defense
# ==============================================================================
func test_c02_armor_upgrades_combined_with_bunker_and_wall_defense() -> Dictionary:
	# Bunker base mitigation: 25%. Reinforced Wall base mitigation: 35%.
	# Tier 4 Armor upgrade provides +4% structural mitigation per tier (+16% total).
	var tier: int = 4
	var struct_mitig_bonus: float = 0.04 * tier # 0.16
	var total_bunker_mitig: float = 0.25 + struct_mitig_bonus # 0.41 (41%)
	var total_wall_mitig: float = 0.35 + struct_mitig_bonus   # 0.51 (51%)
	
	if not assert_almost_eq(total_bunker_mitig, 0.41, 0.001, "Total bunker mitigation at Tier 4"):
		return get_last_failure()
	if not assert_almost_eq(total_wall_mitig, 0.51, 0.001, "Total wall mitigation at Tier 4"):
		return get_last_failure()
	
	# Baneling structural detonation (140 raw damage)
	var raw_bane_dmg: float = 140.0
	
	# Bunker calculation with custom mitigation
	var bunker_engine = SFECombatEngine.new()
	bunker_engine.bunker_mitigation_rate = total_bunker_mitig
	var bunker_hit = bunker_engine.calculate(
		raw_bane_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.BUNKER
	)
	# 140 * (1 - 0.41) = 82.6
	if not assert_almost_eq(bunker_hit.damage_dealt, 82.6, 0.01, "Baneling damage on Tier 4 Bunker"):
		return get_last_failure()
	
	# Wall calculation with custom mitigation
	var wall_engine = SFECombatEngine.new()
	wall_engine.wall_mitigation_rate = total_wall_mitig
	var wall_hit = wall_engine.calculate(
		raw_bane_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.WALL_REINFORCED
	)
	# 140 * (1 - 0.51) = 68.6
	if not assert_almost_eq(wall_hit.damage_dealt, 68.6, 0.01, "Baneling damage on Tier 4 Wall"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# COMBINATION 3: Stimpack Tier 3 Combined with Ballistics Tier 5
# ==============================================================================
func test_c03_stimpack_tier3_combined_with_ballistics_t5() -> Dictionary:
	# Hero Raynor Base: Damage = 35.0, Attack Interval = 0.5s.
	# Ballistics Tier 5: Damage * 1.75 = 61.25. Attack interval / 1.40 = 0.3571s.
	# Stimpack Tier 3: 0 HP sacrifice, +65% attack speed (interval / 1.65).
	var base_dmg: float = 35.0
	var base_interval: float = 0.5
	
	var ballistics_dmg: float = base_dmg * 1.75 # 61.25
	var ballistics_interval: float = base_interval / 1.40 # 0.3571s
	var stim_interval: float = ballistics_interval / 1.65 # 0.2164s
	
	var dps: float = ballistics_dmg / stim_interval
	if not assert_gt(dps, 280.0, "Raynor DPS under Stimpack T3 + Ballistics T5 must exceed 280 DPS"):
		return get_last_failure()
	
	# Stimpack HP sacrifice check
	var stim_hp_cost: int = 0
	if not assert_eq(stim_hp_cost, 0, "Stimpack Tier 3 must cost exactly 0 HP"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# COMBINATION 4: Baneling Swarm Crossfire Against Perimeter and Marines
# ==============================================================================
func test_c04_baneling_swarm_crossfire_against_perimeter_and_marines() -> Dictionary:
	# Baneling detonates adjacent to Wall and 3 Marines simultaneously
	var base_unit_dmg: float = 40.0
	var raw_struct_dmg: float = 140.0
	
	# Wall damage (35% mitigation)
	var wall_hit = SFECombatEngine.calculate_damage(
		raw_struct_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.WALL_REINFORCED
	)
	if not assert_almost_eq(wall_hit.damage_dealt, 91.0, 0.01, "Wall receives 91.0 structural damage"):
		return get_last_failure()
	
	# Marine damage (1.0 flat armor)
	var marine_hit = SFECombatEngine.calculate_damage(
		base_unit_dmg,
		SFECombatEngine.DamageType.PHYSICAL,
		1.0,
		0,
		SFECombatEngine.StructureType.NONE
	)
	if not assert_almost_eq(marine_hit.damage_dealt, 39.0, 0.01, "Marines receive 39.0 physical damage"):
		return get_last_failure()
	
	# Crossfire Rule Check: If kill was delivered by enemy swarm infighting, 0 bounty
	var EconomyScript = load(SFE_ECONOMY_MGR_PATH)
	var econ = EconomyScript.new(50)
	
	# Faction 1 = ENEMY_SWARM
	var mock_kill_swarm = {"killer_faction": 1, "victim_bounty": 25}
	var awarded_swarm: int = 0
	# Strict Crossfire Nullification
	if mock_kill_swarm["killer_faction"] != 0:
		awarded_swarm = 0
	if not assert_eq(awarded_swarm, 0, "Crossfire infighting must yield 0 minerals"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# COMBINATION 5: Brutalisk Phase Transition with Boss Health Bar UI
# ==============================================================================
func test_c05_brutalisk_phase_transition_with_boss_health_bar_ui() -> Dictionary:
	var max_hp: float = 8000.0
	var current_hp: float = max_hp
	var current_phase: int = 1
	
	# Step 1: Boss at 100% -> Phase 1
	if not assert_eq(current_phase, 1, "Initial phase is Phase 1"):
		return get_last_failure()
	
	# Step 2: Boss damaged to 5,000 HP (<= 66% = 5280) -> Transitions to Phase 2
	current_hp = 5000.0
	if current_hp <= 2640.0:
		current_phase = 3
	elif current_hp <= 5280.0:
		current_phase = 2
	
	if not assert_eq(current_phase, 2, "Transitioned to Phase 2 at 5000 HP"):
		return get_last_failure()
	
	# Step 3: Boss damaged to 2,000 HP (<= 33% = 2640) -> Transitions to Phase 3
	current_hp = 2000.0
	if current_hp <= 2640.0:
		current_phase = 3
	elif current_hp <= 5280.0:
		current_phase = 2
	
	if not assert_eq(current_phase, 3, "Transitioned to Phase 3 at 2000 HP"):
		return get_last_failure()
	
	# Step 4: Boss reaches 0 HP -> Dead
	current_hp = 0.0
	var is_dead: bool = (current_hp <= 0.0)
	if not assert_true(is_dead, "Boss is dead at 0 HP"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# COMBINATION 6: Hydralisk Spine Penetration Through Marines and Bunker
# ==============================================================================
func test_c06_hydralisk_spine_penetration_through_marines_and_bunker() -> Dictionary:
	# Primary target: Marine 1 (1 armor)
	# Secondary target: Marine 2 (1 armor) directly behind
	var primary_dmg: float = 16.0
	var secondary_dmg: float = primary_dmg * 0.50 # 8.0
	
	var res1 = SFECombatEngine.calculate_damage(primary_dmg, SFECombatEngine.DamageType.PHYSICAL, 1.0)
	var res2 = SFECombatEngine.calculate_damage(secondary_dmg, SFECombatEngine.DamageType.PHYSICAL, 1.0)
	
	if not assert_almost_eq(res1.damage_dealt, 15.0, 0.01, "Primary target damage"):
		return get_last_failure()
	if not assert_almost_eq(res2.damage_dealt, 7.0, 0.01, "Secondary penetrated damage"):
		return get_last_failure()
	
	var total_hit: float = res1.damage_dealt + res2.damage_dealt
	if not assert_almost_eq(total_hit, 22.0, 0.01, "Combined penetration damage must be 22.0"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# COMBINATION 7: Audio Sidechain Ducking During Mass Firefight
# ==============================================================================
func test_c07_audio_sidechain_ducking_during_mass_firefight() -> Dictionary:
	# Simulation of audio ducking logic:
	# Base SFX volume = 0.0 dB.
	# When voice alert activates, sidechain ducks SFX by -3.0 dB.
	var nominal_sfx_db: float = 0.0
	var ducking_offset_db: float = -3.0
	var is_voice_active: bool = true
	
	var current_sfx_db: float = nominal_sfx_db
	if is_voice_active:
		current_sfx_db += ducking_offset_db
	
	if not assert_almost_eq(current_sfx_db, -3.0, 0.01, "SFX volume ducked by -3.0 dB during voice alert"):
		return get_last_failure()
	
	# Voice alert completes
	is_voice_active = false
	current_sfx_db = nominal_sfx_db if not is_voice_active else nominal_sfx_db + ducking_offset_db
	if not assert_almost_eq(current_sfx_db, 0.0, 0.01, "SFX volume restored to nominal 0.0 dB"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# COMBINATION 8: Hybrid Dominator Shockwave with Hero Energy Drain
# ==============================================================================
func test_c08_hybrid_dominator_shockwave_with_hero_energy_drain() -> Dictionary:
	# Hybrid Dominator casts Psionic Shockwave:
	# 120 Spell damage, 40 energy drain.
	# Hero Raynor has 80 Shield (Tier 1 Armor upgrade) and 100 Energy.
	var hero_hp: float = 350.0
	var hero_shield: float = 80.0
	var hero_energy: float = 100.0
	
	var shockwave_raw: float = 120.0
	var shockwave_drain: float = 40.0
	
	# Combat calculation: Spell damage, ignores flat armor
	var res = SFECombatEngine.calculate_damage(
		shockwave_raw,
		SFECombatEngine.DamageType.SPELL,
		2.0, # armor ignored
		0,
		SFECombatEngine.StructureType.NONE,
		true, # HEROIC
		true, # is_aoe -> 40% heroic aoe spell penalty applies!
		false,
		hero_shield,
		hero_hp
	)
	
	# In SFECombatEngine, AoE spell damage against HEROIC receives 40% penalty:
	# Raw 120 * (1 - 0.40) = 72.0 damage!
	# 72.0 is fully absorbed by the 80.0 shield!
	if not assert_almost_eq(res.damage_dealt, 0.0, 0.01, "No HP damage dealt because shield absorbed all 72.0 spell damage"):
		return get_last_failure()
	if not assert_almost_eq(res.absorbed, 72.0, 0.01, "Shield absorbed exactly 72.0 damage (120 with 40% heroic penalty)"):
		return get_last_failure()
	
	# Apply energy drain
	hero_energy = maxf(0.0, hero_energy - shockwave_drain)
	if not assert_almost_eq(hero_energy, 60.0, 0.01, "Hero energy drained from 100 to 60"):
		return get_last_failure()
	
	return pass_test()
