class_name ExperienceComponent
extends Node

## ExperienceComponent - SFE5 Level & RPG Experience Curve (Task 5.3).
## Progression curve from Level 1 to 100.
## Automatically grants base attribute growth upon level up (+2 STR, +2 DEX, +2 INT, +2 END).

const StatsComponent = preload("res://core/components/stats_component.gd")
const FloatingTextManager = preload("res://core/vfx/floating_text_manager.gd")

const MAX_LEVEL: int = 100

@export var current_level: int = 1
var current_xp: int = 0
var xp_to_next_level: int = 137

var stats_component: StatsComponent = null

signal experience_gained(amount: int, current: int, required: int)
signal level_up(new_level: int)


func _init() -> void:
	xp_to_next_level = calculate_xp_required(current_level)


func _ready() -> void:
	if not stats_component:
		stats_component = get_parent().get_node_or_null("StatsComponent") as StatsComponent
	xp_to_next_level = calculate_xp_required(current_level)


## Formula for XP required to advance from level `lvl` to `lvl + 1`
static func calculate_xp_required(lvl: int) -> int:
	if lvl >= MAX_LEVEL:
		return 999999999
	return int(80.0 + (float(lvl) * 45.0) + pow(float(lvl), 1.6) * 12.0)


## Adds raw experience points and handles multi-level ups
func award_xp(amount: int) -> bool:
	if current_level >= MAX_LEVEL or amount <= 0:
		return false
	
	current_xp += amount
	var leveled_up := false
	
	while current_xp >= xp_to_next_level and current_level < MAX_LEVEL:
		current_xp -= xp_to_next_level
		current_level += 1
		leveled_up = true
		xp_to_next_level = calculate_xp_required(current_level)
		_apply_level_up_bonuses()
	
	experience_gained.emit(amount, current_xp, xp_to_next_level)
	return leveled_up


func _apply_level_up_bonuses() -> void:
	# SFE5 Rule: Each level up grants +2 points to all core RPG attributes
	if stats_component:
		stats_component.strength += 2
		stats_component.dexterity += 2
		stats_component.intelligence += 2
		stats_component.endurance += 2
		stats_component.mark_dirty()
	
	level_up.emit(current_level)
	
	if is_inside_tree():
		var p = get_parent()
		var pos = p.global_position if p is Node3D else Vector3.ZERO
		FloatingTextManager.spawn_text(
			self,
			pos + Vector3(0.0, 3.2, 0.0),
			"¡NIVEL %d ALCANZADO!" % current_level,
			Color(1.0, 0.85, 0.2)
		)


## Awards combat experience from an eliminated foe
func award_kill_xp(victim_max_health: float, is_boss: bool = false) -> void:
	var base_xp := 25 if is_boss else int(maxf(10.0, victim_max_health * 0.03))
	award_xp(base_xp)
