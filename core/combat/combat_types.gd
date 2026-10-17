class_name CombatTypes
extends RefCounted

## Enumerations and common data structures for SFE5 combat engine.

## Damage type classification
enum DamageType {
	PHYSICAL = 0, ## Ballistic bullets, melee bites, kinetic attacks. Mitigated by flat armor.
	SPELL = 1     ## Psionic storm, acid rain, energy discharges. Flat armor bypassed.
}

## Structural defensive classification
enum StructureType {
	NONE = 0,            ## Not a structure / standard ground or air unit.
	WALL_REINFORCED = 1, ## Reinforced defensive wall (35% passive damage mitigation).
	BUNKER = 2,          ## Fortified garrison bunker (25% passive damage mitigation).
	OTHER = 3            ## Generic structure (0% passive mitigation unless specified).
}

## Target classification bitmask
enum TargetTag {
	NONE = 0,
	HEROIC = 1 << 0,     ## Hero unit (takes reduced damage from AoE spells).
	ARMORED = 1 << 1,    ## Heavy chassis / armored carapace.
	LIGHT = 1 << 2,      ## Light infantry / swarmling.
	BIOLOGICAL = 1 << 3, ## Living organism.
	MECHANICAL = 1 << 4, ## Robotic / vehicular.
	MASSIVE = 1 << 5,    ## Super-heavy / colossus.
	STRUCTURE = 1 << 6,  ## Static installation.
	AIR = 1 << 7,        ## Aerial unit.
	GROUND = 1 << 8      ## Terrestrial unit.
}

## Expose CombatResult class through CombatTypes for convenience
const CombatResult = preload("res://core/combat/combat_result.gd")
