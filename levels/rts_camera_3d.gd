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

@onready var camera: Camera3D = $Camera3D

var _target_zoom_height: float = 18.0
var _current_zoom_height: float = 18.0
var _camera_base_tilt_deg: float = 55.0


func _ready() -> void:
	_target_zoom_height = 18.0
	_current_zoom_height = _target_zoom_height
	_update_camera_transform(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.is_pressed():
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom_height = clamp(_target_zoom_height - zoom_step, min_zoom_height, max_zoom_height)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom_height = clamp(_target_zoom_height + zoom_step, min_zoom_height, max_zoom_height)


func _process(delta: float) -> void:
	_handle_panning(delta)
	_handle_zooming(delta)
	_clamp_to_bounds()


func _handle_panning(delta: float) -> void:
	var move_vec: Vector2 = Vector2.ZERO
	
	# Keyboard input (WASD and Arrow keys)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0

	# Edge scrolling
	if edge_scroll_enabled:
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
		global_position.x += move_vec.x * speed * delta
		global_position.z += move_vec.y * speed * delta


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
	global_position.x = clamp(global_position.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x)
	global_position.z = clamp(global_position.z, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)


func get_camera() -> Camera3D:
	return camera
