class_name GameSessionScript
extends Node

const GameConfigScript = preload("res://core/game_config.gd")

## GameSession - Active Match State Autoload for SFE5 Godot.
## Tracks current game difficulty, players, seed, story phase, and session economy metrics.

signal session_started(difficulty_tier: int, map_seed: int)
signal session_ended(victory: bool, elapsed_seconds: float)
signal story_phase_changed(phase_name: String)

var map_seed: int = 1337
var active_seed: int:
	get:
		return map_seed
	set(v):
		map_seed = v
var difficulty_tier: int = 1 # Normal by default
var player_count: int = 1
var split_income_mode: bool = false
var pedestal_bonus_active: bool = false
var outhouse_secret_discovered: bool = false
var current_story_phase: String = "zerg" # "zerg", "protoss_1", "protoss_2", "pinnacle_bosses"

# Session Runtime Stats
var session_elapsed_time: float = 0.0
var total_minerals_earned: int = 0
var total_kills: int = 0
var spawners_destroyed: int = 0
var is_active: bool = false


## Parses command line user arguments for --seed=XXXX
static func parse_cli_seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.get_slice("=", 1))
	return 0


func start_new_session(p_difficulty: int = 1, p_players: int = 1, p_seed: int = 0) -> void:
	difficulty_tier = p_difficulty
	player_count = maxi(1, p_players)
	var effective_seed: int = p_seed
	if effective_seed == 0:
		var cli_seed := parse_cli_seed()
		effective_seed = cli_seed if cli_seed != 0 else randi()
	map_seed = effective_seed
	session_elapsed_time = 0.0
	total_minerals_earned = 0
	total_kills = 0
	spawners_destroyed = 0
	current_story_phase = "zerg"
	pedestal_bonus_active = false
	outhouse_secret_discovered = false
	is_active = true
	session_started.emit(difficulty_tier, map_seed)


func get_initial_minerals(is_random_hero: bool = false) -> int:
	var base_pool: int = 15000 if is_random_hero else 12000
	return int(round(float(base_pool) / float(maxi(1, player_count))))


func get_max_supply() -> int:
	var supply: int = GameConfigScript.BASE_SUPPLY_SOLO - (player_count - 1) * GameConfigScript.SUPPLY_PENALTY_PER_EXTRA_PLAYER
	supply = maxi(GameConfigScript.MIN_SUPPLY_FLOOR, supply)
	if outhouse_secret_discovered:
		supply += 10
	return supply


func on_player_left() -> void:
	if player_count > 1:
		player_count -= 1


func _process(delta: float) -> void:
	if is_active:
		session_elapsed_time += delta
