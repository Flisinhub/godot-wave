class_name EliteComponent
extends Node

## EliteComponent - SFE5 Veterancy & Elite Progression System (Tasks 6.1, 6.2).
## Converts standard units into Elite units.
## Tracks kill stacks up to +125 flat damage and x1.6667 attack speed multiplier.

const CategoryRingStyler = preload("res://core/vfx/category_ring_styler.gd")
const FloatingTextManager = preload("res://core/vfx/floating_text_manager.gd")

const MAX_STACKS: int = 125
const MAX_DAMAGE_BONUS: float = 125.0
const MAX_ATTACK_SPEED_MULT: float = 1.6667

@export var is_elite: bool = false
@export var elite_stacks: int = 0

signal promoted_to_elite()
signal elite_stacks_changed(new_stacks: int, bonus_damage: float, speed_mult: float)


## Promotes the parent unit to an Elite unit (Task 6.1)
func promote_to_elite() -> void:
	if is_elite:
		return
	is_elite = true
	promoted_to_elite.emit()
	
	var p := get_parent()
	if p:
		if "unit_data" in p and p.unit_data:
			p.unit_data.category = "elite"
		if "selection_ring" in p and p.selection_ring is MeshInstance3D:
			CategoryRingStyler.apply_ring_style(p.selection_ring, "elite")
		
		if is_inside_tree() and p is Node3D:
			FloatingTextManager.spawn_text(
				self,
				p.global_position + Vector3(0, 2.0, 0),
				"¡VETERANÍA: UNIDAD ÉLITE!",
				Color(1.0, 0.6, 0.1)
			)


## Increments elite kill stack when this unit eliminates an enemy (Task 6.2)
func add_kill() -> void:
	if not is_elite:
		return
	
	if elite_stacks < MAX_STACKS:
		elite_stacks += 1
		var dmg := get_bonus_damage()
		var spd := get_attack_speed_multiplier()
		elite_stacks_changed.emit(elite_stacks, dmg, spd)


## Returns flat damage bonus (+1 flat damage per stack up to +125)
func get_bonus_damage() -> float:
	if not is_elite:
		return 0.0
	return float(mini(elite_stacks, MAX_STACKS))


## Returns attack speed multiplier (1.0x at 0 stacks up to 1.6667x at 125 stacks)
func get_attack_speed_multiplier() -> float:
	if not is_elite:
		return 1.0
	var ratio := float(elite_stacks) / float(MAX_STACKS)
	return 1.0 + (ratio * (MAX_ATTACK_SPEED_MULT - 1.0))


## Calculates modified attack cooldown taking elite attack speed into account
func get_effective_attack_cooldown(base_cooldown: float) -> float:
	var mult := get_attack_speed_multiplier()
	return maxf(0.05, base_cooldown / mult)
