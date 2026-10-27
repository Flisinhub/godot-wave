class_name PinnacleBossBase
extends CharacterBody3D

## PinnacleBossBase - SFE5 Pinnacle Boss Entity Architecture (Tasks 10.1, 10.3, 10.4).
## Supports multi-phase state machines, cinematic health bar binding,
## channeled abilities with interruption mechanics, and standard 100k/300pts rewards.

signal health_updated(hp: float, max_hp: float, phase: int)
signal phase_transitioned(new_phase: int, phase_name: String)
signal channeling_started(spell_name: String, duration: float)
signal channeling_completed(spell_name: String)
signal channeling_interrupted()
signal boss_defeated_rewards(minerals: int, rank_points: int, unlocked_secret: StringName)

@export var boss_id: StringName = &"pinnacle_boss"
@export var boss_name: String = "Pinnacle Boss"
@export var max_health: float = 12000.0
@export var flat_armor: float = 15.0
@export var attack_damage: float = 75.0
@export var attack_cooldown: float = 1.2
@export var move_speed: float = 3.5

@export var reward_minerals: int = 100000
@export var reward_rank_points: int = 300
@export var secret_unit_unlocked: StringName = &""

var current_health: float = 12000.0
var current_phase: int = 1
var total_phases: int = 3
var is_invulnerable: bool = false
var is_dead: bool = false

var is_channeling: bool = false
var current_channel_spell: String = ""
var channel_time_remaining: float = 0.0


func _init() -> void:
	current_health = max_health
	current_phase = 1


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	add_to_group("pinnacle_bosses")
	_setup_visual_root()
	health_updated.emit(current_health, max_health, current_phase)


func _setup_visual_root() -> void:
	if has_node("VisualRoot"):
		return
	var root := Node3D.new()
	root.name = "VisualRoot"
	add_child(root)


## Applies incoming damage through the SFE5 mitigation pipeline.
func take_damage(amount: float, is_spell: bool = false) -> float:
	if is_dead or is_invulnerable or amount <= 0.0:
		return 0.0

	var net_dmg: float = amount
	if not is_spell:
		net_dmg = maxf(1.0, amount - flat_armor)

	current_health = maxf(0.0, current_health - net_dmg)
	_evaluate_phases()
	health_updated.emit(current_health, max_health, current_phase)

	if current_health <= 0.0:
		_die()

	return net_dmg


## Begins a channeled spell casting sequence.
func start_channeling(spell_name: String, duration: float) -> void:
	is_channeling = true
	current_channel_spell = spell_name
	channel_time_remaining = duration
	channeling_started.emit(spell_name, duration)


## Advances channeling countdown.
func process_channeling(delta: float) -> bool:
	if not is_channeling:
		return false

	channel_time_remaining -= delta
	if channel_time_remaining <= 0.0:
		is_channeling = false
		channeling_completed.emit(current_channel_spell)
		return true

	return false


## Interrupts active channeling.
func interrupt_channeling() -> void:
	if is_channeling:
		is_channeling = false
		channel_time_remaining = 0.0
		channeling_interrupted.emit()


func _evaluate_phases() -> void:
	var ratio: float = current_health / max_health
	var target_phase: int = 1

	if ratio <= 0.33:
		target_phase = 3
	elif ratio <= 0.66:
		target_phase = 2

	if target_phase > current_phase:
		current_phase = target_phase
		var p_name: String = "Fase %d: Furia" % current_phase
		phase_transitioned.emit(current_phase, p_name)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	boss_defeated_rewards.emit(reward_minerals, reward_rank_points, secret_unit_unlocked)
