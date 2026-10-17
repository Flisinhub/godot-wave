class_name HeroSkillData
extends Resource

## Standalone Custom Resource defining active and passive hero abilities in SFE5.
## Completely decoupled from hero entities for modular ability composition and UI data-binding.

enum TargetType {
	NONE = 0,
	SELF_INSTANT = 1,
	TARGET_UNIT = 2,
	TARGET_AREA = 3,
	TARGET_VECTOR = 4,
	PASSIVE = 5,
	TOGGLE = 6
}

@export var skill_id: StringName = &"unnamed_skill"
@export var skill_name: String = "Unnamed Skill"
@export_multiline var description: String = ""
@export var target_type: TargetType = TargetType.SELF_INSTANT

# Resource and timing constraints
@export var energy_cost: float = 0.0
@export var cooldown: float = 5.0
@export var cast_range: float = 8.0
@export var area_radius: float = 0.0

# Combat power & typing
@export var base_power: float = 0.0
@export var damage_type: int = 1 # 0 = PHYSICAL, 1 = SPELL
@export var is_passive: bool = false

# Buff / Status link
@export var buff_id: StringName = &""
@export var buff_duration: float = 0.0

# UI & UX metadata
@export var hotkey: String = "Q"
@export var icon_path: String = ""
@export var max_rank: int = 1
@export var current_rank: int = 1

func can_cast(current_energy: float, is_on_cooldown: bool) -> bool:
	if is_passive:
		return false
	if is_on_cooldown:
		return false
	return current_energy >= energy_cost
