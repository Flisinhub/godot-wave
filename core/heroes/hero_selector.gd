class_name HeroSelector
extends RefCounted

## HeroSelector - Central Hero Archetype Catalog & Selection System for SFE5.
## Supports manual hero selection (filtering out secret archetypes) and random selection
## with exactly 1.0% probability (randf() < 0.01) of unlocking the Secret Hero Archetype.

const HeroData = preload("res://core/heroes/hero_data.gd")

static var _standard_archetypes: Array[HeroData] = []
static var _secret_archetype: HeroData = null
static var _catalog_by_id: Dictionary = {}
static var _is_initialized: bool = false

static func _ensure_catalog_initialized() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	_load_or_create_archetypes()

static func _load_or_create_archetypes() -> void:
	# Attempt loading from res://data/heroes/ or construct defaults
	var marine := _load_or_create(
		"res://data/heroes/marine.tres",
		&"marine",
		"Marine Commander",
		"Heavy Assault Rifle & Stimpack Support",
		false,
		550.0, 28.0, 0.8, 1.0, 120.0, 1.2, 14.0, 1.0,
		12, 10, 8
	)

	var raynor := _load_or_create(
		"res://data/heroes/raynor.tres",
		&"raynor",
		"Jim Raynor",
		"Marine Commander & Tactical Frontline",
		false,
		550.0, 28.0, 0.8, 1.0, 120.0, 1.2, 14.0, 1.0,
		12, 10, 8
	)

	var ghost := _load_or_create(
		"res://data/heroes/ghost.tres",
		&"ghost",
		"Ghost Operative",
		"Long-Range Precision Sniper & Tactical Cloak",
		false,
		420.0, 45.0, 1.2, 0.8, 200.0, 2.0, 18.0, 0.0,
		8, 12, 16
	)

	var nova := _load_or_create(
		"res://data/heroes/nova.tres",
		&"nova",
		"Nova Terra",
		"Ghost Operative & Stealth Assassin",
		false,
		420.0, 45.0, 1.2, 0.8, 200.0, 2.0, 18.0, 0.0,
		8, 12, 16
	)

	var reaper := _load_or_create(
		"res://data/heroes/reaper.tres",
		&"reaper",
		"Reaper Infiltrator",
		"High Mobility Jetpack Raider & Explosive Mines",
		false,
		460.0, 24.0, 0.65, 1.2, 140.0, 1.5, 15.0, 0.5,
		9, 15, 8
	)

	var marauder := _load_or_create(
		"res://data/heroes/marauder.tres",
		&"marauder",
		"Heavy Marauder",
		"Armored Shock Trooper & Concussive Grenades",
		false,
		720.0, 22.0, 0.9, 1.5, 100.0, 1.0, 12.0, 3.0,
		16, 8, 6
	)

	var tychus := _load_or_create(
		"res://data/heroes/tychus.tres",
		&"tychus",
		"Tychus Findlay",
		"Heavy Commando & Minigun Juggernaut",
		false,
		720.0, 24.0, 0.85, 1.5, 110.0, 1.0, 12.0, 3.0,
		16, 8, 6
	)

	var zeratul := _load_or_create(
		"res://data/heroes/zeratul.tres",
		&"zeratul",
		"Zeratul",
		"Dark Templar Prelate & Void Assassin",
		false,
		480.0, 52.0, 0.75, 1.0, 150.0, 1.8, 14.0, 2.0,
		14, 18, 12
	)

	var tassadar := _load_or_create(
		"res://data/heroes/tassadar.tres",
		&"tassadar",
		"Tassadar",
		"High Templar & Psionic Storm Channeler",
		false,
		420.0, 32.0, 1.0, 1.0, 220.0, 2.5, 15.0, 1.0,
		10, 10, 20
	)

	var medic := _load_or_create(
		"res://data/heroes/medic.tres",
		&"medic",
		"Egon Stetmann (Medic)",
		"Combat Support & Nano-Repair Specialist",
		false,
		460.0, 18.0, 0.85, 2.0, 200.0, 2.2, 14.0, 2.0,
		11, 11, 16
	)

	var harbinger := _load_or_create(
		"res://data/heroes/secret_harbinger.tres",
		&"harbinger",
		"Xel'Naga Harbinger",
		"Celestial Singularity & Dimensional Transcendence",
		true, # SECRET ARCHETYPE
		850.0, 55.0, 0.75, 2.5, 300.0, 3.0, 22.0, 4.0,
		18, 18, 22
	)

	_standard_archetypes = [marine, raynor, tychus, nova, zeratul, tassadar, marauder, ghost, medic, reaper]
	_secret_archetype = harbinger

	# Index by ID and canonical aliases
	_catalog_by_id[&"marine"] = marine
	_catalog_by_id[&"raynor"] = raynor
	_catalog_by_id[&"jim_raynor"] = raynor

	_catalog_by_id[&"ghost"] = ghost
	_catalog_by_id[&"nova"] = nova
	_catalog_by_id[&"nova_terra"] = nova

	_catalog_by_id[&"reaper"] = reaper

	_catalog_by_id[&"marauder"] = marauder
	_catalog_by_id[&"tychus"] = tychus
	_catalog_by_id[&"tychus_findlay"] = tychus

	_catalog_by_id[&"zeratul"] = zeratul
	_catalog_by_id[&"tassadar"] = tassadar

	_catalog_by_id[&"medic"] = medic
	_catalog_by_id[&"stetmann"] = medic
	_catalog_by_id[&"egon_stetmann"] = medic

	_catalog_by_id[&"harbinger"] = harbinger
	_catalog_by_id[&"secret_harbinger"] = harbinger
	_catalog_by_id[&"spectre"] = harbinger
	_catalog_by_id[&"xel_naga_harbinger"] = harbinger

static func _load_or_create(
	path: String,
	id: StringName,
	hero_name: String,
	role: String,
	is_secret_archetype: bool,
	hp: float, dmg: float, cd: float, regen: float,
	energy: float, energy_regen: float, vision: float, armor: float,
	str_val: int, dex_val: int, int_val: int
) -> HeroData:
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is HeroData:
			return loaded

	var h: HeroData = HeroData.new()
	h.archetype_id = id
	h.hero_name = hero_name
	h.role_description = role
	h.is_secret = is_secret_archetype
	h.base_hp = hp
	h.base_damage = dmg
	h.base_cooldown = cd
	h.base_hp_regen = regen
	h.base_energy = energy
	h.base_energy_regen = energy_regen
	h.base_vision = vision
	h.flat_armor = armor
	h.strength = str_val
	h.dexterity = dex_val
	h.intelligence = int_val
	h.recalculate_derived_stats(true)
	return h

## Manual selection filtering out secret hero archetypes.
## Returns an isolated instance of the selected hero or null if invalid / secret.
static func select_hero_manual(archetype_id: StringName) -> HeroData:
	_ensure_catalog_initialized()
	var key: StringName = StringName(str(archetype_id).to_lower().strip_edges())

	if not _catalog_by_id.has(key):
		return null

	var hero: HeroData = _catalog_by_id[key]
	# Strictly prohibit manual selection of secret hero
	if hero.is_secret:
		return null

	return hero.duplicate_for_instance()

## Random selection with EXACTLY 1% probability of rolling the secret hero archetype.
## [0.0, 0.01) -> Secret Hero (Xel'Naga Harbinger / Spectre)
## [0.01, 1.0) -> Standard non-secret heroes uniformly distributed
static func select_hero_random(rng: RandomNumberGenerator = null) -> HeroData:
	_ensure_catalog_initialized()

	var roll: float = rng.randf() if rng != null else randf()

	if roll < 0.01:
		# Exactly 1% probability
		return _secret_archetype.duplicate_for_instance()
	else:
		# 99% probability: Pick uniformly among available standard heroes
		var pool_size: int = _standard_archetypes.size()
		if pool_size == 0:
			return null
		var idx: int = 0
		if rng != null:
			idx = rng.randi_range(0, pool_size - 1)
		else:
			idx = randi() % pool_size
		return _standard_archetypes[idx].duplicate_for_instance()

static func get_standard_archetypes() -> Array[HeroData]:
	_ensure_catalog_initialized()
	return _standard_archetypes

static func get_secret_archetype() -> HeroData:
	_ensure_catalog_initialized()
	return _secret_archetype

static func get_all_archetypes() -> Dictionary:
	_ensure_catalog_initialized()
	return _catalog_by_id
