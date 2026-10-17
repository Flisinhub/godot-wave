class_name ActiveBuff
extends RefCounted

## Active runtime instance of a buff or status effect on an entity.
## Handles current stacks, duration countdown, stack clamping, and stat calculation.

const SFEBuffDef = preload("res://core/combat/sfe_buff_def.gd")

var def: Variant = null
var buff_id: StringName = &""
var display_name: String = ""
var current_stacks: int = 1
var max_stacks: int = 2
var duration: float = 5.0
var time_remaining: float = 5.0
var is_invulnerable: bool = false
var stat_multipliers: Dictionary = {}
var flat_modifiers: Dictionary = {}
var custom_data: Dictionary = {}

func _init(p_def: Variant = null, p_duration: float = -1.0, p_max_stacks: int = -1) -> void:
	def = p_def
	if p_def != null:
		if p_def is SFEBuffDef:
			buff_id = p_def.buff_id
			display_name = p_def.display_name
			duration = p_def.default_duration
			max_stacks = p_def.default_max_stacks
			is_invulnerable = p_def.is_invulnerable
			stat_multipliers = p_def.stat_multipliers.duplicate()
			flat_modifiers = p_def.flat_modifiers.duplicate()
			custom_data = p_def.custom_data.duplicate()
		elif p_def is Dictionary:
			buff_id = p_def.get("buff_id", &"custom_buff")
			display_name = p_def.get("display_name", "Custom Buff")
			duration = p_def.get("default_duration", 5.0)
			max_stacks = p_def.get("default_max_stacks", 2)
			is_invulnerable = p_def.get("is_invulnerable", false)
			stat_multipliers = p_def.get("stat_multipliers", {}).duplicate()
			flat_modifiers = p_def.get("flat_modifiers", {}).duplicate()
			custom_data = p_def.get("custom_data", {}).duplicate()
		elif p_def is Resource and p_def.get("buff_id") != null:
			buff_id = p_def.get("buff_id")
			display_name = str(p_def.get("display_name"))
			duration = float(p_def.get("default_duration"))
			max_stacks = int(p_def.get("default_max_stacks"))
			is_invulnerable = bool(p_def.get("is_invulnerable"))
			var sm: Variant = p_def.get("stat_multipliers")
			if sm is Dictionary:
				stat_multipliers = sm.duplicate()
			var fm: Variant = p_def.get("flat_modifiers")
			if fm is Dictionary:
				flat_modifiers = fm.duplicate()

	if p_duration > 0.0:
		duration = p_duration
	if p_max_stacks > 0:
		max_stacks = p_max_stacks

	time_remaining = duration
	current_stacks = 1

## Advances the buff timer by delta seconds. Returns true if the buff has expired.
func tick(delta: float) -> bool:
	time_remaining -= delta
	return is_expired()

## Returns true if time_remaining is less than or equal to zero.
func is_expired() -> bool:
	return time_remaining <= 0.0

## Adds stacks up to max_stacks. Returns the updated stack count.
func add_stack(amount: int = 1) -> int:
	current_stacks = clampi(current_stacks + amount, 1, max_stacks)
	return current_stacks

## Refreshes the remaining duration of the buff.
func refresh_duration(new_duration: float = -1.0) -> void:
	var dur: float = new_duration if new_duration > 0.0 else duration
	time_remaining = maxf(time_remaining, dur)

## Extends duration by flat seconds (e.g. active Lasting Empowerment).
func extend_duration(flat_seconds: float) -> void:
	time_remaining += flat_seconds

## Scales duration by a bonus ratio (e.g. +40% = 0.40).
func apply_lasting_empowerment(bonus_ratio: float) -> void:
	time_remaining *= (1.0 + bonus_ratio)

## Computes stack-scaled multiplier for the given stat. Returns 1.0 if not present.
func get_stat_multiplier(stat_name: String) -> float:
	var base_mult: float = 1.0
	if stat_multipliers.has(stat_name):
		base_mult = float(stat_multipliers[stat_name])
	elif stat_multipliers.has(stat_name + "_per_stack"):
		base_mult = float(stat_multipliers[stat_name + "_per_stack"])
	else:
		return 1.0

	# Scale each stack's delta from 1.0
	return 1.0 + ((base_mult - 1.0) * float(current_stacks))

## Computes stack-scaled flat modifier for the given stat. Returns 0.0 if not present.
func get_flat_modifier(stat_name: String) -> float:
	if not flat_modifiers.has(stat_name):
		return 0.0
	return float(flat_modifiers[stat_name]) * float(current_stacks)

func _to_string() -> String:
	return "[ActiveBuff id=%s stacks=%d/%d time=%.2fs/%.2fs immune=%s]" % [
		buff_id, current_stacks, max_stacks, time_remaining, duration, is_invulnerable
	]
