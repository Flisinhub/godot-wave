extends "res://tests/test_base.gd"

## TestSFE5SprintUnification - Comprehensive verification for Sprint de Unificación Jugable SFE5.
## Verifies:
## 1. Environment ShaderMaterials have zero null shader parameters.
## 2. HeroUnit3D instantiates all 5 components (Stats, Buff, Ability, Experience, Elite) with 4 SFE5 attributes.
## 3. SC2StatPanel displays 4 attributes (STR, DEX, INT, END), effective stats and active buff icons row.
## 4. PlayerConsole racial upgrades (+1, +5, max) and recruitment/elite tab.
## 5. SFEStartModal 6 game modes & 12 hero archetypes catalog + random.
## 6. SC2CommandCard slot 12 [C] Consola and slot 13 [V] Élite shortcuts.

const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const HeroSelector = preload("res://core/heroes/hero_selector.gd")
const StatsComponent = preload("res://core/components/stats_component.gd")
const BuffComponent = preload("res://core/components/buff_component.gd")
const AbilityComponent = preload("res://core/components/ability_component.gd")
const ExperienceComponent = preload("res://core/components/experience_component.gd")
const EliteComponent = preload("res://core/components/elite_component.gd")
const SC2StatPanel = preload("res://ui/sc2_stat_panel.gd")
const PlayerConsole = preload("res://ui/player_console.gd")
const SFEStartModal = preload("res://ui/sfe_start_modal.gd")
const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")


## 1. Test Environment Materials
func test_environment_materials_no_null_parameters() -> Dictionary:
	var paths := [
		"res://assets/materials/environment/char_basalt_ground_pbr.tres",
		"res://assets/materials/environment/lava_fissure_material.tres",
		"res://assets/materials/environment/terran_base_deck_material.tres",
		"res://assets/materials/environment/zerg_creep_material.tres"
	]
	for p in paths:
		if not ResourceLoader.exists(p):
			return fail_test("Environment material missing: " + p)
		var mat = load(p)
		if not (mat is ShaderMaterial):
			return fail_test("Material is not ShaderMaterial: " + p)
		var sm := mat as ShaderMaterial
		if sm.shader == null:
			return fail_test("Shader is null on: " + p)
		var param_list := RenderingServer.get_shader_parameter_list(sm.shader.get_rid())
		for param in param_list:
			var p_name: String = param["name"]
			var val = sm.get_shader_parameter(p_name)
			if val == null:
				return fail_test("Null shader_parameter '%s' in material: %s" % [p_name, p])
	return pass_test()


## 2. Test HeroUnit3D 5 Components and 4 Attributes
func test_hero_unit_5_components_and_4_attributes() -> Dictionary:
	var hero := HeroUnit3D.new()
	var h_data := HeroSelector.select_hero_manual(&"raynor")
	if not assert_not_null(h_data, "Raynor HeroData loaded"):
		return get_last_failure()
	hero.hero_data = h_data
	hero._ensure_components()
	hero._bind_hero_data()

	if not assert_not_null(hero.stats_component, "stats_component created"):
		return get_last_failure()
	if not assert_not_null(hero.buff_component, "buff_component created"):
		return get_last_failure()
	if not assert_not_null(hero.ability_component, "ability_component created"):
		return get_last_failure()
	if not assert_not_null(hero.experience_component, "experience_component created"):
		return get_last_failure()
	if not assert_not_null(hero.elite_component, "elite_component created"):
		return get_last_failure()

	# Check 4 attributes
	if not assert_true(hero.stats_component.strength >= 10, "Strength initialized"):
		return get_last_failure()
	if not assert_true(hero.stats_component.dexterity >= 8, "Dexterity initialized"):
		return get_last_failure()
	if not assert_true(hero.stats_component.intelligence >= 8, "Intelligence initialized"):
		return get_last_failure()
	if not assert_true(hero.stats_component.endurance >= 10, "Endurance initialized"):
		return get_last_failure()

	# Test allocating endurance increases effective armor
	var prev_arm: float = hero.stats_component.get_effective_armor()
	var invested: bool = hero.stats_component.invest_attribute("endurance", 1)
	if not assert_true(invested, "Endurance point invested"):
		return get_last_failure()
	if not assert_true(hero.stats_component.get_effective_armor() > prev_arm, "Armor increased with Endurance"):
		return get_last_failure()

	hero.free()
	return pass_test()


## 3. Test SC2StatPanel 4 Attributes and Buff Icons Row
func test_stat_panel_4_attributes_and_buff_row() -> Dictionary:
	var panel := SC2StatPanel.new()
	panel._ready()

	var hero := HeroUnit3D.new()
	hero.hero_data = HeroSelector.select_hero_manual(&"raynor")
	hero._ensure_components()
	hero._bind_hero_data()
	hero.stats_component.strength = 15
	hero.stats_component.endurance = 14
	hero.buff_component.equip_tier_buff(1, "stimpack", "Estimulante T1", 500)
	hero.buff_component.momentum_stacks = 4
	hero.buff_component.bulwark_stacks = 3

	panel.bind_unit(hero)
	panel.refresh_display()

	if not assert_not_null(panel.end_label, "END label exists in stat panel"):
		return get_last_failure()
	if not assert_true(panel.str_label.text.contains("15"), "STR text updated"):
		return get_last_failure()
	if not assert_true(panel.end_label.text.contains("14"), "END text updated"):
		return get_last_failure()
	if not assert_not_null(panel.active_buffs_container, "active_buffs_container exists"):
		return get_last_failure()
	if not assert_true(panel.active_buffs_container.get_child_count() >= 2, "Active buff icons rendered"):
		return get_last_failure()

	panel.free()
	hero.free()
	return pass_test()


## 4. Test PlayerConsole Racial Upgrades and Recruitment
func test_player_console_racial_and_recruitment() -> Dictionary:
	var console := PlayerConsole.new()
	console._ready()

	var hero := HeroUnit3D.new()
	hero.hero_data = HeroSelector.select_hero_manual(&"raynor")
	hero._ensure_components()
	hero._bind_hero_data()

	var eco := SFEEconomyManager.new(200000)
	console.economy_manager = eco
	console.target_unit = hero
	console.stats_comp = hero.stats_component
	console.elite_comp = hero.elite_component

	if not assert_not_null(console.tab_container, "Console tab_container created"):
		return get_last_failure()
	if not assert_true(console.tab_container.get_tab_count() >= 4, "Console has at least 4 tabs"):
		return get_last_failure()

	# Test purchasing Weapon Damage upgrade
	var prev_min: int = eco.current_minerals
	var prev_dmg: float = hero.stats_component.get_effective_damage()
	console._on_racial_upgrade_clicked("weapon_damage", false, false)
	if not assert_true(eco.current_minerals < prev_min, "Minerals deducted on racial upgrade"):
		return get_last_failure()
	if not assert_true(hero.stats_component.get_effective_damage() > prev_dmg, "Damage increased after upgrade"):
		return get_last_failure()

	# Test veterancy elite promotion
	console._on_buy_veterancy_pressed()
	if not assert_true(hero.elite_component.is_elite, "Elite component marked active"):
		return get_last_failure()

	console.free()
	hero.free()
	eco.free()
	return pass_test()


## 5. Test SFEStartModal 6 Game Modes and 12 Hero Archetypes
func test_start_modal_game_modes_and_12_archetypes() -> Dictionary:
	var modal := SFEStartModal.new()
	if not assert_eq(modal.mode_buttons.size(), 6, "6 game mode buttons created"):
		return get_last_failure()
	if not assert_eq(modal.HEROES_CATALOG.size(), 12, "12 hero archetypes catalog"):
		return get_last_failure()
	if not assert_not_null(modal.random_button, "Random button exists"):
		return get_last_failure()

	modal._update_mode_selection(&"nightmare")
	if not assert_eq(modal.selected_mode_id, &"nightmare", "Selected mode is nightmare"):
		return get_last_failure()

	modal._update_hero_selection(&"tychus", false)
	if not assert_eq(modal.selected_archetype_id, &"tychus", "Selected hero is tychus"):
		return get_last_failure()

	modal.free()
	return pass_test()


## 6. Test SC2CommandCard Shortcuts
func test_command_card_shortcuts() -> Dictionary:
	var card := SC2CommandCard.new()
	var dummy_unit := Node.new()
	card.populate_for_unit(dummy_unit)

	var trigger_events: Array[String] = []
	card.command_triggered.connect(func(cmd: String, _payload = null):
		trigger_events.append(cmd)
	)

	# Trigger slot 12 ([C] Consola)
	card._on_slot_pressed(12)
	if not assert_true(trigger_events.has("open_console"), "Open console triggered from slot 12"):
		return get_last_failure()

	# Trigger slot 13 ([V] Élite)
	card._on_slot_pressed(13)
	if not assert_true(trigger_events.has("open_recruitment"), "Open recruitment triggered from slot 13"):
		return get_last_failure()

	dummy_unit.free()
	card.free()
	return pass_test()


func assert_not_null(val: Variant, msg: String = "Expected not null") -> bool:
	if val == null:
		_last_error = msg
		return false
	return true
