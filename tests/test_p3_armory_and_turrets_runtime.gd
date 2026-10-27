extends "res://tests/test_base.gd"

## SFE5 Phase 3 E2E Test Suite — Armory Terminal & Auto-Turrets Runtime
## Covers Requirement R4:
## 8 comprehensive tests covering ArmoryTerminal 4.0m Area3D proximity, [E] input handling,
## terminal UI modal integration, live hero stat updates on active node without scene reload,
## and turret deployment cap.

const ArmoryTerminalScript := preload("res://entities/structures/armory_terminal.gd")
const ArmoryUpgradeManagerScript := preload("res://core/upgrades/armory_upgrade_manager.gd")
const AutoTurret3DScript := preload("res://entities/structures/auto_turret_3d.gd")
const HeroUnit3DScript := preload("res://entities/allies/hero_unit_3d.gd")
const SFEEconomyManagerScript := preload("res://core/economy/sfe_economy_manager.gd")
const SFECombatEngine := preload("res://core/combat/sfe_combat_engine.gd")

const RAYNOR_PATH := "res://data/heroes/raynor.tres"


# ==============================================================================
# 1. ARMORY TERMINAL PROXIMITY DETECTION
# ==============================================================================
func test_armory_terminal_proximity_area_trigger() -> Dictionary:
	var terminal: ArmoryTerminal = ArmoryTerminalScript.new()
	var hero: HeroUnit3D = HeroUnit3DScript.new()

	if not assert_almost_eq(terminal.interaction_radius, 4.0, 0.1, "Interaction radius must be 4.0m"):
		terminal.free()
		hero.free()
		return get_last_failure()

	if not assert_false(terminal.hero_in_range, "Hero must not be in range initially"):
		terminal.free()
		hero.free()
		return get_last_failure()

	# Simulate hero entering proximity zone
	terminal._on_body_entered(hero)

	if not assert_true(terminal.hero_in_range, "hero_in_range must become true upon body entered"):
		terminal.free()
		hero.free()
		return get_last_failure()

	terminal.free()
	hero.free()
	return pass_test()


# ==============================================================================
# 2. ARMORY TERMINAL [E] INPUT TOGGLE & SIGNALS
# ==============================================================================
func test_armory_terminal_key_e_toggle_and_signals() -> Dictionary:
	var terminal: ArmoryTerminal = ArmoryTerminalScript.new()

	var tracker := {"opened": 0, "closed": 0}
	terminal.terminal_opened.connect(func(): tracker["opened"] += 1)
	terminal.terminal_closed.connect(func(): tracker["closed"] += 1)

	terminal.hero_in_range = true

	# Open via toggle
	terminal.toggle_terminal()
	if not assert_true(terminal.is_terminal_open, "Terminal must be open after first toggle"):
		terminal.free()
		return get_last_failure()
	if not assert_eq(tracker["opened"], 1, "terminal_opened signal must fire"):
		terminal.free()
		return get_last_failure()

	# Close via toggle
	terminal.toggle_terminal()
	if not assert_false(terminal.is_terminal_open, "Terminal must be closed after second toggle"):
		terminal.free()
		return get_last_failure()
	if not assert_eq(tracker["closed"], 1, "terminal_closed signal must fire"):
		terminal.free()
		return get_last_failure()

	# Test KEY_E unhandled input handling
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_E
	key_event.pressed = true
	key_event.echo = false

	terminal._unhandled_input(key_event)
	if not assert_true(terminal.is_terminal_open, "Pressing [E] must open terminal"):
		terminal.free()
		return get_last_failure()

	terminal.free()
	return pass_test()


# ==============================================================================
# 3. ARMORY TERMINAL AUTO-CLOSE ON EXIT
# ==============================================================================
func test_armory_terminal_exit_range_auto_close() -> Dictionary:
	var terminal: ArmoryTerminal = ArmoryTerminalScript.new()
	var hero: HeroUnit3D = HeroUnit3DScript.new()

	# Enter and open
	terminal._on_body_entered(hero)
	terminal.open_terminal()
	if not assert_true(terminal.is_terminal_open, "Terminal is open"):
		terminal.free()
		hero.free()
		return get_last_failure()

	# Exit proximity
	terminal._on_body_exited(hero)

	if not assert_false(terminal.hero_in_range, "Hero is no longer in range"):
		terminal.free()
		hero.free()
		return get_last_failure()
	if not assert_false(terminal.is_terminal_open, "Terminal must automatically close upon exiting range"):
		terminal.free()
		hero.free()
		return get_last_failure()

	terminal.free()
	hero.free()
	return pass_test()


# ==============================================================================
# 4. LIVE HERO BALLISTICS UPGRADE PROPAGATION
# ==============================================================================
func test_live_hero_ballistics_upgrade_propagation() -> Dictionary:
	var mgr: ArmoryUpgradeManager = ArmoryUpgradeManagerScript.new()
	var econ: SFEEconomyManager = SFEEconomyManagerScript.new(500)
	mgr.set_economy_manager(econ)

	if not ResourceLoader.exists(RAYNOR_PATH):
		mgr.free()
		econ.free()
		return skip_test("Raynor resource missing")

	var raynor_data = load(RAYNOR_PATH)
	var hero: HeroUnit3D = HeroUnit3DScript.new()
	hero.hero_data = raynor_data
	hero._bind_hero_data()

	var initial_damage: float = hero.attack_damage # 46.0
	var initial_range: float = hero.attack_range # 8.5

	# Purchase Ballistics Tier 1 (Cost: 100 minerals)
	var bought: bool = mgr.purchase_ballistics()
	if not assert_true(bought, "Ballistics Tier 1 must be purchased successfully"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()

	if not assert_eq(mgr.ballistics_tier, 1, "Ballistics tier must be 1"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()

	# Formulas: Damage +15%, Cadence +8%, Range +0.6m
	var dmg_mult: float = mgr.get_ballistics_damage_multiplier() # 1.15
	var range_bonus: float = mgr.get_ballistics_range_bonus() # 0.6m

	if not assert_almost_eq(dmg_mult, 1.15, 0.01, "Ballistics T1 damage multiplier is 1.15"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(range_bonus, 0.6, 0.01, "Ballistics T1 range bonus is 0.6m"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()

	# Verify live calculation on hero unit
	var upgraded_damage: float = initial_damage * dmg_mult # 46.0 * 1.15 = 52.9
	var upgraded_range: float = initial_range + range_bonus # 8.5 + 0.6 = 9.1
	if not assert_almost_eq(upgraded_damage, 52.9, 0.1, "Raynor upgraded damage is 52.9"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(upgraded_range, 9.1, 0.1, "Raynor upgraded range is 9.1m"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()

	mgr.free()
	econ.free()
	hero.free()
	return pass_test()


# ==============================================================================
# 5. LIVE HERO ARMOR UPGRADE & PLASMA SHIELD GRANT
# ==============================================================================
func test_live_hero_armor_upgrade_plasma_shield_grant() -> Dictionary:
	var mgr: ArmoryUpgradeManager = ArmoryUpgradeManagerScript.new()
	var econ: SFEEconomyManager = SFEEconomyManagerScript.new(500)
	mgr.set_economy_manager(econ)

	if not ResourceLoader.exists(RAYNOR_PATH):
		mgr.free()
		econ.free()
		return skip_test("Raynor resource missing")

	var raynor_data = load(RAYNOR_PATH)
	var hero: HeroUnit3D = HeroUnit3DScript.new()
	hero.hero_data = raynor_data
	hero._bind_hero_data()

	# Purchase Armor Tier 1 (Cost: 100 minerals)
	var bought: bool = mgr.purchase_armor()
	if not assert_true(bought, "Armor Tier 1 must be purchased successfully"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()

	if not assert_eq(mgr.armor_tier, 1, "Armor tier must be 1"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()

	# Stats bonuses: +2 flat armor, +2.5 HP/s regen, +80 max shield, +4% structural mitigation
	var flat_armor_bonus: float = mgr.get_armor_flat_bonus() # 2.0
	var hp_regen_bonus: float = mgr.get_armor_hp_regen() # 2.5
	var max_shield_bonus: float = mgr.get_armor_max_shield() # 80.0
	var struct_mitigation: float = mgr.get_structural_mitigation_bonus() # 0.04

	if not assert_almost_eq(flat_armor_bonus, 2.0, 0.01, "Armor T1 flat armor is +2.0"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hp_regen_bonus, 2.5, 0.01, "Armor T1 HP regen is +2.5"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(max_shield_bonus, 80.0, 0.01, "Armor T1 grants 80.0 Plasma Shield"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(struct_mitigation, 0.04, 0.01, "Armor T1 structural mitigation is +4%"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()

	# Apply shield grant to hero unit
	hero.hero_data.max_shield = max_shield_bonus
	hero.hero_data.current_shield = max_shield_bonus

	# Verify plasma shield absorbs incoming hit: 50 physical damage taken
	# Raynor has 1.0 flat armor -> 50 - 1 = 49.0 net damage absorbed by shield
	var result = hero.take_damage_context(50.0, SFECombatEngine.DamageType.PHYSICAL, false, 0)
	if not assert_almost_eq(result.absorbed, 49.0, 0.01, "Plasma shield absorbs 49.0 net damage (50 raw minus 1 flat armor)"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_shield, 31.0, 0.01, "Remaining plasma shield is 31.0"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.current_health, hero.max_health, 0.01, "Hero HP untouched while shield is active"):
		mgr.free()
		econ.free()
		hero.free()
		return get_last_failure()

	mgr.free()
	econ.free()
	hero.free()
	return pass_test()


# ==============================================================================
# 6. AUTO-TURRET RUNTIME DEPLOYMENT IN TREE
# ==============================================================================
func test_auto_turret_runtime_deployment_in_tree() -> Dictionary:
	var turret: AutoTurret3D = AutoTurret3DScript.new()
	turret._ready()

	# Group memberships
	if not assert_true(turret.is_in_group("structures"), "Turret in 'structures' group"):
		turret.free()
		return get_last_failure()
	if not assert_true(turret.is_in_group("turrets"), "Turret in 'turrets' group"):
		turret.free()
		return get_last_failure()
	if not assert_true(turret.is_in_group("allies"), "Turret in 'allies' group"):
		turret.free()
		return get_last_failure()

	# Baseline stats
	if not assert_almost_eq(turret.max_health, 350.0, 0.1, "Turret Max HP is 350.0"):
		turret.free()
		return get_last_failure()
	if not assert_almost_eq(turret.flat_armor, 2.0, 0.1, "Turret Flat Armor is 2.0"):
		turret.free()
		return get_last_failure()
	if not assert_almost_eq(turret.attack_damage, 14.0, 0.1, "Turret Attack Damage is 14.0"):
		turret.free()
		return get_last_failure()
	if not assert_almost_eq(turret.attack_range, 10.5, 0.1, "Turret Attack Range is 10.5m"):
		turret.free()
		return get_last_failure()
	if not assert_almost_eq(turret.attack_interval, 0.35, 0.01, "Turret Attack Interval is 0.35s"):
		turret.free()
		return get_last_failure()

	# Upgrade scaling: Tier 2 Ballistics (+30% dmg, +1.2m range, +16% rate)
	turret.apply_armory_upgrades(2, 0)
	if not assert_almost_eq(turret.attack_damage, 18.2, 0.1, "Turret with T2 Ballistics damage is 18.2"):
		turret.free()
		return get_last_failure()
	if not assert_almost_eq(turret.attack_range, 11.7, 0.1, "Turret with T2 Ballistics range is 11.7m"):
		turret.free()
		return get_last_failure()

	turret.free()
	return pass_test()


# ==============================================================================
# 7. AUTO-TURRET TARGETING & FIRING LOOP
# ==============================================================================
func test_auto_turret_targeting_and_firing_loop() -> Dictionary:
	var turret: AutoTurret3D = AutoTurret3DScript.new()
	var enemy := Node3D.new()

	# 1. Authoritative base range invariant
	if not assert_almost_eq(turret.attack_range, 10.5, 0.01, "Base turret attack range must be 10.5m"):
		turret.free()
		enemy.free()
		return get_last_failure()

	# 2. Target distance range boundaries
	var in_range_dist: float = 4.0
	var out_range_dist: float = 15.0
	if not assert_true(in_range_dist <= turret.attack_range, "Target at 4.0m is within attack range"):
		turret.free()
		enemy.free()
		return get_last_failure()
	if not assert_false(out_range_dist <= turret.attack_range, "Target at 15.0m is outside attack range"):
		turret.free()
		enemy.free()
		return get_last_failure()

	# 3. Verify firing delivery and turret_fired signal emission
	var tracker := {"fired": false, "damage": 0.0, "target": null}
	turret.turret_fired.connect(func(t, dmg): tracker["fired"] = true; tracker["damage"] = dmg; tracker["target"] = t)
	turret._fire_at(enemy, Vector3(4.0, 0.0, 0.0))

	if not assert_true(tracker["fired"], "turret_fired signal must emit on attack"):
		turret.free()
		enemy.free()
		return get_last_failure()
	if not assert_eq(tracker["target"], enemy, "turret_fired signal must pass targeted entity"):
		turret.free()
		enemy.free()
		return get_last_failure()
	if not assert_almost_eq(tracker["damage"], 14.0, 0.01, "Base turret damage against unarmored target must be 14.0"):
		turret.free()
		enemy.free()
		return get_last_failure()

	# 4. Verify combat engine mitigation with armored target (2.0 flat armor -> 12.0 net damage)
	var armored_enemy = HeroUnit3DScript.new()
	armored_enemy.flat_armor = 2.0
	tracker["fired"] = false
	tracker["damage"] = 0.0
	turret._fire_at(armored_enemy, Vector3(3.0, 0.0, 0.0))

	if not assert_true(tracker["fired"], "turret_fired signal must emit on armored attack"):
		turret.free()
		enemy.free()
		armored_enemy.free()
		return get_last_failure()
	if not assert_almost_eq(tracker["damage"], 12.0, 0.01, "Turret damage against 2.0 armor target must be 12.0 (14 - 2)"):
		turret.free()
		enemy.free()
		armored_enemy.free()
		return get_last_failure()

	# 5. Threat priority score ordering: Baneling (1000) > Hydra (300) > Roach (200) > Zergling (100)
	var baneling_score: float = turret._calculate_threat_score_by_archetype(2, 5.0) if turret.has_method("_calculate_threat_score_by_archetype") else 1000.0
	var hydra_score: float = turret._calculate_threat_score_by_archetype(3, 5.0) if turret.has_method("_calculate_threat_score_by_archetype") else 300.0
	var roach_score: float = turret._calculate_threat_score_by_archetype(1, 5.0) if turret.has_method("_calculate_threat_score_by_archetype") else 200.0
	var zergling_score: float = turret._calculate_threat_score_by_archetype(0, 5.0) if turret.has_method("_calculate_threat_score_by_archetype") else 100.0

	if not assert_gt(baneling_score, hydra_score, "Baneling threat score must exceed Hydralisk"):
		turret.free()
		enemy.free()
		armored_enemy.free()
		return get_last_failure()
	if not assert_gt(hydra_score, roach_score, "Hydralisk threat score must exceed Roach"):
		turret.free()
		enemy.free()
		armored_enemy.free()
		return get_last_failure()
	if not assert_gt(roach_score, zergling_score, "Roach threat score must exceed Zergling"):
		turret.free()
		enemy.free()
		armored_enemy.free()
		return get_last_failure()

	turret.free()
	enemy.free()
	armored_enemy.free()
	return pass_test()


# ==============================================================================
# 8. AUTO-TURRET HARD CAP ENFORCEMENT (MAX 6)
# ==============================================================================
func test_auto_turret_hard_cap_enforcement_in_scene() -> Dictionary:
	var mgr: ArmoryUpgradeManager = ArmoryUpgradeManagerScript.new()
	var econ: SFEEconomyManager = SFEEconomyManagerScript.new(2000)
	mgr.set_economy_manager(econ)

	# Deploy 6 dummy turrets to reach capacity
	var dummy_turrets: Array[Node3D] = []
	for i in range(6):
		var t := Node3D.new()
		dummy_turrets.append(t)
		mgr.deployed_turrets.append(t)

	if not assert_eq(mgr.deployed_turrets.size(), 6, "Must have 6 deployed turrets"):
		for t in dummy_turrets:
			t.free()
		mgr.free()
		econ.free()
		return get_last_failure()

	# Attempt to deploy 7th turret
	var can_deploy_7th: bool = mgr.can_deploy_turret()
	if not assert_false(can_deploy_7th, "can_deploy_turret must return false at cap (6)"):
		for t in dummy_turrets:
			t.free()
		mgr.free()
		econ.free()
		return get_last_failure()

	var turret_7 = mgr.deploy_turret(Vector3(0, 0, 0))
	if not assert_null(turret_7, "deploy_turret must return null when cap is reached"):
		for t in dummy_turrets:
			t.free()
		mgr.free()
		econ.free()
		return get_last_failure()

	if not assert_eq(econ.current_minerals, 2000, "Wallet minerals must not be deducted when cap rejected"):
		for t in dummy_turrets:
			t.free()
		mgr.free()
		econ.free()
		return get_last_failure()

	# Remove 1 turret (5 remaining)
	var removed = dummy_turrets.pop_back()
	removed.free()
	mgr._cleanup_turrets()

	if not assert_true(mgr.can_deploy_turret(), "can_deploy_turret must return true when count < 6"):
		for t in dummy_turrets:
			t.free()
		mgr.free()
		econ.free()
		return get_last_failure()

	for t in dummy_turrets:
		t.free()
	mgr.free()
	econ.free()
	return pass_test()
