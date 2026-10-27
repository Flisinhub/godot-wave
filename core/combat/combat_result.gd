class_name CombatResult
extends RefCounted

## Encapsulates the complete result of an SFE5 combat calculation.

var damage_dealt: float = 0.0
var effective_damage: float:
	get:
		return damage_dealt
	set(val):
		damage_dealt = val
var is_immune: bool = false
var overkill: float = 0.0
var absorbed: float = 0.0
var damage_type: int = 0
var raw_damage: float = 0.0
var mitigated_amount: float = 0.0

func _init(
	p_damage_dealt: float = 0.0,
	p_is_immune: bool = false,
	p_overkill: float = 0.0,
	p_absorbed: float = 0.0,
	p_damage_type: int = 0,
	p_raw_damage: float = 0.0,
	p_mitigated_amount: float = 0.0
) -> void:
	damage_dealt = p_damage_dealt
	is_immune = p_is_immune
	overkill = p_overkill
	absorbed = p_absorbed
	damage_type = p_damage_type
	raw_damage = p_raw_damage
	mitigated_amount = p_mitigated_amount

func to_dict() -> Dictionary:
	return {
		"damage_dealt": damage_dealt,
		"is_immune": is_immune,
		"overkill": overkill,
		"absorbed": absorbed,
		"damage_type": damage_type,
		"raw_damage": raw_damage,
		"mitigated_amount": mitigated_amount
	}

func _to_string() -> String:
	return "[CombatResult dmg=%.2f immune=%s abs=%.2f over=%.2f type=%d]" % [
		damage_dealt, is_immune, absorbed, overkill, damage_type
	]
