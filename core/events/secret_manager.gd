class_name SecretManager
extends RefCounted

## SecretManager - SFE5 Easter Eggs, Secrets & Environmental Hazards (Tasks 9.12 - 9.15).
## Places Mystery Boxes, Lucky Lizard, Outhouse secret (+10 supply), and Fueling Station deterministically by seed.

signal secret_discovered(secret_id: StringName, reward_name: String, details: Dictionary)
signal outhouse_activated(bonus_supply: int)
signal lucky_lizard_claimed(minerals: int)
signal fueling_station_completed(minerals: int)

const MYSTERY_BOX_CANDIDATE_POINTS: Array[Vector3] = [
	Vector3(-34.0, 0.0, -32.0),
	Vector3(34.0, 0.0, 32.0),
	Vector3(-35.0, 0.0, 28.0),
	Vector3(32.0, 0.0, -35.0)
]

const OUTHOUSE_LOCATION: Vector3 = Vector3(-42.0, 0.0, 18.0)
const FUELING_STATION_LOCATION: Vector3 = Vector3(18.0, 0.0, 35.0)
const LUCKY_LIZARD_LOCATION: Vector3 = Vector3(38.0, 0.0, 0.0)

var match_seed: int = 123456
var outhouse_unlocked: bool = false
var lizard_caught: bool = false
var fueling_completed: bool = false
var boxes_opened: Array[int] = []

var _rng: RandomNumberGenerator


func _init(p_seed: int = 123456) -> void:
	match_seed = p_seed
	_rng = RandomNumberGenerator.new()
	_rng.seed = match_seed


## Interacts with the secret Outhouse (Task 9.13).
## Permanently grants +10 supply cap to all players.
func trigger_outhouse_secret(game_session: Variant = null) -> bool:
	if outhouse_unlocked:
		return false

	outhouse_unlocked = true
	if game_session != null:
		if game_session is Dictionary:
			game_session["outhouse_secret_discovered"] = true
		elif "outhouse_secret_discovered" in game_session:
			game_session.outhouse_secret_discovered = true

	secret_discovered.emit(&"outhouse", "Outhouse Secret (+10 Suministro)", {"supply_granted": 10})
	outhouse_activated.emit(10)
	return true


## Catches or slays the roaming Lucky Lizard (Task 9.12).
## Awards 3000 flat minerals.
func trigger_lucky_lizard() -> int:
	if lizard_caught:
		return 0

	lizard_caught = true
	var reward: int = 3000
	secret_discovered.emit(&"lucky_lizard", "Lucky Lizard (+3000 Minerales)", {"minerals": reward})
	lucky_lizard_claimed.emit(reward)
	return reward


## Opens a Mystery Box by index (0..3) (Task 9.12).
## Yields randomized loot based on seed.
func open_mystery_box(box_index: int) -> Dictionary:
	if boxes_opened.has(box_index) or box_index < 0 or box_index >= MYSTERY_BOX_CANDIDATE_POINTS.size():
		return {}

	boxes_opened.append(box_index)
	var roll: int = _rng.randi_range(0, 2)
	var loot: Dictionary = {}

	match roll:
		0:
			loot = {"type": "minerals", "amount": 1500, "label": "1500 Minerales"}
		1:
			loot = {"type": "shield_buff", "amount": 250, "duration": 60.0, "label": "Plasma Shield (250 HP, 60s)"}
		2:
			loot = {"type": "experience", "amount": 2000, "label": "2000 XP de Héroe"}

	secret_discovered.emit(&"mystery_box", "Caja Sorpresa #%d: %s" % [box_index + 1, loot.get("label", "")], loot)
	return loot


## Completes the Fueling Up gas station event (Task 9.14).
func complete_fueling_station() -> int:
	if fueling_completed:
		return 0

	fueling_completed = true
	var reward: int = 4000
	secret_discovered.emit(&"fueling_station", "Estación de Combustible (+4000 Minerales)", {"minerals": reward})
	fueling_station_completed.emit(reward)
	return reward
