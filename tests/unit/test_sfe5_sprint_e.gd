extends "res://tests/test_base.gd"

## TestSFE5SprintE - Test Suite for Sprint E:
## 1. Smart-Cast to cursor / Node3D targets for Hero abilities.
## 2. Full RTS Orders: Attack-Move (A), Patrol (P), Control Groups (1..5), Hero Center (F1 / Space).
## 3. Tactical Radar (Minimap) real-time drawing & Camera Viewport Ground Frustum.
## 4. SFX & Adjutant voice routing across Hero archetypes, structures, and alerts.
## 5. Visual Archetype models and materials for Reaper and Spectre.

const SC2CommandCard = preload("res://ui/sc2_command_card.gd")
const RTSController = preload("res://core/rts_controller.gd")
const RTSCamera3D = preload("res://levels/rts_camera_3d.gd")
const HeroUnit3D = preload("res://entities/allies/hero_unit_3d.gd")
const BaseUnit3D = preload("res://entities/allies/base_unit_3d.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const HeroSkillData = preload("res://data/skills/hero_skill_data.gd")
const SC2HUDRoot = preload("res://ui/sc2_hud_root.gd")
const SFXManager = preload("res://core/audio/sfx_manager.gd")
const CombatTypes = preload("res://core/combat/combat_types.gd")


## 1. Test Smart-Cast to Node3D & Vector3 ground targets for AoE abilities
func test_smart_cast_and_aoe_targeting() -> Dictionary:
	var hero := HeroUnit3D.new()
	var h_data := HeroData.new()
	h_data.current_energy = 200.0
	h_data.max_energy = 200.0

	var bomb_skill := HeroSkillData.new()
	bomb_skill.skill_id = &"orbital_bombardment"
	bomb_skill.skill_name = "Bombardment"
	bomb_skill.energy_cost = 50.0
	bomb_skill.cooldown = 10.0
	bomb_skill.base_power = 120.0
	bomb_skill.area_radius = 8.0

	var blink_skill := HeroSkillData.new()
	blink_skill.skill_id = &"blink"
	blink_skill.skill_name = "Blink"
	blink_skill.energy_cost = 25.0
	blink_skill.cooldown = 5.0

	h_data.skills = [bomb_skill, blink_skill]
	hero.hero_data = h_data

	# Create a dummy enemy target Node3D
	var enemy_target := Node3D.new()
	enemy_target.position = Vector3(15.0, 0.0, 10.0)

	# Cast orbital bombardment targeting enemy node
	var cast_success: bool = hero.cast_skill(bomb_skill, enemy_target)
	if not assert_true(cast_success, "Orbital Bombardment successfully cast with Node3D target"):
		hero.free()
		enemy_target.free()
		return get_last_failure()

	# Cast blink targeting enemy node (hero position should advance towards enemy)
	hero.set_world_pos(Vector3.ZERO)
	var blink_success: bool = hero.cast_skill(blink_skill, enemy_target)
	if not assert_true(blink_success, "Blink successfully cast with Node3D target"):
		hero.free()
		enemy_target.free()
		return get_last_failure()

	var hero_pos: Vector3 = hero.global_position if hero.is_inside_tree() else hero.position
	if not assert_true(hero_pos.length() > 1.0, "Hero blinked towards target location"):
		hero.free()
		enemy_target.free()
		return get_last_failure()

	# Test command card target resolver in headless (safe null check)
	var card := SC2CommandCard.new()
	var resolved_target = card._resolve_cursor_target()
	if not assert_true(resolved_target == null, "Cursor target resolver safely returns null in headless"):
		hero.free()
		enemy_target.free()
		card.free()
		return get_last_failure()

	hero.free()
	enemy_target.free()
	card.free()
	return pass_test()


## 2. Test Full RTS Orders: Attack-Move and Patrol
func test_rts_order_modes_attack_and_patrol() -> Dictionary:
	var rts_ctrl := RTSController.new()
	var hero := HeroUnit3D.new()
	var marine := BaseUnit3D.new()

	# Verify default state
	if not assert_eq(int(rts_ctrl.current_order_mode), int(RTSController.OrderMode.NORMAL), "Initial order mode is NORMAL"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()

	# Mode switching
	rts_ctrl.set_order_mode(RTSController.OrderMode.ATTACK)
	if not assert_eq(int(rts_ctrl.current_order_mode), int(RTSController.OrderMode.ATTACK), "Order mode set to ATTACK"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()

	rts_ctrl.set_order_mode_by_name("PATROL")
	if not assert_eq(int(rts_ctrl.current_order_mode), int(RTSController.OrderMode.PATROL), "Order mode set to PATROL by name"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()

	# Hero Attack-Move
	var dest := Vector3(25.0, 0.0, 15.0)
	hero.attack_move_to(dest)
	if not assert_true(hero.is_attack_moving, "Hero is marked attack-moving"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()
	if not assert_false(hero.is_patrolling, "Hero is not patrolling during attack-move"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()

	# Hero Patrol
	var patrol_dest := Vector3(40.0, 0.0, -10.0)
	hero.patrol_to(patrol_dest)
	if not assert_false(hero.is_attack_moving, "Hero attack-moving cleared on patrol order"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()
	if not assert_true(hero.is_patrolling, "Hero is marked patrolling"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()
	if not assert_eq(hero.patrol_target, patrol_dest, "Hero patrol target assigned"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()

	# Stop order clears both
	hero.stop_action()
	if not assert_false(hero.is_attack_moving or hero.is_patrolling, "Hero stop_action clears all orders"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()

	# Marine Attack-Move & Patrol
	marine.attack_move_to(dest)
	if not assert_true(marine.is_attack_moving, "Marine attack_move_to sets flag"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()

	marine.patrol_to(patrol_dest)
	if not assert_true(marine.is_patrolling, "Marine patrol_to sets flag"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()

	marine.stop_action()
	if not assert_false(marine.is_patrolling, "Marine stop_action clears patrol"):
		rts_ctrl.free()
		hero.free()
		marine.free()
		return get_last_failure()

	rts_ctrl.free()
	hero.free()
	marine.free()
	return pass_test()


## 3. Test Control Groups and Camera Centering Shortcuts
func test_control_groups_and_shortcuts() -> Dictionary:
	var rts_ctrl := RTSController.new()
	var cam_rig := RTSCamera3D.new()
	rts_ctrl.camera_rig = cam_rig

	var u1 := CharacterBody3D.new()
	u1.position = Vector3(10.0, 0.0, 10.0)
	var u2 := CharacterBody3D.new()
	u2.position = Vector3(12.0, 0.0, 14.0)

	rts_ctrl.selected_units = [u1, u2]
	rts_ctrl._bind_control_group(1)

	if not assert_eq(rts_ctrl.control_groups.get(1, []).size(), 2, "Control group 1 bound with 2 units"):
		rts_ctrl.free()
		cam_rig.free()
		u1.free()
		u2.free()
		return get_last_failure()

	# Clear selection and recall group 1
	rts_ctrl.clear_selection()
	if not assert_true(rts_ctrl.selected_units.is_empty(), "Selection cleared"):
		rts_ctrl.free()
		cam_rig.free()
		u1.free()
		u2.free()
		return get_last_failure()

	rts_ctrl._select_control_group(1)
	if not assert_eq(rts_ctrl.selected_units.size(), 2, "Control group 1 restored selection of 2 units"):
		rts_ctrl.free()
		cam_rig.free()
		u1.free()
		u2.free()
		return get_last_failure()

	# Camera frustum ground viewport rect
	var ground_rect: Rect2 = cam_rig.get_ground_viewport_rect()
	if not assert_true(ground_rect.size.x > 0.0 and ground_rect.size.y > 0.0, "Camera ground viewport rect has valid dimensions"):
		rts_ctrl.free()
		cam_rig.free()
		u1.free()
		u2.free()
		return get_last_failure()

	rts_ctrl.free()
	cam_rig.free()
	u1.free()
	u2.free()
	return pass_test()


## 4. Test Live Tactical Radar (Minimap) drawing
func test_tactical_radar_minimap_draw() -> Dictionary:
	var hud := SC2HUDRoot.new()
	if not assert_not_null(hud.minimap_overlay, "Minimap overlay control exists in HUD"):
		hud.free()
		return get_last_failure()

	# Provide dummy spawner markers
	var markers: Array = [
		{"position": Vector3(-20.0, 0.0, -10.0), "state": 0},
		{"position": Vector3(15.0, 0.0, 25.0), "state": 1},
		{"position": Vector3(0.0, 0.0, 30.0), "state": 2}
	]
	hud.update_spawner_markers(markers)

	# Verify draw method executes safely under headless
	hud.minimap_overlay.size = Vector2(240.0, 180.0)
	hud._on_minimap_draw()

	if not assert_eq(hud.spawner_markers.size(), 3, "Minimap recorded 3 spawner markers"):
		hud.free()
		return get_last_failure()

	hud.free()
	return pass_test()


## 5. Test Reaper and Spectre Visual Archetype Scales and Materials
func test_reaper_and_spectre_archetype_visuals() -> Dictionary:
	var hero := HeroUnit3D.new()
	var v_root := Node3D.new()
	v_root.name = "VisualRoot"
	hero.visual_root = v_root
	hero.add_child(v_root)

	var body := MeshInstance3D.new()
	body.name = "BodyMesh"
	v_root.add_child(body)

	# Test Reaper
	var reaper_data := HeroData.new()
	reaper_data.archetype_id = &"reaper"
	hero.apply_archetype_visuals(reaper_data)

	if not assert_eq(v_root.scale, Vector3(0.92, 0.92, 0.92), "Reaper visual scale is 0.92 agile factor"):
		hero.free()
		return get_last_failure()

	var reaper_mat: StandardMaterial3D = body.material_override as StandardMaterial3D
	if not assert_not_null(reaper_mat, "Reaper has override material applied"):
		hero.free()
		return get_last_failure()
	if not assert_true(reaper_mat.emission_enabled, "Reaper material has thruster emission enabled"):
		hero.free()
		return get_last_failure()

	# Test Spectre
	var spectre_data := HeroData.new()
	spectre_data.archetype_id = &"spectre"
	hero.apply_archetype_visuals(spectre_data)

	if not assert_eq(v_root.scale, Vector3(0.96, 0.98, 0.96), "Spectre visual scale is 0.96 covert factor"):
		hero.free()
		return get_last_failure()

	var spectre_mat: StandardMaterial3D = body.material_override as StandardMaterial3D
	if not assert_not_null(spectre_mat, "Spectre has override material applied"):
		hero.free()
		return get_last_failure()
	if not assert_true(spectre_mat.emission_enabled, "Spectre material has psionic emission enabled"):
		hero.free()
		return get_last_failure()

	hero.free()
	return pass_test()


## 6. Test SFX and Voice Alerts
func test_sfx_routing_and_voice_alerts() -> Dictionary:
	var sfx := SFXManager.new()
	sfx.name = "SFXManager"

	# Weapon sound routing check
	if not assert_eq(sfx.get_bus_for_sound(&"snipe"), SFXManager.BUS_WEAPONS, "Snipe routed to Weapons bus"):
		sfx.free()
		return get_last_failure()
	if not assert_eq(sfx.get_bus_for_sound(&"shotgun"), SFXManager.BUS_WEAPONS, "Shotgun routed to Weapons bus"):
		sfx.free()
		return get_last_failure()
	if not assert_eq(sfx.get_bus_for_sound(&"plasma"), SFXManager.BUS_WEAPONS, "Plasma routed to Weapons bus"):
		sfx.free()
		return get_last_failure()
	if not assert_eq(sfx.get_bus_for_sound(&"base_under_attack"), SFXManager.BUS_VOICE, "Base under attack routed to Voice bus"):
		sfx.free()
		return get_last_failure()
	if not assert_eq(sfx.get_bus_for_sound(&"wave_incoming"), SFXManager.BUS_VOICE, "Wave incoming routed to Voice bus"):
		sfx.free()
		return get_last_failure()

	# Play alerts without headless crash
	sfx.play_voice_alert(&"base_under_attack")
	sfx.play_voice_alert(&"wave_incoming")
	sfx.play_hero_voice(&"hero_ack_1")

	if not assert_true(sfx.total_plays >= 1, "SFX manager recorded voice alert playback"):
		sfx.free()
		return get_last_failure()

	sfx.free()
	return pass_test()
