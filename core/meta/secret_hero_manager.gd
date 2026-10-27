class_name SecretHeroManager
extends RefCounted

## SecretHeroManager - SFE5 Secret Hero Activation & Eligibility Engine (Fase 16).
## Implements Task 16.1 & 16.2:
## - Eligibility: Player must have >= 3000 achievement points.
## - Allowed difficulties: < Torment (Casual 0, Normal 1, Hard 2, Brutal 3).
## - Activation probability: (6 - difficulty)%
## - Playing a secret hero disables achievements for that match session.
## - Catalog of 6 original secret sci-fi heroes (ADR-06 recommendation).

const HeroData = preload("res://core/heroes/hero_data.gd")
const HeroSelector = preload("res://core/heroes/hero_selector.gd")

const MIN_ACHIEVEMENT_POINTS: int = 3000
const MAX_ALLOWED_DIFFICULTY: int = 3  ## Brutal (3) is max; Torment (4) & Impossible (5) are forbidden

static var _secret_catalog: Dictionary = {}
static var _catalog_initialized: bool = false


static func _ensure_catalog_initialized() -> void:
	if _catalog_initialized:
		return
	_catalog_initialized = true

	# 1. Xel'Naga Harbinger
	var harbinger := HeroData.new()
	harbinger.archetype_id = &"harbinger"
	harbinger.hero_name = "Xel'Naga Harbinger"
	harbinger.role_description = "Celestial Singularity & Dimensional Transcendence"
	harbinger.is_secret = true
	harbinger.base_hp = 850.0
	harbinger.base_damage = 55.0
	harbinger.base_cooldown = 0.75
	harbinger.base_hp_regen = 2.5
	harbinger.base_energy = 300.0
	harbinger.base_energy_regen = 3.0
	harbinger.base_vision = 22.0
	harbinger.flat_armor = 4.0
	harbinger.strength = 18
	harbinger.dexterity = 18
	harbinger.intelligence = 22
	harbinger.recalculate_derived_stats(true)
	_secret_catalog[&"harbinger"] = harbinger

	# 2. Void Arbiter
	var arbiter := HeroData.new()
	arbiter.archetype_id = &"void_arbiter"
	arbiter.hero_name = "Void Arbiter"
	arbiter.role_description = "Temporal Stasis & Singularity Rift"
	arbiter.is_secret = true
	arbiter.base_hp = 680.0
	arbiter.base_damage = 48.0
	arbiter.base_cooldown = 0.8
	arbiter.base_hp_regen = 1.8
	arbiter.base_energy = 280.0
	arbiter.base_energy_regen = 3.5
	arbiter.base_vision = 20.0
	arbiter.flat_armor = 3.0
	arbiter.strength = 14
	arbiter.dexterity = 14
	arbiter.intelligence = 24
	arbiter.recalculate_derived_stats(true)
	_secret_catalog[&"void_arbiter"] = arbiter

	# 3. Phantom Spectre
	var spectre := HeroData.new()
	spectre.archetype_id = &"phantom_spectre"
	spectre.hero_name = "Phantom Spectre (Kage)"
	spectre.role_description = "Quantum Phase Invisibility & EMP Overload"
	spectre.is_secret = true
	spectre.base_hp = 520.0
	spectre.base_damage = 62.0
	spectre.base_cooldown = 1.1
	spectre.base_hp_regen = 1.5
	spectre.base_energy = 250.0
	spectre.base_energy_regen = 2.8
	spectre.base_vision = 24.0
	spectre.flat_armor = 2.0
	spectre.strength = 10
	spectre.dexterity = 22
	spectre.intelligence = 18
	spectre.recalculate_derived_stats(true)
	_secret_catalog[&"phantom_spectre"] = spectre

	# 4. Apex Ravager
	var ravager := HeroData.new()
	ravager.archetype_id = &"apex_ravager"
	ravager.hero_name = "Apex Ravager (Zul'Korr)"
	ravager.role_description = "Primal Bio-Armor & Caustic Volley"
	ravager.is_secret = true
	ravager.base_hp = 950.0
	ravager.base_damage = 50.0
	ravager.base_cooldown = 0.9
	ravager.base_hp_regen = 4.0
	ravager.base_energy = 150.0
	ravager.base_energy_regen = 1.5
	ravager.base_vision = 16.0
	ravager.flat_armor = 5.0
	ravager.strength = 24
	ravager.dexterity = 12
	ravager.intelligence = 10
	ravager.recalculate_derived_stats(true)
	_secret_catalog[&"apex_ravager"] = ravager

	# 5. Archon of Solitude
	var archon := HeroData.new()
	archon.archetype_id = &"archon_solitude"
	archon.hero_name = "Archon of Solitude"
	archon.role_description = "Resonant Psionic Shockwave & Plasma Barrier"
	archon.is_secret = true
	archon.base_hp = 400.0
	archon.base_damage = 65.0
	archon.base_cooldown = 0.95
	archon.base_hp_regen = 1.0
	archon.base_energy = 320.0
	archon.base_energy_regen = 4.0
	archon.base_vision = 19.0
	archon.flat_armor = 2.0
	archon.strength = 12
	archon.dexterity = 12
	archon.intelligence = 26
	archon.recalculate_derived_stats(true)
	_secret_catalog[&"archon_solitude"] = archon

	# 6. Chronos Vanguard
	var vanguard := HeroData.new()
	vanguard.archetype_id = &"chronos_vanguard"
	vanguard.hero_name = "Chronos Vanguard"
	vanguard.role_description = "Experimental Exosuit & Chrono-Rewind Defense"
	vanguard.is_secret = true
	vanguard.base_hp = 780.0
	vanguard.base_damage = 38.0
	vanguard.base_cooldown = 0.7
	vanguard.base_hp_regen = 2.0
	vanguard.base_energy = 220.0
	vanguard.base_energy_regen = 2.2
	vanguard.base_vision = 18.0
	vanguard.flat_armor = 4.0
	vanguard.strength = 18
	vanguard.dexterity = 16
	vanguard.intelligence = 16
	vanguard.recalculate_derived_stats(true)
	_secret_catalog[&"chronos_vanguard"] = vanguard


## Evaluates if player meets the threshold requirements:
## >= 3000 achievement points and difficulty < Torment (0..3).
static func evaluate_secret_hero_eligibility(achievement_points: int, difficulty_level: int) -> bool:
	if achievement_points < MIN_ACHIEVEMENT_POINTS:
		return false
	if difficulty_level > MAX_ALLOWED_DIFFICULTY:
		return false
	return true


## Computes activation probability according to canonical formula: (6 - difficulty)%
## Returns probability as a float in [0.0..1.0].
## e.g. Casual (0) -> 0.06, Normal (1) -> 0.05, Hard (2) -> 0.04, Brutal (3) -> 0.03.
## Torment (4+) -> 0.0.
static func get_activation_probability(difficulty_level: int) -> float:
	if difficulty_level < 0 or difficulty_level > MAX_ALLOWED_DIFFICULTY:
		return 0.0
	var percent_int: int = 6 - difficulty_level
	return float(percent_int) / 100.0


## Attempts to roll for a secret hero upon game start.
## If activated, returns a Dictionary:
## {
##   "activated": true,
##   "hero_data": HeroData,
##   "achievements_enabled": false
## }
## If not activated or ineligible:
## {
##   "activated": false,
##   "hero_data": null,
##   "achievements_enabled": true
## }
static func roll_secret_hero_activation(
	achievement_points: int,
	difficulty_level: int,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	_ensure_catalog_initialized()

	if not evaluate_secret_hero_eligibility(achievement_points, difficulty_level):
		return {
			"activated": false,
			"hero_data": null,
			"achievements_enabled": true
		}

	var prob: float = get_activation_probability(difficulty_level)
	var roll: float = rng.randf() if rng != null else randf()

	if roll < prob:
		# Success! Pick uniformly among the 6 secret heroes
		var keys: Array = _secret_catalog.keys()
		var chosen_key: StringName = keys[0]
		if rng != null:
			chosen_key = keys[rng.randi_range(0, keys.size() - 1)]
		else:
			chosen_key = keys[randi() % keys.size()]

		var hero: HeroData = _secret_catalog[chosen_key]
		return {
			"activated": true,
			"hero_data": hero.duplicate_for_instance(),
			"achievements_enabled": false  ## Deshabilita logros de la partida (Task 16.1)
		}

	return {
		"activated": false,
		"hero_data": null,
		"achievements_enabled": true
	}


static func get_all_secret_heroes() -> Dictionary:
	_ensure_catalog_initialized()
	return _secret_catalog


## Task 16.5: Xel'Naga Harbinger Secret Roll from Random Hero (1.0% probability)
static func is_harbinger_roll(roll: float) -> bool:
	return roll < 0.01


static func roll_harbinger_secret(rng: RandomNumberGenerator = null) -> Dictionary:
	_ensure_catalog_initialized()
	var roll: float = rng.randf() if rng != null else randf()
	if is_harbinger_roll(roll):
		var hero: HeroData = _secret_catalog[&"harbinger"]
		return {
			"activated": true,
			"hero_data": hero.duplicate_for_instance(),
			"achievements_enabled": false
		}
	return {
		"activated": false,
		"hero_data": null,
		"achievements_enabled": true
	}

