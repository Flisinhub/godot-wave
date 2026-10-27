class_name StatsComponent
extends Node

## StatsComponent - SFE5 Attribute & Progression Component (Tasks 4.1, 4.6, 4.7, 4.10).
## Computes effective vitals and combat stats from:
## Base stats + Attributes (STR/DEX/INT/END) + Racial Upgrades + Neutron Armor.
## Caches values and invalidates upon stat investment.

const GameConfig = preload("res://core/game_config.gd")

# RPG Core Attributes
@export var strength: int = 0      ## Fuerza: Max HP + Physical/Melee Damage
@export var dexterity: int = 0     ## Destreza: Attack Speed + Evasion + Ranged Damage
@export var intelligence: int = 0  ## Inteligencia: Max Energy + Regen + Ability Power
@export var endurance: int = 0     ## Aguante: Armor + HP Regeneration

# Neutron Armor (Task 4.10 - Flat mitigation upgrade)
@export var neutron_armor_level: int = 0

# Base Unit Stats
@export var base_max_hp: float = 790.0
@export var base_shield: float = 0.0
@export var base_damage: float = 46.0
@export var base_attack_period: float = 0.65
@export var base_armor: float = 2.0
@export var base_max_energy: float = 100.0
@export var base_energy_regen: float = 1.0
@export var base_move_speed: float = 5.5

# Racial and External Upgrade Multipliers
var damage_upgrade_mult: float = 1.0
var armor_upgrade_flat: float = 0.0
var hp_upgrade_mult: float = 1.0
var attack_speed_upgrade_mult: float = 1.0

# Cached Effective Values
var _dirty: bool = true
var _cached_max_hp: float = 790.0
var _cached_damage: float = 46.0
var _cached_attack_period: float = 0.65
var _cached_armor: float = 2.0
var _cached_max_energy: float = 100.0
var _cached_energy_regen: float = 1.0
var _cached_ability_power: float = 1.0
var _cached_neutron_mitigation: float = 0.0

signal stats_changed()
signal attribute_invested(attr_name: String, new_val: int, cost: int)


func _ready() -> void:
	recalculate()


func mark_dirty() -> void:
	_dirty = true
	recalculate()


func recalculate() -> void:
	# 1. Fuerza (Strength): +15 HP, +0.8 Damage per point
	var str_hp := float(strength) * GameConfig.STR_HP_BONUS
	var str_dmg := float(strength) * GameConfig.STR_DAMAGE_BONUS

	# 2. Destreza (Dexterity): +1.2% Attack Speed, +0.7 Ranged Damage
	var dex_dmg := float(dexterity) * GameConfig.DEX_RANGED_DAMAGE_BONUS
	var dex_speed_ratio := 1.0 + (float(dexterity) * GameConfig.DEX_ATTACK_SPEED_BONUS * attack_speed_upgrade_mult)

	# 3. Inteligencia (Intelligence): +10 Energy, +0.25 Regen, +1.5% Ability Power
	var int_energy := float(intelligence) * GameConfig.INT_ENERGY_BONUS
	var int_regen := float(intelligence) * GameConfig.INT_ENERGY_REGEN_BONUS
	var int_ap := 1.0 + (float(intelligence) * GameConfig.INT_ABILITY_POWER_BONUS)

	# 4. Aguante (Endurance): +0.12 Armor, +0.35 HP Regen
	var end_armor := float(endurance) * GameConfig.END_ARMOR_BONUS

	# Compute final effective stats
	_cached_max_hp = (base_max_hp + str_hp) * hp_upgrade_mult
	_cached_damage = (base_damage + str_dmg + dex_dmg) * damage_upgrade_mult
	_cached_attack_period = maxf(0.1, base_attack_period / dex_speed_ratio)
	_cached_armor = base_armor + end_armor + armor_upgrade_flat
	_cached_max_energy = base_max_energy + int_energy
	_cached_energy_regen = base_energy_regen + int_regen
	_cached_ability_power = int_ap
	_cached_neutron_mitigation = float(neutron_armor_level) * GameConfig.NEUTRON_ARMOR_MITIGATION_PER_LEVEL

	_dirty = false
	stats_changed.emit()


# Getters with lazy caching
func get_effective_max_hp() -> float:
	if _dirty: recalculate()
	return _cached_max_hp

func get_effective_damage() -> float:
	if _dirty: recalculate()
	return _cached_damage

func get_effective_attack_period() -> float:
	if _dirty: recalculate()
	return _cached_attack_period

func get_effective_armor() -> float:
	if _dirty: recalculate()
	return _cached_armor

func get_effective_max_energy() -> float:
	if _dirty: recalculate()
	return _cached_max_energy

func get_effective_energy_regen() -> float:
	if _dirty: recalculate()
	return _cached_energy_regen

func get_effective_ability_power() -> float:
	if _dirty: recalculate()
	return _cached_ability_power

func get_neutron_armor_mitigation() -> float:
	if _dirty: recalculate()
	return _cached_neutron_mitigation


## Calculates cost to purchase the next point of an attribute
func get_next_attribute_cost(attr_name: String) -> int:
	var current_pts: int = get_attribute_value(attr_name)
	return GameConfig.get_attribute_cost(current_pts)


func get_attribute_value(attr_name: String) -> int:
	match attr_name.to_lower():
		"strength", "fuerza": return strength
		"dexterity", "destreza": return dexterity
		"intelligence", "inteligencia": return intelligence
		"endurance", "aguante": return endurance
	return 0


## Invest single or N points into an attribute
func invest_attribute(attr_name: String, points: int = 1) -> bool:
	if points <= 0:
		return false
	
	match attr_name.to_lower():
		"strength", "fuerza": strength += points
		"dexterity", "destreza": dexterity += points
		"intelligence", "inteligencia": intelligence += points
		"endurance", "aguante": endurance += points
		_: return false
	
	mark_dirty()
	attribute_invested.emit(attr_name, get_attribute_value(attr_name), get_next_attribute_cost(attr_name))
	return true


## Shift+Click support: Spend all available minerals on this attribute (Task 4.5).
## Returns summary of points bought, total cost, and remaining minerals.
func invest_max_possible(attr_name: String, available_minerals: int) -> Dictionary:
	var points_bought: int = 0
	var total_spent: int = 0
	var current_pts: int = get_attribute_value(attr_name)
	var remaining: int = available_minerals

	while true:
		var cost := GameConfig.get_attribute_cost(current_pts)
		if remaining < cost:
			break
		remaining -= cost
		total_spent += cost
		current_pts += 1
		points_bought += 1

	if points_bought > 0:
		invest_attribute(attr_name, points_bought)

	return {
		"points_bought": points_bought,
		"total_spent": total_spent,
		"remaining_minerals": remaining
	}


## Neutron Armor Upgrade (Task 4.10)
func get_next_neutron_armor_cost() -> int:
	return GameConfig.get_neutron_armor_cost(neutron_armor_level)


func upgrade_neutron_armor() -> bool:
	neutron_armor_level += 1
	mark_dirty()
	return true
