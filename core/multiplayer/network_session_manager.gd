class_name NetworkSessionManager
extends RefCounted

## NetworkSessionManager - SFE5 Co-op Network Session & Lobby Manager (Tasks 13.3 - 13.8).
## Coordinates player slots, ready checks, server-authoritative purchases,
## dynamic supply recalculation upon disconnects, and team voting.

const PlayerSlot = preload("res://core/multiplayer/player_slot.gd")

signal player_joined(slot: PlayerSlot)
signal player_left(peer_id: int, remaining_count: int, new_supply_limit: int)
signal lobby_status_changed(all_ready: bool)
signal vote_started(vote_type: String, topic: String)
signal vote_concluded(result: Dictionary)
signal purchase_authorized(peer_id: int, item_id: StringName, cost: int)

const DEFAULT_PORT: int = 7777
const BASE_SUPPLY_SOLO: int = 80
const SUPPLY_PENALTY_PER_EXTRA: int = 10
const MIN_SUPPLY_FLOOR: int = 30

var is_server: bool = true
var max_players: int = 6
var player_slots: Dictionary = {} # peer_id -> PlayerSlot

# Active Vote State (Task 13.8)
var is_voting_active: bool = false
var active_vote_type: String = ""
var active_vote_topic: String = ""
var cast_votes: Dictionary = {} # peer_id -> Variant


func _init(p_is_server: bool = true, p_max_players: int = 6) -> void:
	is_server = p_is_server
	max_players = p_max_players
	player_slots.clear()


## Registers a new player in an open slot (Task 13.2, 13.3).
func register_player(peer_id: int, player_name: String, is_host: bool = false) -> PlayerSlot:
	if player_slots.size() >= max_players or player_slots.has(peer_id):
		return null

	var slot := PlayerSlot.new(peer_id, player_name, is_host)
	# Recalculate minerals per player
	var count: int = player_slots.size() + 1
	slot.minerals = int(12000.0 / float(count))

	player_slots[peer_id] = slot
	player_joined.emit(slot)
	_evaluate_ready_state()
	return slot


## Removes a player (disconnect) and recalculates team supply limit dynamically (Task 13.7).
func unregister_player(peer_id: int) -> int:
	if not player_slots.has(peer_id):
		return calculate_supply_limit()

	player_slots.erase(peer_id)
	cast_votes.erase(peer_id)

	var new_supply: int = calculate_supply_limit()
	player_left.emit(peer_id, player_slots.size(), new_supply)
	_evaluate_ready_state()
	return new_supply


## Computes supply cap according to current connected player count (Task 13.7).
## Formula: 80 - 10*(players - 1), clamped to minimum 30.
func calculate_supply_limit(outhouse_unlocked: bool = false) -> int:
	var count: int = maxi(1, player_slots.size())
	var supply: int = BASE_SUPPLY_SOLO - ((count - 1) * SUPPLY_PENALTY_PER_EXTRA)
	supply = maxi(MIN_SUPPLY_FLOOR, supply)
	if outhouse_unlocked:
		supply += 10
	return supply


## Sets player ready state in lobby.
func set_player_ready(peer_id: int, ready: bool) -> void:
	if player_slots.has(peer_id):
		player_slots[peer_id].is_ready = ready
		_evaluate_ready_state()


## Checks if all connected players are ready to deploy.
func are_all_players_ready() -> bool:
	if player_slots.is_empty():
		return false
	for slot in player_slots.values():
		if not slot.is_ready:
			return false
	return true


func _evaluate_ready_state() -> void:
	lobby_status_changed.emit(are_all_players_ready())


## Host-authoritative purchase validation (Task 13.6).
## Ensures player has sufficient minerals before deducting and authorizing.
func validate_and_process_purchase(peer_id: int, item_id: StringName, cost: int) -> bool:
	if not player_slots.has(peer_id):
		return false

	var slot: PlayerSlot = player_slots[peer_id]
	if slot.minerals < cost:
		return false

	slot.minerals -= cost
	purchase_authorized.emit(peer_id, item_id, cost)
	return true


## Starts a democratic vote (Difficulty voting, Kick voting) (Task 13.8).
func start_vote(v_type: String, topic: String) -> void:
	is_voting_active = true
	active_vote_type = v_type
	active_vote_topic = topic
	cast_votes.clear()
	vote_started.emit(v_type, topic)


## Casts a vote from peer_id.
func cast_vote(peer_id: int, value: Variant) -> void:
	if not is_voting_active or not player_slots.has(peer_id):
		return
	cast_votes[peer_id] = value


## Concludes and tallies vote. Returns winning option.
func conclude_vote() -> Dictionary:
	if not is_voting_active:
		return {}

	is_voting_active = false
	var tallies: Dictionary = {}
	for v in cast_votes.values():
		var k = str(v)
		tallies[k] = tallies.get(k, 0) + 1

	var winner: String = ""
	var max_votes: int = -1
	for k in tallies.keys():
		if tallies[k] > max_votes:
			max_votes = tallies[k]
			winner = k

	var result := {
		"vote_type": active_vote_type,
		"topic": active_vote_topic,
		"winner": winner,
		"total_votes": cast_votes.size(),
		"tallies": tallies
	}
	vote_concluded.emit(result)
	return result
