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
const IncomeFormula = preload("res://core/economy/income_formula.gd")
const IncomeParams = preload("res://core/economy/income_params.gd")
const GameConfigScript = preload("res://core/game_config.gd")

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

## Economy Telemetry & Statistics (Fase 1 Requirements)
var minerals_by_source: Dictionary = {
	"kill": 0,
	"initial": 50,
	"puzzle": 0,
	"credit": 0
}
var last_kill_telemetry: Dictionary = {}
var _session_start_time: float = 0.0

func _init(p_starting_minerals: int = 50) -> void:
	starting_minerals = p_starting_minerals
	current_minerals = starting_minerals
	total_minerals_earned = 0
	total_minerals_spent = 0
	minerals_by_source = {
		"kill": 0,
		"initial": p_starting_minerals,
		"puzzle": 0,
		"credit": 0
	}
	_session_start_time = float(Time.get_ticks_msec())
	if instance == null:
		instance = self

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	_session_start_time = float(Time.get_ticks_msec())
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
	minerals_by_source = {
		"kill": 0,
		"initial": p_starting_minerals,
		"puzzle": 0,
		"credit": 0
	}
	last_kill_telemetry = {}
	_session_start_time = float(Time.get_ticks_msec())

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

	var key: String = "credit"
	if reason.begins_with("kill"):
		key = "kill"
	elif reason.begins_with("Pedestal") or reason.begins_with("puzzle"):
		key = "puzzle"
	elif reason.begins_with("initial") or reason.begins_with("Random"):
		key = "initial"
	minerals_by_source[key] = minerals_by_source.get(key, 0) + amount

	minerals_changed.emit(current_minerals, amount, reason)
	
	var signal_bus = _get_signal_bus()
	if signal_bus and signal_bus.has_signal("minerals_updated"):
		signal_bus.emit_signal("minerals_updated", current_minerals)

## Alias for add_minerals for API robustness
func award_minerals(amount: int, reason: String = "credit") -> void:
	add_minerals(amount, reason)

## Calculates current minerals earned per minute.
func get_minerals_per_minute() -> float:
	var sess = _get_game_session()
	var elapsed: float = 0.0
	if sess and "session_elapsed_time" in sess and sess.session_elapsed_time > 0.0:
		elapsed = sess.session_elapsed_time
	else:
		elapsed = (Time.get_ticks_msec() - _session_start_time) / 1000.0
	if elapsed <= 1.0:
		return float(total_minerals_earned)
	return (float(total_minerals_earned) / elapsed) * 60.0

## Returns complete economy statistics dictionary.
func get_economy_stats() -> Dictionary:
	return {
		"current_minerals": current_minerals,
		"total_earned": total_minerals_earned,
		"total_spent": total_minerals_spent,
		"by_source": minerals_by_source.duplicate(),
		"minerals_per_minute": get_minerals_per_minute(),
		"last_kill": last_kill_telemetry.duplicate()
	}

## Processes a lethal kill event and evaluates bounty eligibility via the Crossfire Nullification Rule.
## When income_params is available or extractable from victim, SFE5 Master Income Formula is evaluated.
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
	var inc_params: IncomeParams = null
	
	# Extract parameters from KillContext, Dictionary, or Mock RefCounted
	if kill_context is Dictionary:
		killer_faction = kill_context.get("killer_faction", EconomyTypes.Faction.HOSTILE)
		base_bounty = kill_context.get("base_bounty", 0)
		victim = kill_context.get("victim", null)
		killer = kill_context.get("killer", null)
		if kill_context.has("income_params") and kill_context["income_params"] is IncomeParams:
			inc_params = kill_context["income_params"]
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

		if "income_params" in kill_context and kill_context.income_params is IncomeParams:
			inc_params = kill_context.income_params
		elif kill_context.has_meta("income_params") and kill_context.get_meta("income_params") is IncomeParams:
			inc_params = kill_context.get_meta("income_params")

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

	# -------------------------------------------------------------------------
	# SFE5 MASTER INCOME CALCULATION:
	# If income_params is provided, evaluate pure IncomeFormula.
	# If not provided, inspect victim attributes, or fallback gracefully to base_bounty.
	# -------------------------------------------------------------------------
	if inc_params == null and is_instance_valid(victim):
		inc_params = _try_extract_income_params_from_victim(victim)

	var awarded_bounty: int = 0
	if inc_params != null:
		_sync_income_params_with_session(inc_params)
		awarded_bounty = IncomeFormula.compute(inc_params)
		last_kill_telemetry = {
			"victim_name": victim.name if is_instance_valid(victim) and "name" in victim else inc_params.category,
			"category": inc_params.category,
			"category_mult": inc_params.category_multiplier,
			"hp": inc_params.base_health * inc_params.health_mult,
			"shield": inc_params.base_shield * inc_params.health_mult,
			"damage": inc_params.weapon_damage * inc_params.damage_mult,
			"period": inc_params.attack_period,
			"difficulty_mult": inc_params.difficulty_mult,
			"player_count": inc_params.player_count,
			"split_income": inc_params.split_income,
			"pedestal_bonus": inc_params.pedestal_bonus,
			"bounty": awarded_bounty
		}
	else:
		# Fallback to difficulty-scaled base_bounty for legacy tests & callers
		var income_mult: float = SFEDifficultyManager.get_income_rate_multiplier()
		if base_bounty > 0:
			awarded_bounty = maxi(1, int(round(float(base_bounty) * income_mult)))
		last_kill_telemetry = {
			"victim_name": victim.name if is_instance_valid(victim) and "name" in victim else "LegacyUnit",
			"category": "normal",
			"category_mult": 1.0,
			"hp": 0.0,
			"shield": 0.0,
			"damage": float(base_bounty),
			"period": 1.0,
			"difficulty_mult": income_mult,
			"player_count": 1,
			"split_income": false,
			"pedestal_bonus": 0.0,
			"bounty": awarded_bounty
		}

	if awarded_bounty > 0:
		add_minerals(awarded_bounty, "kill_bounty")

	kill_bounty_awarded.emit(victim, killer, awarded_bounty, killer_faction)
	bounty_awarded.emit(awarded_bounty, current_minerals, kill_context)

	var signal_bus = _get_signal_bus()
	if signal_bus and signal_bus.has_signal("bounty_awarded"):
		signal_bus.emit_signal("bounty_awarded", awarded_bounty, current_minerals)

	return awarded_bounty


func _try_extract_income_params_from_victim(vic: Object) -> IncomeParams:
	if vic.has_method("get_income_params"):
		var res = vic.get_income_params()
		if res is IncomeParams:
			return res
	if "income_params" in vic and vic.income_params is IncomeParams:
		return vic.income_params
	if vic.has_meta("income_params") and vic.get_meta("income_params") is IncomeParams:
		return vic.get_meta("income_params")

	# Inspect standard unit nodes
	if "max_health" in vic:
		var p := IncomeParams.new()
		p.base_health = vic.max_health
		p.weapon_damage = vic.attack_damage if "attack_damage" in vic else 0.0
		p.attack_period = vic.attack_cooldown if "attack_cooldown" in vic else 1.0
		p.has_weapon = (p.weapon_damage > 0.0)

		if vic is Node:
			var n: Node = vic as Node
			if n.is_in_group("bosses") or n.is_in_group("secret_boss"):
				p.category = "map_boss"
				p.category_multiplier = 6.0
			elif n.is_in_group("structures"):
				p.category = "structure"
				p.category_multiplier = 8.0
			elif n.is_in_group("heroic"):
				p.category = "heroic"
				p.category_multiplier = 4.0
		return p

	return null


func _sync_income_params_with_session(p: IncomeParams) -> void:
	var sess = _get_game_session()
	if sess:
		if p.player_count <= 1 and "player_count" in sess:
			p.player_count = sess.player_count
		if "split_income_mode" in sess:
			p.split_income = sess.split_income_mode
		if p.pedestal_bonus == 0.0 and "pedestal_bonus_active" in sess and sess.pedestal_bonus_active:
			p.pedestal_bonus = 50.0
		if p.difficulty_mult == 1.0 and "difficulty_tier" in sess:
			p.difficulty_mult = GameConfigScript.DIFFICULTY_INCOME_MULTIPLIERS.get(sess.difficulty_tier, 1.0)
	elif p.difficulty_mult == 1.0:
		p.difficulty_mult = SFEDifficultyManager.get_income_rate_multiplier()


func _get_game_session() -> Object:
	if Engine.has_singleton("GameSession"):
		return Engine.get_singleton("GameSession")
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameSession"):
		return tree.root.get_node("GameSession")
	return null

func _get_signal_bus() -> Object:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null
