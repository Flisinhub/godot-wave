class_name RTSController
extends Node

## RTSController - Handles RTS unit selection, box selection, focus fire, and tactical movement orders.

@export var camera_rig: RTSCamera3D
@export var selection_box_ui: SelectionBoxUI
@export var formation_spacing: float = 1.6
@export var drag_threshold: float = 8.0

var move_indicator_scene: PackedScene = preload("res://levels/move_indicator.tscn")

var selected_units: Array[CharacterBody3D] = []
var is_box_selecting: bool = false
var box_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	SignalBus.unit_died.connect(_on_unit_died)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		
		# LEFT CLICK - Selection & Box Selection
		if mb.button_index == MOUSE_BUTTON_LEFT:
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
			for unit in selected_units:
				if is_instance_valid(unit) and unit.has_method("stop_action"):
					unit.stop_action()


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
		SignalBus.units_selected.emit(selected_units)
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

	SignalBus.units_selected.emit(selected_units)


func _handle_right_click_order(screen_pos: Vector2) -> void:
	if selected_units.is_empty():
		return

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

	SignalBus.move_command_issued.emit(target_pos)


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
	SignalBus.units_deselected.emit()


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
