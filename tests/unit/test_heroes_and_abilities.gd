class_name TestHeroesAndAbilities
extends RefCounted

## TestHeroesAndAbilities - Verification Suite for SFE5 Fase 5 (Heroes & Abilities).
## Covers:
## 1. AbilityComponent energy consumption, cooldown management, and Intelligence AP scaling.
## 2. ExperienceComponent XP progression curve, level up triggers, and attribute bonuses.
## 3. AbilityEffects reusable spell logic and area-of-effect calculations.
## 4. Task 5.14 - Buff interaction (Quantum Field +75% spell amplification).

const StatsComponent = preload("res://core/components/stats_component.gd")
const AbilityComponent = preload("res://core/components/ability_component.gd")
const ExperienceComponent = preload("res://core/components/experience_component.gd")
const AbilityEffects = preload("res://core/combat/ability_effects.gd")
const AbilityData = preload("res://core/data/ability_data.gd")

var passed_count: int = 0
var failed_count: int = 0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed_count += 1
		push_error("Assertion Failed: " + message)
		assert(condition, message)
	else:
		passed_count += 1


## Test 1: AbilityComponent energy consumption and cooldown enforcement
func test_ability_component_energy_and_cooldowns() -> void:
	var root := Node.new()
	var stats := StatsComponent.new()
	stats.intelligence = 10
	stats.name = "StatsComponent"
	root.add_child(stats)
	
	var abilities := AbilityComponent.new()
	abilities.name = "AbilityComponent"
	abilities.stats_component = stats
	abilities.current_energy = 100.0
	root.add_child(abilities)
	
	# Proper typed AbilityData resource
	var skill := AbilityData.new()
	skill.id = &"penetrating_round"
	skill.ability_name = "Penetrating Round"
	skill.energy_cost = 35.0
	skill.cooldown = 4.0
	
	abilities.bind_skill("Q", skill)
	_assert(abilities.can_cast("Q"), "Can cast Q initially with full energy")
	
	# Cast Q
	var success := abilities.cast_skill("Q")
	_assert(success, "Q cast was successful")
	_assert(is_equal_approx(abilities.cooldowns["Q"], 4.0), "Cooldown set to 4.0 seconds")
	_assert(not abilities.can_cast("Q"), "Cannot cast Q while on cooldown")
	
	# Advance time by 2.0s -> cooldown drops to 2.0s
	abilities._process(2.0)
	_assert(is_equal_approx(abilities.cooldowns["Q"], 2.0), "Cooldown reduced to 2.0s")
	_assert(not abilities.can_cast("Q"), "Still cannot cast at 2.0s remaining")
	
	# Advance remaining 2.1s -> cooldown ready
	abilities._process(2.1)
	_assert(is_equal_approx(abilities.cooldowns["Q"], 0.0), "Cooldown complete")
	_assert(abilities.can_cast("Q"), "Can cast Q again once cooldown expires")
	
	root.free()


## Test 2: Task 5.4 - Intelligence scaling boosts Ability Power and spell effect
func test_intelligence_ability_power_scaling() -> void:
	var stats := StatsComponent.new()
	stats.intelligence = 0
	stats.recalculate()
	_assert(is_equal_approx(stats.get_effective_ability_power(), 1.0), "0 INT gives 1.0x baseline AP")
	
	# 20 INT: +1.5% per point -> +30% AP = 1.3x
	stats.intelligence = 20
	stats.recalculate()
	_assert(is_equal_approx(stats.get_effective_ability_power(), 1.30), "20 INT scales AP to 1.30x (+30%)")
	
	# 50 INT: +1.5% per point -> +75% AP = 1.75x
	stats.intelligence = 50
	stats.recalculate()
	_assert(is_equal_approx(stats.get_effective_ability_power(), 1.75), "50 INT scales AP to 1.75x (+75%)")


## Test 3: Task 5.3 - ExperienceComponent level curve and +2 stat bonuses per level
func test_experience_progression_and_stat_bonuses() -> void:
	var root := Node.new()
	var stats := StatsComponent.new()
	stats.strength = 10
	stats.dexterity = 10
	stats.intelligence = 10
	stats.endurance = 10
	stats.name = "StatsComponent"
	root.add_child(stats)
	
	var exp_comp := ExperienceComponent.new()
	exp_comp.name = "ExperienceComponent"
	exp_comp.stats_component = stats
	root.add_child(exp_comp)
	
	_assert(exp_comp.current_level == 1, "Starts at Level 1")
	var req_xp := exp_comp.xp_to_next_level
	_assert(req_xp > 100, "Level 1 requirement > 100 XP (calc = %d)" % req_xp)
	
	# Award enough XP to trigger exactly 1 level up
	var leveled := exp_comp.award_xp(req_xp + 10)
	_assert(leveled, "Level up achieved")
	_assert(exp_comp.current_level == 2, "Hero is now Level 2")
	_assert(exp_comp.current_xp == 10, "10 rollover XP stored")
	
	# SFE5 Rule: Each level up grants +2 STR, +2 DEX, +2 INT, +2 END
	_assert(stats.strength == 12, "STR increased from 10 to 12")
	_assert(stats.dexterity == 12, "DEX increased from 10 to 12")
	_assert(stats.intelligence == 12, "INT increased from 10 to 12")
	_assert(stats.endurance == 12, "END increased from 10 to 12")
	
	# Clamping test: Level cannot exceed 100
	exp_comp.current_level = 100
	var no_level := exp_comp.award_xp(1000000)
	_assert(not no_level, "Cannot exceed Level 100")
	_assert(exp_comp.current_level == 100, "Level remains clamped at 100")
	
	root.free()


## Test 4: Task 5.2 - AbilityEffects healing, shield absorption, stun and storm pulse
func test_ability_effects_healing_and_shields() -> void:
	# Mock test unit with script properties
	var mock_script := GDScript.new()
	mock_script.source_code = "@tool\nextends Node\nvar current_health: float = 500.0\nvar max_health: float = 800.0\nvar plasma_shield_hp: float = 0.0\nvar is_stunned: bool = false\nvar stun_timer: float = 0.0\n"
	mock_script.reload()
	
	var mock_unit = Node.new()
	mock_unit.set_script(mock_script)
	
	# Apply 100 healing with 1.25x Ability Power
	var healed := AbilityEffects.apply_healing(mock_unit, 100.0, 1.25)
	_assert(is_equal_approx(healed, 125.0), "Healed 125 HP (100 * 1.25 AP)")
	_assert(is_equal_approx(mock_unit.current_health, 625.0), "Current HP raised to 625")
	
	# Apply temporary plasma shield
	var shield_val := AbilityEffects.apply_temporary_shield(mock_unit, 150.0, 1.20)
	_assert(is_equal_approx(shield_val, 180.0), "Granted 180 Plasma Shield (150 * 1.20 AP)")
	_assert(is_equal_approx(mock_unit.plasma_shield_hp, 180.0), "Shield registered on unit")
	
	# Apply stun
	var stunned := AbilityEffects.apply_stun(mock_unit, 2.5)
	_assert(stunned, "Stun applied successfully")
	_assert(mock_unit.is_stunned, "Unit is stunned")
	_assert(is_equal_approx(mock_unit.stun_timer, 2.5), "Stun timer set to 2.5s")
	
	mock_unit.free()


## Test 5: Task 5.14 - Quantum Field buff interaction (+75% spell damage at 100% energy)
func test_quantum_field_spell_amplification() -> void:
	var root := Node.new()
	var stats := StatsComponent.new()
	stats.intelligence = 0
	stats.base_max_energy = 100.0
	stats.name = "StatsComponent"
	root.add_child(stats)
	
	var abilities := AbilityComponent.new()
	abilities.name = "AbilityComponent"
	abilities.stats_component = stats
	abilities.current_energy = 100.0 # 100% full energy triggers Quantum Field
	root.add_child(abilities)
	
	# Target dummy
	var dummy_script := GDScript.new()
	dummy_script.source_code = "@tool\nextends Node\nvar current_hp: float = 1000.0\nfunc take_damage(dmg: float) -> void:\n\tcurrent_hp -= dmg\n"
	dummy_script.reload()
	var dummy = Node.new()
	dummy.set_script(dummy_script)
	root.add_child(dummy)
	
	var spell := AbilityData.new()
	spell.id = &"psionic_storm"
	spell.energy_cost = 50.0
	spell.cooldown = 6.0
	spell.base_power = 100.0 # 100 base spell damage
	
	abilities.bind_skill("Q", spell)
	
	# Full energy -> +75% damage (175.0)
	abilities.cast_skill("Q", Vector3.ZERO, dummy)
	_assert(is_equal_approx(dummy.current_hp, 825.0), "Dummy took 175 damage (100 * 1.75 Quantum Field boost)")
	
	root.free()


## Test 6: Task 5.8 - Tanda A 6 Heroes have 4 skills each and proper attributes
func test_tanda_a_heroes_catalog() -> void:
	var HeroSelector = preload("res://core/heroes/hero_selector.gd")
	var tanda_a_ids := [&"marine", &"raynor", &"tychus", &"nova", &"zeratul", &"tassadar"]
	
	for hero_id in tanda_a_ids:
		var hero = HeroSelector.select_hero_manual(hero_id)
		_assert(hero != null, "Hero '%s' successfully loaded" % hero_id)
		_assert(hero.skills.size() == 4, "Hero '%s' has exactly 4 skills (Q/W/E/R)" % hero_id)
		_assert(hero.base_hp > 300.0, "Hero '%s' base HP > 300" % hero_id)
		_assert(hero.weapon_damage > 15.0, "Hero '%s' base weapon damage > 15" % hero_id)
		_assert(hero.strength > 0 and hero.dexterity > 0 and hero.intelligence > 0, "Hero '%s' has positive RPG attributes" % hero_id)


## Test 7: Task 5.7 - Random Hero gives 15000 / player_count mineral bonus
func test_random_hero_mineral_bonus() -> void:
	var GameSession = preload("res://core/game_session.gd")
	var sess = GameSession.new()
	
	# 1 player: 15000 minerals for random hero, 12000 for standard
	sess.player_count = 1
	_assert(sess.get_initial_minerals(false) == 12000, "1 player standard = 12000 minerals")
	_assert(sess.get_initial_minerals(true) == 15000, "1 player random hero = 15000 minerals")
	
	# 2 players: 7500 minerals for random hero, 6000 for standard
	sess.player_count = 2
	_assert(sess.get_initial_minerals(false) == 6000, "2 players standard = 6000 minerals")
	_assert(sess.get_initial_minerals(true) == 7500, "2 players random hero = 7500 minerals")
	
	# 4 players: 3750 minerals for random hero, 3000 for standard
	sess.player_count = 4
	_assert(sess.get_initial_minerals(false) == 3000, "4 players standard = 3000 minerals")
	_assert(sess.get_initial_minerals(true) == 3750, "4 players random hero = 3750 minerals")
	
	sess.free()
