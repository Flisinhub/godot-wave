class_name RankSystem
extends RefCounted

## RankSystem - SFE5 Competitive Ladder & Ranking Formulas (Tasks 12.1, 12.2).
## Calculates progression curve: R -> D-1 (0 pts) -> D-10 -> C-10 -> B-10 -> A-10 -> S-10 -> S-Max.
## Base level-up cost: 10,000 pts from D-1 to D-2, +250 per subsequent sub-level.

const BASE_COST: int = 10000
const COST_INCREMENT: int = 250
const SUBDIVISIONS_PER_TIER: int = 10

const TIER_LETTERS: Array[String] = ["D", "C", "B", "A", "S"]

# Canonical match outcome point deltas (Task 12.2)
const POINTS_DEFEAT: int = -6000
const POINTS_ABANDON: int = -8000
const POINTS_VOTE_KICK: int = -20000
const POINTS_PER_BOSS_SLAIN: int = 300

const VICTORY_BASE_BY_TIER: Dictionary = {
	0: 2500,  # Casual
	1: 5000,  # Normal
	2: 8000,  # Hard
	3: 12000, # Brutal
	4: 18000, # Torment
	5: 25000  # Impossible
}


## Returns the incremental cost to advance from level L to L+1.
static func get_next_level_cost(current_level: int) -> int:
	if current_level < 0:
		return BASE_COST
	return BASE_COST + (COST_INCREMENT * current_level)


## Computes total cumulative points required to reach level L from 0 points (D-1).
## Formula: Sum_{k=0}^{L-1} (10000 + 250k) = 10000*L + 125*L*(L-1)
static func calculate_points_for_level(level: int) -> int:
	if level <= 0:
		return 0
	return (BASE_COST * level) + (125 * level * (level - 1))


## Solves for integer level L given total points P >= 0.
## Solves: 125*L^2 + 9875*L - P = 0 using the quadratic formula.
static func calculate_level_from_points(points: int) -> int:
	if points <= 0:
		return 0
	# a = 125, b = 9875, c = -points
	# L = (-9875 + sqrt(9875^2 + 4*125*P)) / 250
	var b_val: float = float(BASE_COST - 125) # 9875.0
	var discr: float = (b_val * b_val) + (500.0 * float(points))
	var l_float: float = (-b_val + sqrt(discr)) / 250.0
	return int(floorf(l_float))


## Maps total points to human-readable rank notation (e.g. "R", "D-1", "B-7", "S-10", "S-Max").
static func get_rank_string(points: int) -> String:
	if points < 0:
		return "R" # Recruit

	var level: int = calculate_level_from_points(points)
	if level < 0:
		return "R"

	var tier_idx: int = int(level / SUBDIVISIONS_PER_TIER)
	var sub_idx: int = (level % SUBDIVISIONS_PER_TIER) + 1

	if tier_idx >= TIER_LETTERS.size():
		return "S-Max"

	var letter: String = TIER_LETTERS[tier_idx]
	return "%s-%d" % [letter, sub_idx]


## Returns structured progression metrics for UI progress bars.
static func get_progression_details(points: int) -> Dictionary:
	if points < 0:
		return {
			"rank_string": "R",
			"level": -1,
			"points_in_level": 0,
			"level_cost": BASE_COST,
			"ratio": 0.0
		}

	var level: int = calculate_level_from_points(points)
	var pts_base: int = calculate_points_for_level(level)
	var pts_in_level: int = points - pts_base
	var cost_to_next: int = get_next_level_cost(level)
	var ratio: float = clampf(float(pts_in_level) / float(cost_to_next), 0.0, 1.0)

	return {
		"rank_string": get_rank_string(points),
		"level": level,
		"points_in_level": pts_in_level,
		"level_cost": cost_to_next,
		"ratio": ratio
	}


## Computes point delta resulting from a match outcome (Task 12.2).
static func calculate_match_outcome(outcome: String, diff_tier: int = 1, players: int = 1, bosses_slain: int = 0) -> Dictionary:
	var delta: int = 0
	var reason: String = ""

	match outcome.to_lower():
		"victory":
			var base: int = VICTORY_BASE_BY_TIER.get(diff_tier, 5000)
			# Solo bonus: +25%
			var solo_mult: float = 1.25 if players == 1 else 1.0
			delta = int(float(base) * solo_mult) + (bosses_slain * POINTS_PER_BOSS_SLAIN)
			reason = "Victoria en Dificultad %d (Jefes: %d)" % [diff_tier, bosses_slain]
		"defeat":
			delta = POINTS_DEFEAT + (bosses_slain * POINTS_PER_BOSS_SLAIN)
			reason = "Derrota de la Base"
		"abandon":
			delta = POINTS_ABANDON
			reason = "Abandono de Partida"
		"vote_kick":
			delta = POINTS_VOTE_KICK
			reason = "Expulsión por Votación del Equipo"
		_:
			delta = 0
			reason = "Partida sin clasificar"

	return {
		"delta": delta,
		"reason": reason
	}
