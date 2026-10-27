class_name UnitRecruitmentManager
extends RefCounted

## UnitRecruitmentManager - SFE5 Base Unit Recruitment & Supply System (Tasks 6.3, 6.4).
## Governs unit recruitment, supply cap enforcement, and veterancy conversion.

const BaseUnit3DScript = preload("res://entities/allies/base_unit_3d.gd")
const UnitData = preload("res://core/data/unit_data.gd")
const SFEEconomyManager = preload("res://core/economy/sfe_economy_manager.gd")

const RECRUIT_CATALOG: Dictionary = {
	"marine": {
		"name": "Marine",
		"cost": 50,
		"supply": 1,
		"hp": 45.0,
		"damage": 7.0,
		"cooldown": 0.6,
		"range": 10.0,
		"speed": 5.0,
		"is_vision": false,
		"is_flying": false
	},
	"zealot": {
		"name": "Zealot",
		"cost": 100,
		"supply": 2,
		"hp": 160.0,
		"damage": 16.0,
		"cooldown": 0.8,
		"range": 2.0,
		"speed": 5.2,
		"is_vision": false,
		"is_flying": false
	},
	"zergling": {
		"name": "Zergling",
		"cost": 25,
		"supply": 1,
		"hp": 35.0,
		"damage": 5.0,
		"cooldown": 0.5,
		"range": 1.5,
		"speed": 6.0,
		"is_vision": false,
		"is_flying": false
	},
	"observer": {
		"name": "Observer",
		"cost": 150,
		"supply": 1,
		"hp": 60.0,
		"damage": 0.0,
		"cooldown": 1.0,
		"range": 0.0,
		"speed": 5.5,
		"is_vision": true,
		"is_flying": true
	},
	"blimp": {
		"name": "Tactical Blimp",
		"cost": 150,
		"supply": 1,
		"hp": 100.0,
		"damage": 0.0,
		"cooldown": 1.0,
		"range": 0.0,
		"speed": 4.5,
		"is_vision": true,
		"is_flying": true
	}
}

const VETERANCY_COST: int = 500


## Evaluates if recruitment is permissible under mineral and supply caps (Task 6.4)
static func can_recruit(
	unit_id: String,
	current_minerals: int,
	current_supply: int,
	max_supply: int
) -> Dictionary:
	var key := unit_id.to_lower()
	if not RECRUIT_CATALOG.has(key):
		return { "can_recruit": false, "reason": "Unidad desconocida" }
	
	var def: Dictionary = RECRUIT_CATALOG[key]
	var cost: int = def["cost"]
	var sup: int = def["supply"]
	
	if current_minerals < cost:
		return { "can_recruit": false, "reason": "Minerales insuficientes (%d necesarios)" % cost }
	
	if (current_supply + sup) > max_supply:
		return { "can_recruit": false, "reason": "Suministro agotado (%d / %d)" % [current_supply, max_supply] }
	
	return { "can_recruit": true, "cost": cost, "supply": sup, "def": def }


## Spawns a recruited unit, deducts minerals, and updates supply (Task 6.3)
static func recruit_unit(
	unit_id: String,
	spawn_pos: Vector3,
	parent_node: Node,
	economy_mgr: SFEEconomyManager,
	current_supply: int,
	max_supply: int,
	has_ace_supreme_buff: bool = false
) -> Node:
	var check := can_recruit(unit_id, economy_mgr.current_minerals if economy_mgr else 999999, current_supply, max_supply)
	if not check["can_recruit"]:
		return null
	
	var def: Dictionary = check["def"]
	var cost: int = check["cost"]
	
	if economy_mgr and economy_mgr.has_method("spend_minerals"):
		economy_mgr.spend_minerals(cost)
	
	var unit := BaseUnit3DScript.new()
	unit.name = "%s_%d" % [def["name"], Time.get_ticks_msec()]
	unit.max_health = def["hp"]
	unit.current_health = def["hp"]
	unit.attack_damage = def["damage"]
	unit.attack_cooldown = def["cooldown"]
	unit.attack_range = def["range"]
	unit.move_speed = def["speed"]
	unit.position = spawn_pos
	
	# Task 6.5: Vision units with Ace become invulnerable
	if def["is_vision"]:
		unit.add_to_group("vision_units")
		if has_ace_supreme_buff:
			unit.set_meta("is_invulnerable", true)
	
	if parent_node:
		parent_node.add_child(unit)
	
	return unit


## Purchases Veterancy for a unit, promoting it to Elite status (Task 6.1)
static func buy_veterancy(target_unit: Node, economy_mgr: SFEEconomyManager) -> bool:
	if not target_unit or not is_instance_valid(target_unit):
		return false
	
	if economy_mgr:
		if economy_mgr.current_minerals < VETERANCY_COST:
			return false
		economy_mgr.spend_minerals(VETERANCY_COST)
	
	if target_unit.has_method("promote_to_elite"):
		target_unit.promote_to_elite()
		return true
	elif target_unit.has_node("EliteComponent"):
		var elite_comp = target_unit.get_node("EliteComponent")
		if elite_comp.has_method("promote_to_elite"):
			elite_comp.promote_to_elite()
			return true
	return false
