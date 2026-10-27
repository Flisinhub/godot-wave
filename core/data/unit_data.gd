class_name UnitData
extends Resource

## UnitData - Central Data Schema for all physical and combat units in SFE5.
## Defines physical attributes, weapon mechanics, armor, SFE5 category, and tags.

const IncomeParams = preload("res://core/economy/income_params.gd")

@export_group("Identity")
@export var id: StringName = &"unit"
@export var unit_name: String = "Unit"
@export_enum("terran", "zerg", "protoss", "hybrid", "neutral") var race: String = "terran"
@export_enum("normal", "structure", "heroic", "elite", "map_boss", "summoned_boss", "pinnacle_boss") var category: String = "normal"
@export var category_multiplier: float = 1.0
@export var icon_path: String = ""

@export_group("Health & Armor")
@export var max_health: float = 45.0
@export var max_shield: float = 0.0
@export var flat_armor: float = 0.0
@export var hp_regen: float = 0.0
@export var shield_regen: float = 0.0

@export_group("Offensive Capabilities")
@export var attack_damage: float = 6.0
@export var attack_cooldown: float = 0.6
@export var attack_range: float = 6.0
@export var has_weapon: bool = true
@export var ignores_armor: bool = false # SFE5 Task 3.8: penetra-armadura

@export_group("Energy & Magic")
@export var max_energy: float = 0.0
@export var energy_regen: float = 0.0

@export_group("Kinematics & Vision")
@export var move_speed: float = 5.0
@export var vision_range: float = 12.0
@export var tags: Array[String] = ["light", "biological"]

@export_group("Visual Representation")
@export var scene: PackedScene = null
@export var mesh_scale: Vector3 = Vector3.ONE
@export var custom_material: Material = null


## Generates an IncomeParams container for SFE5 Master Income Formula evaluation.
func get_income_params(player_count: int = 1, diff_mult: float = 1.0) -> IncomeParams:
	var p := IncomeParams.new()
	p.base_health = max_health
	p.base_shield = max_shield
	p.weapon_damage = attack_damage
	p.attack_period = attack_cooldown
	p.has_weapon = has_weapon
	p.max_energy = max_energy
	p.category = category
	p.category_multiplier = category_multiplier if category_multiplier > 0.0 else 1.0
	p.player_count = player_count
	p.difficulty_mult = diff_mult
	return p
