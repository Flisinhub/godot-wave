class_name SFESettingsModal
extends CanvasLayer

## SFESettingsModal - Pause and Settings Menu for SFE5.
## Controls audio volumes, edge scrolling, accessibility/colorblind profiles, and game pause.

const GameSettings = preload("res://core/meta/game_settings.gd")
const AccessibilityManager = preload("res://core/ui/accessibility_and_color_manager.gd")

signal closed()
signal restart_requested()

var settings: GameSettings = null
var accessibility: AccessibilityManager = null

var master_slider: HSlider
var sfx_slider: HSlider
var music_slider: HSlider
var edge_scroll_check: CheckBox
var colorblind_option: OptionButton


func _init() -> void:
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	settings = GameSettings.new()
	accessibility = AccessibilityManager.new()
	_build_ui()


func _build_ui() -> void:
	# Dimmed backdrop
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0.02, 0.04, 0.07, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 480)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.13, 0.98)
	style.border_color = Color(0.25, 0.6, 0.95, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "⚙ AJUSTES Y PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Audio Settings
	var audio_lbl := Label.new()
	audio_lbl.text = "VOLÚMENES DE AUDIO"
	audio_lbl.add_theme_font_size_override("font_size", 13)
	audio_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(audio_lbl)

	# Master
	master_slider = _add_slider_row(vbox, "Volumen General (Master):", settings.master_volume, func(val: float):
		settings.master_volume = val
		_apply_audio_bus_volume("Master", val)
	)

	# SFX
	sfx_slider = _add_slider_row(vbox, "Efectos de Sonido (SFX):", settings.sfx_volume, func(val: float):
		settings.sfx_volume = val
		_apply_audio_bus_volume("SFX", val)
	)

	# Music
	music_slider = _add_slider_row(vbox, "Música:", settings.music_volume, func(val: float):
		settings.music_volume = val
		_apply_audio_bus_volume("Music", val)
	)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Controls & Accessibility
	var gameplay_lbl := Label.new()
	gameplay_lbl.text = "JUGABILIDAD Y ACCESIBILIDAD"
	gameplay_lbl.add_theme_font_size_override("font_size", 13)
	gameplay_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(gameplay_lbl)

	# Edge scroll checkbox
	edge_scroll_check = CheckBox.new()
	edge_scroll_check.text = "Desplazamiento por Bordes de Pantalla (Edge Scroll)"
	edge_scroll_check.button_pressed = settings.edge_scroll_enabled
	edge_scroll_check.toggled.connect(func(pressed: bool):
		settings.edge_scroll_enabled = pressed
	)
	vbox.add_child(edge_scroll_check)

	# Colorblind Selector
	var cb_row := HBoxContainer.new()
	cb_row.add_theme_constant_override("separation", 10)
	vbox.add_child(cb_row)

	var cb_lbl := Label.new()
	cb_lbl.text = "Modo Daltonismo:"
	cb_lbl.custom_minimum_size = Vector2(160, 0)
	cb_row.add_child(cb_lbl)

	colorblind_option = OptionButton.new()
	colorblind_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colorblind_option.add_item("Estándar (Ninguno)", AccessibilityManager.ColorblindMode.NONE)
	colorblind_option.add_item("Protanopía (Rojo débil)", AccessibilityManager.ColorblindMode.PROTANOPIA)
	colorblind_option.add_item("Deuteranopía (Verde débil)", AccessibilityManager.ColorblindMode.DEUTERANOPIA)
	colorblind_option.add_item("Tritanopía (Azul débil)", AccessibilityManager.ColorblindMode.TRITANOPIA)
	colorblind_option.selected = accessibility.colorblind_mode
	colorblind_option.item_selected.connect(func(idx: int):
		accessibility.colorblind_mode = idx as AccessibilityManager.ColorblindMode
	)
	cb_row.add_child(colorblind_option)

	var sep3 := HSeparator.new()
	vbox.add_child(sep3)

	# Action Buttons
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_box)

	var resume_btn := Button.new()
	resume_btn.text = "REANUDAR PARTIDA"
	resume_btn.custom_minimum_size = Vector2(170, 36)
	resume_btn.pressed.connect(close)
	btn_box.add_child(resume_btn)

	var restart_btn := Button.new()
	restart_btn.text = "REINICIAR MISIÓN"
	restart_btn.custom_minimum_size = Vector2(170, 36)
	restart_btn.pressed.connect(func():
		settings.save_settings()
		if get_tree():
			get_tree().paused = false
			restart_requested.emit()
			get_tree().reload_current_scene()
	)
	btn_box.add_child(restart_btn)


func _add_slider_row(parent: VBoxContainer, label_text: String, initial_val: float, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)

	return slider


func _apply_audio_bus_volume(bus_name: String, linear_vol: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		var db := linear_to_db(maxf(0.0001, linear_vol))
		AudioServer.set_bus_volume_db(bus_idx, db)


func open() -> void:
	visible = true
	if get_tree():
		get_tree().paused = true


func close() -> void:
	if settings:
		settings.save_settings()
	if get_tree():
		get_tree().paused = false
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_F10:
			close()
			get_viewport().set_input_as_handled()
