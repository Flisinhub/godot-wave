class_name RTSController
extends Node

## RTSController - Handles RTS unit selection, box selection, focus fire, and tactical movement orders.

@export var camera_rig: RTSCamera3D
@export var selection_box_ui: SelectionBoxUI
@export var formation_spacing: float = 1.6
@export var drag_threshold: float = 8.0

var move_indicator_scene: PackedScene = preload("res://levels/move_indicator.tscn")

enum OrderMode { NORMAL = 0, ATTACK = 1, PATROL = 2 }
var current_order_mode: OrderMode = OrderMode.NORMAL

var selected_units: Array[CharacterBody3D] = []
var is_box_selecting: bool = false
var box_start_pos: Vector2 = Vector2.ZERO

# Control Groups & Tactical Voice
var control_groups: Dictionary = {} # int (1..5) -> Array[CharacterBody3D]
var _last_group_press_time: Dictionary = {} # int -> float (msec)
var _last_order_voice_time: float = -999.0


func _get_signal_bus() -> Node:
	if Engine.has_singleton("SignalBus"):
		return Engine.get_singleton("SignalBus")
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("SignalBus"):
		return tree.root.get_node("SignalBus")
	return null


func _emit_units_selected(units: Array) -> void:
	var sb := _get_signal_bus()
	if sb and sb.has_signal("units_selected"):
		sb.emit_signal("units_selected", units)


func _emit_units_deselected() -> void:
	var sb := _get_signal_bus()
	if sb and sb.has_signal("units_deselected"):
		sb.emit_signal("units_deselected")


func _emit_move_command_issued(target_pos: Vector3) -> void:
	var sb := _get_signal_bus()
	if sb and sb.has_signal("move_command_issued"):
		sb.emit_signal("move_command_issued", target_pos)


func _ready() -> void:
	var sb := _get_signal_bus()
	if sb and sb.has_signal("unit_died"):
		sb.connect("unit_died", _on_unit_died)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		
		# LEFT CLICK - Selection, Box Selection or Attack/Patrol Execution
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if current_order_mode != OrderMode.NORMAL:
				if mb.is_pressed():
					var click_res = _resolve_ground_or_target(mb.position)
					if current_order_mode == OrderMode.ATTACK:
						_issue_attack_move_order(click_res)
					elif current_order_mode == OrderMode.PATROL:
						_issue_patrol_order(click_res)
					current_order_mode = OrderMode.NORMAL
					if get_viewport():
						get_viewport().set_input_as_handled()
				return

			if mb.is_pressed():
				box_start_pos = mb.position
				is_box_selecting = true
				if camera_rig:
					camera_rig.block_edge_scroll = true
				if selection_box_ui:
					selection_box_ui.start_box(mb.position)
			else:
				if is_box_selecting:
					is_box_selecting = false
					if camera_rig:
						camera_rig.block_edge_scroll = false
					var rect: Rect2 = Rect2()
					if selection_box_ui:
						rect = selection_box_ui.end_box()
					
					var is_shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
					
					if rect.size.length() > drag_threshold:
						_handle_box_selection(rect, is_shift_held)
					else:
						_handle_single_click_selection(mb.position, is_shift_held)

		# RIGHT CLICK - Tactical Movement & Interaction / Attack Orders
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.is_pressed():
			_handle_right_click_order(mb.position)

	elif event is InputEventMouseMotion:
		if is_box_selecting and selection_box_ui:
			selection_box_ui.update_box(event.position)

	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_ev: InputEventKey = event as InputEventKey
		# Stop / Hold position hotkeys (S or H)
		if key_ev.keycode == KEY_S or key_ev.keycode == KEY_H:
			current_order_mode = OrderMode.NORMAL
			for unit in selected_units:
				if is_instance_valid(unit) and unit.has_method("stop_action"):
					unit.stop_action()
			return

		# Attack-Move hotkey (A)
		if key_ev.keycode == KEY_A:
			current_order_mode = OrderMode.ATTACK
			return

		# Patrol hotkey (P)
		if key_ev.keycode == KEY_P:
			current_order_mode = OrderMode.PATROL
			return

		# Hero Selection & Camera Centering (F1 or Space)
		if key_ev.keycode == KEY_F1 or key_ev.keycode == KEY_SPACE:
			_select_hero_and_center()
			return

		# Control Groups 1..5 (Ctrl+1..5 to bind, 1..5 to select, double tap to center)
		if key_ev.keycode >= KEY_1 and key_ev.keycode <= KEY_5:
			var group_num: int = key_ev.keycode - KEY_1 + 1
			if key_ev.ctrl_pressed or Input.is_key_pressed(KEY_CTRL):
				_bind_control_group(group_num)
			else:
				_select_control_group(group_num)
			return


func _handle_single_click_selection(screen_pos: Vector2, is_shift_held: bool) -> void:
	var ray_res: Dictionary = _raycast_from_screen(screen_pos)
	if ray_res.is_empty():
		if not is_shift_held:
			clear_selection()
		return
	
	var collider: Object = ray_res.collider
	
	# Check if an allied unit was clicked
	if collider is CharacterBody3D and (collider.is_in_group("allies") or collider is BaseUnit3D):
		var unit: CharacterBody3D = collider as CharacterBody3D
		if not is_shift_held:
			clear_selection()
			select_unit(unit)
		else:
			if selected_units.has(unit):
				deselect_unit(unit)
			else:
				select_unit(unit)
		_emit_units_selected(selected_units)
		return

	# Check if clicked on a gate to manually toggle it
	if collider is GateStructure:
		var gate: GateStructure = collider as GateStructure
		gate.toggle_gate()
		return

	# Clicked on ground or empty space
	if not is_shift_held:
		clear_selection()


func _handle_box_selection(screen_rect: Rect2, is_shift_held: bool) -> void:
	if not camera_rig or not camera_rig.get_camera():
		return
	
	var cam: Camera3D = camera_rig.get_camera()
	
	if not is_shift_held:
		clear_selection()

	var ally_nodes: Array[Node] = get_tree().get_nodes_in_group("allies")
	for node in ally_nodes:
		if node is CharacterBody3D:
			var unit: CharacterBody3D = node as CharacterBody3D
			if not is_instance_valid(unit):
				continue
			
			# Project torso center (0.9m above ground) instead of feet for natural box selection
			var torso_pos: Vector3 = unit.global_position + Vector3(0.0, 0.9, 0.0)
			if cam.is_position_behind(torso_pos):
				continue
			
			var unit_screen_pos: Vector2 = cam.unproject_position(torso_pos)
			if screen_rect.has_point(unit_screen_pos):
				select_unit(unit)

	_emit_units_selected(selected_units)


func _handle_right_click_order(screen_pos: Vector2) -> void:
	current_order_mode = OrderMode.NORMAL
	if selected_units.is_empty():
		return

	# Confirmation voice line with >= 3.5s rate-limiting
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	if (now_sec - _last_order_voice_time) >= 3.5:
		_last_order_voice_time = now_sec
		var SFXM: GDScript = load("res://core/audio/sfx_manager.gd") as GDScript
		if SFXM and SFXM.instance != null:
			SFXM.instance.play_hero_voice(&"hero_ack")

	var ray_res: Dictionary = _raycast_from_screen(screen_pos)

	# 1. Target Focus Fire: Right-click directly on an enemy
	if not ray_res.is_empty() and (ray_res.collider is BaseEnemy3D or (ray_res.collider is Node3D and ray_res.collider.is_in_group("enemies"))):
		var enemy: Node3D = ray_res.collider as Node3D
		_spawn_move_indicator(enemy.global_position, Color(1.0, 0.2, 0.2, 0.95))
		for unit in selected_units:
			if is_instance_valid(unit) and unit.has_method("set_attack_target"):
				unit.set_attack_target(enemy)
		return

	# 2. Movement Order to ground position
	var target_pos: Vector3 = Vector3.ZERO
	if not ray_res.is_empty():
		target_pos = ray_res.position
	else:
		# Fallback to horizontal ground plane at Y = 0.0
		if not camera_rig or not camera_rig.get_camera():
			return
		var cam: Camera3D = camera_rig.get_camera()
		var ray_origin: Vector3 = cam.project_ray_origin(screen_pos)
		var ray_dir: Vector3 = cam.project_ray_normal(screen_pos)
		var ground_plane: Plane = Plane(Vector3.UP, 0.0)
		var hit = ground_plane.intersects_ray(ray_origin, ray_dir)
		if hit:
			target_pos = hit
		else:
			return

	target_pos.y = 0.0

	# Spawn visual green click indicator on the ground
	_spawn_move_indicator(target_pos, Color(0.1, 1.0, 0.35, 0.9))
	
	# Calculate formation positions to prevent infinite collisions/crowding
	var formation_positions: Array[Vector3] = _calculate_formation_positions(target_pos, selected_units.size(), formation_spacing)
	var nav_map: RID = get_viewport().world_3d.navigation_map
	
	for i in range(selected_units.size()):
		var unit: CharacterBody3D = selected_units[i]
		if is_instance_valid(unit) and unit.has_method("move_to"):
			var pos: Vector3 = formation_positions[i]
			# Validate formation target on navigable mesh
			if nav_map.is_valid():
				var valid_pos: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, pos)
				valid_pos.y = 0.0
				unit.move_to(valid_pos)
			else:
				unit.move_to(pos)

	_emit_move_command_issued(target_pos)


func _spawn_move_indicator(pos: Vector3, color: Color = Color(0.1, 1.0, 0.35, 0.9)) -> void:
	if not move_indicator_scene:
		return
	var indicator: MoveIndicator = move_indicator_scene.instantiate() as MoveIndicator
	get_tree().current_scene.add_child(indicator)
	indicator.global_position = pos + Vector3(0.0, 0.05, 0.0)
	indicator.set_color(color)


func _calculate_formation_positions(center: Vector3, count: int, spacing: float) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if count <= 1:
		positions.append(center)
		return positions

	var cols: int = int(ceil(sqrt(float(count))))
	var rows: int = int(ceil(float(count) / float(cols)))

	var offset_x_start: float = -(float(cols - 1) * spacing) * 0.5
	var offset_z_start: float = -(float(rows - 1) * spacing) * 0.5

	for i in range(count):
		var c: int = i % cols
		var r: int = i / cols
		var pos: Vector3 = center + Vector3(offset_x_start + (c * spacing), 0.0, offset_z_start + (r * spacing))
		positions.append(pos)

	return positions


func select_unit(unit: CharacterBody3D) -> void:
	if not selected_units.has(unit):
		selected_units.append(unit)
		if unit.has_method("set_selected"):
			unit.set_selected(true)


func deselect_unit(unit: CharacterBody3D) -> void:
	if selected_units.has(unit):
		selected_units.erase(unit)
		if is_instance_valid(unit) and unit.has_method("set_selected"):
			unit.set_selected(false)


func clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("set_selected"):
			unit.set_selected(false)
	selected_units.clear()
	_emit_units_deselected()


func _on_unit_died(unit: Node) -> void:
	if unit is CharacterBody3D:
		selected_units.erase(unit as CharacterBody3D)


func _raycast_from_screen(screen_pos: Vector2) -> Dictionary:
	if not camera_rig or not camera_rig.get_camera():
		return {}

	var cam: Camera3D = camera_rig.get_camera()
	var ray_origin: Vector3 = cam.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = cam.project_ray_normal(screen_pos)
	var ray_end: Vector3 = ray_origin + (ray_dir * 1000.0)

	var space_state: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 7 # Detect Layer 1 (World/Walls), Layer 2 (Allies), Layer 4 (Enemies)

	return space_state.intersect_ray(query)


func set_order_mode(mode: OrderMode) -> void:
	current_order_mode = mode


func set_order_mode_by_name(mode_name: String) -> void:
	match mode_name.to_upper():
		"ATTACK":
			current_order_mode = OrderMode.ATTACK
		"PATROL":
			current_order_mode = OrderMode.PATROL
		_:
			current_order_mode = OrderMode.NORMAL


func _resolve_ground_or_target(screen_pos: Vector2) -> Variant:
	var ray_res: Dictionary = _raycast_from_screen(screen_pos)
	if not ray_res.is_empty():
		var col = ray_res.collider
		if col is Node3D and (col.is_in_group("enemies") or (col.get_script() != null and col.get_script().get_global_name() in ["BaseEnemy3D", "SpawnerNode"])):
			return col
		var p: Vector3 = ray_res.position
		p.y = 0.0
		return p

	if not camera_rig or not camera_rig.get_camera():
		return Vector3.ZERO

	var cam: Camera3D = camera_rig.get_camera()
	var ray_origin: Vector3 = cam.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = cam.project_ray_normal(screen_pos)
	var ground_plane: Plane = Plane(Vector3.UP, 0.0)
	var hit = ground_plane.intersects_ray(ray_origin, ray_dir)
	if hit:
		hit.y = 0.0
		return hit
	return Vector3.ZERO


func _issue_attack_move_order(click_target: Variant) -> void:
	if selected_units.is_empty():
		return

	if click_target is Node3D and is_instance_valid(click_target) and (click_target.is_in_group("enemies") or click_target.is_in_group("bosses")):
		_spawn_move_indicator(click_target.global_position, Color(1.0, 0.2, 0.2, 0.95))
		for unit in selected_units:
			if is_instance_valid(unit) and unit.has_method("set_attack_target"):
				unit.set_attack_target(click_target)
		return

	var target_pos: Vector3 = click_target.global_position if (click_target is Node3D and is_instance_valid(click_target)) else (click_target if click_target is Vector3 else Vector3.ZERO)
	target_pos.y = 0.0
	_spawn_move_indicator(target_pos, Color(1.0, 0.35, 0.1, 0.95))

	var formation_positions: Array[Vector3] = _calculate_formation_positions(target_pos, selected_units.size(), formation_spacing)
	var nav_map: RID = get_viewport().world_3d.navigation_map if get_viewport() and get_viewport().world_3d else RID()

	for i in range(selected_units.size()):
		var unit: CharacterBody3D = selected_units[i]
		if is_instance_valid(unit):
			var pos: Vector3 = formation_positions[i]
			if nav_map.is_valid():
				var valid_pos: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, pos)
				valid_pos.y = 0.0
				pos = valid_pos
			if unit.has_method("attack_move_to"):
				unit.attack_move_to(pos)
			elif unit.has_method("move_to"):
				unit.move_to(pos)

	_emit_move_command_issued(target_pos)


func _issue_patrol_order(click_target: Variant) -> void:
	if selected_units.is_empty():
		return

	var target_pos: Vector3 = click_target.global_position if (click_target is Node3D and is_instance_valid(click_target)) else (click_target if click_target is Vector3 else Vector3.ZERO)
	target_pos.y = 0.0
	_spawn_move_indicator(target_pos, Color(0.2, 0.7, 1.0, 0.95))

	var formation_positions: Array[Vector3] = _calculate_formation_positions(target_pos, selected_units.size(), formation_spacing)
	var nav_map: RID = get_viewport().world_3d.navigation_map if get_viewport() and get_viewport().world_3d else RID()

	for i in range(selected_units.size()):
		var unit: CharacterBody3D = selected_units[i]
		if is_instance_valid(unit):
			var pos: Vector3 = formation_positions[i]
			if nav_map.is_valid():
				var valid_pos: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, pos)
				valid_pos.y = 0.0
				pos = valid_pos
			if unit.has_method("patrol_to"):
				unit.patrol_to(pos)
			elif unit.has_method("move_to"):
				unit.move_to(pos)

	_emit_move_command_issued(target_pos)


func _bind_control_group(group_num: int) -> void:
	var valid_units: Array[CharacterBody3D] = []
	for u in selected_units:
		if is_instance_valid(u) and ("is_dead" not in u or not u.is_dead):
			valid_units.append(u)
	control_groups[group_num] = valid_units


func _select_control_group(group_num: int) -> void:
	var raw_units: Array = control_groups.get(group_num, [])
	var living_units: Array[CharacterBody3D] = []
	for u in raw_units:
		if is_instance_valid(u) and ("is_dead" not in u or not u.is_dead):
			living_units.append(u)
	control_groups[group_num] = living_units

	if living_units.is_empty():
		return

	clear_selection()
	for u in living_units:
		select_unit(u)
	_emit_units_selected(selected_units)

	var now: float = Time.get_ticks_msec()
	var last_t: float = _last_group_press_time.get(group_num, 0.0)
	_last_group_press_time[group_num] = now
	if (now - last_t) < 350.0:
		if camera_rig and not living_units.is_empty():
			var center_p: Vector3 = living_units[0].global_position if living_units[0].is_inside_tree() else living_units[0].position
			camera_rig.pan_to_position(center_p)


func _select_hero_and_center() -> void:
	var heroes: Array[Node] = get_tree().get_nodes_in_group("heroes") if is_inside_tree() else []
	var living_hero: CharacterBody3D = null
	for h in heroes:
		if h is CharacterBody3D and is_instance_valid(h):
			if "is_dead" not in h or not h.is_dead:
				living_hero = h as CharacterBody3D
				break

	if living_hero:
		clear_selection()
		select_unit(living_hero)
		_emit_units_selected(selected_units)
		if camera_rig:
			var h_pos: Vector3 = living_hero.global_position if living_hero.is_inside_tree() else living_hero.position
			camera_rig.pan_to_position(h_pos)

