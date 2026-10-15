class_name SelectionBoxUI
extends Control

## SelectionBoxUI - Renders StarCraft 2 style drag selection rectangle.

var is_dragging: bool = false
var start_pos: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO

@export var fill_color: Color = Color(0.1, 0.9, 0.25, 0.18)
@export var border_color: Color = Color(0.2, 1.0, 0.35, 0.9)
@export var border_width: float = 1.5


func start_box(pos: Vector2) -> void:
	is_dragging = true
	start_pos = pos
	current_pos = pos
	queue_redraw()


func update_box(pos: Vector2) -> void:
	current_pos = pos
	queue_redraw()


func end_box() -> Rect2:
	var rect: Rect2 = get_selection_rect()
	is_dragging = false
	queue_redraw()
	return rect


func get_selection_rect() -> Rect2:
	var top_left: Vector2 = Vector2(min(start_pos.x, current_pos.x), min(start_pos.y, current_pos.y))
	var size: Vector2 = Vector2(abs(current_pos.x - start_pos.x), abs(current_pos.y - start_pos.y))
	return Rect2(top_left, size)


func _draw() -> void:
	if not is_dragging:
		return
	
	var rect: Rect2 = get_selection_rect()
	# Don't draw if size is negligible
	if rect.size.x < 2.0 and rect.size.y < 2.0:
		return
		
	# Draw filled semi-transparent box
	draw_rect(rect, fill_color, true)
	# Draw sharp green outline
	draw_rect(rect, border_color, false, border_width)
