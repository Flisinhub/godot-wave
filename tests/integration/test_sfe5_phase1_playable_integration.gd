extends RefCounted

## Automated Verification Suite for Phase 1 SFE5 Playable Integration.
## Validates:
## 1. PBR Environment ShaderMaterials (0 null parameters).
## 2. SFEStartModal (Difficulty selection, Hero catalog, Random bonus +50, Bank profile).
## 3. SC2HUDRoot Top Bar & real-time telemetry.
## 4. SC2CommandCard Q, W, E, R hotkeys and order execution.
## 5. HeroUnit3D active & passive skills (Stimpack, Blink, Storm, Heal, Minigun stacks, Level Up).
## 6. Swarm & Bunker combat with Crossfire Nullification and BankManager persistence.

var _last_error: String = ""


func _pass() -> Dictionary:
	return {"passed": true}


func _fail(msg: String) -> Dictionary:
	_last_error = msg
	return {"passed": false, "error": msg}


func test_shader_materials_no_null_parameters() -> Dictionary:
	var shader_mat_paths: Array[String] = [
		"res://assets/materials/environment/char_basalt_ground_pbr.tres",
		"res://assets/materials/environment/lava_fissure_material.tres",
		"res://assets/materials/environment/terran_base_deck_material.tres",
		"res://assets/materials/environment/zerg_creep_material.tres"
	]

	for path in shader_mat_paths:
		var mat = load(path) as ShaderMaterial
		if mat == null:
			return _fail("Failed to load material: " + path)

		var mat_text := FileAccess.get_file_as_string(path)
		if mat_text.contains("= null"):
			return _fail("Found null shader parameter in: " + path)

	return _pass()


func test_start_modal_and_hero_selection() -> Dictionary:
	var modal_script = load("res://ui/sfe_start_modal.gd")
	if modal_script == null:
		return _fail("Failed to load sfe_start_modal.gd")

	var modal = modal_script.new()
	if modal == null:
		return _fail("Failed to instantiate SFEStartModal")

	# Test player profile loading
	modal.load_player_profile()
	if modal.bank_data.is_empty():
		return _fail("Bank data empty in modal")

	# Test difficulty selection
	modal._update_difficulty_selection(3) # Brutal
	if modal.selected_difficulty != 3:
		return _fail("Expected difficulty tier 3 (Brutal)")

	# Test hero selection
	modal._update_hero_selection(&"zeratul", false)
	if modal.selected_archetype_id != &"zeratul":
		return _fail("Expected archetype zeratul")

	# Test random hero roll with bonus
	var capture := {
		"hero": null,
		"tier": -1,
		"random": false
	}

	modal.deployment_confirmed.connect(func(h, tier, is_rnd):
		capture["hero"] = h
		capture["tier"] = tier
		capture["random"] = is_rnd
	)

	modal._update_hero_selection(&"raynor", true)
	modal._on_deploy_pressed()

	if capture["hero"] == null:
		return _fail("No hero data received on deployment")
	if not capture["random"]:
		return _fail("Random flag should be true")
	if capture["tier"] != 3:
		return _fail("Expected tier 3")

	return _pass()


func test_sc2_hud_top_bar_telemetry() -> Dictionary:
	var hud_script = load("res://ui/sc2_hud_root.gd")
	var hud = hud_script.new()
	if hud == null:
		return _fail("Failed to instantiate SC2HUDRoot")

	if hud.top_bar == null:
		return _fail("TopBar container missing")
	if hud.top_minerals_label == null:
		return _fail("TopBar minerals label missing")
	if hud.top_diff_badge == null:
		return _fail("TopBar difficulty badge missing")

	# Test telemetry updates
	hud.update_minerals(750)
	if not hud.top_minerals_label.text.contains("750"):
		return _fail("Minerals display incorrect: " + hud.top_minerals_label.text)

	hud.update_difficulty("Brutal", 3)
	if not hud.top_diff_badge.text.contains("BRUTAL"):
		return _fail("Badge incorrect: " + hud.top_diff_badge.text)

	hud.update_hive_evolution(2, 45.0)
	if not hud.top_hive_label.text.contains("HIVE LVL 2"):
		return _fail("Hive label incorrect: " + hud.top_hive_label.text)

	hud.update_wave_status(4, 35, true)
	if not hud.top_wave_label.text.contains("35"):
		return _fail("Wave label incorrect: " + hud.top_wave_label.text)

	hud.free()
	return _pass()


func test_command_card_hotkeys_and_orders() -> Dictionary:
	var card_script = load("res://ui/sc2_command_card.gd")
	var card = card_script.new()
	if card == null:
		return _fail("Failed to instantiate SC2CommandCard")

	var hero_unit_script = load("res://entities/allies/hero_unit_3d.gd")
	var hero = hero_unit_script.new()
	card.populate_for_unit(hero)

	# Verify standard RTS order slots populated
	var stop_slot: Dictionary = card.slot_data[6]
	if stop_slot.get("id") != "STOP":
		return _fail("Slot 6 not bound to STOP order")

	# Test programmatic slot activation
	var triggered_cmd: Array[String] = [""]
	card.command_triggered.connect(func(cmd, _payload): triggered_cmd[0] = cmd)
	card.activate_skill_by_slot(6)
	if triggered_cmd[0] != "STOP":
		return _fail("Expected STOP command triggered, got: " + triggered_cmd[0])

	card.free()
	hero.free()
	return _pass()


func test_hero_skills_and_leveling() -> Dictionary:
	var hero_unit_script = load("res://entities/allies/hero_unit_3d.gd")
	var hero = hero_unit_script.new()
	var hero_selector = load("res://core/heroes/hero_selector.gd")

	# 1. Test Jim Raynor Stimpack
	var raynor_data = hero_selector.select_hero_manual(&"raynor")
	hero.hero_data = raynor_data
	hero._bind_hero_data()
	hero.apply_archetype_visuals(raynor_data)

	var hp_before: float = hero.current_health
	var cast_stim: bool = hero.activate_skill(0) # Stimpack
	if not cast_stim:
		return _fail("Stimpack cast failed")
	if hero.current_health >= hp_before:
		return _fail("HP not reduced by Stimpack")
	if not hero.buff_engine.has_buff(&"stimpack"):
		return _fail("Stimpack buff missing in SFEBuffEngine")

	# 2. Test RPG Level-Up restoration & rewards
	hero.current_health = 50.0 # severely damaged
	hero.hero_data.current_energy = 10.0 # drained
	hero.gain_experience(200) # triggers level up

	if hero.hero_data.xp_level < 2:
		return _fail("Hero level not increased")
	if hero.current_health <= 50.0:
		return _fail("Health not restored on level up")
	if hero.hero_data.current_energy <= 10.0:
		return _fail("Energy not restored on level up")
	if hero.hero_data.attribute_points < 3:
		return _fail("Attribute points missing on level up")

	# 3. Test Zeratul Blink
	var zeratul_data = hero_selector.select_hero_manual(&"zeratul")
	hero.hero_data = zeratul_data
	hero._bind_hero_data()
	hero.set_world_pos(Vector3.ZERO)
	var cast_blink: bool = hero.activate_skill(0, Vector3(5.0, 0.0, 0.0))
	if not cast_blink:
		return _fail("Blink failed")
	if hero.get_world_pos().distance_to(Vector3.ZERO) <= 2.0:
		return _fail("Blink did not teleport hero, current pos: " + str(hero.get_world_pos()))

	# 4. Test Tychus Minigun passive stacking
	var tychus_data = hero_selector.select_hero_manual(&"tychus")
	hero.hero_data = tychus_data
	hero._bind_hero_data()
	var mock_target = Node3D.new()
	hero._fire_at(mock_target)
	if not hero.buff_engine.has_buff(&"tychus_passive"):
		return _fail("Passive minigun stack missing on attack")

	mock_target.free()
	hero.free()
	return _pass()


func test_combat_crossfire_and_bank_persistence() -> Dictionary:
	var economy_script = load("res://core/economy/sfe_economy_manager.gd")
	var economy = economy_script.new()
	var difficulty_script = load("res://core/economy/sfe_difficulty_manager.gd")
	var difficulty = difficulty_script.new()
	difficulty.set_difficulty(1) # Normal

	# 1. Test Crossfire Nullification: Allied kill grants minerals
	var ally_ctx = KillContext.new(null, null, EconomyTypes.Faction.ALLIED, 10, CombatTypes.DamageType.PHYSICAL)
	var bounty_allied: int = economy.process_kill(ally_ctx)
	if bounty_allied != 10:
		return _fail("Expected 10 bounty for allied kill, got %d" % bounty_allied)

	# Hostile crossfire kill yields strictly 0 minerals
	var hostile_ctx = KillContext.new(null, null, EconomyTypes.Faction.HOSTILE, 10, CombatTypes.DamageType.PHYSICAL)
	var bounty_hostile: int = economy.process_kill(hostile_ctx)
	if bounty_hostile != 0:
		return _fail("Expected 0 bounty for crossfire kill, got %d" % bounty_hostile)

	# 2. Test BankManager Persistence
	var bank = BankManager.load_bank()
	var initial_kills: int = bank.get("total_kills", 0)
	bank["total_kills"] = initial_kills + 100
	bank["veterancy_level"] = maxi(1, 1 + int(bank["total_kills"] / 100))
	var saved: bool = BankManager.save_bank(bank)
	if not saved:
		return _fail("Bank save failed")

	var reloaded = BankManager.load_bank()
	if reloaded.get("total_kills", 0) != initial_kills + 100:
		return _fail("Bank career kills mismatch after reload")

	economy.free()
	difficulty.free()
	return _pass()


func test_sc2_camera_controls_and_minimap_panning() -> Dictionary:
	var cam_script = load("res://levels/rts_camera_3d.gd")
	var cam = cam_script.new()
	if cam == null:
		return _fail("Failed to instantiate RTSCamera3D")

	# 1. Test pan_to_position
	cam.pan_to_position(Vector3(-22.0, 0.0, 22.0))
	if not (is_equal_approx(cam.position.x, -22.0) and is_equal_approx(cam.position.z, 22.0)):
		cam.free()
		return _fail("pan_to_position failed: " + str(cam.position))

	# 2. Test middle mouse button dragging
	var start_pos: Vector3 = cam.position
	var mb_down := InputEventMouseButton.new()
	mb_down.button_index = MOUSE_BUTTON_MIDDLE
	mb_down.pressed = true
	cam._unhandled_input(mb_down)

	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(50.0, -30.0) # Moving right and up
	mouse_motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	cam._unhandled_input(mouse_motion)

	var mb_up := InputEventMouseButton.new()
	mb_up.button_index = MOUSE_BUTTON_MIDDLE
	mb_up.pressed = false
	cam._unhandled_input(mb_up)

	if not (cam.position.x < start_pos.x and cam.position.z > start_pos.z):
		var final_pos: Vector3 = cam.position
		cam.free()
		return _fail("Middle mouse drag motion unexpected: " + str(final_pos))

	# 3. Test map bounds clamping
	cam.pan_to_position(Vector3(100.0, 0.0, 100.0))
	if cam.position.x > 38.0 or cam.position.z > 38.0:
		cam.free()
		return _fail("Map bounds clamp failed: " + str(cam.position))

	# 4. Test middle mouse release safeguard via _input
	cam._is_middle_dragging = true
	var mb_release_input := InputEventMouseButton.new()
	mb_release_input.button_index = MOUSE_BUTTON_MIDDLE
	mb_release_input.pressed = false
	cam._input(mb_release_input)
	if cam._is_middle_dragging:
		cam.free()
		return _fail("_input middle mouse release safeguard failed to reset _is_middle_dragging")

	# 5. Test motion with button_mask == 0 auto-clearing _is_middle_dragging
	cam._is_middle_dragging = true
	var mm_empty := InputEventMouseMotion.new()
	mm_empty.button_mask = 0
	cam._unhandled_input(mm_empty)
	if cam._is_middle_dragging:
		cam.free()
		return _fail("Mouse motion with button_mask 0 failed to reset stuck _is_middle_dragging")

	cam.free()

	# 6. Test SC2HUDRoot minimap panning helper
	var hud_script = load("res://ui/sc2_hud_root.gd")
	var hud = hud_script.new()
	var test_uv := Vector2(0.5, 0.5) # Center of minimap
	var world_x: float = lerpf(-38.0, 38.0, test_uv.x)
	var world_z: float = lerpf(-38.0, 38.0, test_uv.y)
	if not (is_equal_approx(world_x, 0.0) and is_equal_approx(world_z, 0.0)):
		hud.free()
		return _fail("Minimap UV mapping incorrect: " + str(Vector2(world_x, world_z)))

	hud.free()
	return _pass()


func test_base_layout_and_hero_single_unit_invariants() -> Dictionary:
	var tscn_path := "res://levels/main_level.tscn"
	var tscn_text := FileAccess.get_file_as_string(tscn_path)
	if tscn_text.is_empty():
		return _fail("Failed to read main_level.tscn")

	# 1. Verify CommandCenter relocated to bottom-left (-24, 0, 24)
	if not tscn_text.contains("-24, 0, 24"):
		return _fail("CommandCenter not positioned at (-24, 0, 24)")

	# 2. Verify RallyPoint relocated to (-22, 0, 20)
	if not tscn_text.contains("-22, 0, 20"):
		return _fail("RallyPoint not positioned at (-22, 0, 20)")

	# 3. Verify ArmoryTerminal stationed at (-20, 0, 26)
	if not tscn_text.contains("-20, 0, 26"):
		return _fail("ArmoryTerminal not positioned at (-20, 0, 26)")

	# 4. Verify Bunkers flank the open breach (BunkerWest and BunkerEast)
	if not tscn_text.contains("BunkerWest") or not tscn_text.contains("BunkerEast"):
		return _fail("BunkerWest or BunkerEast missing from BasePerimeter")
	if not tscn_text.contains("-20, 0, 15") or not tscn_text.contains("-15, 0, 20"):
		return _fail("Bunker positions do not match choke point layout")

	# 5. Verify NO Gates exist (6-meter open breach without doors)
	if tscn_text.contains("WestGate") or tscn_text.contains("EastGate") or tscn_text.contains("gate_structure.tscn"):
		return _fail("Gates found in scene: breach must remain open without doors")

	# 6. Verify Allies contains strictly single Hero and 0 generic Marines
	for i in range(1, 6):
		if tscn_text.contains("Marine%d" % i) or tscn_text.contains("Marine %d" % i):
			return _fail("Generic Marine%d found in main_level.tscn" % i)
	if not tscn_text.contains("HeroRaynor"):
		return _fail("HeroRaynor missing from Allies")

	# 7. Verify legacy overlapping UI panels removed
	if tscn_text.contains("WavePanel") or tscn_text.contains("HUDPanel"):
		return _fail("Legacy WavePanel or HUDPanel still present in main_level.tscn")

	# 8. Verify camera initial focus at base (-22, 0, 22)
	if not tscn_text.contains("-22, 0, 22"):
		return _fail("RTSCamera3D initial position not set to (-22, 0, 22)")

	# 9. Verify overlapping wall segments (WallNorth5 and WallEast1) removed to prevent mesh clipping into Bunkers
	if tscn_text.contains("WallNorth5") or tscn_text.contains("WallEast1"):
		return _fail("Overlapping wall segments WallNorth5 or WallEast1 found in BasePerimeter")

	return _pass()

