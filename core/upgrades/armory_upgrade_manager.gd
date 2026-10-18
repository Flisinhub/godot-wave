class_name ArmoryUpgradeManager
extends Node

## ArmoryUpgradeManager - Central Upgrades Subsystem & Turret Deployment Controller.
## Implements Milestone 2: Features 5, 6, 7, and 8 of SFE5 Phase 2.
## Manages Ballistics T1-5, Armor T1-5, Hero Abilities, Turret Deployments,
## atomic SFEEconomyManager transactions, and BankManager persistence.

const AutoTurret3D = preload("res://entities/structures/auto_turret_3d.gd")

signal upgrade_purchased(category: StringName, new_tier: int, cost: int)
signal turret_deployed(turret: Node3D, remaining_cap: int)
signal ability_unlocked(ability_id: StringName, new_tier: int)

const BALLISTICS_COSTS: Array[int] = [100, 250, 500, 900, 1500]
const ARMOR_COSTS: Array[int] = [100, 225, 450, 800, 1400]
const STIMPACK_COSTS: Array[int] = [150, 300, 550]
const PENETRATING_COSTS: Array[int] = [200, 400, 700]
const ORBITAL_COST: int = 800
const TURRET_COST: int = 125

const MAX_UPGRADE_TIER: int = 5
const MAX_TURRETS: int = 6
const MAX_BASE_RADIUS: float = 24.0

static var instance: ArmoryUpgradeManager = null

var ballistics_tier: int = 0
var armor_tier: int = 0
var stimpack_tier: int = 0
var penetrating_round_tier: int = 0
var orbital_bombardment_unlocked: bool = false

var deployed_turrets: Array[Node3D] = []
var _economy_override: Object = null


func _init() -> void:
	if instance == null:
		instance = self


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	load_upgrades_from_bank()


func set_economy_manager(econ: Object) -> void:
	_economy_override = econ


func _get_economy() -> Object:
	if _economy_override != null:
		return _economy_override
	var SFEEconomyManagerScript: GDScript = load("res://core/economy/sfe_economy_manager.gd") as GDScript
	if SFEEconomyManagerScript and SFEEconomyManagerScript.instance:
		return SFEEconomyManagerScript.instance as Object
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			return tree.current_scene.get_node_or_null("EconomyManager") as Object
	return null


# ==============================================================================
# FEATURE 5: Ballistics Arsenal Upgrades (Tiers 1–5)
# ==============================================================================

func can_purchase_ballistics() -> bool:
	if ballistics_tier >= MAX_UPGRADE_TIER:
		return false
	var econ: Object = _get_economy()
	if econ == null:
		return false
	return bool(econ.can_afford(BALLISTICS_COSTS[ballistics_tier]))


func purchase_ballistics() -> bool:
	if not can_purchase_ballistics():
		return false
	var cost: int = BALLISTICS_COSTS[ballistics_tier]
	var econ: Object = _get_economy()
	if econ and bool(econ.spend_minerals(cost, "Ballistics Tier %d" % (ballistics_tier + 1))):
		ballistics_tier += 1
		upgrade_purchased.emit(&"ballistics", ballistics_tier, cost)
		_apply_ballistics_upgrades()
		save_upgrades_to_bank()
		return true
	return false


func get_ballistics_damage_multiplier() -> float:
	return 1.0 + (0.15 * ballistics_tier)


func get_ballistics_cadence_multiplier() -> float:
	return 1.0 + (0.08 * ballistics_tier)


func get_ballistics_range_bonus() -> float:
	return 0.6 * ballistics_tier


func _apply_ballistics_upgrades() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var turrets: Array[Node] = tree.get_nodes_in_group("turrets")
	for turret: Node in turrets:
		if turret is Node3D and turret.has_method("apply_armory_upgrades"):
			turret.apply_armory_upgrades(ballistics_tier, armor_tier)


# ==============================================================================
# FEATURE 6: Armor & Survival Upgrades (Tiers 1–5)
# ==============================================================================

func can_purchase_armor() -> bool:
	if armor_tier >= MAX_UPGRADE_TIER:
		return false
	var econ: Object = _get_economy()
	if econ == null:
		return false
	return bool(econ.can_afford(ARMOR_COSTS[armor_tier]))


func purchase_armor() -> bool:
	if not can_purchase_armor():
		return false
	var cost: int = ARMOR_COSTS[armor_tier]
	var econ: Object = _get_economy()
	if econ and bool(econ.spend_minerals(cost, "Armor Tier %d" % (armor_tier + 1))):
		armor_tier += 1
		upgrade_purchased.emit(&"armor", armor_tier, cost)
		_apply_armor_upgrades()
		save_upgrades_to_bank()
		return true
	return false


func get_armor_flat_bonus() -> float:
	return 2.0 * armor_tier


func get_armor_hp_regen() -> float:
	return 2.5 * armor_tier


func get_armor_max_shield() -> float:
	return 80.0 * armor_tier


func get_structural_mitigation_bonus() -> float:
	return 0.04 * armor_tier


func _apply_armor_upgrades() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var turrets: Array[Node] = tree.get_nodes_in_group("turrets")
	for turret: Node in turrets:
		if turret is Node3D and turret.has_method("apply_armory_upgrades"):
			turret.apply_armory_upgrades(ballistics_tier, armor_tier)


# ==============================================================================
# FEATURE 7: Hero Ability Progression & Ultimates
# ==============================================================================

func can_purchase_hero_ability(ability_id: StringName) -> bool:
	var econ: Object = _get_economy()
	if econ == null:
		return false

	match ability_id:
		&"stimpack":
			if stimpack_tier >= 3:
				return false
			return bool(econ.can_afford(STIMPACK_COSTS[stimpack_tier]))
		&"penetrating_round":
			if penetrating_round_tier >= 3:
				return false
			return bool(econ.can_afford(PENETRATING_COSTS[penetrating_round_tier]))
		&"orbital_bombardment":
			if orbital_bombardment_unlocked:
				return false
			return bool(econ.can_afford(ORBITAL_COST))
		_:
			return false


func purchase_hero_ability(ability_id: StringName) -> bool:
	if not can_purchase_hero_ability(ability_id):
		return false
	var econ: Object = _get_economy()
	if econ == null:
		return false

	match ability_id:
		&"stimpack":
			var cost: int = STIMPACK_COSTS[stimpack_tier]
			if bool(econ.spend_minerals(cost, "Stimpack Tier %d" % (stimpack_tier + 1))):
				stimpack_tier += 1
				upgrade_purchased.emit(ability_id, stimpack_tier, cost)
				ability_unlocked.emit(ability_id, stimpack_tier)
				_apply_hero_ability_upgrades()
				save_upgrades_to_bank()
				return true
		&"penetrating_round":
			var cost: int = PENETRATING_COSTS[penetrating_round_tier]
			if bool(econ.spend_minerals(cost, "Penetrating Round Tier %d" % (penetrating_round_tier + 1))):
				penetrating_round_tier += 1
				upgrade_purchased.emit(ability_id, penetrating_round_tier, cost)
				ability_unlocked.emit(ability_id, penetrating_round_tier)
				_apply_hero_ability_upgrades()
				save_upgrades_to_bank()
				return true
		&"orbital_bombardment":
			if bool(econ.spend_minerals(ORBITAL_COST, "Unlock Orbital Bombardment")):
				orbital_bombardment_unlocked = true
				upgrade_purchased.emit(ability_id, 1, ORBITAL_COST)
				ability_unlocked.emit(ability_id, 1)
				_apply_hero_ability_upgrades()
				save_upgrades_to_bank()
				return true
	return false


func get_stimpack_hp_cost() -> int:
	var costs: Array[int] = [20, 12, 6, 0]
	return costs[clampi(stimpack_tier, 0, 3)]


func get_penetrating_round_cooldown() -> float:
	var cds: Array[float] = [8.0, 6.5, 5.0, 3.5]
	return cds[clampi(penetrating_round_tier, 0, 3)]


func get_penetrating_round_energy() -> float:
	var energies: Array[float] = [30.0, 22.0, 16.0, 10.0]
	return energies[clampi(penetrating_round_tier, 0, 3)]


func _apply_hero_ability_upgrades() -> void:
	var stim_res: Resource = load("res://data/skills/stimpack.tres") as Resource
	if stim_res != null:
		stim_res.set("current_rank", stimpack_tier + 1)
	var pen_res: Resource = load("res://data/skills/penetrating_round.tres") as Resource
	if pen_res != null:
		pen_res.set("current_rank", penetrating_round_tier + 1)
		pen_res.set("cooldown", get_penetrating_round_cooldown())
		pen_res.set("energy_cost", get_penetrating_round_energy())


# ==============================================================================
# FEATURE 8: Automated Perimeter Turrets Deployment
# ==============================================================================

func can_deploy_turret() -> bool:
	_cleanup_turrets()
	if deployed_turrets.size() >= MAX_TURRETS:
		return false
	var econ: Object = _get_economy()
	if econ == null or not bool(econ.can_afford(TURRET_COST)):
		return false
	return true


func is_valid_turret_position(world_pos: Vector3) -> bool:
	var cc_pos: Vector3 = _get_command_center_position()
	if cc_pos.distance_to(world_pos) > MAX_BASE_RADIUS:
		return false
	var flow_field: Variant = _get_flow_field()
	if flow_field != null and flow_field.has_method("world_to_grid") and flow_field.has_method("get_cell_cost"):
		var grid_pos: Vector2i = flow_field.world_to_grid(Vector2(world_pos.x, world_pos.z))
		var cost: int = flow_field.get_cell_cost(grid_pos.x, grid_pos.y)
		if cost >= 15:
			return false
	return true


func deploy_turret(world_position: Vector3) -> AutoTurret3D:
	if not can_deploy_turret():
		return null
	if not is_valid_turret_position(world_position):
		return null
	var econ: Object = _get_economy()
	if econ == null or not bool(econ.spend_minerals(TURRET_COST, "Deploy AutoTurret")):
		return null

	var turret: AutoTurret3D = null
	var turret_scene: PackedScene = load("res://entities/structures/auto_turret_3d.tscn") as PackedScene
	if turret_scene != null:
		turret = turret_scene.instantiate() as AutoTurret3D
	if turret == null:
		turret = AutoTurret3D.new() as AutoTurret3D

	if turret != null:
		turret.global_position = world_position
		turret.apply_armory_upgrades(ballistics_tier, armor_tier)

		var parent: Node = _get_turret_parent()
		if parent != null:
			parent.add_child(turret)

		deployed_turrets.append(turret)
		turret.tree_exited.connect(_cleanup_turrets)
		turret.turret_destroyed.connect(func(_t: AutoTurret3D) -> void:
			_cleanup_turrets()
			turret_deployed.emit(null, MAX_TURRETS - deployed_turrets.size())
		)

		turret_deployed.emit(turret, MAX_TURRETS - deployed_turrets.size())
	return turret


func _cleanup_turrets() -> void:
	var valid: Array[Node3D] = []
	for t: Node3D in deployed_turrets:
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			valid.append(t)
	deployed_turrets = valid


func _get_command_center_position() -> Vector3:
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			var cc: Node = tree.current_scene.find_child("CommandCenter", true, false)
			if cc is Node3D:
				return (cc as Node3D).global_position
	return Vector3.ZERO


func _get_flow_field() -> Variant:
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			var swarm_sim: Node = tree.current_scene.get_node_or_null("SwarmSimulation")
			if swarm_sim and "flow_field" in swarm_sim:
				return swarm_sim.get("flow_field")
	return null


func _get_turret_parent() -> Node:
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree and tree.current_scene:
			var perimeter: Node = tree.current_scene.get_node_or_null("NavigationRegion3D/BasePerimeter")
			if perimeter != null:
				return perimeter
			return tree.current_scene
	return null


# ==============================================================================
# BankManager Integration
# ==============================================================================

func save_upgrades_to_bank() -> bool:
	var BankManagerScript: GDScript = load("res://core/persistence/bank_manager.gd") as GDScript
	if BankManagerScript and BankManagerScript.has_method("load_bank") and BankManagerScript.has_method("save_bank"):
		var bank: Dictionary = BankManagerScript.load_bank()
		if bank != null:
			bank["upgrades"] = {
				"ballistics_tier": ballistics_tier,
				"armor_tier": armor_tier,
				"stimpack_tier": stimpack_tier,
				"penetrating_round_tier": penetrating_round_tier,
				"orbital_bombardment_unlocked": orbital_bombardment_unlocked
			}
			return bool(BankManagerScript.save_bank(bank))
	return false


func load_upgrades_from_bank() -> void:
	var BankManagerScript: GDScript = load("res://core/persistence/bank_manager.gd") as GDScript
	if BankManagerScript and BankManagerScript.has_method("load_bank"):
		var bank: Dictionary = BankManagerScript.load_bank()
		if bank != null and bank.has("upgrades") and bank["upgrades"] is Dictionary:
			var u: Dictionary = bank["upgrades"]
			ballistics_tier = clampi(int(u.get("ballistics_tier", 0)), 0, MAX_UPGRADE_TIER)
			armor_tier = clampi(int(u.get("armor_tier", 0)), 0, MAX_UPGRADE_TIER)
			stimpack_tier = clampi(int(u.get("stimpack_tier", 0)), 0, 3)
			penetrating_round_tier = clampi(int(u.get("penetrating_round_tier", 0)), 0, 3)
			orbital_bombardment_unlocked = bool(u.get("orbital_bombardment_unlocked", false))
