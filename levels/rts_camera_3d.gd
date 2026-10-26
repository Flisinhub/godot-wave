class_name RTSCamera3D
extends Node3D

## RTSCamera3D - StarCraft 2 style isometric RTS camera rig.
## Features WASD/arrow keys movement, edge scrolling, mouse wheel zoom, and map bounds clamping.

@export_group("Movement")
@export var pan_speed: float = 24.0
@export var fast_pan_multiplier: float = 1.8
@export var edge_scroll_enabled: bool = true
@export var edge_scroll_margin: float = 18.0

@export_group("Zoom")
@export var min_zoom_height: float = 8.0
@export var max_zoom_height: float = 34.0
@export var zoom_step: float = 2.5
@export var zoom_smoothness: float = 10.0

@export_group("Bounds")
@export var map_bounds: Rect2 = Rect2(-38.0, -38.0, 76.0, 76.0)

@export var drag_speed: float = 0.04

var block_edge_scroll: bool = false
var _is_middle_dragging: bool = false

@onready var camera: Camera3D = $Camera3D

var _target_zoom_height: float = 18.0
var _current_zoom_height: float = 18.0
var _camera_base_tilt_deg: float = 55.0


func _ready() -> void:
	add_to_group("rts_camera")
	_target_zoom_height = 18.0
	_current_zoom_height = _target_zoom_height
	_update_camera_transform(true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE and not mb.is_pressed():
			_is_middle_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_middle_dragging = mb.is_pressed()
			if _is_middle_dragging and get_viewport():
				get_viewport().set_input_as_handled()
		elif mb.is_pressed():
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom_height = clamp(_target_zoom_height - zoom_step, min_zoom_height, max_zoom_height)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom_height = clamp(_target_zoom_height + zoom_step, min_zoom_height, max_zoom_height)
	elif event is InputEventMouseMotion and _is_middle_dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE) == 0:
			_is_middle_dragging = false
			return
		var zoom_factor: float = _current_zoom_height / 18.0
		var tilt_factor: float = maxf(0.1, sin(deg_to_rad(_camera_base_tilt_deg)))
		var dx: float = mm.relative.x * drag_speed * zoom_factor
		var dz: float = (mm.relative.y * drag_speed * zoom_factor) / tilt_factor
		if is_inside_tree():
			global_position.x -= dx
			global_position.z -= dz
		else:
			position.x -= dx
			position.z -= dz
		_clamp_to_bounds()
		if get_viewport():
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_handle_panning(delta)
	_handle_zooming(delta)
	_clamp_to_bounds()


func _handle_panning(delta: float) -> void:
	var move_vec: Vector2 = Vector2.ZERO
	
	# Arrow keys for keyboard accessibility (WASD reserved exclusively for hero abilities & orders)
	if Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0

	# Edge scrolling (active when cursor is at window margins and not dragging with middle mouse)
	if edge_scroll_enabled and not block_edge_scroll and not _is_middle_dragging:
		var viewport: Viewport = get_viewport()
		if viewport:
			var mouse_pos: Vector2 = viewport.get_mouse_position()
			var win_size: Vector2 = viewport.get_visible_rect().size
			
			if mouse_pos.x >= 0 and mouse_pos.y >= 0 and mouse_pos.x <= win_size.x and mouse_pos.y <= win_size.y:
				if mouse_pos.x < edge_scroll_margin:
					move_vec.x -= 1.0
				elif mouse_pos.x > win_size.x - edge_scroll_margin:
					move_vec.x += 1.0
				
				if mouse_pos.y < edge_scroll_margin:
					move_vec.y -= 1.0
				elif mouse_pos.y > win_size.y - edge_scroll_margin:
					move_vec.y += 1.0

	if move_vec.length_squared() > 0.001:
		move_vec = move_vec.normalized()
		var speed: float = pan_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= fast_pan_multiplier
		
		# Move pivot along XZ world plane
		var px: float = move_vec.x * speed * delta
		var pz: float = move_vec.y * speed * delta
		if is_inside_tree():
			global_position.x += px
			global_position.z += pz
		else:
			position.x += px
			position.z += pz


func _handle_zooming(delta: float) -> void:
	if not is_equal_approx(_current_zoom_height, _target_zoom_height):
		_current_zoom_height = lerp(_current_zoom_height, _target_zoom_height, zoom_smoothness * delta)
		_update_camera_transform(false)


func _update_camera_transform(_instant: bool) -> void:
	if not camera:
		return
	
	# Trigonometric offset for a fixed ~55 degree pitch
	var tilt_rad: float = deg_to_rad(_camera_base_tilt_deg)
	var z_offset: float = _current_zoom_height / tan(tilt_rad)
	
	camera.position = Vector3(0.0, _current_zoom_height, z_offset)
	camera.rotation_degrees = Vector3(-_camera_base_tilt_deg, 0.0, 0.0)


func _clamp_to_bounds() -> void:
	var min_x: float = map_bounds.position.x
	var max_x: float = map_bounds.position.x + map_bounds.size.x
	var min_z: float = map_bounds.position.y
	var max_z: float = map_bounds.position.y + map_bounds.size.y
	if is_inside_tree():
		global_position.x = clamp(global_position.x, min_x, max_x)
		global_position.z = clamp(global_position.z, min_z, max_z)
	else:
		position.x = clamp(position.x, min_x, max_x)
		position.z = clamp(position.z, min_z, max_z)


func get_camera() -> Camera3D:
	return camera


func pan_to_position(target_pos: Vector3) -> void:
	if is_inside_tree():
		global_position.x = target_pos.x
		global_position.z = target_pos.z
	else:
		position.x = target_pos.x
		position.z = target_pos.z
	_clamp_to_bounds()
