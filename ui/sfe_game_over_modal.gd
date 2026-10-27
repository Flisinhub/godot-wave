class_name SFEGameOverModal
extends CanvasLayer

## SFEGameOverModal - SFE5 Victory / Defeat Post-Mission Summary (Task 3.19).
## Shows detailed telemetry: time elapsed, total kills, minerals earned, spawners cleared, and difficulty.

var is_victory: bool = false
var elapsed_time_sec: float = 0.0
var total_kills: int = 0
var total_minerals: int = 0
var spawners_cleared: int = 0
var total_spawners: int = 0
var difficulty_name: String = "Normal"

signal restart_requested()


func setup(
	p_victory: bool,
	p_time_sec: float,
	p_kills: int,
	p_minerals: int,
	p_spawners_cleared: int,
	p_total_spawners: int,
	p_diff: String
) -> void:
	is_victory = p_victory
	elapsed_time_sec = p_time_sec
	total_kills = p_kills
	total_minerals = p_minerals
	spawners_cleared = p_spawners_cleared
	total_spawners = p_total_spawners
	difficulty_name = p_diff


func _ready() -> void:
	layer = 120 # Above all other HUD elements
	_build_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	
	# Dimmed backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.08, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	
	# Center Panel Container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 420)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.16, 0.95)
	var border_color := Color(0.2, 0.85, 0.3) if is_victory else Color(0.9, 0.2, 0.2)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	# Header Title
	var title_lbl := Label.new()
	title_lbl.text = "¡VICTORIA ROTUNDA!" if is_victory else "¡MISIÓN FALLIDA!"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", border_color)
	vbox.add_child(title_lbl)
	
	var sub_lbl := Label.new()
	sub_lbl.text = "Has erradicado todos los nidos enemigos" if is_victory else "La Fortaleza Planetaria ha sucumbido al enjambre"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(sub_lbl)
	
	var sep := HSeparator.new()
	vbox.add_child(sep)
	
	# Statistics Grid
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	
	var mins: int = int(elapsed_time_sec) / 60
	var secs: int = int(elapsed_time_sec) % 60
	var time_str := "%02d:%02d" % [mins, secs]
	
	_add_stat_row(grid, "Tiempo de Partida:", time_str)
	_add_stat_row(grid, "Dificultad:", difficulty_name)
	_add_stat_row(grid, "Engendradores Erradicados:", "%d / %d" % [spawners_cleared, total_spawners])
	_add_stat_row(grid, "Bajas Enemigas Totales:", str(total_kills))
	_add_stat_row(grid, "Minerales Acumulados:", "%d 💎" % total_minerals)
	
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)
	
	# Action Button
	var btn := Button.new()
	btn.text = "REINICIAR MISIÓN"
	btn.custom_minimum_size = Vector2(220, 44)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.22, 0.35)
	btn_style.border_color = Color(0.3, 0.6, 0.9)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", btn_style)
	
	btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(btn)


func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	grid.add_child(l)
	
	var v := Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	grid.add_child(v)


func _on_restart_pressed() -> void:
	restart_requested.emit()
	get_tree().reload_current_scene()
