class_name AbilityEffects
extends RefCounted

## AbilityEffects - Reusable Combat Effect Library for SFE5 (Task 5.2).
## Completely decoupled from visual presentations for deterministic logic and testability.
## Provides AoE damage, crowd control (stun), shield grants, healing, stealth, and storm pulses.

const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")


## Deals area-of-effect spell damage with intelligence scaling and falloff
static func apply_aoe_spell_damage(
	center: Vector3,
	radius: float,
	raw_damage: float,
	ability_power_mult: float,
	swarm_sim: Node,
	friendly_fire: bool = false
) -> Array[int]:
	var hit_indices: Array[int] = []
	if not swarm_sim or not is_instance_valid(swarm_sim):
		return hit_indices
	
	var final_damage := raw_damage * ability_power_mult
	var rad_sq := radius * radius
	
	if "swarm_data" in swarm_sim and swarm_sim.swarm_data:
		var sd = swarm_sim.swarm_data
		var cap: int = sd.capacity
		var alive = sd.alive_mask
		var px = sd.pos_x
		var pz = sd.pos_z
		
		for i in range(cap):
			if not alive[i]:
				continue
			var dx: float = px[i] - center.x
			var dz: float = pz[i] - center.z
			var d_sq := dx * dx + dz * dz
			if d_sq <= rad_sq:
				if swarm_sim.has_method("apply_damage_to_unit"):
					swarm_sim.apply_damage_to_unit(i, final_damage)
				hit_indices.append(i)
				
	return hit_indices


## Restores health to a target unit, clamped to maximum health
static func apply_healing(target: Node, amount: float, ability_power_mult: float = 1.0) -> float:
	if not target or not is_instance_valid(target):
		return 0.0
	
	var final_heal := amount * ability_power_mult
	if "current_health" in target and "max_health" in target:
		var cur_hp: float = target.get("current_health")
		var m_hp: float = target.get("max_health")
		var prev_hp: float = cur_hp
		var new_hp: float = minf(m_hp, cur_hp + final_heal)
		target.set("current_health", new_hp)
		return new_hp - prev_hp
	return 0.0


## Grants temporary plasma shield to absorb incoming attacks
static func apply_temporary_shield(target: Node, shield_amount: float, ability_power_mult: float = 1.0) -> float:
	if not target or not is_instance_valid(target):
		return 0.0
	
	var final_shield := shield_amount * ability_power_mult
	if "plasma_shield_hp" in target:
		var prev_s: float = target.get("plasma_shield_hp")
		var new_s: float = prev_s + final_shield
		target.set("plasma_shield_hp", new_s)
		return new_s
	elif "shield_hp" in target:
		var prev_s: float = target.get("shield_hp")
		var new_s: float = prev_s + final_shield
		target.set("shield_hp", new_s)
		return new_s
	return 0.0


## Stuns a target unit for a given duration
static func apply_stun(target: Node, duration: float) -> bool:
	if not target or not is_instance_valid(target):
		return false
	
	if target.has_method("apply_stun"):
		target.apply_stun(duration)
		return true
	elif "is_stunned" in target:
		target.set("is_stunned", true)
		if "stun_timer" in target:
			target.set("stun_timer", duration)
		return true
	return false


## Applies temporary stealth / cloak to a target unit
static func apply_invisibility(target: Node, duration: float) -> bool:
	if not target or not is_instance_valid(target):
		return false
	
	if target.has_node("BuffComponent"):
		var buff_comp = target.get_node("BuffComponent")
		if buff_comp.has_method("apply_buff"):
			buff_comp.apply_buff(&"cloak", duration)
			return true
	if "is_cloaked" in target:
		target.set("is_cloaked", true)
		return true
	return false


## Executes a single periodic pulse of a psionic/elemental storm in an area
static func apply_storm_pulse(
	center: Vector3,
	radius: float,
	pulse_damage: float,
	ability_power_mult: float,
	swarm_sim: Node
) -> int:
	var hits := apply_aoe_spell_damage(center, radius, pulse_damage, ability_power_mult, swarm_sim)
	return hits.size()
