extends Node

## Adversarial Stress & Edge Case Test Suite for Milestone 4
## Tests failure modes, boundary conditions, zero vectors, extreme numbers,
## rapid recycling, and integrity of Combat VFX & SC2 Console HUD.

const CombatVFXPool = preload("res://core/vfx/combat_vfx_pool.gd")
const StructureDamageVFX = preload("res://core/vfx/structure_damage_vfx.gd")
const SC2HUDRoot = preload("res://ui/sc2_hud_root.gd")
const SC2StatPanel = preload("res://ui/sc2_stat_panel.gd")
const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const HeroSkillData = preload("res://data/skills/hero_skill_data.gd")
const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _ready() -> void:
	print("\u001b[35m\u001b[1m==========================================================")
	print("=== SFE5 MILESTONE 4: ADVERSARIAL STRESS TEST SUITE ===")
	print("==========================================================\u001b[0m")
	var start_ms: int = Time.get_ticks_msec()

	_run_adversarial_suite()

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	print("\n\u001b[35m==========================================================")
	print("Adversarial Suite Execution in %d ms" % elapsed_ms)
	print("Total Tests: %d" % total_tests)
	print("Passed:      %d" % passed_tests)
	print("Failed:      %d" % failed_tests)

	if failed_tests > 0:
		print("\u001b[31mAdversarial Failures:")
		for msg in failures:
			print("  * " + msg)
		print("\u001b[1mADVERSARIAL STRESS TEST FAILED! [STATUS: RED]\u001b[0m")
		print("==========================================================\u001b[0m")
		get_tree().quit(1)
	else:
		print("\u001b[32m\u001b[1mALL ADVERSARIAL STRESS TESTS PASSED! [STATUS: GREEN]\u001b[0m")
		print("==========================================================")
		get_tree().quit(0)


func _run_adversarial_suite() -> void:
	_test("adv_tracer_extreme_vectors_and_vertical_shots", adv_tracer_extreme_vectors_and_vertical_shots)
	_test("adv_acid_burst_flood_and_frame_throttle", adv_acid_burst_flood_and_frame_throttle)
	_test("adv_structure_damage_degenerate_hp_values", adv_structure_damage_degenerate_hp_values)
	_test("adv_structure_damage_rapid_threshold_oscillation", adv_structure_damage_rapid_threshold_oscillation)
	_test("adv_stat_panel_null_and_extreme_vitals", adv_stat_panel_null_and_extreme_vitals)
	_test("adv_wireframe_display_state_invariants", adv_wireframe_display_state_invariants)
	_test("adv_command_card_out_of_bounds_and_hotkey_integrity", adv_command_card_out_of_bounds_and_hotkey_integrity)
	_test("adv_defensive_structures_full_hierarchy_and_vfx_contract", adv_defensive_structures_full_hierarchy_and_vfx_contract)


func _test(test_name: String, callable: Callable) -> void:
	total_tests += 1
	var res: Dictionary = callable.call()
	if res.get("passed", false):
		passed_tests += 1
		print("  \u001b[32m[PASS]\u001b[0m %s" % test_name)
	else:
		failed_tests += 1
		var err: String = "%s: %s" % [test_name, res.get("error", "Failed")]
		failures.append(err)
		print("  \u001b[31m[FAIL]\u001b[0m %s" % err)


## Stress 1: Spawn tracers with degenerate vectors: exactly identical positions,
## pure vertical shots (Vector3.UP and -Vector3.UP), extreme distances (>10,000 units),
## and negative coordinates.
func adv_tracer_extreme_vectors_and_vertical_shots() -> Dictionary:
	var pool := CombatVFXPool.new()
	add_child(pool)

	# 1. Identical positions (distance 0.0)
	var t0 = pool.spawn_tracer(Vector3(10, 5, 10), Vector3(10, 5, 10))
	if t0 == null:
		pool.queue_free()
		return {"passed": false, "error": "spawn_tracer failed on zero distance"}

	# 2. Pure vertical shots straight UP (dot with UP is 1.0)
	var t_up = pool.spawn_tracer(Vector3(0, 0, 0), Vector3(0, 50, 0))
	if t_up == null:
		pool.queue_free()
		return {"passed": false, "error": "spawn_tracer failed on straight vertical UP shot"}

	# 3. Pure vertical shots straight DOWN (dot with UP is -1.0)
	var t_down = pool.spawn_tracer(Vector3(0, 50, 0), Vector3(0, 0, 0))
	if t_down == null:
		pool.queue_free()
		return {"passed": false, "error": "spawn_tracer failed on straight vertical DOWN shot"}

	# 4. Rapid spam of 500 shots with random extreme coordinates
	for i in range(500):
		var p1 := Vector3(float(i * 10), -50.0, float(-i * 5))
		var p2 := Vector3(float(-i * 10), 100.0, float(i * 5))
		var tr := pool.spawn_tracer(p1, p2)
		if tr == null:
			pool.queue_free()
			return {"passed": false, "error": "Failed during 500-shot tracer spam at iteration %d" % i}

	# Child count must remain exactly 44
	if pool.get_child_count() != 44:
		pool.queue_free()
		return {"passed": false, "error": "Child count leaked: %d" % pool.get_child_count()}

	pool.queue_free()
	return {"passed": true}


## Stress 2: Flood acid bursts in a single frame to verify burst rate limiter
func adv_acid_burst_flood_and_frame_throttle() -> Dictionary:
	var pool := CombatVFXPool.new()
	add_child(pool)

	# In one frame, spawn 50 bursts. Only MAX_BURSTS_PER_FRAME (6) should succeed.
	var success_count: int = 0
	var throttled_count: int = 0
	for i in range(50):
		var b = pool.spawn_acid_burst(Vector3(float(i), 0, 0))
		if b != null:
			success_count += 1
		else:
			throttled_count += 1

	if success_count != 6:
		pool.queue_free()
		return {"passed": false, "error": "Expected exactly 6 allowed bursts per frame, got %d" % success_count}

	if throttled_count != 44:
		pool.queue_free()
		return {"passed": false, "error": "Expected 44 throttled bursts, got %d" % throttled_count}

	# Simulate next frame: throttle must reset
	pool._process(0.016)
	var next_b = pool.spawn_acid_burst(Vector3.ZERO)
	if next_b == null:
		pool.queue_free()
		return {"passed": false, "error": "Acid burst throttle did not reset on next frame"}

	pool.queue_free()
	return {"passed": true}


## Stress 3: Degenerate HP values for StructureDamageVFX (negative HP, 0 max_hp, negative max_hp, overhealed)
func adv_structure_damage_degenerate_hp_values() -> Dictionary:
	var vfx := StructureDamageVFX.new()
	add_child(vfx)
	vfx._is_headless = false # Enable logical checking

	# Overkill: negative current HP (-500 HP / 1000 max) -> Critical damage state (< 35%)
	vfx.update_damage_state(-500.0, 1000.0)
	if not (vfx.is_smoke_active() and vfx.is_fire_active() and vfx.is_sparks_active()):
		vfx.queue_free()
		return {"passed": false, "error": "Overkill negative HP failed to activate critical damage emitters"}

	# Zero max_hp: must not divide by zero!
	vfx.update_damage_state(0.0, 0.0)
	# ratio = 0.0 / maxf(1.0, 0.0) = 0.0 -> Critical damage state (< 35%)
	if not (vfx.is_smoke_active() and vfx.is_fire_active() and vfx.is_sparks_active()):
		vfx.queue_free()
		return {"passed": false, "error": "Zero max_hp caused error or failed to activate critical state"}

	# Negative max_hp: maxf(1.0, -100.0) = 1.0 -> ratio = 100.0 / 1.0 = 100.0 -> Pristine state (> 70%)
	vfx.update_damage_state(100.0, -100.0)
	if vfx.is_smoke_active() or vfx.is_fire_active() or vfx.is_sparks_active():
		vfx.queue_free()
		return {"passed": false, "error": "Negative max_hp caused erroneous emitter activation"}

	# Overhealed: 2000 HP / 1000 max -> Pristine state (> 70%)
	vfx.update_damage_state(2000.0, 1000.0)
	if vfx.is_smoke_active() or vfx.is_fire_active() or vfx.is_sparks_active():
		vfx.queue_free()
		return {"passed": false, "error": "Overhealed state failed to keep emitters off"}

	vfx.queue_free()
	return {"passed": true}


## Stress 4: Rapid threshold oscillation across 70% and 35% boundaries
func adv_structure_damage_rapid_threshold_oscillation() -> Dictionary:
	var vfx := StructureDamageVFX.new()
	add_child(vfx)
	vfx._is_headless = false

	for cycle in range(100):
		# Just above 70% (701 / 1000 = 0.701) -> Pristine
		vfx.update_damage_state(701.0, 1000.0)
		if vfx.is_smoke_active() or vfx.is_fire_active():
			vfx.queue_free()
			return {"passed": false, "error": "Smoke active at 70.1% on cycle %d" % cycle}

		# Just below 70% (699 / 1000 = 0.699) -> Light Smoke ONLY
		vfx.update_damage_state(699.0, 1000.0)
		if not vfx.is_smoke_active() or vfx.is_fire_active() or vfx.is_sparks_active():
			vfx.queue_free()
			return {"passed": false, "error": "Incorrect emitters at 69.9% on cycle %d" % cycle}

		# Just below 35% (349 / 1000 = 0.349) -> Heavy Smoke, Fire, Sparks
		vfx.update_damage_state(349.0, 1000.0)
		if not (vfx.is_smoke_active() and vfx.is_fire_active() and vfx.is_sparks_active()):
			vfx.queue_free()
			return {"passed": false, "error": "Missing emitters at 34.9% on cycle %d" % cycle}

		# Repaired back to 1000 / 1000 -> Pristine
		vfx.update_damage_state(1000.0, 1000.0)
		if vfx.is_smoke_active() or vfx.is_fire_active() or vfx.is_sparks_active():
			vfx.queue_free()
			return {"passed": false, "error": "Emitters failed to deactivate on repair at cycle %d" % cycle}

	vfx.queue_free()
	return {"passed": true}


## Stress 5: Stat panel handling null unit, freed unit, and extreme vital values
func adv_stat_panel_null_and_extreme_vitals() -> Dictionary:
	var panel := SC2StatPanel.new()
	add_child(panel)
	panel._build_ui_layout()

	# 1. Bind null unit
	panel.bind_unit(null)
	if panel.name_label.text != "No Selection":
		panel.queue_free()
		return {"passed": false, "error": "Expected 'No Selection' on null bind"}

	# 2. Bind temporary node then free it
	var temp_node := Node3D.new()
	add_child(temp_node)
	panel.bind_unit(temp_node)
	temp_node.free()
	# Refreshing display on freed unit must gracefully fallback to clear display without crashing
	panel.refresh_display()
	if panel.name_label.text != "No Selection":
		panel.queue_free()
		return {"passed": false, "error": "Expected graceful fallback on freed unit"}

	# 3. Hero with 0 max_hp, extreme energy, negative shield
	var dummy_hero := Node3D.new()
	var hdata := HeroData.new()
	hdata.hero_name = "Adversarial Marine"
	hdata.max_hp = 0.0
	hdata.current_hp = 0.0
	hdata.max_shield = 0.0
	hdata.max_energy = 5000.0
	hdata.current_energy = 4500.0
	hdata.attribute_points = 0
	dummy_hero.set("hero_data", hdata)

	panel.bind_unit(dummy_hero)
	panel._update_hp_bar_color(0.0, 0.0) # Must not crash with divide-by-zero
	if panel._hp_fill_style.bg_color.r < 0.9:
		panel.queue_free()
		dummy_hero.free()
		return {"passed": false, "error": "Expected critical red color on 0/0 HP"}

	# Spend attribute points when 0 points available: must reject
	panel._on_attribute_allocated("str")
	if hdata.strength != 10:
		panel.queue_free()
		dummy_hero.free()
		return {"passed": false, "error": "Attribute was allocated with 0 attribute points!"}

	panel.queue_free()
	dummy_hero.free()
	return {"passed": true}


## Stress 6: Wireframe rect state invariants
func adv_wireframe_display_state_invariants() -> Dictionary:
	var wireframe := SC2StatPanel.SC2WireframeDisplay.new()
	add_child(wireframe)

	if wireframe.custom_minimum_size != Vector2(90, 110):
		wireframe.queue_free()
		return {"passed": false, "error": "Wireframe minimum size expected Vector2(90, 110)"}

	# Check process queue_redraw guard
	wireframe._process(0.016)

	wireframe.queue_free()
	return {"passed": true}


## Stress 7: Command card out-of-bounds slot press & hotkey integrity
func adv_command_card_out_of_bounds_and_hotkey_integrity() -> Dictionary:
	var card := SC2CommandCard.new()
	add_child(card)
	card._setup_procedural_grid()

	# 1. Out-of-bounds slot press
	card._on_slot_pressed(-1)
	card._on_slot_pressed( card.slot_buttons.size() + 10 )

	# 2. Check 15 slots have unique hotkeys in default set
	var hotkeys_seen: Dictionary = {}
	for k in SC2CommandCard.DEFAULT_HOTKEYS:
		if hotkeys_seen.has(k):
			card.queue_free()
			return {"passed": false, "error": "Duplicate hotkey '%s' in DEFAULT_HOTKEYS" % k}
		hotkeys_seen[k] = true

	if SC2CommandCard.DEFAULT_HOTKEYS.size() != 15:
		card.queue_free()
		return {"passed": false, "error": "DEFAULT_HOTKEYS does not match 15 slots"}

	# 3. Hero cooldown formatting
	var hero_dummy := CharacterBody3D.new()
	hero_dummy.set_script(HeroUnit3D)
	add_child(hero_dummy)
	var h_data := HeroData.new()
	var s1 := HeroSkillData.new()
	s1.skill_id = "test_grenade"
	s1.skill_name = "Frag Grenade"
	s1.hotkey = "Q"
	s1.energy_cost = 20.0
	s1.cooldown = 6.0
	h_data.skills = [s1]
	h_data.current_energy = 50.0

	hero_dummy.hero_data = h_data
	card.populate_for_unit(hero_dummy)

	var btn0: Button = card.slot_buttons[0]
	if not btn0.text.begins_with("[Q]"):
		card.queue_free()
		hero_dummy.queue_free()
		return {"passed": false, "error": "Expected button 0 to start with '[Q]', got: %s" % btn0.text}

	card.queue_free()
	hero_dummy.queue_free()
	return {"passed": true}


## Stress 8: Defensive structures full hierarchy and VFX contract
func adv_defensive_structures_full_hierarchy_and_vfx_contract() -> Dictionary:
	var cc_scene: PackedScene = load("res://entities/structures/command_center.tscn")
	var wall_scene: PackedScene = load("res://entities/structures/wall_segment.tscn")
	var gate_scene: PackedScene = load("res://entities/structures/gate_structure.tscn")
	var bunker_scene: PackedScene = load("res://entities/structures/bunker_structure.tscn")

	# Check Command Center
	var cc = cc_scene.instantiate()
	var cc_vfx = cc.get_node_or_null("VisualRoot/DamageVFX")
	if cc_vfx == null or not (cc_vfx is StructureDamageVFX):
		cc.free()
		return {"passed": false, "error": "CommandCenter missing StructureDamageVFX under VisualRoot"}
	var cc_col: CollisionShape3D = cc.get_node_or_null("CollisionShape3D")
	if cc_col == null or not (cc_col.shape is BoxShape3D) or (cc_col.shape as BoxShape3D).size != Vector3(8, 4, 8):
		cc.free()
		return {"passed": false, "error": "CommandCenter CollisionShape3D invalid"}
	cc.free()

	# Check Wall Segment
	var wall = wall_scene.instantiate()
	var wall_vfx = wall.get_node_or_null("VisualRoot/DamageVFX")
	if wall_vfx == null or not (wall_vfx is StructureDamageVFX):
		wall.free()
		return {"passed": false, "error": "WallSegment missing StructureDamageVFX under VisualRoot"}
	var wall_col: CollisionShape3D = wall.get_node_or_null("CollisionShape3D")
	if wall_col == null or not (wall_col.shape is BoxShape3D) or (wall_col.shape as BoxShape3D).size != Vector3(4, 3.2, 1.2):
		wall.free()
		return {"passed": false, "error": "WallSegment CollisionShape3D invalid"}
	wall.free()

	# Check Gate Structure
	var gate = gate_scene.instantiate()
	var gate_vfx = gate.get_node_or_null("VisualRoot/DamageVFX")
	if gate_vfx == null or not (gate_vfx is StructureDamageVFX):
		gate.free()
		return {"passed": false, "error": "GateStructure missing StructureDamageVFX under VisualRoot"}
	var gate_light = gate.get_node_or_null("VisualRoot/StatusLight")
	var gate_door = gate.get_node_or_null("VisualRoot/DoorSlidingPart")
	if gate_light == null or gate_door == null:
		gate.free()
		return {"passed": false, "error": "GateStructure missing StatusLight or DoorSlidingPart in VisualRoot"}
	var gate_col: CollisionShape3D = gate.get_node_or_null("DoorCollisionShape")
	if gate_col == null or not (gate_col.shape is BoxShape3D) or (gate_col.shape as BoxShape3D).size != Vector3(4, 3.3, 0.6):
		gate.free()
		return {"passed": false, "error": "GateStructure DoorCollisionShape invalid"}
	gate.free()

	# Check Bunker Structure
	var bunker = bunker_scene.instantiate()
	var bunker_vfx = bunker.get_node_or_null("VisualRoot/DamageVFX")
	if bunker_vfx == null or not (bunker_vfx is StructureDamageVFX):
		bunker.free()
		return {"passed": false, "error": "BunkerStructure missing StructureDamageVFX under VisualRoot"}
	var bunker_col: CollisionShape3D = bunker.get_node_or_null("CollisionShape3D")
	if bunker_col == null or not (bunker_col.shape is BoxShape3D) or (bunker_col.shape as BoxShape3D).size != Vector3(3.5, 2.5, 3.5):
		bunker.free()
		return {"passed": false, "error": "BunkerStructure CollisionShape3D invalid"}
	bunker.free()

	return {"passed": true}
