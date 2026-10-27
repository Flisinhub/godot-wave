class_name BuffComponent
extends Node

## BuffComponent - SFE5 Tier 1-7 and Supreme Buff System (Tasks 4.11 - 4.20).
## SFE5 Rules:
## 1. Strictly one active buff per tier (Tiers 1 to 7).
## 2. Supreme Buffs: Ace, Demiurge (cheat-death 180s cd), Máxima Experiencia (level 100).
## 3. Dynamic condition engine: Momentum (stacks while moving), Predator (+100% vs heroic),
##    Static Charge (+10 stacks), Optical Lens (camouflage after 2s without damage),
##    Bulwark (+5% per stack while stationary).

signal buff_applied(tier: int, buff_id: String, buff_name: String)
signal buff_removed(tier: int, buff_id: String)
signal demiurge_triggered()
signal optical_lens_state_changed(is_camouflaged: bool)
signal momentum_stacks_changed(stacks: int)

# Active buffs per tier (1 to 7): tier (int) -> Dictionary
# { "id": String, "name": String, "cost": int }
var active_tier_buffs: Dictionary = {}

# Supreme buffs active: id (String) -> bool
var supreme_buffs: Dictionary = {
	"ace": false,
	"demiurge": false,
	"maxima_experiencia": false
}

# Runtime Condition States
var time_since_last_damage: float = 10.0
var time_stationary: float = 0.0
var is_moving: bool = false

# Stack trackers
var momentum_stacks: int = 0         ## T3 Momentum: 0..5 stacks (+5% damage each)
var static_charge_stacks: int = 0     ## T4 Static Charge: 0..10 stacks (+1% dmg, +2 reg/s)
var bulwark_stacks: int = 0           ## T6 Bulwark: 0..5 stacks (+5% reduction while stationary)

# Supreme State Trackers
var demiurge_cooldown_timer: float = 0.0
var demiurge_available: bool = false
var is_camouflaged: bool = false
var is_ace_active: bool = false


func _ready() -> void:
	pass


## Applies or replaces a buff in a specific tier (Tasks 4.12 - 4.16).
## SFE5 Rule: Strictly one buff per tier. Replaces existing buff with 50% partial refund.
func equip_tier_buff(tier: int, buff_id: String, buff_name: String, cost: int) -> Dictionary:
	var refund: int = 0
	var replaced_id: String = ""

	if active_tier_buffs.has(tier):
		var prev: Dictionary = active_tier_buffs[tier]
		replaced_id = prev.get("id", "")
		refund = int(float(prev.get("cost", 0)) * 0.5)
		buff_removed.emit(tier, replaced_id)

	active_tier_buffs[tier] = {
		"id": buff_id,
		"name": buff_name,
		"cost": cost
	}

	# Reset conditions for newly equipped buffs
	if buff_id == "momentum":
		momentum_stacks = 0
	elif buff_id == "static_charge":
		static_charge_stacks = 5

	buff_applied.emit(tier, buff_id, buff_name)
	return {
		"replaced_id": replaced_id,
		"refund": refund
	}


func has_buff(buff_id: String) -> bool:
	for b in active_tier_buffs.values():
		if b.get("id", "") == buff_id:
			return true
	return supreme_buffs.get(buff_id, false)


func get_buff_in_tier(tier: int) -> Dictionary:
	return active_tier_buffs.get(tier, {})


## Evaluates dynamic buff conditions based on unit motion, damage, and timers (Task 4.11)
func update_conditions(delta: float, unit_speed: float, unit_energy_ratio: float = 1.0) -> void:
	# 1. Damage clock
	time_since_last_damage += delta

	# 2. Motion clock (Momentum vs Bulwark)
	if unit_speed > 0.2:
		is_moving = true
		time_stationary = 0.0
		bulwark_stacks = 0
		if has_buff("momentum"):
			# Accumulate 1 stack per 0.6 seconds of continuous motion, up to 5 stacks
			momentum_stacks = mini(5, momentum_stacks + 1)
			momentum_stacks_changed.emit(momentum_stacks)
	else:
		is_moving = false
		time_stationary += delta
		if momentum_stacks > 0:
			momentum_stacks = 0
			momentum_stacks_changed.emit(0)
		if has_buff("bulwark") or has_buff("braced"):
			bulwark_stacks = mini(5, int(time_stationary / 1.0))

	# 3. Optical Lens (Tier 1): Camouflage if no damage taken for 2.0s
	if has_buff("optical_lens"):
		var should_cloak: bool = (time_since_last_damage >= 2.0)
		if should_cloak != is_camouflaged:
			is_camouflaged = should_cloak
			optical_lens_state_changed.emit(is_camouflaged)
	else:
		if is_camouflaged:
			is_camouflaged = false
			optical_lens_state_changed.emit(false)

	# 4. Static Charge (Tier 4): Slowly charges up to 10 stacks over time
	if has_buff("static_charge"):
		static_charge_stacks = mini(10, static_charge_stacks + 1)

	# 5. Demiurge Cooldown Timer
	if supreme_buffs.get("demiurge", false):
		if demiurge_cooldown_timer > 0.0:
			demiurge_cooldown_timer = maxf(0.0, demiurge_cooldown_timer - delta)
			if demiurge_cooldown_timer == 0.0:
				demiurge_available = true


func record_damage_taken() -> void:
	time_since_last_damage = 0.0
	if is_camouflaged:
		is_camouflaged = false
		optical_lens_state_changed.emit(false)


## Computes cumulative attack damage multiplier from active buffs (Momentum, Predator, Static Charge)
func get_damage_multiplier(target_is_heroic: bool = false) -> float:
	var mult: float = 1.0

	# Momentum: +5% per stack (up to +25%)
	if has_buff("momentum"):
		mult += float(momentum_stacks) * 0.05

	# Predator: +100% vs Heroic targets; +150% if no damage taken in last 5 seconds
	if has_buff("predator") and target_is_heroic:
		mult += 1.0
		if time_since_last_damage >= 5.0:
			mult += 0.5

	# Static Charge: +1% per stack (up to +10%)
	if has_buff("static_charge"):
		mult += float(static_charge_stacks) * 0.01

	# Ace supreme buff: +50% global damage
	if supreme_buffs.get("ace", false):
		mult += 0.5

	return mult


## Computes damage mitigation ratio from defensive buffs (Bulwark)
func get_mitigation_ratio() -> float:
	var ratio: float = 0.0
	if has_buff("bulwark") or has_buff("braced"):
		ratio += float(bulwark_stacks) * 0.05 # up to 25% mitigation while stationary
	return minf(0.5, ratio)


# -------------------------------------------------------------
# SUPREME BUFFS (Tasks 4.18 - 4.20)
# -------------------------------------------------------------

## Ace (As): Grants supreme combat power or vision invulnerability
func unlock_ace() -> void:
	supreme_buffs["ace"] = true
	is_ace_active = true


## Demiurge: Cheat-death mechanism (prevents fatal damage once every 180s)
func unlock_demiurge() -> void:
	supreme_buffs["demiurge"] = true
	demiurge_available = true
	demiurge_cooldown_timer = 0.0


## Called when the unit receives fatal damage.
## If Demiurge is available, cancels death, restores 35% HP, and starts 180s cooldown.
func attempt_cheat_death() -> bool:
	if supreme_buffs.get("demiurge", false) and demiurge_available:
		demiurge_available = false
		demiurge_cooldown_timer = 180.0
		demiurge_triggered.emit()
		return true # Death cancelled!
	return false


## Máxima Experiencia (Nivel 100 - Task 4.20)
## Cost is 75,000 minerals minus 750 refund per each level already possessed.
func calculate_maxima_experiencia_cost(current_level: int) -> int:
	var refund := current_level * 750
	return maxi(0, 75000 - refund)


func purchase_maxima_experiencia(current_level: int, available_minerals: int) -> Dictionary:
	var cost := calculate_maxima_experiencia_cost(current_level)
	if available_minerals < cost:
		return { "success": false, "cost": cost, "remaining": available_minerals }
	
	supreme_buffs["maxima_experiencia"] = true
	return {
		"success": true,
		"cost": cost,
		"refund_amount": current_level * 750,
		"remaining": available_minerals - cost
	}


## Strips active buffs upon hero death according to difficulty rules (Task 7.3).
## Returns total mineral refund based on cost_retention percentage (e.g. 0.25 -> 25% cost retained).
func strip_buffs_on_death(cost_retention: float = 0.0) -> int:
	var total_refund: int = 0
	for tier in active_tier_buffs.keys():
		var buff_info: Dictionary = active_tier_buffs[tier]
		var cost: int = buff_info.get("cost", 0)
		total_refund += int(float(cost) * cost_retention)
		buff_removed.emit(tier, buff_info.get("id", ""))
	
	active_tier_buffs.clear()
	momentum_stacks = 0
	static_charge_stacks = 0
	bulwark_stacks = 0
	is_camouflaged = false
	return total_refund
