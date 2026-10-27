class_name DataValidator
extends RefCounted

## DataValidator - SFE5 Data Integrity & Sanity Verification Engine (Task 2.3).
## Recursively validates all .tres resources in res://data/.
## Detects duplicate IDs, broken references, non-positive vitals, and invalid ranges.

static func validate_all(root_dir: String = "res://data") -> Dictionary:
	var report := {
		"valid": true,
		"checked_count": 0,
		"error_count": 0,
		"warning_count": 0,
		"errors": [] as Array[String],
		"warnings": [] as Array[String],
		"ids_seen": {} as Dictionary # type_name -> Array[String]
	}

	var files := _collect_tres_files(root_dir)
	report["checked_count"] = files.size()

	for f_path in files:
		_validate_single_resource(f_path, report)

	report["error_count"] = report["errors"].size()
	report["warning_count"] = report["warnings"].size()
	report["valid"] = (report["error_count"] == 0)
	return report


static func _collect_tres_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			result.append_array(_collect_tres_files(dir_path.path_join(file_name)))
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			result.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


static func _validate_single_resource(path: String, report: Dictionary) -> void:
	var res := ResourceLoader.load(path)
	if res == null:
		report["errors"].append("Resource failed to load (corrupt or broken script): " + path)
		return

	# 1. HeroData validation
	if res is HeroData:
		var hero: HeroData = res as HeroData
		var h_id := str(hero.archetype_id)
		_check_id("hero", h_id, path, report)
		if hero.base_hp <= 0.0:
			report["errors"].append("%s: base_hp must be > 0 (got %.1f)" % [path, hero.base_hp])
		if hero.base_cooldown <= 0.0:
			report["errors"].append("%s: base_cooldown must be > 0 (got %.2f)" % [path, hero.base_cooldown])
		if hero.move_speed <= 0.0:
			report["warnings"].append("%s: hero move_speed is non-positive" % path)

		for i in range(hero.skills.size()):
			var sk = hero.skills[i]
			if sk == null:
				report["errors"].append("%s: hero skill slot %d is null" % [path, i])

	# 2. UnitData / BossData validation
	elif res is UnitData:
		var unit: UnitData = res as UnitData
		var u_id := str(unit.id)
		_check_id("unit", u_id, path, report)
		if unit.max_health <= 0.0:
			report["errors"].append("%s: max_health must be > 0 (got %.1f)" % [path, unit.max_health])
		if unit.attack_cooldown <= 0.0 and unit.has_weapon:
			report["errors"].append("%s: attack_cooldown must be > 0 (got %.2f)" % [path, unit.attack_cooldown])

	# 3. AbilityData / HeroSkillData validation
	elif res is AbilityData:
		var ab: AbilityData = res as AbilityData
		var ab_id := str(ab.id)
		_check_id("ability", ab_id, path, report)
		if ab.cooldown < 0.0:
			report["errors"].append("%s: cooldown cannot be negative (got %.2f)" % [path, ab.cooldown])
		if ab.energy_cost < 0.0:
			report["errors"].append("%s: energy_cost cannot be negative (got %.1f)" % [path, ab.energy_cost])

	elif res is HeroSkillData:
		var sk: HeroSkillData = res as HeroSkillData
		var sk_id := str(sk.skill_id)
		_check_id("skill", sk_id, path, report)
		if sk.cooldown < 0.0:
			report["errors"].append("%s: cooldown cannot be negative (got %.2f)" % [path, sk.cooldown])
		if sk.energy_cost < 0.0:
			report["errors"].append("%s: energy_cost cannot be negative (got %.1f)" % [path, sk.energy_cost])

	# 4. BuffData / SFEBuffDef validation
	elif res is BuffData:
		var buf: BuffData = res as BuffData
		var b_id := str(buf.id)
		_check_id("buff", b_id, path, report)
		if buf.duration < 0.0:
			report["errors"].append("%s: duration cannot be negative (got %.2f)" % [path, buf.duration])
		if buf.max_stacks < 1:
			report["errors"].append("%s: max_stacks must be >= 1 (got %d)" % [path, buf.max_stacks])

	elif res is SFEBuffDef:
		var b_def: SFEBuffDef = res as SFEBuffDef
		var b_id := str(b_def.buff_id)
		_check_id("buff", b_id, path, report)
		if b_def.default_duration < 0.0:
			report["errors"].append("%s: duration cannot be negative" % path)

	# 5. SpawnerData validation
	elif res is SpawnerData:
		var sp: SpawnerData = res as SpawnerData
		var sp_id := str(sp.id)
		_check_id("spawner", sp_id, path, report)
		if sp.cycle_seconds <= 0.0:
			report["errors"].append("%s: cycle_seconds must be > 0 (got %.2f)" % [path, sp.cycle_seconds])
		if sp.group_size < 1:
			report["errors"].append("%s: group_size must be >= 1" % path)
		if sp.structure_health <= 0.0:
			report["errors"].append("%s: structure_health must be > 0" % path)


static func _check_id(type_name: String, id_val: String, path: String, report: Dictionary) -> void:
	if id_val.strip_edges() == "" or id_val == "unnamed_" + type_name:
		report["warnings"].append("%s: %s has default or empty id '%s'" % [path, type_name, id_val])
		return

	var seen_map: Dictionary = report["ids_seen"]
	if not seen_map.has(type_name):
		seen_map[type_name] = []
	var list: Array = seen_map[type_name]
	if list.has(id_val):
		report["errors"].append("%s: Duplicate %s id '%s' already registered" % [path, type_name, id_val])
	else:
		list.append(id_val)
