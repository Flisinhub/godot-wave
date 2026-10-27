class_name AbilityComponent
extends Node

## AbilityComponent - SFE5 Hero Ability Manager (Tasks 5.1, 5.4, 5.14).
## Manages Q/W/E/R skill slots, energy consumption, cooldown timers,
## Intelligence AP scaling, and state-consuming buffs (Quantum Field).

const StatsComponent = preload("res://core/components/stats_component.gd")
const AbilityEffects = preload("res://core/combat/ability_effects.gd")

# Slot -> Resource (AbilityData / HeroSkillData)
var skills: Dictionary = {
	"Q": null,
	"W": null,
	"E": null,
	"R": null
}

# Slot -> Remaining cooldown in seconds
var cooldowns: Dictionary = {
	"Q": 0.0,
	"W": 0.0,
	"E": 0.0,
	"R": 0.0
}

var current_energy: float = 100.0
var stats_component: StatsComponent = null
var swarm_simulation: Node = null

signal skill_cast(slot: String, skill_name: String, target_pos: Vector3)
signal cooldown_updated(slot: String, remaining: float, total: float)
signal energy_changed(current: float, max_energy: float)


func _ready() -> void:
	if not stats_component:
		stats_component = get_parent().get_node_or_null("StatsComponent") as StatsComponent
	if stats_component:
		current_energy = stats_component.get_effective_max_energy()


func set_simulation(sim: Node) -> void:
	swarm_simulation = sim


func bind_skill(slot: String, skill_res: Resource) -> void:
	var s := slot.to_upper()
	skills[s] = skill_res
	cooldowns[s] = 0.0


func get_skill(slot: String) -> Resource:
	return skills.get(slot.to_upper(), null)


func can_cast(slot: String) -> bool:
	var s := slot.to_upper()
	var skill = skills.get(s, null)
	if skill == null:
		return false
	
	if cooldowns.get(s, 0.0) > 0.0:
		return false
	
	var cost: float = 0.0
	if "energy_cost" in skill:
		cost = skill.get("energy_cost")
	
	return current_energy >= cost


func cast_skill(slot: String, target_pos: Vector3 = Vector3.ZERO, target_unit: Node = null) -> bool:
	var s := slot.to_upper()
	if not can_cast(s):
		return false
	
	var skill = skills[s]
	var cost: float = skill.get("energy_cost") if "energy_cost" in skill else 0.0
	var total_cd: float = skill.get("cooldown") if "cooldown" in skill else 5.0
	var max_e: float = stats_component.get_effective_max_energy() if stats_component else 100.0
	
	# Task 5.14: Check Quantum Field (100% energy -> +75% spell damage for 4s)
	var was_full_energy := (current_energy >= (max_e - 0.001))
	
	# Consume Energy
	current_energy = maxf(0.0, current_energy - cost)
	energy_changed.emit(current_energy, max_e)
	
	# Set Cooldown
	cooldowns[s] = total_cd
	cooldown_updated.emit(s, total_cd, total_cd)
	
	# Compute Intelligence-scaled Ability Power (Task 5.4)
	var ap_mult: float = stats_component.get_effective_ability_power() if stats_component else 1.0
	
	# Task 5.14: If energy was 100% or has quantum_field buff, amplify spell damage by +75%
	var parent_node = get_parent()
	var has_qfield := false
	if parent_node and parent_node.has_node("BuffComponent"):
		var buff_comp = parent_node.get_node("BuffComponent")
		if buff_comp.has_method("has_buff") and buff_comp.has_buff(&"quantum_field"):
			has_qfield = true
	
	if was_full_energy or has_qfield:
		ap_mult *= 1.75
	
	# Execute Effect
	_execute_skill_effect(skill, target_pos, target_unit, ap_mult)
	
	var skill_title: String = s
	if "ability_name" in skill:
		skill_title = str(skill.get("ability_name"))
	elif "skill_name" in skill:
		skill_title = str(skill.get("skill_name"))
		
	skill_cast.emit(s, skill_title, target_pos)
	return true


func _execute_skill_effect(skill: Resource, target_pos: Vector3, target_unit: Node, ap_mult: float) -> void:
	var base_dmg: float = 0.0
	if "base_power" in skill:
		base_dmg = skill.get("base_power")
	elif "damage" in skill:
		base_dmg = skill.get("damage")
	
	var aoe_radius: float = 0.0
	if "area_radius" in skill:
		aoe_radius = skill.get("area_radius")
	elif "radius" in skill:
		aoe_radius = skill.get("radius")
	elif "aoe_radius" in skill:
		aoe_radius = skill.get("aoe_radius")
	
	if aoe_radius > 0.0 and base_dmg > 0.0:
		AbilityEffects.apply_aoe_spell_damage(target_pos, aoe_radius, base_dmg, ap_mult, swarm_simulation)
	elif base_dmg > 0.0 and target_unit and target_unit.has_method("take_damage"):
		target_unit.take_damage(base_dmg * ap_mult)


func _process(delta: float) -> void:
	# 1. Energy Regeneration scaled with Intelligence
	var max_e: float = stats_component.get_effective_max_energy() if stats_component else 100.0
	var regen_rate: float = stats_component.get_effective_energy_regen() if stats_component else 1.0
	
	if current_energy < max_e:
		current_energy = minf(max_e, current_energy + (regen_rate * delta))
		energy_changed.emit(current_energy, max_e)
	
	# 2. Cooldown Tick
	for s in cooldowns.keys():
		var remaining: float = cooldowns[s]
		if remaining > 0.0:
			remaining = maxf(0.0, remaining - delta)
			cooldowns[s] = remaining
			var skill = skills.get(s, null)
			var total_cd: float = 5.0
			if skill:
				if "cooldown" in skill:
					total_cd = skill.get("cooldown")
			cooldown_updated.emit(s, remaining, total_cd)
