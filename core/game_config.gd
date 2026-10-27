class_name GameConfigScript
extends Node

## GameConfig - Central Configuration and Balance Constants for SFE5 Godot.
## Pure data and gameplay constants referenced across economy, swarm, and game modes.

const MAX_LIVING_ENEMIES_BUDGET: int = 300
const SPAWNER_CYCLE_SECONDS: float = 20.0
const DROP_POD_INTERVAL_SECONDS: float = 45.0
const DROP_POD_GRACE_PERIOD_SECONDS: float = 120.0
const TIMED_ATTACK_INTERVAL_SECONDS: float = 300.0
const DEFAULT_SEED: int = 12345
const SPAWNER_COUNT_DEFAULT: int = 6

# Difficulty Income Multipliers
const DIFFICULTY_INCOME_MULTIPLIERS: Dictionary = {
	0: 1.15, # Casual
	1: 1.00, # Normal
	2: 0.80, # Hard
	3: 0.70, # Brutal
	4: 0.60, # Torment
	5: 0.30  # Impossible
}

# Category Multipliers for SFE5 Income Formula
const CATEGORY_MULTIPLIERS: Dictionary = {
	"normal": 1.0,
	"structure": 8.0,
	"heroic": 4.0,
	"elite": 6.0,
	"map_boss": 6.0,
	"summoned_boss": 2.0,
	"pinnacle_boss": 6.0
}

# Category Colors for SFE5 Floating Combat Text
const CATEGORY_COLORS: Dictionary = {
	"structure": Color(0.2, 1.0, 0.3),      # Green
	"heroic": Color(1.0, 0.9, 0.2),         # Yellow
	"elite": Color(1.0, 0.55, 0.1),         # Orange
	"map_boss": Color(1.0, 0.55, 0.1),      # Orange
	"summoned_boss": Color(1.0, 0.25, 0.25),# Red
	"pinnacle_boss": Color(1.0, 0.25, 0.25),# Red
	"boss": Color(1.0, 0.25, 0.25),          # Red
	"normal": Color(0.2, 0.95, 1.0)          # Cyan
}

static func get_category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category.to_lower(), Color(0.2, 0.95, 1.0))

# Supply Constants
const BASE_SUPPLY_SOLO: int = 80
const SUPPLY_PENALTY_PER_EXTRA_PLAYER: int = 10
const MIN_SUPPLY_FLOOR: int = 30

# SFE5 Attribute Scaling & Costs (Tasks 4.1 & 4.7)
const ATTRIBUTE_BASE_COST: int = 50
const ATTRIBUTE_COST_INCREMENT_PER_TIER: int = 5
const ATTRIBUTE_TIER_STEP: int = 10

const STR_HP_BONUS: float = 15.0
const STR_DAMAGE_BONUS: float = 0.8

const DEX_ATTACK_SPEED_BONUS: float = 0.012 # +1.2% attack rate
const DEX_RANGED_DAMAGE_BONUS: float = 0.7

const INT_ENERGY_BONUS: float = 10.0
const INT_ENERGY_REGEN_BONUS: float = 0.25
const INT_ABILITY_POWER_BONUS: float = 0.015 # +1.5% ability power

const END_ARMOR_BONUS: float = 0.12
const END_HP_REGEN_BONUS: float = 0.35

# SFE5 Neutron Armor Constants (Task 4.10)
const NEUTRON_ARMOR_BASE_COST: int = 250
const NEUTRON_ARMOR_COST_STEP: int = 150
const NEUTRON_ARMOR_MITIGATION_PER_LEVEL: float = 1.5

static func get_attribute_cost(current_points: int) -> int:
	return ATTRIBUTE_BASE_COST + (int(current_points / ATTRIBUTE_TIER_STEP) * ATTRIBUTE_COST_INCREMENT_PER_TIER)

static func get_neutron_armor_cost(current_level: int) -> int:
	return NEUTRON_ARMOR_BASE_COST + (current_level * NEUTRON_ARMOR_COST_STEP)
