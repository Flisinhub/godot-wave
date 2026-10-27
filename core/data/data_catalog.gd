class_name DataCatalog
extends Node

## DataCatalog - SFE5 Central Data Registry & Resource Cache (Task 2.2).
## Recursively indexes all `.tres` resources under `res://data/`.
## Provides typed O(1) dictionary lookups for units, heroes, abilities, buffs, upgrades, and spawners.

static var instance: DataCatalog = null

var units: Dictionary = {}        # id (StringName) -> UnitData
var heroes: Dictionary = {}       # id (StringName) -> HeroData
var skills: Dictionary = {}       # id (StringName) -> Resource (AbilityData / HeroSkillData)
var buffs: Dictionary = {}        # id (StringName) -> Resource (BuffData / SFEBuffDef)
var upgrades: Dictionary = {}     # id (StringName) -> UpgradeData
var spawners: Dictionary = {}     # id (StringName) -> SpawnerData
var bosses: Dictionary = {}       # id (StringName) -> BossData
var events: Dictionary = {}       # id (StringName) -> EventData
var difficulties: Dictionary = {} # tier (int) -> DifficultyData
var modes: Dictionary = {}        # id (StringName) -> ModeData

var loaded_resources_count: int = 0
var is_initialized: bool = false

signal catalog_loaded(total_count: int)


func _init() -> void:
	if instance == null:
		instance = self
	reload_catalog()


func _enter_tree() -> void:
	if instance == null:
		instance = self


## Scans res://data/ and registers all .tres resources into categorized tables.
func reload_catalog() -> void:
	units.clear()
	heroes.clear()
	skills.clear()
	buffs.clear()
	upgrades.clear()
	spawners.clear()
	bosses.clear()
	events.clear()
	difficulties.clear()
	modes.clear()
	loaded_resources_count = 0

	_scan_directory_recursive("res://data")
	is_initialized = true
	catalog_loaded.emit(loaded_resources_count)


func _scan_directory_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_directory_recursive(dir_path.path_join(file_name))
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var full_path := dir_path.path_join(file_name)
			_register_resource_file(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_resource_file(path: String) -> void:
	var res := ResourceLoader.load(path)
	if res == null:
		return

	loaded_resources_count += 1
	var registered := false

	# 1. HeroData check
	if res is HeroData:
		var hero: HeroData = res as HeroData
		var h_id := StringName(hero.archetype_id)
		heroes[h_id] = hero
		units[h_id] = hero
		registered = true

	# 2. BossData check
	if res is BossData:
		var boss: BossData = res as BossData
		bosses[boss.id] = boss
		units[boss.id] = boss
		registered = true

	# 3. UnitData check (non-hero/non-boss)
	if not registered and res is UnitData:
		var u: UnitData = res as UnitData
		units[u.id] = u
		registered = true

	# 4. Ability / Skill check
	if res is AbilityData:
		var a: AbilityData = res as AbilityData
		skills[a.id] = a
		registered = true
	elif res is HeroSkillData:
		var s: HeroSkillData = res as HeroSkillData
		skills[s.skill_id] = s
		registered = true

	# 5. BuffData check
	if res is BuffData:
		var b: BuffData = res as BuffData
		buffs[b.id] = b
		registered = true
	elif res is SFEBuffDef:
		var b_def: SFEBuffDef = res as SFEBuffDef
		buffs[b_def.buff_id] = b_def
		registered = true

	# 6. UpgradeData check
	if res is UpgradeData:
		var up: UpgradeData = res as UpgradeData
		upgrades[up.id] = up
		registered = true

	# 7. SpawnerData check
	if res is SpawnerData:
		var sp: SpawnerData = res as SpawnerData
		spawners[sp.id] = sp
		registered = true

	# 8. EventData check
	if res is EventData:
		var ev: EventData = res as EventData
		events[ev.id] = ev
		registered = true

	# 9. DifficultyData check
	if res is DifficultyData:
		var d: DifficultyData = res as DifficultyData
		difficulties[d.tier] = d
		registered = true

	# 10. ModeData check
	if res is ModeData:
		var m: ModeData = res as ModeData
		modes[m.id] = m
		registered = true


# -----------------------------------------------------------------------------
# Type-Safe Public Query API
# -----------------------------------------------------------------------------

func get_unit(id_val: Variant) -> Resource:
	var key := StringName(str(id_val))
	return units.get(key, null)


func get_hero(id_val: Variant) -> Resource:
	var key := StringName(str(id_val))
	return heroes.get(key, null)


func get_skill(id_val: Variant) -> Resource:
	var key := StringName(str(id_val))
	return skills.get(key, null)


func get_buff(id_val: Variant) -> Resource:
	var key := StringName(str(id_val))
	return buffs.get(key, null)


func get_upgrade(id_val: Variant) -> UpgradeData:
	var key := StringName(str(id_val))
	return upgrades.get(key, null)


func get_spawner(id_val: Variant) -> SpawnerData:
	var key := StringName(str(id_val))
	return spawners.get(key, null)


func get_boss(id_val: Variant) -> BossData:
	var key := StringName(str(id_val))
	return bosses.get(key, null)


func get_difficulty(tier: int) -> DifficultyData:
	return difficulties.get(tier, null)


func get_mode(id_val: Variant) -> ModeData:
	var key := StringName(str(id_val))
	return modes.get(key, null)


func get_all_heroes() -> Array:
	return heroes.values()


func get_all_units() -> Array:
	return units.values()


func get_all_skills() -> Array:
	return skills.values()


func get_all_buffs() -> Array:
	return buffs.values()


func get_all_spawners() -> Array:
	return spawners.values()
