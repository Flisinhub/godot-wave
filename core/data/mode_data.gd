class_name ModeData
extends Resource

## ModeData - SFE5 Game Mode Schema.
## Configures gameplay mutators, victory conditions, and restrictions.

@export_group("Identity")
@export var id: StringName = &"classic"
@export var mode_name: String = "Classic Survival"
@export_multiline var description: String = "Standard SFE5 cooperative experience."

@export_group("Rules & Modifiers")
@export var split_income: bool = false
@export var no_buffs: bool = false
@export var no_protoss: bool = false
@export var nightmare_mode: bool = false
@export var permadeath: bool = false
@export var use_waves_mode: bool = false # Legacy / alternative rounds mode
@export var max_players: int = 6
