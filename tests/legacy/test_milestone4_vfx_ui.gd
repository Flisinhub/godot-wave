extends SceneTree

## Test Suite for Milestone 4:
## Real-Time Combat VFX (CombatVFXPool, StructureDamageVFX) & StarCraft II Console HUD Finishing.
## Validates zero-allocation object pooling, damage particle thresholds, collision preservation,
## procedural StyleBoxFlat theme hierarchies, and 100% headless test stability.

const CombatVFXPool = preload("res://core/vfx/combat_vfx_pool.gd")
const StructureDamageVFX = preload("res://core/vfx/structure_damage_vfx.gd")
const SC2HUDRoot = preload("res://ui/sc2_hud_root.gd")
const SC2StatPanel = preload("res://ui/sc2_stat_panel.gd")
const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_messages: Array[String] = []


func _init() -> void:
	print("\u001b[36m\u001b[1m==========================================================")
	print("=== SFE5 MILESTONE 4: COMBAT VFX & SC2 HUD TEST SUITE ===")
	print("==========================================================\u001b[0m")
	var start_time: int = Time.get_ticks_msec()

	_run_all_tests()

	var elapsed_ms: int = Time.get_ticks_msec() - start_time
	print("\n\u001b[36m==========================================================")
	print("Milestone 4 Test Execution Complete in %d ms" % elapsed_ms)
	print("Total Tests: %d" % total_tests)
	print("Passed:      %d" % passed_tests)
	print("Failed:      %d" % failed_tests)

	if failed_tests > 0:
		print("\u001b[31mFailures:")
		for msg in failure_messages:
			print("  * " + msg)
		print("\u001b[1mTEST SUITE FAILED! [STATUS: RED]\u001b[0m")
		print("==========================================================\u001b[0m")
		quit(1)
	else:
		print("\u001b[32m\u001b[1mALL MILESTONE 4 TEST SUITES PASSED! [STATUS: GREEN]\u001b[0m")
		print("==========================================================")
		quit(0)


func _run_all_tests() -> void:
	_run_test("test_combat_vfx_pool_preallocation", test_combat_vfx_pool_preallocation)
	_run_test("test_combat_vfx_pool_zero_allocation", test_combat_vfx_pool_zero_allocation)
	_run_test("test_combat_vfx_pool_circular_recycling", test_combat_vfx_pool_circular_recycling)
	_run_test("test_structure_damage_vfx_thresholds", test_structure_damage_vfx_thresholds)
	_run_test("test_defensive_structures_preserve_collision_and_mitigation", test_defensive_structures_preserve_collision_and_mitigation)
	_run_test("test_sc2_hud_root_procedural_styling", test_sc2_hud_root_procedural_styling)
	_run_test("test_sc2_stat_panel_wireframe_and_gauges", test_sc2_stat_panel_wireframe_and_gauges)
	_run_test("test_sc2_command_card_grid_and_hotkey_styling", test_sc2_command_card_grid_and_hotkey_styling)


func _run_test(test_name: String, test_func: Callable) -> void:
	total_tests += 1
	var result: Dictionary = test_func.call()
	if result.get("passed", false):
		passed_tests += 1
		print("  \u001b[32m[PASS]\u001b[0m %s" % test_name)
	else:
		failed_tests += 1
		var err_msg: String = "%s -> %s" % [test_name, result.get("error", "Unknown failure")]
		failure_messages.append(err_msg)
		print("  \u001b[31m[FAIL]\u001b[0m %s" % err_msg)


## Test 1: Verify CombatVFXPool pre-allocates 24 Gauss tracers and 20 acid blood bursts
func test_combat_vfx_pool_preallocation() -> Dictionary:
	var pool := CombatVFXPool.new()
	pool._ready()

	if pool.get_tracer_pool_size() != 24:
		pool.free()
		return {"passed": false, "error": "Expected 24 pre-allocated tracers, got %d" % pool.get_tracer_pool_size()}

	if pool.get_acid_pool_size() != 20:
		pool.free()
		return {"passed": false, "error": "Expected 20 pre-allocated acid bursts, got %d" % pool.get_acid_pool_size()}

	# Verify all initial instances are hidden or dormant
	var child_count := pool.get_child_count()
	if child_count != 44:
		pool.free()
		return {"passed": false, "error": "Expected 44 total pooled children (24 + 20), got %d" % child_count}

	pool.free()
	return {"passed": true}


## Test 2: Verify zero allocations occur when repeatedly spawning tracers and acid bursts
func test_combat_vfx_pool_zero_allocation() -> Dictionary:
	var pool := CombatVFXPool.new()
	pool._ready()

	var initial_child_count := pool.get_child_count()

	# Fire 50 bullet tracers across space
	for i in range(50):
		var from_pos := Vector3(0.0, 1.0, 0.0)
		var to_pos := Vector3(float(i), 0.0, float(i * 2))
		var tracer := pool.spawn_tracer(from_pos, to_pos)
		if tracer == null:
			pool.free()
			return {"passed": false, "error": "spawn_tracer returned null on iteration %d" % i}

	# Spawn 50 acid blood bursts (with per-frame resets)
	for i in range(50):
		pool._process(0.016) # Resets frame burst limiter
		var burst := pool.spawn_acid_burst(Vector3(float(i), 0.0, 0.0))
		if burst == null:
			pool.free()
			return {"passed": false, "error": "spawn_acid_burst returned null on iteration %d" % i}

	# Verify child count has NOT grown
	var final_child_count := pool.get_child_count()
	if final_child_count != initial_child_count:
		pool.free()
		return {
			"passed": false,
			"error": "Memory leak/allocation spike detected! Children grew from %d to %d" % [initial_child_count, final_child_count]
		}

	pool.free()
	return {"passed": true}


## Test 3: Verify circular ring-buffer index recycling for both pools
func test_combat_vfx_pool_circular_recycling() -> Dictionary:
	var pool := CombatVFXPool.new()
	pool._ready()

	# Spawn 24 tracers: should occupy indices 0 through 23
	for i in range(24):
		pool.spawn_tracer(Vector3.ZERO, Vector3.FORWARD * 10.0)

	if pool._tracer_index != 0:
		pool.free()
		return {"passed": false, "error": "Expected tracer ring index to wrap to 0, got %d" % pool._tracer_index}

	# Spawn 20 acid bursts: should occupy indices 0 through 19
	for i in range(20):
		pool._process(0.016)
		pool.spawn_acid_burst(Vector3.ZERO)

	if pool._acid_index != 0:
		pool.free()
		return {"passed": false, "error": "Expected acid burst ring index to wrap to 0, got %d" % pool._acid_index}

	pool.free()
	return {"passed": true}


## Test 4: Verify StructureDamageVFX thresholds (< 70% light smoke, < 35% heavy smoke, sparks, fire)
func test_structure_damage_vfx_thresholds() -> Dictionary:
	var damage_vfx := StructureDamageVFX.new()
	damage_vfx._ready()

	# Force non-headless simulation state for logical flag testing
	damage_vfx._is_headless = false

	# 1. 100% Health (Pristine): No emissions
	damage_vfx.update_damage_state(1000.0, 1000.0)
	if damage_vfx.is_smoke_active() or damage_vfx.is_fire_active() or damage_vfx.is_sparks_active():
		damage_vfx.free()
		return {"passed": false, "error": "Expected all emitters OFF at 100% health"}

	# 2. 80% Health: No emissions
	damage_vfx.update_damage_state(800.0, 1000.0)
	if damage_vfx.is_smoke_active() or damage_vfx.is_fire_active() or damage_vfx.is_sparks_active():
		damage_vfx.free()
		return {"passed": false, "error": "Expected all emitters OFF at 80% health"}

	# 3. 60% Health (< 70% Moderate Damage): Light smoke ON, fire and sparks OFF
	damage_vfx.update_damage_state(600.0, 1000.0)
	if not damage_vfx.is_smoke_active():
		damage_vfx.free()
		return {"passed": false, "error": "Expected smoke ON at 60% health"}
	if damage_vfx.is_fire_active() or damage_vfx.is_sparks_active():
		damage_vfx.free()
		return {"passed": false, "error": "Expected fire and sparks OFF at 60% health"}

	# 4. 20% Health (< 35% Critical Damage): Heavy smoke ON, sparks ON, fire ON
	damage_vfx.update_damage_state(200.0, 1000.0)
	if not damage_vfx.is_smoke_active():
		damage_vfx.free()
		return {"passed": false, "error": "Expected smoke ON at 20% health"}
	if not damage_vfx.is_fire_active():
		damage_vfx.free()
		return {"passed": false, "error": "Expected fire ON at 20% health"}
	if not damage_vfx.is_sparks_active():
		damage_vfx.free()
		return {"passed": false, "error": "Expected sparks ON at 20% health"}

	# 5. Headless Guard Check: In headless mode, emitting must remain false
	damage_vfx._is_headless = true
	damage_vfx.update_damage_state(100.0, 1000.0)
	if damage_vfx.smoke_particles.emitting or damage_vfx.fire_particles.emitting or damage_vfx.sparks_particles.emitting:
		damage_vfx.free()
		return {"passed": false, "error": "Headless guard failed: particles emitting in headless mode"}

	damage_vfx.free()
	return {"passed": true}


## Test 5: Verify defensive structure scenes retain exact collision hitboxes, mitigations, and have DamageVFX
func test_defensive_structures_preserve_collision_and_mitigation() -> Dictionary:
	# 1. CommandCenter (.tscn)
	var cc_text := FileAccess.get_file_as_string("res://entities/structures/command_center.tscn")
	if not cc_text.contains("Vector3(8, 4, 8)"):
		return {"passed": false, "error": "CommandCenter collision box modified (expected Vector3(8, 4, 8))"}
	if not cc_text.contains('name="DamageVFX"'):
		return {"passed": false, "error": "CommandCenter missing DamageVFX node"}

	# 2. WallSegment (.tscn)
	var wall_text := FileAccess.get_file_as_string("res://entities/structures/wall_segment.tscn")
	if not wall_text.contains("Vector3(4, 3.2, 1.2)"):
		return {"passed": false, "error": "WallSegment collision box modified (expected Vector3(4, 3.2, 1.2))"}
	if not wall_text.contains('name="DamageVFX"'):
		return {"passed": false, "error": "WallSegment missing DamageVFX node"}

	# 3. GateStructure (.tscn)
	var gate_text := FileAccess.get_file_as_string("res://entities/structures/gate_structure.tscn")
	if not gate_text.contains("Vector3(4, 3.3, 0.6)"):
		return {"passed": false, "error": "GateStructure DoorCollisionShape modified (expected Vector3(4, 3.3, 0.6))"}
	if not gate_text.contains('name="DamageVFX"'):
		return {"passed": false, "error": "GateStructure missing DamageVFX node"}

	# 4. BunkerStructure (.tscn)
	var bunker_text := FileAccess.get_file_as_string("res://entities/structures/bunker_structure.tscn")
	if not bunker_text.contains("Vector3(3.5, 2.5, 3.5)"):
		return {"passed": false, "error": "BunkerStructure collision box modified (expected Vector3(3.5, 2.5, 3.5))"}
	if not bunker_text.contains('name="DamageVFX"'):
		return {"passed": false, "error": "BunkerStructure missing DamageVFX node"}

	# 5. Combat Engine Mitigations (35% Wall, 25% Bunker)
	var wall_res = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	if absf(wall_res.damage_dealt - 65.0) > 0.01:
		return {"passed": false, "error": "Wall 35% mitigation broken: expected 65.0 damage, got %f" % wall_res.damage_dealt}

	var bunker_res = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER, false)
	if absf(bunker_res.damage_dealt - 75.0) > 0.01:
		return {"passed": false, "error": "Bunker 25% mitigation broken: expected 75.0 damage, got %f" % bunker_res.damage_dealt}

	return {"passed": true}


## Test 6: Verify SC2HUDRoot procedural console styling, background panel, and MinimapBox
func test_sc2_hud_root_procedural_styling() -> Dictionary:
	var hud := SC2HUDRoot.new()
	hud._build_hud_layout()

	if hud.bottom_console == null:
		hud.free()
		return {"passed": false, "error": "BottomConsole missing in SC2HUDRoot"}

	var root_ctrl: Control = hud.get_node_or_null("HUDControlRoot")
	if root_ctrl == null:
		hud.free()
		return {"passed": false, "error": "HUDControlRoot missing in SC2HUDRoot"}

	var console_bg: Panel = root_ctrl.get_node_or_null("ConsoleBackground")
	if console_bg == null:
		hud.free()
		return {"passed": false, "error": "ConsoleBackground Panel missing in HUDControlRoot"}

	var console_style: StyleBox = console_bg.get_theme_stylebox("panel")
	if console_style == null or not (console_style is StyleBoxFlat):
		hud.free()
		return {"passed": false, "error": "ConsoleBackground missing procedural StyleBoxFlat"}

	var sb_flat: StyleBoxFlat = console_style as StyleBoxFlat
	if sb_flat.bg_color.a < 0.8:
		hud.free()
		return {"passed": false, "error": "ConsoleBackground expected dark gunmetal opacity >= 0.8"}

	if hud.minimap_box == null or hud.minimap_box.get_theme_stylebox("panel") == null:
		hud.free()
		return {"passed": false, "error": "MinimapBox missing procedural StyleBoxFlat"}

	hud.free()
	return {"passed": true}


## Test 7: Verify SC2StatPanel holographic wireframe display and glowing vital gauges
func test_sc2_stat_panel_wireframe_and_gauges() -> Dictionary:
	var stat_panel := SC2StatPanel.new()
	stat_panel._build_ui_layout()

	# Check panel styling
	var panel_style: StyleBox = stat_panel.get_theme_stylebox("panel")
	if panel_style == null or not (panel_style is StyleBoxFlat):
		stat_panel.free()
		return {"passed": false, "error": "SC2StatPanel missing procedural StyleBoxFlat panel style"}

	# Check wireframe display
	if stat_panel.wireframe_rect == null or not (stat_panel.wireframe_rect is ColorRect):
		stat_panel.free()
		return {"passed": false, "error": "wireframe_rect missing or not a ColorRect"}

	# Check vital bars troughs and fills
	if stat_panel.hp_bar.get_theme_stylebox("background") == null:
		stat_panel.free()
		return {"passed": false, "error": "hp_bar missing trough StyleBoxFlat"}
	if stat_panel.hp_bar.get_theme_stylebox("fill") == null:
		stat_panel.free()
		return {"passed": false, "error": "hp_bar missing fill StyleBoxFlat"}

	if stat_panel.shield_bar.get_theme_stylebox("fill") == null:
		stat_panel.free()
		return {"passed": false, "error": "shield_bar missing fill StyleBoxFlat"}

	if stat_panel.energy_bar.get_theme_stylebox("fill") == null:
		stat_panel.free()
		return {"passed": false, "error": "energy_bar missing fill StyleBoxFlat"}

	# Check dynamic HP color shift logic
	stat_panel._update_hp_bar_color(100.0, 100.0)
	var high_col: Color = stat_panel._hp_fill_style.bg_color
	if high_col.g < 0.7:
		stat_panel.free()
		return {"passed": false, "error": "Expected green HP at 100% health"}

	stat_panel._update_hp_bar_color(40.0, 100.0)
	var mid_col: Color = stat_panel._hp_fill_style.bg_color
	if mid_col.r < 0.8 or mid_col.g < 0.6:
		stat_panel.free()
		return {"passed": false, "error": "Expected amber/yellow HP at 40% health"}

	stat_panel._update_hp_bar_color(15.0, 100.0)
	var low_col: Color = stat_panel._hp_fill_style.bg_color
	if low_col.r < 0.8 or low_col.g > 0.4:
		stat_panel.free()
		return {"passed": false, "error": "Expected red HP at 15% health"}

	stat_panel.free()
	return {"passed": true}


## Test 8: Verify SC2CommandCard 3x5 button grid, sci-fi StyleBoxFlat borders, and hotkey formatting
func test_sc2_command_card_grid_and_hotkey_styling() -> Dictionary:
	var card := SC2CommandCard.new()
	card._setup_procedural_grid()

	if card.slot_buttons.size() != 15:
		card.free()
		return {"passed": false, "error": "Expected 15 command card slot buttons, got %d" % card.slot_buttons.size()}

	# Check button styles on all 15 slots
	for i in range(15):
		var btn: Button = card.slot_buttons[i]
		if btn.get_theme_stylebox("normal") == null or not (btn.get_theme_stylebox("normal") is StyleBoxFlat):
			card.free()
			return {"passed": false, "error": "Slot button %d missing normal StyleBoxFlat" % i}
		if btn.get_theme_stylebox("hover") == null or not (btn.get_theme_stylebox("hover") is StyleBoxFlat):
			card.free()
			return {"passed": false, "error": "Slot button %d missing hover StyleBoxFlat" % i}
		if btn.get_theme_stylebox("pressed") == null or not (btn.get_theme_stylebox("pressed") is StyleBoxFlat):
			card.free()
			return {"passed": false, "error": "Slot button %d missing pressed StyleBoxFlat" % i}
		if btn.get_theme_stylebox("disabled") == null or not (btn.get_theme_stylebox("disabled") is StyleBoxFlat):
			card.free()
			return {"passed": false, "error": "Slot button %d missing disabled StyleBoxFlat" % i}

	# Check order button hotkey formatting
	card._bind_order_button(0, "ATTACK", "A", "Attack order")
	var btn0: Button = card.slot_buttons[0]
	if not btn0.text.begins_with("[A]"):
		card.free()
		return {"passed": false, "error": "Expected hotkey badge '[A]', got text: '%s'" % btn0.text}

	card.free()
	return {"passed": true}
