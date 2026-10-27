extends "res://tests/test_base.gd"

## TestSFE5SprintC - Comprehensive unit suite for Sprint C:
## 1. PedestalNode independent materials, status labels, and hint flashes.
## 2. Pinnacle Boss Altars (Odin, Gorgon, Kerrigan) and BossRewardManager.
## 3. FuelingStation3D (+4000 minerals and ach_fueling_up).
## 4. Tactical Teleport Network & Command Card [T] Recall a Base.
## 5. Active Buff Badges in SC2StatPanel.

const PedestalNode = preload("res://levels/pedestal_node.gd")
const PinnacleBossCatalog = preload("res://core/bosses/pinnacle_boss_catalog.gd")
const BossRewardManager = preload("res://core/bosses/boss_reward_manager.gd")
const AchievementSystem = preload("res://core/meta/achievement_system.gd")
const SecretManager = preload("res://core/events/secret_manager.gd")
const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const SC2StatPanel = preload("res://ui/sc2_stat_panel.gd")
const SC2HUDRoot = preload("res://ui/sc2_hud_root.gd")
const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")
const HeroSelector = preload("res://core/heroes/hero_selector.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")


## 1. Test PedestalNode Visuals, Materials & Hint Flashing
func test_pedestal_visuals_independent_materials_and_hints() -> Dictionary:
	var ped := PedestalNode.new()
	ped.pedestal_id = 3
	ped.is_active = false

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "VisualMesh"
	var cyl := CylinderMesh.new()
	mesh_inst.mesh = cyl
	ped.add_child(mesh_inst)

	ped._ready()

	if not assert_not_null(ped.visual_mesh, "VisualMesh found"):
		return get_last_failure()
	if not assert_true(ped.visual_mesh.material_override is StandardMaterial3D, "Material override is StandardMaterial3D"):
		return get_last_failure()
	if not assert_not_null(ped.status_label, "StatusLabel created"):
		return get_last_failure()
	if not assert_true(ped.status_label.text.contains("[3] OFF"), "Initial label shows [3] OFF"):
		return get_last_failure()

	# Test activation
	ped.set_active_state(true)
	if not assert_true(ped.status_label.text.contains("[3] ON"), "Active label shows [3] ON"):
		return get_last_failure()
	var mat: StandardMaterial3D = ped.visual_mesh.material_override as StandardMaterial3D
	if not assert_true(mat.emission_enabled, "Active pedestal has emission enabled"):
		return get_last_failure()

	# Test hint flash
	ped.flash_hint(1.5)
	if not assert_true(ped.status_label.text.contains("PISTA"), "Hint flash updates label to PISTA"):
		return get_last_failure()

	ped.free()
	return pass_test()


## 2. Test Pinnacle Boss Altars & BossRewardManager
func test_pinnacle_boss_altars_and_reward_manager() -> Dictionary:
	# Verify Odin
	var odin_info := PinnacleBossCatalog.get_boss_info(&"odin")
	if not assert_ge(odin_info.get("hp", 0.0), 16000.0, "Odin HP >= 16000"):
		return get_last_failure()
	if not assert_eq(odin_info.get("secret_unit"), &"thor_ace", "Odin unlocks Thor Ace"):
		return get_last_failure()

	# Verify Gorgon
	var gorgon_info := PinnacleBossCatalog.get_boss_info(&"gorgon")
	if not assert_ge(gorgon_info.get("hp", 0.0), 14000.0, "Gorgon HP >= 14000"):
		return get_last_failure()
	if not assert_eq(gorgon_info.get("secret_unit"), &"battlecruiser_ace", "Gorgon unlocks Battlecruiser Ace"):
		return get_last_failure()

	# Verify Celestial Kerrigan
	var kerr_info := PinnacleBossCatalog.get_boss_info(&"celestial_kerrigan")
	if not assert_ge(kerr_info.get("hp", 0.0), 28000.0, "Celestial Kerrigan HP >= 28000"):
		return get_last_failure()
	if not assert_eq(kerr_info.get("secret_unit"), &"leviathan_ace", "Kerrigan unlocks Leviathan Ace"):
		return get_last_failure()

	# Test victory reward processing
	var eco := SFEEconomyManager.new(10000)
	var res := BossRewardManager.process_pinnacle_victory(&"odin", eco, 1, &"thor_ace")
	if not assert_eq(res.get("minerals", 0), 100000, "Awards 100k minerals"):
		return get_last_failure()
	if not assert_eq(res.get("rank_points", 0), 300, "Awards 300 rank points"):
		return get_last_failure()
	if not assert_ge(eco.current_minerals, 110000, "Minerals deposited into economy"):
		return get_last_failure()

	# Test achievements exist in catalog
	if not assert_true(AchievementSystem.ACHIEVEMENTS.has(&"ach_odin_slayer"), "ach_odin_slayer in catalog"):
		return get_last_failure()
	if not assert_true(AchievementSystem.ACHIEVEMENTS.has(&"ach_gorgon_slayer"), "ach_gorgon_slayer in catalog"):
		return get_last_failure()
	if not assert_true(AchievementSystem.ACHIEVEMENTS.has(&"ach_kerrigan_slayer"), "ach_kerrigan_slayer in catalog"):
		return get_last_failure()

	return pass_test()


## 3. Test FuelingStation3D Event & Achievement
func test_fueling_station_event_and_achievement() -> Dictionary:
	var sm := SecretManager.new(55555)
	if not assert_false(sm.fueling_completed, "Initially fueling incomplete"):
		return get_last_failure()

	var reward := sm.complete_fueling_station()
	if not assert_eq(reward, 4000, "Fueling station awards 4000 minerals"):
		return get_last_failure()
	if not assert_true(sm.fueling_completed, "Marked completed in SecretManager"):
		return get_last_failure()

	if not assert_true(AchievementSystem.ACHIEVEMENTS.has(&"ach_fueling_up"), "ach_fueling_up exists in AchievementSystem"):
		return get_last_failure()

	return pass_test()


## 4. Test Tactical Teleport Network & Command Card [T] Recall
func test_tactical_teleport_network_and_command_card_recall() -> Dictionary:
	var card := SC2CommandCard.new()
	card._ready()

	var hero := HeroUnit3D.new()
	hero.hero_data = HeroSelector.select_hero_manual(&"raynor")
	hero._ensure_components()
	hero._bind_hero_data()

	card.populate_for_unit(hero)

	# Verify Slot 4 has Recall [T]
	var btn: Button = card.slot_buttons[4]
	if not assert_true(btn.text.contains("[T]"), "Slot 4 contains hotkey [T]"):
		return get_last_failure()
	if not assert_true(btn.text.contains("Recall"), "Slot 4 button text contains Recall"):
		return get_last_failure()
	if not assert_false(btn.disabled, "Slot 4 button is initially enabled"):
		return get_last_failure()

	# Simulate pressing slot 4
	var recall_state := {"emitted": false}
	card.command_triggered.connect(func(cmd: String, _payload: Variant):
		if cmd == "recall_base":
			recall_state["emitted"] = true
	)

	card.activate_skill_by_slot(4)
	if not assert_true(recall_state["emitted"], "recall_base signal emitted when slot 4 pressed"):
		return get_last_failure()
	if not assert_ge(card.recall_cooldown, 29.0, "Recall cooldown set to 30s"):
		return get_last_failure()

	# Button should be disabled during cooldown
	card._process(0.1)
	if not assert_true(btn.disabled, "Button disabled while on cooldown"):
		return get_last_failure()

	# Verify SC2HUDRoot has recall signal
	var hud := SC2HUDRoot.new()
	if not assert_true(hud.has_signal("recall_base_requested"), "SC2HUDRoot exposes recall_base_requested signal"):
		return get_last_failure()

	hud.free()
	hero.free()
	card.free()
	return pass_test()


## 5. Test Active Buff Badges in SC2StatPanel
func test_active_buff_badges_formatting_in_stat_panel() -> Dictionary:
	var panel := SC2StatPanel.new()
	panel._ready()

	var hero := HeroUnit3D.new()
	hero.hero_data = HeroSelector.select_hero_manual(&"raynor")
	hero._ensure_components()
	hero._bind_hero_data()

	var bc = hero.buff_component
	bc.equip_tier_buff(2, "predator", "Predator", 1000)
	bc.is_camouflaged = true
	bc.momentum_stacks = 3
	bc.static_charge_stacks = 8
	bc.bulwark_stacks = 5
	bc.is_ace_active = true
	bc.supreme_buffs["demiurge"] = true
	bc.demiurge_cooldown_timer = 0.0

	panel.bind_unit(hero)
	panel.refresh_display()

	var badges := panel.get_active_buff_texts()
	if not assert_ge(badges.size(), 7, "At least 7 active buff badges rendered"):
		return get_last_failure()

	var joined := " | ".join(badges)
	if not assert_true(joined.contains("Optical Lens [Camuflado]"), "Has Optical Lens [Camuflado] badge"):
		return get_last_failure()
	if not assert_true(joined.contains("Momentum [x3]"), "Has Momentum [x3] badge"):
		return get_last_failure()
	if not assert_true(joined.contains("Predator"), "Has Predator badge"):
		return get_last_failure()
	if not assert_true(joined.contains("Static Charge [x8]"), "Has Static Charge [x8] badge"):
		return get_last_failure()
	if not assert_true(joined.contains("Bulwark [x5]"), "Has Bulwark [x5] badge"):
		return get_last_failure()
	if not assert_true(joined.contains("★ ACE"), "Has ★ ACE badge"):
		return get_last_failure()
	if not assert_true(joined.contains("★ DEMIURGE [Listo]"), "Has ★ DEMIURGE [Listo] badge"):
		return get_last_failure()

	panel.free()
	hero.free()
	return pass_test()
