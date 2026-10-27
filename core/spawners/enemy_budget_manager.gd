class_name EnemyBudgetManager
extends RefCounted

## EnemyBudgetManager - Global Budget Controller for SFE5 Living Horde (Task 3.4).
## SFE5 Rule: Maximum 300 living enemies. If budget is exceeded, spawners pause cycle production.
## Resumes immediately when living count drops below 300 (to 299 or less).

const GameConfig = preload("res://core/game_config.gd")

var max_budget: int = GameConfig.MAX_LIVING_ENEMIES_BUDGET
var swarm_simulation: Node = null
var extra_living_enemies: Array[Node] = []
var _was_saturated: bool = false

signal budget_saturated(is_saturated: bool)


func _init(p_max_budget: int = GameConfig.MAX_LIVING_ENEMIES_BUDGET) -> void:
	max_budget = p_max_budget


func set_simulation(sim: Node) -> void:
	swarm_simulation = sim


func register_extra_enemy(enemy_node: Node) -> void:
	if enemy_node and not extra_living_enemies.has(enemy_node):
		extra_living_enemies.append(enemy_node)
		_check_saturation()


func unregister_extra_enemy(enemy_node: Node) -> void:
	extra_living_enemies.erase(enemy_node)
	_check_saturation()


## Returns current number of active enemies in swarm simulation plus tracked standalone nodes.
func get_living_count() -> int:
	var count: int = 0
	if swarm_simulation and is_instance_valid(swarm_simulation):
		if swarm_simulation.has_method("get_active_unit_count"):
			count += swarm_simulation.get_active_unit_count()
	
	# Clean up invalid extra enemy references
	var valid_extra: Array[Node] = []
	for e in extra_living_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			valid_extra.append(e)
	extra_living_enemies = valid_extra
	count += extra_living_enemies.size()
	
	return count


## Returns true if spawning the given count will not exceed the hard living cap.
func can_spawn(count: int = 1) -> bool:
	return (get_living_count() + count) <= max_budget


## Returns true if the budget is currently at or above the maximum limit.
func is_saturated() -> bool:
	return get_living_count() >= max_budget


## Internal check to emit signals on state change
func _check_saturation() -> void:
	var sat := is_saturated()
	if sat != _was_saturated:
		_was_saturated = sat
		budget_saturated.emit(sat)
