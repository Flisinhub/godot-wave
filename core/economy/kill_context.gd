class_name KillContext
extends RefCounted

## KillContext - Data provenance container for lethal damage and bounty attribution.
## Used by SFEEconomyManager to strictly enforce the Crossfire Nullification Rule (Requirement R3).

## The entity that died / took lethal damage
var victim: Object = null

## The entity that dealt the lethal blow
var killer: Object = null

## The faction of the killer (EconomyTypes.Faction: ALLIED = 0, HOSTILE = 1, NEUTRAL = 2, ENVIRONMENT = 3, ROGUE = 4)
var killer_faction: int = 1 # Default HOSTILE

## The nominal mineral bounty awarded if eliminated by allied units
var base_bounty: int = 0

## The type of lethal damage dealt (0 = Physical, 1 = Spell)
var lethal_damage_type: int = 0

## Timestamp of the lethal kill event
var timestamp_ms: int = 0

func _init(
	p_victim: Object = null,
	p_killer: Object = null,
	p_killer_faction: int = 1,
	p_base_bounty: int = 0,
	p_lethal_damage_type: int = 0
) -> void:
	victim = p_victim
	killer = p_killer
	killer_faction = p_killer_faction
	base_bounty = p_base_bounty
	lethal_damage_type = p_lethal_damage_type
	timestamp_ms = Time.get_ticks_msec()

## Returns true if the killer was confirmed to be on the Allied side (Player hero / allied unit / defensive structure)
func is_allied_kill() -> bool:
	return killer_faction == 0

func _to_string() -> String:
	return "<KillContext victim=%s killer=%s killer_faction=%d base_bounty=%d>" % [
		str(victim), str(killer), killer_faction, base_bounty
	]
