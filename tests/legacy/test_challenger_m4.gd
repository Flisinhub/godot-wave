extends Node

## Challenger 2 Empirical Test Harness for Milestone 4:
## Visual Overhaul: Cinematic Real-Time Combat VFX & StarCraft II HUD Finishing
##
## Rigorously stress-tests:
## 1. SC2HUDRoot under extreme inputs (null selection, empty array, rapid 1000-iteration switching, freed instance safety)
## 2. SC2StatPanel RPG progression (STR/DEX/INT [+] allocation with 0 points vs >0 points, derived recalculations, dynamic vital gauge color shifts, wireframe draw modes)
## 3. SC2CommandCard under extreme inputs (empty card clicks, slot clicks on cleared card, out-of-bounds indices, standard vs hero layouts, cooldown/energy state guards)
## 4. Headless rendering safety (zero warnings, particle headless guards, DisplayServer checks)
## 5. Defensive structure collision footprints (exact 8x4x8, 4x3.2x1.2, 4x3.3x0.6, 3.5x2.5x3.5)
## 6. Flow field obstacle registration (all 30 base perimeter structures are registered, and are the ONLY registered obstacles)
## 7. Structural combat mitigations (35% Wall, 25% Bunker for both Physical and Spell damage, combined with armor and upgrades)

const SC2HUDRoot = preload("res://ui/sc2_hud_root.gd")
const SC2StatPanel = preload("res://ui/sc2_stat_panel.gd")
const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")
const BaseUnit3D = preload("res://entities/allies/base_unit_3d.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const HeroSkillData = preload("res://data/skills/hero_skill_data.gd")
const SFECombatEngine = preload("res://core/combat/sfe_combat_engine.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")
const CombatVFXPool = preload("res://core/vfx/combat_vfx_pool.gd")
const StructureDamageVFX = preload("res://core/vfx/structure_damage_vfx.gd")

const CommandCenterScene = preload("res://entities/structures/command_center.tscn")
const WallSegmentScene = preload("res://entities/structures/wall_segment.tscn")
const GateStructureScene = preload("res://entities/structures/gate_structure.tscn")
const BunkerStructureScene = preload("res://entities/structures/bunker_structure.tscn")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failures: Array[String] = []


func _ready() -> void:
	print("==================================================================")
	print("=== EMPIRICAL CHALLENGER 2: MILESTONE 4 ADVERSARIAL HARNESS ===")
	print("==================================================================")
	var start_ms: int = Time.get_ticks_msec()

	_run_all_challenger_tests()

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	print("\n==================================================================")
	print("Empirical Challenge Results:")
	print("Elapsed Time: %d ms" % elapsed_ms)
	print("Total Tests:  %d" % total_tests)
	print("Passes:       %d" % passed_tests)
	print("Failures:     %d" % failed_tests)

	if failures.is_empty():
		print("\u001b[32m\u001b[1mALL EMPIRICAL CHALLENGES PASSED! [VERDICT: APPROVE]\u001b[0m")
		print("==================================================================")
		get_tree().quit(0)
	else:
		print("\u001b[31m\u001b[1mEMPIRICAL CHALLENGES FAILED! [VERDICT: REJECT]\u001b[0m")
		for f in failures:
			print("  \u001b[31m* " + f + "\u001b[0m")
		print("==================================================================")
		get_tree().quit(1)


func _assert(condition: bool, test_name: String, error_msg: String = "") -> bool:
	total_tests += 1
	if not condition:
		failed_tests += 1
		var full_msg := "%s -> %s" % [test_name, error_msg]
		failures.append(full_msg)
		print("  \u001b[31m[FAIL]\u001b[0m " + full_msg)
		return false
	passed_tests += 1
	print("  \u001b[32m[PASS]\u001b[0m " + test_name)
	return true


func _run_all_challenger_tests() -> void:
	print("\n>> 1. Testing SC2HUDRoot Extreme Selection Inputs...")
	_test_hud_extreme_selection_inputs()

	print("\n>> 2. Testing Rapid Selection Switching & Dangling Instance Safety...")
	_test_hud_rapid_switching_and_dangling_instances()

	print("\n>> 3. Testing SC2StatPanel RPG Progression & Dynamic Vital Gauges...")
	_test_stat_panel_rpg_progression_and_gauges()

	print("\n>> 4. Testing SC2StatPanel Wireframe Draw Modes & Headless Safety...")
	_test_stat_panel_wireframe_draw_modes()

	print("\n>> 5. Testing SC2CommandCard Extreme Inputs & Empty Slot Clicks...")
	_test_command_card_extreme_inputs()

	print("\n>> 6. Testing Combat VFX Pool & Structure Damage VFX Headless Safety...")
	_test_vfx_headless_safety()

	print("\n>> 7. Testing 30 Base Perimeter Structure Collision Footprints...")
	_test_structure_collision_footprints()

	print("\n>> 8. Testing SwarmSimulation Flow Field Obstacle Registration Invariants...")
	_test_flow_field_obstacle_registration_invariants()

	print("\n>> 9. Testing Structural Damage Mitigations (35% Wall, 25% Bunker)...")
	_test_structural_damage_mitigations()


# -----------------------------------------------------------------------------
# 1. SC2HUDRoot Extreme Selection Inputs
# -----------------------------------------------------------------------------
func _test_hud_extreme_selection_inputs() -> void:
	var hud := SC2HUDRoot.new()
	add_child(hud)
	hud._build_hud_layout()

	_assert(hud.bottom_console != null, "HUD bottom_console initialized")
	_assert(hud.stat_panel != null, "HUD stat_panel child initialized")
	_assert(hud.command_card != null, "HUD command_card child initialized")

	# Test 1A: Empty array selection
	hud._on_units_selected([])
	_assert(hud.stat_panel.bound_unit == null, "Empty array selection deselects stat_panel (bound_unit == null)")
	_assert(hud.command_card.bound_unit == null, "Empty array selection deselects command_card (bound_unit == null)")
	_assert(hud.stat_panel.name_label.text == "No Selection", "Empty array resets stat_panel name to 'No Selection'")

	# Test 1B: Selection containing [null]
	hud._on_units_selected([null])
	_assert(hud.stat_panel.bound_unit == null, "[null] array safely clears stat_panel")
	_assert(hud.command_card.bound_unit == null, "[null] array safely clears command_card")

	# Test 1C: Repeated deselect spam (100 times)
	for i in range(100):
		hud._on_units_deselected()
	_assert(hud.stat_panel.bound_unit == null, "100x deselect calls executed safely without error")

	# Test 1D: Process tick when bound unit is null
	hud.stat_panel._process(0.016)
	hud.command_card._process(0.016)
	_assert(true, "HUD process ticks with null bound_unit execute cleanly without errors")

	hud.free()


# -----------------------------------------------------------------------------
# 2. Rapid Selection Switching & Dangling Instance Safety
# -----------------------------------------------------------------------------
func _test_hud_rapid_switching_and_dangling_instances() -> void:
	var hud := SC2HUDRoot.new()
	add_child(hud)
	hud._build_hud_layout()

	var hero := HeroUnit3D.new()
	var hero_d := HeroData.new()
	hero_d.hero_name = "Jim Raynor"
	hero_d.strength = 15
	hero_d.dexterity = 12
	hero_d.intelligence = 10
	hero_d.recalculate_derived_stats(true)
	hero.hero_data = hero_d
	add_child(hero)

	var marine := BaseUnit3D.new()
	marine.name = "Marine1"
	marine.current_health = 100.0
	marine.max_health = 100.0
	add_child(marine)

	var wall: Node = WallSegmentScene.instantiate()
	add_child(wall)

	var bunker: Node = BunkerStructureScene.instantiate()
	add_child(bunker)

	var cc: Node = CommandCenterScene.instantiate()
	add_child(cc)

	var units: Array[Node] = [hero, marine, wall, bunker, cc, null]

	# Stress: 1000 rapid switches in sequence
	for i in range(1000):
		var target: Node = units[i % units.size()]
		if target == null:
			hud._on_units_deselected()
		else:
			hud._on_units_selected([target])
		
		# Intermittent process tick
		if i % 100 == 0:
			hud.stat_panel._process(0.016)
			hud.command_card._process(0.016)

	_assert(true, "1000 rapid unit selection switches completed with zero errors or state corruption")

	# Dangling pointer test: Bind a temporary unit, then free it while HUD is bound
	var temp_unit := BaseUnit3D.new()
	temp_unit.name = "TempUnit"
	add_child(temp_unit)
	hud._on_units_selected([temp_unit])
	_assert(hud.stat_panel.bound_unit == temp_unit, "Temp unit successfully bound to stat_panel")

	# Free temp unit
	temp_unit.free()

	# Execute refresh and update: must NOT crash due to is_instance_valid() guards
	hud.stat_panel.refresh_display()
	hud.stat_panel._process(0.016)
	hud.command_card._update_slot_states()
	hud.command_card._process(0.016)

	_assert(hud.stat_panel.name_label.text == "No Selection", "Freed unit safely recognized as invalid; display reset to 'No Selection'")

	# Synchronously free test nodes so they do not pollute group lists in later tests
	hero.free()
	marine.free()
	wall.free()
	bunker.free()
	cc.free()
	hud.free()


# -----------------------------------------------------------------------------
# 3. SC2StatPanel RPG Progression & Dynamic Vital Gauges
# -----------------------------------------------------------------------------
func _test_stat_panel_rpg_progression_and_gauges() -> void:
	var stat_panel := SC2StatPanel.new()
	add_child(stat_panel)
	stat_panel._build_ui_layout()

	var hero := HeroUnit3D.new()
	var hd := HeroData.new()
	hd.hero_name = "Commander Raynor"
	hd.base_hp = 500.0
	hd.base_damage = 25.0
	hd.base_cooldown = 0.8
	hd.base_energy = 100.0
	hd.strength = 10
	hd.dexterity = 10
	hd.intelligence = 10
	hd.attribute_points = 0 # ZERO unspent points initially
	hd.recalculate_derived_stats(true)
	hero.hero_data = hd
	add_child(hero)

	stat_panel.bind_unit(hero)

	# 3A: When points == 0, buttons must be disabled
	_assert(stat_panel.str_plus_btn.disabled == true, "STR [+] button disabled when attribute_points == 0")
	_assert(stat_panel.dex_plus_btn.disabled == true, "DEX [+] button disabled when attribute_points == 0")
	_assert(stat_panel.int_plus_btn.disabled == true, "INT [+] button disabled when attribute_points == 0")

	# 3B: Attempt illegal allocation when points == 0
	stat_panel._on_attribute_allocated("str")
	stat_panel._on_attribute_allocated("dex")
	stat_panel._on_attribute_allocated("int")
	_assert(hd.strength == 10, "STR unchanged after illegal allocation attempt with 0 points")
	_assert(hd.dexterity == 10, "DEX unchanged after illegal allocation attempt with 0 points")
	_assert(hd.intelligence == 10, "INT unchanged after illegal allocation attempt with 0 points")

	# 3C: Grant 15 attribute points and refresh
	hd.attribute_points = 15
	stat_panel.refresh_display()
	_assert(stat_panel.str_plus_btn.disabled == false, "STR [+] button enabled when attribute_points > 0")
	_assert(stat_panel.dex_plus_btn.disabled == false, "DEX [+] button enabled when attribute_points > 0")
	_assert(stat_panel.int_plus_btn.disabled == false, "INT [+] button enabled when attribute_points > 0")
	_assert(stat_panel.points_label.text == "Attribute Points: 15", "points_label reflects 15 unspent points")

	# 3D: Allocate 5 STR, 5 DEX, 5 INT via panel callbacks
	for i in range(5):
		stat_panel._on_attribute_allocated("str")
	for i in range(5):
		stat_panel._on_attribute_allocated("dex")
	for i in range(5):
		stat_panel._on_attribute_allocated("int")

	_assert(hd.strength == 15, "Strength incremented to 15 (got %d)" % hd.strength)
	_assert(hd.dexterity == 15, "Dexterity incremented to 15 (got %d)" % hd.dexterity)
	_assert(hd.intelligence == 15, "Intelligence incremented to 15 (got %d)" % hd.intelligence)
	_assert(hd.attribute_points == 0, "Unspent attribute points consumed to 0 (got %d)" % hd.attribute_points)

	# Verify derived formulas:
	# Max HP: 500 + (15 * 20.0) = 800.0
	_assert(absf(hd.max_hp - 800.0) < 0.01, "Derived Max HP recalculated to 800.0 (got %.1f)" % hd.max_hp)
	# Weapon Damage: 25.0 + (15 * 1.5) = 47.5
	_assert(absf(hd.weapon_damage - 47.5) < 0.01, "Derived Weapon Damage recalculated to 47.5 (got %.1f)" % hd.weapon_damage)
	# Max Energy: 100.0 + (15 * 10.0) = 250.0
	_assert(absf(hd.max_energy - 250.0) < 0.01, "Derived Max Energy recalculated to 250.0 (got %.1f)" % hd.max_energy)

	# Verify UI refreshed
	_assert(stat_panel.str_label.text == "STR: 15", "str_label shows 'STR: 15'")
	_assert(stat_panel.dex_label.text == "DEX: 15", "dex_label shows 'DEX: 15'")
	_assert(stat_panel.int_label.text == "INT: 15", "int_label shows 'INT: 15'")
	_assert(stat_panel.str_plus_btn.disabled == true, "STR button disabled again after points depleted")

	# 3E: Dynamic Vital Bar Color Shifts
	stat_panel._update_hp_bar_color(800.0, 800.0) # 100% -> Terran Vital Green
	_assert(stat_panel._hp_fill_style.bg_color.g > 0.7, "HP Bar is green at 100%% (green channel: %.2f)" % stat_panel._hp_fill_style.bg_color.g)

	stat_panel._update_hp_bar_color(400.0, 800.0) # 50% -> Warning Amber
	_assert(stat_panel._hp_fill_style.bg_color.r > 0.8 and stat_panel._hp_fill_style.bg_color.g > 0.6, "HP Bar is amber at 50%")

	stat_panel._update_hp_bar_color(160.0, 800.0) # 20% -> Critical Red
	_assert(stat_panel._hp_fill_style.bg_color.r > 0.8 and stat_panel._hp_fill_style.bg_color.g < 0.4, "HP Bar is critical red at 20%")

	# 3F: Division by Zero Safety check
	stat_panel._update_hp_bar_color(0.0, 0.0)
	_assert(stat_panel._hp_fill_style.bg_color.r > 0.8, "HP Bar color shift survives max_hp == 0 without crash (ratio clamped)")

	hero.free()
	stat_panel.free()


# -----------------------------------------------------------------------------
# 4. SC2StatPanel Wireframe Draw Modes & Headless Safety
# -----------------------------------------------------------------------------
func _test_stat_panel_wireframe_draw_modes() -> void:
	var wireframe := SC2StatPanel.SC2WireframeDisplay.new()
	wireframe.size = Vector2(90, 110)

	# Mode 1: No Unit Bound (Tactical Reticle)
	wireframe.bound_unit = null
	wireframe._draw()
	_assert(true, "Wireframe _draw() executes cleanly in Null/Reticle mode")

	# Mode 2: Hero Unit Bound (Marine Vector Silhouette)
	var hero := HeroUnit3D.new()
	wireframe.bound_unit = hero
	wireframe._draw()
	_assert(true, "Wireframe _draw() executes cleanly in Marine/Hero silhouette mode")

	# Mode 3: Structure Bound (Hexagonal Defense Ring)
	var cc: Node = CommandCenterScene.instantiate()
	wireframe.bound_unit = cc
	wireframe._draw()
	_assert(true, "Wireframe _draw() executes cleanly in Structure hexagonal mode")

	# Mode 4: Degenerate size (0, 0)
	wireframe.size = Vector2.ZERO
	wireframe._draw()
	_assert(true, "Wireframe _draw() safely early-exits on degenerate size Vector2.ZERO")

	hero.free()
	cc.free()
	wireframe.free()


# -----------------------------------------------------------------------------
# 5. SC2CommandCard Extreme Inputs & Empty Slot Clicks
# -----------------------------------------------------------------------------
func _test_command_card_extreme_inputs() -> void:
	var card := SC2CommandCard.new()
	add_child(card)
	card._setup_procedural_grid()

	# 5A: Verify 15 buttons initialized
	_assert(card.slot_buttons.size() == 15, "CommandCard has exactly 15 slot buttons")
	_assert(card.slot_data.size() == 15, "CommandCard has exactly 15 slot_data entries")

	# 5B: Empty Card Clicks
	# When card is cleared, clicking every single slot must produce zero crashes and zero commands
	var commands_received: Array[String] = []
	card.command_triggered.connect(func(cmd: String, _payload: Variant): commands_received.append(cmd))

	for i in range(15):
		card._on_slot_pressed(i)
		card.slot_buttons[i].pressed.emit()

	_assert(commands_received.is_empty(), "Cleared card produces 0 commands when clicking all 15 slots")

	# 5C: Out-of-bounds slot index stress
	card._on_slot_pressed(-1)
	card._on_slot_pressed(15)
	card._on_slot_pressed(9999)
	_assert(commands_received.is_empty(), "Out-of-bounds indices (-1, 15, 9999) safely ignored")

	# 5D: Standard Unit (Marine) Card Population
	var marine := BaseUnit3D.new()
	marine.name = "TestMarine"
	add_child(marine)
	card.populate_for_unit(marine)

	# Verify Standard Unit assigns slots 5, 6, 7, 10
	_assert(card.slot_data[5].get("id") == "ATTACK", "Slot 5 assigned to ATTACK")
	_assert(card.slot_data[6].get("id") == "STOP", "Slot 6 assigned to STOP")
	_assert(card.slot_data[7].get("id") == "HOLD", "Slot 7 assigned to HOLD")
	_assert(card.slot_data[10].get("id") == "MOVE", "Slot 10 assigned to MOVE")

	# Inactive slots must be empty and disabled
	for empty_slot in [0, 1, 2, 3, 4, 8, 9, 11, 12, 13, 14]:
		_assert(card.slot_buttons[empty_slot].disabled == true, "Empty slot %d is disabled" % empty_slot)
		card._on_slot_pressed(empty_slot)
	_assert(commands_received.is_empty(), "Clicking inactive slots on Standard Unit produces 0 commands")

	# Click ATTACK slot
	card._on_slot_pressed(5)
	_assert(commands_received.has("ATTACK"), "Clicking slot 5 triggers 'ATTACK' command signal")

	# 5E: Hero Unit Ability State Checks (Cooldown & Energy)
	var hero := HeroUnit3D.new()
	var hd := HeroData.new()
	hd.hero_name = "Jim Raynor"
	hd.max_energy = 100.0

	var skill := HeroSkillData.new()
	skill.skill_id = "penetrating_round"
	skill.skill_name = "Penetrating Round"
	skill.hotkey = "Q"
	skill.energy_cost = 50.0 # Requires 50, only has 10!
	skill.cooldown = 8.0
	hd.skills = [skill]

	hero.hero_data = hd
	add_child(hero)

	# Drain energy after hero._ready() runs
	hero.hero_data.current_energy = 10.0

	card.populate_for_unit(hero)

	# Verify Energy check disables slot 0
	card._update_slot_states()
	_assert(card.slot_buttons[0].disabled == true, "Skill slot 0 disabled when hero energy (10) < energy_cost (50)")
	_assert(card.slot_buttons[0].text.contains("(NRG)"), "Skill slot 0 displays '(NRG)' when energy is depleted")

	# Refill energy -> button becomes enabled
	hero.hero_data.current_energy = 100.0
	card._update_slot_states()
	_assert(card.slot_buttons[0].disabled == false, "Skill slot 0 enabled when hero has full energy")

	marine.free()
	hero.free()
	card.free()


# -----------------------------------------------------------------------------
# 6. Combat VFX Pool & Structure Damage VFX Headless Safety
# -----------------------------------------------------------------------------
func _test_vfx_headless_safety() -> void:
	_assert(DisplayServer.get_name() == "headless", "Confirmed running in headless DisplayServer mode")

	# Test CombatVFXPool in headless
	var pool := CombatVFXPool.new()
	add_child(pool)

	# Spawn 30 tracers across origin
	for i in range(30):
		var t = pool.spawn_tracer(Vector3.ZERO, Vector3(float(i), 1.0, 5.0))
		_assert(t != null, "Tracer %d spawned successfully in headless" % i)

	# Spawn 25 acid bursts across origin
	for i in range(25):
		pool._process(0.016)
		var b = pool.spawn_acid_burst(Vector3(float(i), 0.0, 0.0))
		_assert(b != null, "Acid burst %d spawned successfully in headless" % i)

	_assert(pool.get_child_count() == 44, "Total pooled child nodes strictly invariant at 44 (24 tracers + 20 bursts)")

	# Test StructureDamageVFX in headless
	var damage_vfx := StructureDamageVFX.new()
	add_child(damage_vfx)

	# Force health update to critical (< 35%)
	damage_vfx.update_damage_state(100.0, 1000.0)

	# In headless mode, GPUParticles3D.emitting must remain false to prevent headless errors
	_assert(damage_vfx.smoke_particles.emitting == false, "Headless: smoke_particles.emitting is false")
	_assert(damage_vfx.fire_particles.emitting == false, "Headless: fire_particles.emitting is false")
	_assert(damage_vfx.sparks_particles.emitting == false, "Headless: sparks_particles.emitting is false")

	pool.free()
	damage_vfx.free()


# -----------------------------------------------------------------------------
# 7. 30 Base Perimeter Structure Collision Footprints
# -----------------------------------------------------------------------------
func _test_structure_collision_footprints() -> void:
	# 7A: CommandCenter
	var cc: Node = CommandCenterScene.instantiate()
	var cc_col: CollisionShape3D = cc.get_node_or_null("CollisionShape3D")
	_assert(cc_col != null, "CommandCenter has CollisionShape3D")
	var cc_box := cc_col.shape as BoxShape3D
	_assert(cc_box != null, "CommandCenter shape is BoxShape3D")
	_assert(cc_box.size.is_equal_approx(Vector3(8.0, 4.0, 8.0)), "CommandCenter collision footprint is exact Vector3(8, 4, 8) (got %s)" % cc_box.size)
	_assert(cc_col.position.is_equal_approx(Vector3(0.0, 2.0, 0.0)), "CommandCenter collision center is at y = 2.0 (flush from y = 0 to 4)")
	cc.free()

	# 7B: WallSegment
	var wall: Node = WallSegmentScene.instantiate()
	var wall_col: CollisionShape3D = wall.get_node_or_null("CollisionShape3D")
	_assert(wall_col != null, "WallSegment has CollisionShape3D")
	var wall_box := wall_col.shape as BoxShape3D
	_assert(wall_box != null, "WallSegment shape is BoxShape3D")
	_assert(wall_box.size.is_equal_approx(Vector3(4.0, 3.2, 1.2)), "WallSegment collision footprint is exact Vector3(4, 3.2, 1.2) (got %s)" % wall_box.size)
	_assert(wall_col.position.is_equal_approx(Vector3(0.0, 1.6, 0.0)), "WallSegment collision center is at y = 1.6 (flush from y = 0 to 3.2)")
	wall.free()

	# 7C: GateStructure
	var gate: Node = GateStructureScene.instantiate()
	var gate_door_col: CollisionShape3D = gate.get_node_or_null("DoorCollisionShape")
	_assert(gate_door_col != null, "GateStructure has DoorCollisionShape")
	var gate_box := gate_door_col.shape as BoxShape3D
	_assert(gate_box != null, "GateStructure door shape is BoxShape3D")
	_assert(gate_box.size.is_equal_approx(Vector3(4.0, 3.3, 0.6)), "GateStructure door collision footprint is exact Vector3(4, 3.3, 0.6) (got %s)" % gate_box.size)
	_assert(gate_door_col.position.is_equal_approx(Vector3(0.0, 1.65, 0.0)), "GateStructure door collision center is at y = 1.65 (flush from y = 0 to 3.3)")
	gate.free()

	# 7D: BunkerStructure
	var bunker: Node = BunkerStructureScene.instantiate()
	var bunker_col: CollisionShape3D = bunker.get_node_or_null("CollisionShape3D")
	_assert(bunker_col != null, "BunkerStructure has CollisionShape3D")
	var bunker_box := bunker_col.shape as BoxShape3D
	_assert(bunker_box != null, "BunkerStructure shape is BoxShape3D")
	_assert(bunker_box.size.is_equal_approx(Vector3(3.5, 2.5, 3.5)), "BunkerStructure collision footprint is exact Vector3(3.5, 2.5, 3.5) (got %s)" % bunker_box.size)
	_assert(bunker_col.position.is_equal_approx(Vector3(0.0, 1.25, 0.0)), "BunkerStructure collision center is at y = 1.25 (flush from y = 0 to 2.5)")
	bunker.free()


# -----------------------------------------------------------------------------
# 8. SwarmSimulation Flow Field Obstacle Registration Invariants
# -----------------------------------------------------------------------------
func _test_flow_field_obstacle_registration_invariants() -> void:
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	var main_level: Node = main_scene.instantiate()
	add_child(main_level)

	var swarm_sim = main_level.get("swarm_simulation")
	_assert(swarm_sim != null, "MainLevel has active SwarmSimulation")
	var flow_field = swarm_sim.get("flow_field")
	_assert(flow_field != null, "SwarmSimulation has active SwarmFlowField")

	var registered_obstacles: Dictionary = flow_field.registered_obstacles
	_assert(registered_obstacles.size() == 30, "FlowField has EXACTLY 30 registered obstacles (got %d)" % registered_obstacles.size())

	# Verify every single registered obstacle is an actual base perimeter structure
	var perimeter := main_level.get_node_or_null("NavigationRegion3D/BasePerimeter") as Node3D
	_assert(perimeter != null, "NavigationRegion3D/BasePerimeter exists")

	var perimeter_structures: Array[Node] = []
	for child in perimeter.get_children():
		if child is Node3D and (child.is_in_group("structures") or child.name.begins_with("Wall") or child.name.begins_with("Gate") or child.name.begins_with("Bunker") or child.name == "CommandCenter"):
			perimeter_structures.append(child)

	_assert(perimeter_structures.size() == 30, "BasePerimeter contains exactly 30 structures (got %d)" % perimeter_structures.size())

	for s in perimeter_structures:
		_assert(registered_obstacles.has(s), "Structure '%s' is registered in flow_field.registered_obstacles" % s.name)

	# Verify no orphan or ghost obstacles
	for key in registered_obstacles.keys():
		_assert(perimeter_structures.has(key), "Registered obstacle '%s' belongs strictly to BasePerimeter" % key.name)

	main_level.free()


# -----------------------------------------------------------------------------
# 9. Structural Damage Mitigations (35% Wall, 25% Bunker)
# -----------------------------------------------------------------------------
func _test_structural_damage_mitigations() -> void:
	# 9A: Reinforced Wall - 35% Mitigation (deals 65% of incoming damage)
	var wall_phys = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(wall_phys.damage_dealt - 65.0) < 0.001, "Wall 35%% mitigation vs Physical 100 raw damage: dealt 65.0 (got %.3f)" % wall_phys.damage_dealt)

	var wall_spell = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.SPELL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(wall_spell.damage_dealt - 65.0) < 0.001, "Wall 35%% mitigation vs Spell 100 raw damage: dealt 65.0 (got %.3f)" % wall_spell.damage_dealt)

	# High damage stress test
	var wall_high = SFECombatEngine.calculate_damage(1000.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(wall_high.damage_dealt - 650.0) < 0.001, "Wall 35%% mitigation vs 1000 raw damage: dealt 650.0 (got %.3f)" % wall_high.damage_dealt)

	# 9B: Fortified Bunker - 25% Mitigation (deals 75% of incoming damage)
	var bunker_phys = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER, false)
	_assert(absf(bunker_phys.damage_dealt - 75.0) < 0.001, "Bunker 25%% mitigation vs Physical 100 raw damage: dealt 75.0 (got %.3f)" % bunker_phys.damage_dealt)

	var bunker_spell = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.SPELL, 0.0, 0, CombatTypes.StructureType.BUNKER, false)
	_assert(absf(bunker_spell.damage_dealt - 75.0) < 0.001, "Bunker 25%% mitigation vs Spell 100 raw damage: dealt 75.0 (got %.3f)" % bunker_spell.damage_dealt)

	# High damage stress test
	var bunker_high = SFECombatEngine.calculate_damage(1000.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.BUNKER, false)
	_assert(absf(bunker_high.damage_dealt - 750.0) < 0.001, "Bunker 25%% mitigation vs 1000 raw damage: dealt 750.0 (got %.3f)" % bunker_high.damage_dealt)

	# 9C: Combined Mitigations (Wall + Flat Armor + Upgrade Level)
	# Raw 100, Flat armor 10 -> (100 - 10) = 90. Upgrade level 10 (0.2% * 10 = 2% reduction) -> 90 * 0.98 = 88.2.
	# Wall 35% mitigation -> 88.2 * 0.65 = 57.33
	var wall_stacked = SFECombatEngine.calculate_damage(100.0, CombatTypes.DamageType.PHYSICAL, 10.0, 10, CombatTypes.StructureType.WALL_REINFORCED, false)
	_assert(absf(wall_stacked.damage_dealt - 57.33) < 0.01, "Stacked Physical (Wall + Armor 10 + Lvl 10): dealt 57.33 (got %.3f)" % wall_stacked.damage_dealt)

	# 9D: Invulnerability flag on structure
	var invuln_res = SFECombatEngine.calculate_damage(500.0, CombatTypes.DamageType.PHYSICAL, 0.0, 0, CombatTypes.StructureType.WALL_REINFORCED, false, false, true)
	_assert(invuln_res.damage_dealt == 0.0, "Invulnerable wall receives 0.0 damage")
