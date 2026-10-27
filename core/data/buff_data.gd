class_name BuffData
extends Resource

## BuffData - SFE5 Data Schema for Tier 1-7 Attribute Buffs & Supreme Buffs.
## Supports modular stat modifiers, stack clamping, activation conditions, and mineral costs.

@export_group("Identity & Tier")
@export var id: StringName = &"unnamed_buff"
@export var buff_name: String = "Unnamed Buff"
@export_range(1, 10) var tier: int = 1 # 1-7 = Standard Tiers, 8 = Ace, 9 = Demiurge, 10 = Maxima Experiencia
@export var mineral_cost: int = 500
@export var is_supreme: bool = false
@export var icon_path: String = ""
@export_multiline var description: String = ""

@export_group("Timing & Stacking")
@export var duration: float = 0.0 # 0.0 = Permanent passive
@export var max_stacks: int = 1
@export var is_invulnerable: bool = false

@export_group("Modular Modifiers")
@export var stat_multipliers: Dictionary = {} # e.g. {"attack_speed": 1.2, "move_speed": 1.15}
@export var flat_modifiers: Dictionary = {}    # e.g. {"flat_armor": 2.0, "max_health": 100.0}

@export_group("Activation Conditions")
## Supported conditions: "always", "stationary", "moving", "undamaged_5s", "full_energy", "below_30_hp"
@export var conditions: Array[String] = ["always"]


func is_permanent() -> bool:
	return duration <= 0.0


func is_condition_met(evaluator_state: Dictionary) -> bool:
	if conditions.has("always") or conditions.is_empty():
		return true
	for cond in conditions:
		match cond:
			"stationary":
				if not evaluator_state.get("is_stationary", true):
					return false
			"moving":
				if not evaluator_state.get("is_moving", false):
					return false
			"full_energy":
				if evaluator_state.get("current_energy", 0.0) < evaluator_state.get("max_energy", 100.0):
					return false
			"below_30_hp":
				var hp_ratio = evaluator_state.get("current_hp", 1.0) / maxf(1.0, evaluator_state.get("max_hp", 1.0))
				if hp_ratio > 0.3:
					return false
	return true
