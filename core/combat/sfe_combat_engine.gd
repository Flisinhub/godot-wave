class_name SFECombatEngine
extends RefCounted

## Pure mathematical combat calculator for SFE5.
## Completely decoupled from Node3D / SceneTree for deterministic simulation and testing.

const CombatResult = preload("res://core/combat/combat_result.gd")

## Damage type classification
enum DamageType {
	PHYSICAL = 0,
	SPELL = 1
}

## Structural defensive classification
enum StructureType {
	NONE = 0,
	WALL_REINFORCED = 1,
	BUNKER = 2,
	OTHER = 3
}

## Target classification bitmask
enum TargetTag {
	NONE = 0,
	HEROIC = 1 << 0,
	ARMORED = 1 << 1,
	LIGHT = 1 << 2,
	BIOLOGICAL = 1 << 3,
	MECHANICAL = 1 << 4,
	MASSIVE = 1 << 5,
	STRUCTURE = 1 << 6,
	AIR = 1 << 7,
	GROUND = 1 << 8
}

## Standard mathematical constants
const PROGRESSIVE_MITIGATION_PER_LEVEL: float = 0.002  ## 0.2% per upgrade level
const DEFAULT_PROGRESSIVE_CAP: float = 0.50            ## 50% max progressive reduction
const WALL_REINFORCED_MITIGATION: float = 0.35         ## 35% reduction for reinforced walls
const BUNKER_MITIGATION: float = 0.25                  ## 25% reduction for fortified bunkers
const HEROIC_AOE_SPELL_PENALTY: float = 0.40           ## 40% reduction against HEROIC from AoE spells

## Instance configurable properties
var progressive_rate: float = PROGRESSIVE_MITIGATION_PER_LEVEL
var progressive_cap: float = DEFAULT_PROGRESSIVE_CAP
var wall_mitigation_rate: float = WALL_REINFORCED_MITIGATION
var bunker_mitigation_rate: float = BUNKER_MITIGATION
var heroic_aoe_penalty_rate: float = HEROIC_AOE_SPELL_PENALTY

## Static calculation method matching interface contracts
static func calculate_damage(
	raw_damage: float,
	damage_type: int = DamageType.PHYSICAL,
	flat_armor: float = 0.0,
	upgrade_level: int = 0,
	structure_type: int = StructureType.NONE,
	is_heroic: Variant = false,
	is_aoe: bool = false,
	is_invulnerable: bool = false,
	shield_hp: float = 0.0,
	current_hp: float = -1.0,
	target_tags: int = 0
) -> CombatResult:
	# 1. Invulnerability Check
	if is_invulnerable:
		return CombatResult.new(
			0.0,
			true,
			0.0,
			0.0,
			damage_type,
			raw_damage,
			raw_damage
		)

	if raw_damage <= 0.0:
		return CombatResult.new(0.0, false, 0.0, 0.0, damage_type, raw_damage, 0.0)

	# Resolve heroic tag
	var is_heroic_target: bool = false
	if is_heroic is bool:
		is_heroic_target = is_heroic
	elif is_heroic is int:
		is_heroic_target = (is_heroic & TargetTag.HEROIC) != 0 or is_heroic != 0

	if not is_heroic_target and (target_tags & TargetTag.HEROIC) != 0:
		is_heroic_target = true

	var effective_dmg: float = raw_damage

	# 2. Damage Type Branching: Physical vs Spell
	if damage_type == DamageType.PHYSICAL:
		# Physical attacks are mitigated by flat armor with a minimum floor of 1.0 damage
		effective_dmg = maxf(1.0, effective_dmg - flat_armor)
	else:
		# Spell attacks completely bypass flat armor (0 reduction)
		effective_dmg = raw_damage

	# 3. Progressive Upgrade Mitigation (0.2% per level, capped at 50%)
	if upgrade_level > 0:
		var prog_ratio: float = minf(DEFAULT_PROGRESSIVE_CAP, float(upgrade_level) * PROGRESSIVE_MITIGATION_PER_LEVEL)
		effective_dmg = effective_dmg * (1.0 - prog_ratio)

	# 4. Passive Structural Mitigation
	if structure_type == StructureType.WALL_REINFORCED:
		effective_dmg = effective_dmg * (1.0 - WALL_REINFORCED_MITIGATION)
	elif structure_type == StructureType.BUNKER:
		effective_dmg = effective_dmg * (1.0 - BUNKER_MITIGATION)

	# 5. HEROIC Tag Penalties (AoE Spells deal reduced damage to heroes)
	if is_heroic_target and damage_type == DamageType.SPELL and is_aoe:
		effective_dmg = effective_dmg * (1.0 - HEROIC_AOE_SPELL_PENALTY)

	effective_dmg = maxf(0.0, effective_dmg)

	# 6. Shield Absorption
	var absorbed: float = 0.0
	if shield_hp > 0.0:
		absorbed = minf(shield_hp, effective_dmg)
		effective_dmg -= absorbed

	# 7. Overkill Calculation
	var overkill: float = 0.0
	if current_hp >= 0.0 and effective_dmg > current_hp:
		overkill = effective_dmg - current_hp

	var mitigated_amount: float = maxf(0.0, raw_damage - (effective_dmg + absorbed))

	return CombatResult.new(
		effective_dmg,
		false,
		overkill,
		absorbed,
		damage_type,
		raw_damage,
		mitigated_amount
	)

## Instance calculation method utilizing configured engine rates
func calculate(
	raw_damage: float,
	damage_type: int = DamageType.PHYSICAL,
	flat_armor: float = 0.0,
	upgrade_level: int = 0,
	structure_type: int = StructureType.NONE,
	is_heroic: Variant = false,
	is_aoe: bool = false,
	is_invulnerable: bool = false,
	shield_hp: float = 0.0,
	current_hp: float = -1.0,
	target_tags: int = 0
) -> CombatResult:
	if is_invulnerable:
		return CombatResult.new(0.0, true, 0.0, 0.0, damage_type, raw_damage, raw_damage)

	if raw_damage <= 0.0:
		return CombatResult.new(0.0, false, 0.0, 0.0, damage_type, raw_damage, 0.0)

	var is_heroic_target: bool = false
	if is_heroic is bool:
		is_heroic_target = is_heroic
	elif is_heroic is int:
		is_heroic_target = (is_heroic & TargetTag.HEROIC) != 0 or is_heroic != 0

	if not is_heroic_target and (target_tags & TargetTag.HEROIC) != 0:
		is_heroic_target = true

	var effective_dmg: float = raw_damage

	if damage_type == DamageType.PHYSICAL:
		effective_dmg = maxf(1.0, effective_dmg - flat_armor)

	if upgrade_level > 0:
		var prog_ratio: float = minf(progressive_cap, float(upgrade_level) * progressive_rate)
		effective_dmg = effective_dmg * (1.0 - prog_ratio)

	if structure_type == StructureType.WALL_REINFORCED:
		effective_dmg = effective_dmg * (1.0 - wall_mitigation_rate)
	elif structure_type == StructureType.BUNKER:
		effective_dmg = effective_dmg * (1.0 - bunker_mitigation_rate)

	if is_heroic_target and damage_type == DamageType.SPELL and is_aoe:
		effective_dmg = effective_dmg * (1.0 - heroic_aoe_penalty_rate)

	effective_dmg = maxf(0.0, effective_dmg)

	var absorbed: float = 0.0
	if shield_hp > 0.0:
		absorbed = minf(shield_hp, effective_dmg)
		effective_dmg -= absorbed

	var overkill: float = 0.0
	if current_hp >= 0.0 and effective_dmg > current_hp:
		overkill = effective_dmg - current_hp

	var mitigated_amount: float = maxf(0.0, raw_damage - (effective_dmg + absorbed))

	return CombatResult.new(
		effective_dmg,
		false,
		overkill,
		absorbed,
		damage_type,
		raw_damage,
		mitigated_amount
	)

## Helper to calculate from a dictionary of parameters
static func calculate_from_dict(params: Dictionary) -> CombatResult:
	return calculate_damage(
		params.get("raw_damage", 0.0),
		params.get("damage_type", DamageType.PHYSICAL),
		params.get("flat_armor", 0.0),
		params.get("upgrade_level", 0),
		params.get("structure_type", StructureType.NONE),
		params.get("is_heroic", false),
		params.get("is_aoe", false),
		params.get("is_invulnerable", false),
		params.get("shield_hp", 0.0),
		params.get("current_hp", -1.0),
		params.get("target_tags", 0)
	)
