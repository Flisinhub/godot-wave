class_name SFEEconomyManager
extends Node

## SFEEconomyManager - Central Mineral Wallet & Kill Bounty Processor for SFE5.
## Enforces the Strict Crossfire Nullification Rule (Requirement R3):
## - When allied units or base defenses deliver the lethal blow, mineral bounties
##   are scaled by the active difficulty income multiplier and added to the player's wallet.
## - When hostile infighting, friendly fire between enemies, or environmental hazards
##   destroy an entity, the kill is nullified and awards EXACTLY 0 minerals.

const EconomyTypes = preload("res://core/economy/economy_types.gd")
const SFEDifficultyManager = preload("res://core/economy/sfe_difficulty_manager.gd")

## Primary lifecycle signals per Milestone 3 specification
signal minerals_changed(new_amount: int, delta: int, reason: String)
signal kill_bounty_awarded(victim: Object, killer: Object, bounty: int, faction: int)
signal kill_bounty_nullified(victim: Object, killer_faction: int, reason: String)

## Downstream & Explorer survey compatibility signals
signal bounty_awarded(amount: int, total_minerals: int, kill_ctx: Object)
signal bounty_nullified(kill_ctx: Object, reason: String)

static var instance: Node = null

## Mineral wallet state
@export var starting_minerals: int = 50
var current_minerals: int = 50
var total_minerals_earned: int = 0
var total_minerals_spent: int = 0

func _init(p_starting_minerals: int = 50) -> void:
	starting_minerals = p_starting_minerals
	current_minerals = starting_minerals
	total_minerals_earned = 0
	total_minerals_spent = 0
	if instance == null:
		instance = self

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	var signal_bus = _get_signal_bus()
	if signal_bus:
		if signal_bus.has_signal("unit_killed_with_context") and not signal_bus.is_connected("unit_killed_with_context", Callable(self, "process_kill")):
			signal_bus.connect("unit_killed_with_context", Callable(self, "process_kill"))

## Resets wallet back to starting minerals and clears cumulative counters.
func reset(p_starting_minerals: int = 50) -> void:
	starting_minerals = p_starting_minerals
	current_minerals = starting_minerals
	total_minerals_earned = 0
	total_minerals_spent = 0

## Checks if the wallet has sufficient minerals for an expenditure.
func can_afford(cost: int) -> bool:
	return current_minerals >= cost

## Attempts to spend minerals from the wallet. Returns true if successful, false if unaffordable.
func spend_minerals(cost: int, reason: String = "purchase") -> bool:
	if cost < 0 or not can_afford(cost):
		return false
	current_minerals -= cost
	total_minerals_spent += cost
	minerals_changed.emit(current_minerals, -cost, reason)
	
	var signal_bus = _get_signal_bus()
	if signal_bus and signal_bus.has_signal("minerals_updated"):
		signal_bus.emit_signal("minerals_updated", current_minerals)
	return true

## Directly credits minerals to the wallet (e.g. from mission rewards or starting bonuses).
func add_minerals(amount: int, reason: String = "credit") -> void:
	if amount <= 0:
		return
	current_minerals += amount
	total_minerals_earned += amount
	minerals_changed.emit(current_minerals, amount, reason)
	
	var signal_bus = _get_signal_bus()
	if signal_bus and signal_bus.has_signal("minerals_updated"):
		signal_bus.emit_signal("minerals_updated", current_minerals)

## Alias for add_minerals for API robustness
func award_minerals(amount: int, reason: String = "credit") -> void:
	add_minerals(amount, reason)

## Processes a lethal kill event and evaluates bounty eligibility via the Crossfire Nullification Rule.
## Returns the net minerals awarded (>= 0).
func process_kill(kill_context: Variant) -> int:
	if kill_context == null:
		kill_bounty_nullified.emit(null, -1, "KillContext is null")
		bounty_nullified.emit(null, "KillContext is null")
		return 0
		
	var killer_faction: int = EconomyTypes.Faction.HOSTILE
	var base_bounty: int = 0
	var victim: Object = null
	var killer: Object = null
	
	# Extract parameters from KillContext, Dictionary, or Mock RefCounted
	if kill_context is Dictionary:
		killer_faction = kill_context.get("killer_faction", EconomyTypes.Faction.HOSTILE)
		base_bounty = kill_context.get("base_bounty", 0)
		victim = kill_context.get("victim", null)
		killer = kill_context.get("killer", null)
	else:
		if "killer_faction" in kill_context:
			killer_faction = kill_context.killer_faction
		elif kill_context.has_meta("killer_faction"):
			killer_faction = kill_context.get_meta("killer_faction")
			
		if "base_bounty" in kill_context:
			base_bounty = kill_context.base_bounty
		elif kill_context.has_meta("base_bounty"):
			base_bounty = kill_context.get_meta("base_bounty")
			
		if "victim" in kill_context:
			victim = kill_context.victim
		elif kill_context.has_meta("victim"):
			victim = kill_context.get_meta("victim")
			
		if "killer" in kill_context:
			killer = kill_context.killer
		elif kill_context.has_meta("killer"):
			killer = kill_context.get_meta("killer")

	# -------------------------------------------------------------------------
	# STRICT CROSSFIRE NULLIFICATION RULE (Requirement R3):
	# When hostile infighting, crossfire, or environmental hazards kill an entity,
	# the player receives strictly 0 minerals.
	# Only lethal blows delivered by Faction.ALLIED are credited.
	# -------------------------------------------------------------------------
	if killer_faction != EconomyTypes.Faction.ALLIED:
		var nullify_reason: String = "Lethal blow was non-allied (crossfire/friendly fire/hazard)"
		kill_bounty_nullified.emit(victim, killer_faction, nullify_reason)
		bounty_nullified.emit(kill_context, nullify_reason)
		
		var signal_bus = _get_signal_bus()
		if signal_bus and signal_bus.has_signal("bounty_nullified"):
			signal_bus.emit_signal("bounty_nullified", kill_context)
		return 0

	# Allied lethal blow confirmed -> Apply Dynamic Difficulty Income Multiplier
	var income_mult: float = SFEDifficultyManager.get_income_rate_multiplier()
	var awarded_bounty: int = 0
	if base_bounty > 0:
		awarded_bounty = maxi(1, int(round(float(base_bounty) * income_mult)))

	if awarded_bounty > 0:
		add_minerals(awarded_bounty, "kill_bounty")

	kill_bounty_awarded.emit(victim, killer, awarded_bounty, killer_faction)
	bounty_awarded.emit(awarded_bounty, current_minerals, kill_context)

	var signal_bus = _get_signal_bus()
	if signal_bus and signal_bus.has_signal("bounty_awarded"):
		signal_bus.emit_signal("bounty_awarded", awarded_bounty, current_minerals)

	return awarded_bounty

func _get_signal_bus() -> Object:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null
