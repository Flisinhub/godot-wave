class_name SFEDifficultyManager
extends Node

## SFEDifficultyManager - Dynamic Difficulty Scaling Engine for SFE5.
## Simultaneously modulates three core parameters across 5 difficulty tiers (Requirement R3):
## 1. Player income rate multiplier (Casual: 1.50x -> Torment: 0.50x)
## 2. Enemy health and damage stat multiplier (Casual: 0.75x -> Torment: 2.50x)
## 3. Swarm automatic hive upgrade cadence (Casual: 180s -> Torment: 40s)

const EconomyTypes = preload("res://core/economy/economy_types.gd")

signal difficulty_changed(new_tier: int)
signal swarm_hive_upgraded(new_hive_level: int)

static var instance: Node = null

## State variables
static var current_tier: int = 1 # 1 = NORMAL
static var hive_level: int = 0
static var cadence_timer: float = 120.0

func _init() -> void:
	if instance == null:
		instance = self

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _process(delta: float) -> void:
	cadence_timer -= delta
	if cadence_timer <= 0.0:
		cadence_timer = get_upgrade_cadence()
		hive_level += 1
		swarm_hive_upgraded.emit(hive_level)
		var signal_bus = _get_signal_bus()
		if signal_bus and signal_bus.has_signal("swarm_hive_upgraded"):
			signal_bus.emit_signal("swarm_hive_upgraded", hive_level)

## Sets the current difficulty tier and resets the hive evolution cadence timer.
static func set_difficulty(tier: int) -> void:
	current_tier = clampi(tier, 0, 4)
	cadence_timer = get_upgrade_cadence()
	if instance != null and is_instance_valid(instance):
		instance.difficulty_changed.emit(current_tier)
	var signal_bus = _get_signal_bus_static()
	if signal_bus and signal_bus.has_signal("difficulty_changed"):
		signal_bus.emit_signal("difficulty_changed", current_tier)

static func get_difficulty() -> int:
	return current_tier

static func get_difficulty_name() -> String:
	match current_tier:
		0: return "Casual"
		1: return "Normal"
		2: return "Hard"
		3: return "Brutal"
		4: return "Torment"
		_: return "Normal"

## Player income rate multiplier (Requirement R3 & test_runner interface)
static func get_income_multiplier() -> float:
	match current_tier:
		0: return 1.50 # Casual
		1: return 1.00 # Normal
		2: return 0.80 # Hard
		3: return 0.65 # Brutal
		4: return 0.50 # Torment
		_: return 1.00

## Alias for test_r3_economy.gd compatibility
static func get_income_rate_multiplier() -> float:
	return get_income_multiplier()

## Enemy health & damage stat multiplier
static func get_enemy_stat_multiplier() -> float:
	match current_tier:
		0: return 0.75 # Casual
		1: return 1.00 # Normal
		2: return 1.30 # Hard
		3: return 1.75 # Brutal
		4: return 2.50 # Torment
		_: return 1.00

## Swarm automatic hive upgrade cadence interval in seconds
static func get_upgrade_cadence() -> float:
	match current_tier:
		0: return 180.0 # Casual
		1: return 120.0 # Normal
		2: return 90.0  # Hard
		3: return 60.0  # Brutal
		4: return 40.0  # Torment
		_: return 120.0

## Helper to calculate scaled enemy HP taking difficulty and hive evolution level into account
static func get_scaled_enemy_hp(base_hp: float) -> float:
	return base_hp * get_enemy_stat_multiplier() * (1.0 + float(hive_level) * 0.05)

## Helper to calculate scaled enemy damage taking difficulty and hive evolution level into account
static func get_scaled_enemy_damage(base_damage: float) -> float:
	return base_damage * get_enemy_stat_multiplier() * (1.0 + float(hive_level) * 0.04)

## Resets difficulty state to default baseline
static func reset() -> void:
	current_tier = 1
	hive_level = 0
	cadence_timer = get_upgrade_cadence()

func _get_signal_bus() -> Object:
	return _get_signal_bus_static()

static func _get_signal_bus_static() -> Object:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null
