class_name SFEBuffDef
extends Resource

## Data definition for SFE5 Buffs and Status Effects.
## Can be saved as .tres resources or created dynamically in code.

@export var buff_id: StringName = &"unnamed_buff"
@export var display_name: String = "Unnamed Buff"
@export_range(1, 10) var tier: int = 1
@export var mineral_cost: int = 500
@export var default_duration: float = 5.0
@export var default_max_stacks: int = 2
@export var is_invulnerable: bool = false
@export var is_supreme: bool = false
@export var stat_multipliers: Dictionary = {}  ## e.g. {"attack_speed": 1.5, "move_speed": 1.3}
@export var flat_modifiers: Dictionary = {}    ## e.g. {"flat_armor": 5.0}
@export var conditions: Array[String] = ["always"]
@export var custom_data: Dictionary = {}

func _init(
	p_buff_id: StringName = &"unnamed_buff",
	p_display_name: String = "Unnamed Buff",
	p_duration: float = 5.0,
	p_max_stacks: int = 2,
	p_is_invulnerable: bool = false,
	p_stat_multipliers: Dictionary = {},
	p_flat_modifiers: Dictionary = {},
	p_custom_data: Dictionary = {},
	p_tier: int = 1,
	p_cost: int = 500
) -> void:
	buff_id = p_buff_id
	display_name = p_display_name
	default_duration = p_duration
	default_max_stacks = p_max_stacks
	is_invulnerable = p_is_invulnerable
	stat_multipliers = p_stat_multipliers
	flat_modifiers = p_flat_modifiers
	custom_data = p_custom_data
	tier = p_tier
	mineral_cost = p_cost
