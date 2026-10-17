class_name HeroAttributeCalculator
extends RefCounted

## Pure mathematical RPG Attribute Calculator for SFE5 Heroes.
## Computes derived combat and utility stats from base stats and STR / DEX / INT attributes.
## Formulated without iterative compounding to prevent precision and rounding drift.

# Attribute Scaling Constants (per Requirement R4 / PROJECT.md specification)
const HP_PER_STRENGTH: float = 20.0
const DAMAGE_PER_STRENGTH: float = 1.5
const COOLDOWN_DEX_FACTOR: float = 0.01
const HP_REGEN_PER_DEXTERITY: float = 0.15
const ENERGY_PER_INTELLIGENCE: float = 10.0
const ENERGY_REGEN_PER_INTELLIGENCE: float = 0.08
const VISION_PER_INTELLIGENCE: float = 0.2
const MIN_ATTACK_COOLDOWN: float = 0.05

## Max HP: base_hp + (strength * 20.0)
static func calculate_max_hp(base_hp: float, strength: int) -> float:
	return base_hp + (float(strength) * HP_PER_STRENGTH)

## Weapon Damage: base_damage + (strength * 1.5)
static func calculate_weapon_damage(base_damage: float, strength: int) -> float:
	return base_damage + (float(strength) * DAMAGE_PER_STRENGTH)

## Attack Cooldown: base_cooldown / (1.0 + (dexterity * 0.01))
static func calculate_attack_cooldown(base_cooldown: float, dexterity: int) -> float:
	var denominator: float = 1.0 + (float(dexterity) * COOLDOWN_DEX_FACTOR)
	if denominator <= 0.0:
		return base_cooldown
	return maxf(MIN_ATTACK_COOLDOWN, base_cooldown / denominator)

## HP Regen: base_regen + (dexterity * 0.15)
static func calculate_hp_regen(base_regen: float, dexterity: int) -> float:
	return base_regen + (float(dexterity) * HP_REGEN_PER_DEXTERITY)

## Max Energy: base_energy + (intelligence * 10.0)
static func calculate_max_energy(base_energy: float, intelligence: int) -> float:
	return base_energy + (float(intelligence) * ENERGY_PER_INTELLIGENCE)

## Energy Regen: base_energy_regen + (intelligence * 0.08)
static func calculate_energy_regen(base_energy_regen: float, intelligence: int) -> float:
	return base_energy_regen + (float(intelligence) * ENERGY_REGEN_PER_INTELLIGENCE)

## Vision Radius: base_vision + (intelligence * 0.2)
static func calculate_vision_radius(base_vision: float, intelligence: int) -> float:
	return base_vision + (float(intelligence) * VISION_PER_INTELLIGENCE)

## Calculates all derived stats dictionary directly from base values and attributes
static func calculate_all(
	base_hp: float,
	base_damage: float,
	base_cooldown: float,
	base_hp_regen: float,
	base_energy: float,
	base_energy_regen: float,
	base_vision: float,
	strength: int,
	dexterity: int,
	intelligence: int
) -> Dictionary:
	return {
		"max_hp": calculate_max_hp(base_hp, strength),
		"weapon_damage": calculate_weapon_damage(base_damage, strength),
		"attack_cooldown": calculate_attack_cooldown(base_cooldown, dexterity),
		"hp_regen": calculate_hp_regen(base_hp_regen, dexterity),
		"max_energy": calculate_max_energy(base_energy, intelligence),
		"energy_regen": calculate_energy_regen(base_energy_regen, intelligence),
		"vision_radius": calculate_vision_radius(base_vision, intelligence)
	}
