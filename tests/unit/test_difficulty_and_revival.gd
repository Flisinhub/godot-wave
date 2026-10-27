class_name TestDifficultyAndRevival
extends RefCounted

## TestDifficultyAndRevival - Verification Suite for SFE5 Fase 7 (Difficulty, Death & Revival).
## Covers:
## 1. DifficultyData resource integrity across all 6 tiers (Casual -> Impossible).
## 2. Revive timer calculation: base + (increment * hero_level).
## 3. Wallet mineral penalties on death per difficulty tier.
## 4. Buff stripping and cost retention on hero death.
## 5. HeroUnit3D death, countdown, and respawn loop with invulnerability shield.

const DifficultyData = preload("res://core/data/difficulty_data.gd")
const HeroUnit3DScript = preload("res://entities/allies/hero_unit_3d.gd")
const BuffComponent = preload("res://core/components/buff_component.gd")

var passed_count: int = 0
var failed_count: int = 0


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failed_count += 1
		push_error("Assertion Failed: " + message)
		assert(condition, message)
	else:
		passed_count += 1


## Test 1: Task 7.1 - 6 DifficultyData resources loaded with exact specification values
func test_difficulty_resources_specification_matrix() -> void:
	var tiers_info := [
		{ "path": "res://data/difficulties/casual.tres", "tier": 0, "name": "Casual", "inc": 1.15, "base_t": 15.0, "inc_t": 0.3, "pen": 0.0, "buffs": false },
		{ "path": "res://data/difficulties/normal.tres", "tier": 1, "name": "Normal", "inc": 1.00, "base_t": 20.0, "inc_t": 0.4, "pen": 0.25, "buffs": true },
		{ "path": "res://data/difficulties/hard.tres", "tier": 2, "name": "Hard", "inc": 0.80, "base_t": 30.0, "inc_t": 0.6, "pen": 0.50, "buffs": true },
		{ "path": "res://data/difficulties/brutal.tres", "tier": 3, "name": "Brutal", "inc": 0.70, "base_t": 40.0, "inc_t": 0.9, "pen": 0.75, "buffs": true },
		{ "path": "res://data/difficulties/torment.tres", "tier": 4, "name": "Torment", "inc": 0.60, "base_t": 40.0, "inc_t": 0.9, "pen": 1.00, "buffs": true },
		{ "path": "res://data/difficulties/impossible.tres", "tier": 5, "name": "Impossible", "inc": 0.30, "base_t": 40.0, "inc_t": 0.9, "pen": 1.00, "buffs": true }
	]

	for entry in tiers_info:
		var d = load(entry["path"]) as DifficultyData
		_assert(d != null, "Difficulty resource '%s' loaded" % entry["path"])
		_assert(d.tier == entry["tier"], "%s has tier %d" % [entry["name"], entry["tier"]])
		_assert(is_equal_approx(d.income_multiplier, entry["inc"]), "%s income multiplier = %.2fx" % [entry["name"], entry["inc"]])
		_assert(is_equal_approx(d.base_revive_time_seconds, entry["base_t"]), "%s base revive time = %.1fs" % [entry["name"], entry["base_t"]])
		_assert(is_equal_approx(d.revive_time_increment_per_level, entry["inc_t"]), "%s increment per level = %.2fs" % [entry["name"], entry["inc_t"]])
		_assert(is_equal_approx(d.mineral_penalty_on_death, entry["pen"]), "%s mineral penalty = %.0f%%" % [entry["name"], entry["pen"] * 100.0])
		_assert(d.loses_buffs_on_death == entry["buffs"], "%s buff loss on death = %s" % [entry["name"], str(entry["buffs"])])


## Test 2: Task 7.4 - Revive time formulas scale with hero level
func test_revive_time_calculations() -> void:
	var casual: DifficultyData = load("res://data/difficulties/casual.tres")
	var normal: DifficultyData = load("res://data/difficulties/normal.tres")
	var brutal: DifficultyData = load("res://data/difficulties/brutal.tres")

	# Casual: 15s + 0.3s * level
	_assert(is_equal_approx(casual.calculate_revive_time(1), 15.3), "Casual Lvl 1 = 15.3s")
	_assert(is_equal_approx(casual.calculate_revive_time(10), 18.0), "Casual Lvl 10 = 18.0s")
	_assert(is_equal_approx(casual.calculate_revive_time(100), 45.0), "Casual Lvl 100 = 45.0s")

	# Normal: 20s + 0.4s * level
	_assert(is_equal_approx(normal.calculate_revive_time(1), 20.4), "Normal Lvl 1 = 20.4s")
	_assert(is_equal_approx(normal.calculate_revive_time(10), 24.0), "Normal Lvl 10 = 24.0s")
	_assert(is_equal_approx(normal.calculate_revive_time(50), 40.0), "Normal Lvl 50 = 40.0s")

	# Brutal: 40s + 0.9s * level
	_assert(is_equal_approx(brutal.calculate_revive_time(10), 49.0), "Brutal Lvl 10 = 49.0s")
	_assert(is_equal_approx(brutal.calculate_revive_time(100), 130.0), "Brutal Lvl 100 = 130.0s")


## Test 3: Task 7.3 - Mineral loss penalty calculations on death
func test_mineral_penalty_calculations() -> void:
	var casual: DifficultyData = load("res://data/difficulties/casual.tres")
	var normal: DifficultyData = load("res://data/difficulties/normal.tres")
	var hard: DifficultyData = load("res://data/difficulties/hard.tres")
	var brutal: DifficultyData = load("res://data/difficulties/brutal.tres")
	var torment: DifficultyData = load("res://data/difficulties/torment.tres")

	var wallet: int = 10000
	_assert(casual.calculate_mineral_penalty(wallet) == 0, "Casual: 0 penalty on 10000 minerals")
	_assert(normal.calculate_mineral_penalty(wallet) == 2500, "Normal: 2500 penalty (25%) on 10000 minerals")
	_assert(hard.calculate_mineral_penalty(wallet) == 5000, "Hard: 5000 penalty (50%) on 10000 minerals")
	_assert(brutal.calculate_mineral_penalty(wallet) == 7500, "Brutal: 7500 penalty (75%) on 10000 minerals")
	_assert(torment.calculate_mineral_penalty(wallet) == 10000, "Torment: 10000 penalty (100%) on 10000 minerals")


## Test 4: Task 7.3 - Buff stripping and cost retention upon death
func test_buff_stripping_on_death() -> void:
	var buff_comp := BuffComponent.new()
	buff_comp.equip_tier_buff(1, "optical_lens", "Optical Lens", 1000)
	buff_comp.equip_tier_buff(3, "momentum", "Momentum", 3000)
	_assert(buff_comp.active_tier_buffs.size() == 2, "2 tier buffs equipped initially")

	# Normal difficulty: 25% cost retained refund (1000 + 3000 = 4000 total -> 1000 refund)
	var refund := buff_comp.strip_buffs_on_death(0.25)
	_assert(refund == 1000, "Normal death refund = 1000 minerals (25% of 4000)")
	_assert(buff_comp.active_tier_buffs.is_empty(), "All buffs stripped from component")

	buff_comp.free()


## Test 5: Task 7.4 & 7.5 - HeroUnit3D death, countdown, and respawn loop
func test_hero_death_and_respawn_loop() -> void:
	var hero := HeroUnit3DScript.new()
	hero.current_difficulty_data = load("res://data/difficulties/normal.tres")
	hero.spawn_position = Vector3(10.0, 0.0, 20.0)
	hero.max_health = 500.0
	hero.current_health = 500.0

	var died_signal_received := [false]
	var respawned_signal_received := [false]
	hero.hero_died_event.connect(func(_h, _t, _p): died_signal_received[0] = true)
	hero.hero_respawned.connect(func(_h): respawned_signal_received[0] = true)

	# Trigger death
	hero.die()
	_assert(died_signal_received[0], "hero_died_event signal emitted")
	_assert(hero.is_dead, "Hero enters is_dead state")
	_assert(hero.revive_timer > 20.0, "Revive timer initialized (> 20s for normal)")

	# Advance time halfway
	var initial_time: float = hero.revive_timer
	hero._physics_process(10.0)
	_assert(hero.is_dead, "Still dead after 10s")
	_assert(is_equal_approx(hero.revive_timer, initial_time - 10.0), "Revive timer decreased by 10s")

	# Advance remaining time to complete revival
	hero._physics_process(initial_time)
	_assert(not hero.is_dead, "Hero is no longer dead")
	_assert(respawned_signal_received[0], "hero_respawned signal emitted")
	_assert(is_equal_approx(hero.current_health, 500.0), "Hero HP restored to 500.0")
	_assert(hero.buff_engine.is_invulnerable(), "Hero has invulnerability shield upon respawn")

	hero.free()
