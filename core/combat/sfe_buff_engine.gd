class_name SFEBuffEngine
extends RefCounted

## Buff and Status Engine for SFE5.
## Manages active buffs, stacking caps, invulnerability windows, and duration extensions.

const SFEBuffDef = preload("res://core/combat/sfe_buff_def.gd")
const ActiveBuff = preload("res://core/combat/active_buff.gd")

signal buff_applied(buff_id: StringName, current_stacks: int)
signal buff_refreshed(buff_id: StringName, current_stacks: int, time_remaining: float)
signal buff_expired(buff_id: StringName)
signal buff_removed(buff_id: StringName)
signal invulnerability_changed(is_active: bool)

## Active buffs mapped by buff_id
var _active_buffs: Dictionary = {}

## Percentage duration extension applied to newly applied buffs (e.g. 0.40 = +40%)
var lasting_empowerment_bonus: float = 0.0

## Default stacking limit for standard buffs
const DEFAULT_MAX_STACKS: int = 2

## Extended stacking limit for high-capacity passives (e.g. Tychus)
const EXTENDED_MAX_STACKS_TYCHUS: int = 20

## Applies or stacks a buff on this engine instance.
## Accepts an SFEBuffDef resource, a Dictionary, or a StringName (which auto-loads from res://data/buffs/).
func apply_buff(
	buff_def_or_id: Variant,
	duration_override: float = -1.0,
	max_stacks_override: int = -1,
	lasting_empowerment_override: float = -1.0
) -> ActiveBuff:
	var def: Variant = buff_def_or_id

	# Auto-load from res://data/buffs/ if string or StringName
	if buff_def_or_id is String or buff_def_or_id is StringName:
		var id_str: String = str(buff_def_or_id).to_snake_case()
		var res_path: String = "res://data/buffs/%s.tres" % id_str
		if ResourceLoader.exists(res_path):
			def = load(res_path)
		else:
			# Fallback definition if no .tres file found
			def = SFEBuffDef.new(StringName(buff_def_or_id), str(buff_def_or_id), 5.0, DEFAULT_MAX_STACKS)

	# Extract buff_id
	var buff_id: StringName = &""
	var base_duration: float = 5.0
	var default_max_stacks: int = DEFAULT_MAX_STACKS
	var is_invuln: bool = false

	if def is SFEBuffDef:
		buff_id = def.buff_id
		base_duration = def.default_duration
		default_max_stacks = def.default_max_stacks
		is_invuln = def.is_invulnerable
	elif def is Dictionary:
		buff_id = def.get("buff_id", &"custom_buff")
		base_duration = def.get("default_duration", 5.0)
		default_max_stacks = def.get("default_max_stacks", DEFAULT_MAX_STACKS)
		is_invuln = def.get("is_invulnerable", false)
	elif def is Resource and def.get("buff_id") != null:
		buff_id = def.get("buff_id")
		base_duration = float(def.get("default_duration"))
		default_max_stacks = int(def.get("default_max_stacks"))
		is_invuln = bool(def.get("is_invulnerable"))

	if duration_override > 0.0:
		base_duration = duration_override

	# Calculate duration with Lasting Empowerment percentage bonus
	var le_ratio: float = lasting_empowerment_override if lasting_empowerment_override >= 0.0 else lasting_empowerment_bonus
	var effective_duration: float = base_duration * (1.0 + maxf(0.0, le_ratio))

	# Determine max stacks: override > definition > default
	var target_max_stacks: int = default_max_stacks
	if max_stacks_override > 0:
		target_max_stacks = max_stacks_override

	var prior_invulnerable: bool = is_invulnerable()

	if _active_buffs.has(buff_id):
		var active: ActiveBuff = _active_buffs[buff_id]
		if max_stacks_override > 0:
			active.max_stacks = max_stacks_override

		# Stack clamping: increments current stacks up to active.max_stacks
		active.add_stack(1)

		# Refresh duration
		active.refresh_duration(effective_duration)

		buff_refreshed.emit(buff_id, active.current_stacks, active.time_remaining)

		_check_invulnerability_transition(prior_invulnerable)
		return active
	else:
		var active := ActiveBuff.new(def, effective_duration, target_max_stacks)
		_active_buffs[buff_id] = active

		buff_applied.emit(buff_id, active.current_stacks)

		_check_invulnerability_transition(prior_invulnerable)
		return active

## Advances all active buffs by delta seconds, pruning expired entries.
func tick(delta: float) -> void:
	if _active_buffs.is_empty():
		return

	var prior_invulnerable: bool = is_invulnerable()
	var expired_ids: Array[StringName] = []

	for buff_id in _active_buffs.keys():
		var buff: ActiveBuff = _active_buffs[buff_id]
		if buff.tick(delta):
			expired_ids.append(buff_id)

	for buff_id in expired_ids:
		_active_buffs.erase(buff_id)
		buff_expired.emit(buff_id)

	_check_invulnerability_transition(prior_invulnerable)

## Checks whether a buff is currently active and not expired.
func has_buff(buff_id: StringName) -> bool:
	if not _active_buffs.has(buff_id):
		return false
	var buff: ActiveBuff = _active_buffs[buff_id]
	return not buff.is_expired()

## Retrieves the active buff instance by buff_id, or null if absent.
func get_buff(buff_id: StringName) -> ActiveBuff:
	if has_buff(buff_id):
		return _active_buffs[buff_id]
	return null

## Returns the current number of stacks for a buff, or 0 if inactive.
func get_stacks(buff_id: StringName) -> int:
	if has_buff(buff_id):
		return _active_buffs[buff_id].current_stacks
	return 0

## Checks if any active buff grants invulnerability.
func is_invulnerable() -> bool:
	for buff in _active_buffs.values():
		if buff.is_invulnerable and not buff.is_expired():
			return true
	return false

## Lasting Empowerment Mechanic B: Active flat duration extension across all active buffs.
func apply_lasting_empowerment_active(flat_extension: float = 3.0) -> int:
	var count: int = 0
	for buff in _active_buffs.values():
		if not buff.is_expired():
			buff.extend_duration(flat_extension)
			count += 1
	return count

## Alias for apply_lasting_empowerment_active
func extend_all_buffs(flat_extension: float) -> int:
	var count: int = 0
	for buff in _active_buffs.values():
		if not buff.is_expired():
			buff.extend_duration(flat_extension)
			count += 1
	return count

## Lasting Empowerment Mechanic A: Sets the percentage duration bonus on apply.
func set_lasting_empowerment_bonus(bonus_ratio: float) -> void:
	lasting_empowerment_bonus = maxf(0.0, bonus_ratio)

func get_lasting_empowerment_bonus() -> float:
	return lasting_empowerment_bonus

## Explicitly removes an active buff.
func remove_buff(buff_id: StringName) -> bool:
	if _active_buffs.has(buff_id):
		var prior_invulnerable: bool = is_invulnerable()
		_active_buffs.erase(buff_id)
		buff_removed.emit(buff_id)
		_check_invulnerability_transition(prior_invulnerable)
		return true
	return false

## Clears all active buffs.
func clear_all() -> void:
	var prior_invulnerable: bool = is_invulnerable()
	_active_buffs.clear()
	_check_invulnerability_transition(prior_invulnerable)

## Computes cumulative stat multiplier across all active buffs.
func get_total_stat_multiplier(stat_name: String) -> float:
	var total_multiplier: float = 1.0
	for buff in _active_buffs.values():
		if not buff.is_expired():
			var mult: float = buff.get_stat_multiplier(stat_name)
			total_multiplier += (mult - 1.0)
	return total_multiplier

## Computes cumulative flat modifier across all active buffs.
func get_total_flat_modifier(stat_name: String) -> float:
	var total_flat: float = 0.0
	for buff in _active_buffs.values():
		if not buff.is_expired():
			total_flat += buff.get_flat_modifier(stat_name)
	return total_flat

## Returns all currently active buffs.
func get_all_active_buffs() -> Array[ActiveBuff]:
	var result: Array[ActiveBuff] = []
	for buff in _active_buffs.values():
		if not buff.is_expired():
			result.append(buff)
	return result

func _check_invulnerability_transition(prior_state: bool) -> void:
	var current_state: bool = is_invulnerable()
	if prior_state != current_state:
		invulnerability_changed.emit(current_state)
