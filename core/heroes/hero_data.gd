class_name HeroData
extends Resource

## HeroData - Core RPG Data Model for SFE5 Heroes.
## Manages base stats, RPG attributes (Strength, Dexterity, Intelligence), XP progression,
## unspent attribute points, and real-time recalculation of derived combat stats.

const HeroAttributeCalculator = preload("res://core/heroes/hero_attribute_calculator.gd")

signal derived_stats_updated(stats: Dictionary)
signal attributes_changed(str_val: int, dex_val: int, int_val: int, unspent: int)
signal level_up(new_level: int)
signal xp_changed(curr_xp: int, next_xp: int)

# Identity & Archetype Metadata
@export var archetype_id: StringName = &"marine"
@export var hero_name: String = "Marine Commander"
@export var role_description: String = "Ranged DPS & Tactical Infantry"
@export var is_secret: bool = false
@export var icon_path: String = ""

# Base Statistics (Pre-Attribute Modifiers)
@export var base_hp: float = 550.0
@export var base_damage: float = 28.0
@export var base_cooldown: float = 0.8
@export var base_hp_regen: float = 1.0
@export var base_energy: float = 120.0
@export var base_energy_regen: float = 1.2
@export var base_vision: float = 14.0
@export var base_shield: float = 0.0
@export var base_shield_regen: float = 0.0
@export var move_speed: float = 5.2
@export var attack_range: float = 8.5
@export var flat_armor: float = 1.0

# RPG Attributes
@export var strength: int = 10
@export var dexterity: int = 10
@export var intelligence: int = 10
@export var endurance: int = 10
@export var attribute_points: int = 0

# Progression & Leveling
@export var xp_level: int = 1
@export var max_level: int = 20
@export var current_xp: int = 0
@export var xp_for_next_level: int = 150
@export var growth_strength: int = 2
@export var growth_dexterity: int = 2
@export var growth_intelligence: int = 2
@export var growth_endurance: int = 2

# Skills Array
@export var skills: Array[Resource] = []

# Cached Derived Stats (Calculated in real time without rounding drift)
var max_hp: float = 550.0
var current_hp: float = 550.0
var max_shield: float = 0.0
var current_shield: float = 0.0
var max_energy: float = 120.0
var current_energy: float = 120.0

var weapon_damage: float = 28.0
var attack_cooldown: float = 0.8
var hp_regen: float = 1.0
var shield_regen: float = 0.0
var energy_regen: float = 1.2
var vision_radius: float = 14.0
var effective_armor: float = 1.0

func _init() -> void:
	recalculate_derived_stats(true)

## Recalculates all derived stats in real time using exact specification formulas.
## When full_refill is false (e.g. attribute allocation mid-combat), HP and Energy capacity
## expansions preserve current values and health deltas without percentage drift.
func recalculate_derived_stats(full_refill: bool = false) -> void:
	var old_max_hp: float = max_hp
	var old_max_energy: float = max_energy

	# Derived calculations from HeroAttributeCalculator formulas:
	# Max HP: base_hp + (strength * 20.0)
	# Weapon Damage: base_damage + (strength * 1.5)
	# Attack Cooldown: base_cooldown / (1.0 + (dexterity * 0.01))
	# HP Regen: base_regen + (dexterity * 0.15)
	# Max Energy: base_energy + (intelligence * 10.0)
	# Energy Regen: base_energy_regen + (intelligence * 0.08)
	# Vision Radius: base_vision + (intelligence * 0.2)
	max_hp = HeroAttributeCalculator.calculate_max_hp(base_hp, strength)
	weapon_damage = HeroAttributeCalculator.calculate_weapon_damage(base_damage, strength)
	attack_cooldown = HeroAttributeCalculator.calculate_attack_cooldown(base_cooldown, dexterity)
	hp_regen = HeroAttributeCalculator.calculate_hp_regen(base_hp_regen, dexterity)
	max_energy = HeroAttributeCalculator.calculate_max_energy(base_energy, intelligence)
	energy_regen = HeroAttributeCalculator.calculate_energy_regen(base_energy_regen, intelligence)
	vision_radius = HeroAttributeCalculator.calculate_vision_radius(base_vision, intelligence)

	max_shield = base_shield
	shield_regen = base_shield_regen
	effective_armor = flat_armor

	if full_refill:
		current_hp = max_hp
		current_energy = max_energy
		current_shield = max_shield
	else:
		var hp_delta: float = max_hp - old_max_hp
		if hp_delta > 0.0:
			current_hp = clampf(current_hp + hp_delta, 1.0, max_hp)
		else:
			current_hp = clampf(current_hp, 1.0, max_hp)

		var energy_delta: float = max_energy - old_max_energy
		if energy_delta > 0.0:
			current_energy = clampf(current_energy + energy_delta, 0.0, max_energy)
		else:
			current_energy = clampf(current_energy, 0.0, max_energy)

	var stats: Dictionary = get_derived_stats()
	derived_stats_updated.emit(stats)

func get_derived_stats() -> Dictionary:
	return {
		"max_hp": max_hp,
		"current_hp": current_hp,
		"max_shield": max_shield,
		"current_shield": current_shield,
		"max_energy": max_energy,
		"current_energy": current_energy,
		"weapon_damage": weapon_damage,
		"attack_cooldown": attack_cooldown,
		"hp_regen": hp_regen,
		"shield_regen": shield_regen,
		"energy_regen": energy_regen,
		"vision_radius": vision_radius,
		"effective_armor": effective_armor
	}

## Allocates unspent attribute points to Strength, Dexterity, or Intelligence.
func allocate_attribute(attribute_name: String, amount: int = 1) -> bool:
	if amount <= 0 or attribute_points < amount:
		return false

	var attr_lower: String = attribute_name.to_lower().strip_edges()
	match attr_lower:
		"strength", "str":
			strength += amount
		"dexterity", "dex":
			dexterity += amount
		"intelligence", "int":
			intelligence += amount
		"endurance", "end":
			endurance += amount
		_:
			return false

	attribute_points -= amount
	recalculate_derived_stats(false)
	attributes_changed.emit(strength, dexterity, intelligence, attribute_points)
	return true

## Adds experience points and performs level-up calculations when threshold is met.
func add_experience(amount: int) -> bool:
	if amount <= 0 or xp_level >= max_level:
		return false

	current_xp += amount
	var leveled: bool = false

	while xp_level < max_level and current_xp >= xp_for_next_level:
		current_xp -= xp_for_next_level
		xp_level += 1
		leveled = true

		# Reward 3 unspent attribute points per level
		attribute_points += 3

		# Apply archetype passive growth
		strength += growth_strength
		dexterity += growth_dexterity
		intelligence += growth_intelligence
		endurance += growth_endurance

		xp_for_next_level = _calculate_xp_requirement(xp_level + 1)
		recalculate_derived_stats(false)
		level_up.emit(xp_level)
		attributes_changed.emit(strength, dexterity, intelligence, attribute_points)

	xp_changed.emit(current_xp, xp_for_next_level)
	return leveled

func _calculate_xp_requirement(target_level: int) -> int:
	return int(round(100.0 * pow(float(target_level), 1.5) + float(target_level * 50)))

## Creates an isolated runtime duplicate so mutations mid-match do not overwrite shared .tres resources.
func duplicate_for_instance() -> Resource:
	var script_class: GDScript = get_script() as GDScript
	var copy = script_class.new()
	copy.archetype_id = archetype_id
	copy.hero_name = hero_name
	copy.role_description = role_description
	copy.is_secret = is_secret
	copy.icon_path = icon_path

	copy.base_hp = base_hp
	copy.base_damage = base_damage
	copy.base_cooldown = base_cooldown
	copy.base_hp_regen = base_hp_regen
	copy.base_energy = base_energy
	copy.base_energy_regen = base_energy_regen
	copy.base_vision = base_vision
	copy.base_shield = base_shield
	copy.base_shield_regen = base_shield_regen
	copy.move_speed = move_speed
	copy.attack_range = attack_range
	copy.flat_armor = flat_armor

	copy.strength = strength
	copy.dexterity = dexterity
	copy.intelligence = intelligence
	copy.attribute_points = attribute_points

	copy.xp_level = xp_level
	copy.max_level = max_level
	copy.current_xp = current_xp
	copy.xp_for_next_level = xp_for_next_level
	copy.growth_strength = growth_strength
	copy.growth_dexterity = growth_dexterity
	copy.growth_intelligence = growth_intelligence

	var cloned_skills: Array[Resource] = []
	for s in skills:
		cloned_skills.append(s)
	copy.skills = cloned_skills

	copy.recalculate_derived_stats(true)
	return copy
