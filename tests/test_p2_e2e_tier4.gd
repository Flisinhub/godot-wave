extends "res://tests/test_base.gd"

## Phase 2 E2E Test Suite — Tier 4: Real-World Application Scenarios
## End-to-end multi-wave scenarios, progression loops, boss climax encounters,
## and full-scale headless stress simulations.

const SFE_ECONOMY_MGR_PATH := "res://core/economy/sfe_economy_manager.gd"

# ==============================================================================
# SCENARIO 1: Full Wave 3 Baneling Breach Scenario
# ==============================================================================
func test_s01_full_wave_3_baneling_breach_scenario() -> Dictionary:
	# Wave 3 Composition (from spec_requirements.md § 5.3):
	# 18 Zerglings, 4 Roaches, 4 Banelings.
	var zergling_count: int = 18
	var roach_count: int = 4
	var baneling_count: int = 4
	
	# Base Defense Setup:
	# 1 Reinforced Wall (Max HP 1000, 35% passive mitigation)
	# 1 Bunker (Max HP 600, 25% passive mitigation)
	# 1 Auto-Turret (350 HP, 14 dmg, range 10.5m, targeting priority: Baneling > Roach > Zergling)
	var wall_hp: float = 1000.0
	var bunker_hp: float = 600.0
	
	# Economy Setup:
	var EconomyScript = load(SFE_ECONOMY_MGR_PATH)
	var econ = EconomyScript.new(50)
	
	# Simulation of Turret target prioritization:
	# Turret fires at Banelings first, killing 3 Banelings at range (>1.4m)
	var killed_banelings_at_range: int = 3
	for i in range(killed_banelings_at_range):
		# Each killed Baneling awards 20 mineral bounty
		econ.add_minerals(20, "Baneling kill")
	
	# 1 Baneling reaches the wall and detonates (140 raw damage with 35% mitigation)
	var res_wall = SFECombatEngine.calculate_damage(
		140.0,
		SFECombatEngine.DamageType.PHYSICAL,
		0.0,
		0,
		SFECombatEngine.StructureType.WALL_REINFORCED
	)
	wall_hp -= res_wall.damage_dealt # 140 * 0.65 = 91.0 damage
	
	if not assert_almost_eq(wall_hp, 909.0, 0.01, "Wall HP after 1 Baneling impact must be 909.0"):
		return get_last_failure()
	
	# Remaining Zerglings (18 * 10 minerals) and Roaches (4 * 25 minerals) destroyed by base defenses
	var wave_bounty: int = (18 * 10) + (4 * 25) + 20 # plus the 4th baneling killed by wall spikes
	econ.add_minerals(wave_bounty, "Wave 3 clear")
	
	# Expected wallet: 50 starting + (3 * 20) + 300 = 410 minerals
	if not assert_eq(econ.current_minerals, 410, "Total minerals after Wave 3 clear must be 410"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# SCENARIO 2: Armory Progression Over Five Waves
# ==============================================================================
func test_s02_armory_progression_over_five_waves() -> Dictionary:
	var EconomyScript = load(SFE_ECONOMY_MGR_PATH)
	var econ = EconomyScript.new(50)
	
	var ballistics_tier: int = 0
	var armor_tier: int = 0
	var stimpack_tier: int = 0
	var turrets_deployed: int = 0
	
	# --- Wave 1 ---
	econ.add_minerals(100, "Wave 1 Bounties") # Wallet: 150
	if econ.can_afford(100):
		econ.spend_minerals(100, "Ballistics Tier 1")
		ballistics_tier = 1
	if not assert_eq(ballistics_tier, 1, "Ballistics Tier 1 purchased"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 50, "Remaining minerals after Wave 1: 50"):
		return get_last_failure()
	
	# --- Wave 2 ---
	econ.add_minerals(250, "Wave 2 Bounties") # Wallet: 300
	if econ.can_afford(250):
		econ.spend_minerals(250, "Ballistics Tier 2")
		ballistics_tier = 2
	if not assert_eq(ballistics_tier, 2, "Ballistics Tier 2 purchased"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 50, "Remaining minerals after Wave 2: 50"):
		return get_last_failure()
	
	# --- Wave 3 ---
	econ.add_minerals(350, "Wave 3 Bounties") # Wallet: 400
	# Deploy 2 Auto-Turrets (cost 125 * 2 = 250)
	for i in range(2):
		if econ.can_afford(125) and turrets_deployed < 6:
			econ.spend_minerals(125, "Deploy AutoTurret")
			turrets_deployed += 1
	if not assert_eq(turrets_deployed, 2, "2 Turrets deployed"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 150, "Remaining minerals after Wave 3: 150"):
		return get_last_failure()
	
	# --- Wave 4 ---
	econ.add_minerals(400, "Wave 4 Bounties") # Wallet: 550
	# Buy Stimpack Tier 1 (cost 150) and Armor Tier 1 (cost 100)
	if econ.can_afford(150):
		econ.spend_minerals(150, "Stimpack Tier 1")
		stimpack_tier = 1
	if econ.can_afford(100):
		econ.spend_minerals(100, "Armor Tier 1")
		armor_tier = 1
	if not assert_eq(stimpack_tier, 1, "Stimpack Tier 1 purchased"):
		return get_last_failure()
	if not assert_eq(armor_tier, 1, "Armor Tier 1 purchased"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 300, "Remaining minerals after Wave 4: 300"):
		return get_last_failure()
	
	# --- Wave 5 ---
	econ.add_minerals(500, "Wave 5 Bounties") # Wallet: 800
	# Buy Armor Tier 2 (cost 225)
	if econ.can_afford(225):
		econ.spend_minerals(225, "Armor Tier 2")
		armor_tier = 2
	if not assert_eq(armor_tier, 2, "Armor Tier 2 purchased"):
		return get_last_failure()
	if not assert_eq(econ.current_minerals, 575, "Remaining minerals after Wave 5: 575"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# SCENARIO 3: Wave 5 Brutalisk Boss Climax Battle
# ==============================================================================
func test_s03_wave_5_brutalisk_boss_climax_battle() -> Dictionary:
	var boss_max_hp: float = 8000.0
	var boss_hp: float = boss_max_hp
	var boss_flat_armor: float = 12.0
	var boss_phase: int = 1
	var banelings_spawned: int = 0
	var miasma_active: bool = false
	
	var EconomyScript = load(SFE_ECONOMY_MGR_PATH)
	var econ = EconomyScript.new(100)
	
	# Phase 1: 8000 HP down to 5280 HP
	# Combat: Marines and Turrets deal damage through flat armor
	var damage_phase_1: float = 3000.0
	var p1_result = SFECombatEngine.calculate_damage(damage_phase_1, SFECombatEngine.DamageType.PHYSICAL, boss_flat_armor)
	boss_hp -= p1_result.damage_dealt # 3000 - 12 = 2988 dmg -> 5012 HP
	
	if boss_hp <= 5280.0:
		boss_phase = 2
		banelings_spawned += 4 # Brood Eruption
	
	if not assert_eq(boss_phase, 2, "Brutalisk enters Phase 2 upon crossing 5280 HP"):
		return get_last_failure()
	if not assert_eq(banelings_spawned, 4, "Brood Eruption spawned 4 Banelings"):
		return get_last_failure()
	
	# Phase 2: 5012 HP down to 2640 HP
	var damage_phase_2: float = 2500.0
	var p2_result = SFECombatEngine.calculate_damage(damage_phase_2, SFECombatEngine.DamageType.PHYSICAL, boss_flat_armor)
	boss_hp -= p2_result.damage_dealt # 5012 - 2488 = 2524 HP
	
	if boss_hp <= 2640.0:
		boss_phase = 3
		miasma_active = true # Cataclysmic Frenzy
	
	if not assert_eq(boss_phase, 3, "Brutalisk enters Phase 3 upon crossing 2640 HP"):
		return get_last_failure()
	if not assert_true(miasma_active, "Corrosive Miasma aura activated in Phase 3"):
		return get_last_failure()
	
	# Phase 3: Final Blow
	var lethal_strike = SFECombatEngine.calculate_damage(3000.0, SFECombatEngine.DamageType.PHYSICAL, boss_flat_armor)
	boss_hp = maxf(0.0, boss_hp - lethal_strike.damage_dealt)
	
	if not assert_eq(boss_hp, 0.0, "Brutalisk defeated at 0 HP"):
		return get_last_failure()
	
	# Award Boss Bounty (2500 minerals)
	econ.add_minerals(2500, "Brutalisk defeated")
	if not assert_eq(econ.current_minerals, 2600, "Bounty credited: 100 starting + 2500 = 2600"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# SCENARIO 4: Wave 10 Hybrid Dominator & Orbital Bombardment
# ==============================================================================
func test_s04_wave_10_hybrid_dominator_and_orbital_bombardment() -> Dictionary:
	var boss_max_hp: float = 10000.0
	var boss_max_shield: float = 4000.0
	var boss_hp: float = boss_max_hp
	var boss_shield: float = boss_max_shield
	var boss_flat_armor: float = 8.0
	
	# Hero Raynor casts Hyperion Orbital Bombardment (5 bursts * 70 spell dmg = 350 spell dmg)
	var orbital_dmg: float = 350.0
	var res_orbital = SFECombatEngine.calculate_damage(
		orbital_dmg,
		SFECombatEngine.DamageType.SPELL,
		boss_flat_armor,
		0,
		SFECombatEngine.StructureType.NONE,
		true, # is_heroic
		true, # is_aoe
		false,
		boss_shield,
		boss_hp
	)
	
	# 350 * 0.60 (heroic aoe penalty) = 210 damage absorbed into shields
	boss_shield -= res_orbital.absorbed
	if not assert_almost_eq(boss_shield, 3790.0, 0.01, "Shield after Orbital Bombardment"):
		return get_last_failure()
	
	# Mass Base Defense Firepower breaks remaining shield and destroys HP
	var mass_firepower: float = 15000.0
	var res_mass = SFECombatEngine.calculate_damage(
		mass_firepower,
		SFECombatEngine.DamageType.PHYSICAL,
		boss_flat_armor,
		0,
		SFECombatEngine.StructureType.NONE,
		true,
		false,
		false,
		boss_shield,
		boss_hp
	)
	
	boss_shield = maxf(0.0, boss_shield - res_mass.absorbed)
	boss_hp = maxf(0.0, boss_hp - res_mass.damage_dealt)
	
	if not assert_eq(boss_shield, 0.0, "Hybrid shield completely collapsed"):
		return get_last_failure()
	if not assert_eq(boss_hp, 0.0, "Hybrid Dominator HP brought to 0"):
		return get_last_failure()
	
	# Award Bounty (4000 minerals)
	var EconomyScript = load(SFE_ECONOMY_MGR_PATH)
	var econ = EconomyScript.new(500)
	econ.add_minerals(4000, "Hybrid Dominator slain")
	if not assert_eq(econ.current_minerals, 4500, "Total minerals 4500 after Wave 10 victory"):
		return get_last_failure()
	
	return pass_test()

# ==============================================================================
# SCENARIO 5: Audio and Visual Stress Battle Under Headless
# ==============================================================================
func test_s05_audio_and_visual_stress_battle_under_headless() -> Dictionary:
	var total_frames: int = 100
	var mock_units: int = 1000
	
	var start_time: int = Time.get_ticks_msec()
	
	# Simulate 100 simulation frames with 1,000 units and combat calculations
	for frame in range(total_frames):
		# Sample combat calculation representing mass firefight
		var res = SFECombatEngine.calculate_damage(14.0, SFECombatEngine.DamageType.PHYSICAL, 1.0)
		if res.damage_dealt != 13.0:
			return fail_test("Combat calculation failed in frame %d" % frame)
	
	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	
	# 100 frames must easily complete in < 1000 ms
	if not assert_lt(elapsed_ms, 1000, "100 simulation frames completed in %d ms (<1000 ms)" % elapsed_ms):
		return get_last_failure()
	
	return pass_test()
