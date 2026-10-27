class_name BossHealthBarUI
extends Control

## BossHealthBarUI - Top-screen Cinematic Boss Health & Shield Bar
## Features dual-layer HP and Plasma Shield bars, phase marker notches at 66% and 33%,
## boss name title banner, and an ability casting telegraph warning bar.
## Binds to boss signals: boss_spawned, boss_health_changed, boss_ability_casting, boss_died.

@warning_ignore("unused_signal")
signal boss_spawned(boss_name: String, max_hp: float, max_shields: float)
@warning_ignore("unused_signal")
signal boss_health_changed(current_hp: float, current_shields: float, phase: int)
@warning_ignore("unused_signal")
signal boss_ability_casting(ability_name: String, windup_duration: float)
@warning_ignore("unused_signal")
signal boss_died()

@export var phase2_notch: float = 0.66
@export var phase3_notch: float = 0.33

var boss_name_label: Label
var shield_bar: ProgressBar
var health_bar: ProgressBar
var cast_bar: ProgressBar
var cast_label: Label
var notch_p2: ColorRect
var notch_p3: ColorRect
var container: Control

var max_hp: float = 8000.0
var max_shields: float = 0.0
var current_hp: float = 8000.0
var current_shields: float = 0.0

var _is_casting: bool = false
var _cast_duration: float = 0.0
var _cast_elapsed: float = 0.0
var _bound_boss: Node = null


func _init() -> void:
	visible = false


func _ready() -> void:
	_setup_ui_hierarchy()
	visible = false


func _setup_ui_hierarchy() -> void:
	if container != null and is_instance_valid(container):
		return

	# Anchor to top center of screen
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 16.0
	offset_right = 0.0
	offset_bottom = 110.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	container = Control.new()
	container.name = "BarContainer"
	container.anchor_left = 0.5
	container.anchor_top = 0.0
	container.anchor_right = 0.5
	container.anchor_bottom = 0.0
	container.offset_left = -320.0
	container.offset_top = 0.0
	container.offset_right = 320.0
	container.offset_bottom = 90.0
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	# 1. Boss Name Label
	boss_name_label = Label.new()
	boss_name_label.name = "BossNameLabel"
	boss_name_label.text = "BRUTALISK"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.offset_left = 0.0
	boss_name_label.offset_top = 0.0
	boss_name_label.offset_right = 640.0
	boss_name_label.offset_bottom = 24.0
	boss_name_label.add_theme_font_size_override("font_size", 16)
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	boss_name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	container.add_child(boss_name_label)

	# 2. Background Frame
	var bg_frame := Panel.new()
	bg_frame.name = "BackgroundFrame"
	bg_frame.offset_left = 0.0
	bg_frame.offset_top = 26.0
	bg_frame.offset_right = 640.0
	bg_frame.offset_bottom = 54.0
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.3, 0.35, 0.45)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bg_frame.add_theme_stylebox_override("panel", bg_style)
	container.add_child(bg_frame)

	# 3. Health Bar (Bottom Layer)
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.offset_left = 2.0
	health_bar.offset_top = 28.0
	health_bar.offset_right = 638.0
	health_bar.offset_bottom = 52.0
	health_bar.min_value = 0.0
	health_bar.max_value = 8000.0
	health_bar.value = 8000.0
	health_bar.show_percentage = false

	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.85, 0.15, 0.18, 1.0)
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.18, 0.04, 0.05, 0.8)
	health_bar.add_theme_stylebox_override("fill", hp_fill)
	health_bar.add_theme_stylebox_override("background", hp_bg)
	container.add_child(health_bar)

	# 4. Plasma Shield Bar (Top Layer)
	shield_bar = ProgressBar.new()
	shield_bar.name = "ShieldBar"
	shield_bar.offset_left = 2.0
	shield_bar.offset_top = 28.0
	shield_bar.offset_right = 638.0
	shield_bar.offset_bottom = 36.0
	shield_bar.min_value = 0.0
	shield_bar.max_value = 4000.0
	shield_bar.value = 0.0
	shield_bar.show_percentage = false

	var shield_fill := StyleBoxFlat.new()
	shield_fill.bg_color = Color(0.2, 0.85, 1.0, 0.9)
	var shield_bg := StyleBoxFlat.new()
	shield_bg.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	shield_bar.add_theme_stylebox_override("fill", shield_fill)
	shield_bar.add_theme_stylebox_override("background", shield_bg)
	container.add_child(shield_bar)

	# 5. Phase Divider Notches (66% and 33%)
	var bar_w: float = 636.0
	notch_p2 = ColorRect.new()
	notch_p2.name = "NotchPhase2"
	notch_p2.color = Color(1.0, 0.9, 0.3, 0.95)
	notch_p2.offset_left = 2.0 + (bar_w * phase2_notch) - 1.0
	notch_p2.offset_top = 26.0
	notch_p2.offset_right = notch_p2.offset_left + 2.0
	notch_p2.offset_bottom = 54.0
	container.add_child(notch_p2)

	notch_p3 = ColorRect.new()
	notch_p3.name = "NotchPhase3"
	notch_p3.color = Color(1.0, 0.3, 0.2, 0.95)
	notch_p3.offset_left = 2.0 + (bar_w * phase3_notch) - 1.0
	notch_p3.offset_top = 26.0
	notch_p3.offset_right = notch_p3.offset_left + 2.0
	notch_p3.offset_bottom = 54.0
	container.add_child(notch_p3)

	# 6. Ability Casting Bar (Amber Windup Warning)
	cast_bar = ProgressBar.new()
	cast_bar.name = "AbilityCastBar"
	cast_bar.offset_left = 40.0
	cast_bar.offset_top = 58.0
	cast_bar.offset_right = 600.0
	cast_bar.offset_bottom = 70.0
	cast_bar.min_value = 0.0
	cast_bar.max_value = 1.0
	cast_bar.value = 0.0
	cast_bar.show_percentage = false
	cast_bar.visible = false

	var cast_fill := StyleBoxFlat.new()
	cast_fill.bg_color = Color(1.0, 0.72, 0.1, 1.0)
	var cast_bg := StyleBoxFlat.new()
	cast_bg.bg_color = Color(0.15, 0.1, 0.05, 0.8)
	cast_bar.add_theme_stylebox_override("fill", cast_fill)
	cast_bar.add_theme_stylebox_override("background", cast_bg)
	container.add_child(cast_bar)

	cast_label = Label.new()
	cast_label.name = "CastLabel"
	cast_label.text = "GROUND SLAM"
	cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cast_label.offset_left = 40.0
	cast_label.offset_top = 70.0
	cast_label.offset_right = 600.0
	cast_label.offset_bottom = 86.0
	cast_label.add_theme_font_size_override("font_size", 11)
	cast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	cast_label.visible = false
	container.add_child(cast_label)


func bind_boss(boss_node: Node) -> void:
	if not is_instance_valid(boss_node):
		return

	_bound_boss = boss_node
	_setup_ui_hierarchy()

	if boss_node.has_signal("boss_spawned") and not boss_node.boss_spawned.is_connected(_on_boss_spawned):
		boss_node.boss_spawned.connect(_on_boss_spawned)

	if boss_node.has_signal("boss_health_changed") and not boss_node.boss_health_changed.is_connected(_on_boss_health_changed):
		boss_node.boss_health_changed.connect(_on_boss_health_changed)

	if boss_node.has_signal("boss_ability_casting") and not boss_node.boss_ability_casting.is_connected(_on_boss_ability_casting):
		boss_node.boss_ability_casting.connect(_on_boss_ability_casting)

	if boss_node.has_signal("boss_died") and not boss_node.boss_died.is_connected(_on_boss_died):
		boss_node.boss_died.connect(_on_boss_died)

	# Read current state if already initialized
	var b_name: String = boss_node.get("boss_name") if "boss_name" in boss_node else "BOSS"
	var m_hp: float = boss_node.get("max_health") if "max_health" in boss_node else 8000.0
	var m_sh: float = boss_node.get("max_shields") if "max_shields" in boss_node else 0.0
	var c_hp: float = boss_node.get("current_health") if "current_health" in boss_node else m_hp
	var c_sh: float = boss_node.get("current_shields") if "current_shields" in boss_node else m_sh
	var ph: int = boss_node.get("current_phase") if "current_phase" in boss_node else 1

	_on_boss_spawned(b_name, m_hp, m_sh)
	_on_boss_health_changed(c_hp, c_sh, ph)


func _on_boss_spawned(b_name: String, m_hp: float, m_shields: float) -> void:
	_setup_ui_hierarchy()
	max_hp = m_hp
	max_shields = m_shields
	current_hp = m_hp
	current_shields = m_shields

	if boss_name_label:
		boss_name_label.text = b_name.to_upper()

	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

	if shield_bar:
		shield_bar.max_value = max_shields if max_shields > 0.0 else 1.0
		shield_bar.value = current_shields
		shield_bar.visible = (max_shields > 0.0)

	if cast_bar:
		cast_bar.visible = false
	if cast_label:
		cast_label.visible = false

	visible = true


func _on_boss_health_changed(cur_hp: float, cur_shields: float, _phase: int) -> void:
	current_hp = cur_hp
	current_shields = cur_shields

	if health_bar:
		health_bar.value = current_hp
	if shield_bar:
		shield_bar.value = current_shields
		shield_bar.visible = (max_shields > 0.0 and current_shields > 0.0)


func _on_boss_ability_casting(ability_name: String, windup_duration: float) -> void:
	if windup_duration <= 0.0:
		return
	_is_casting = true
	_cast_duration = windup_duration
	_cast_elapsed = 0.0

	if cast_bar:
		cast_bar.max_value = windup_duration
		cast_bar.value = 0.0
		cast_bar.visible = true

	if cast_label:
		cast_label.text = "¡CANALIZANDO %s!" % ability_name.to_upper()
		cast_label.visible = true


func _on_boss_died() -> void:
	visible = false
	_is_casting = false
	_bound_boss = null


func _process(delta: float) -> void:
	if _is_casting:
		_cast_elapsed += delta
		if cast_bar:
			cast_bar.value = _cast_elapsed
		if _cast_elapsed >= _cast_duration:
			_is_casting = false
			if cast_bar:
				cast_bar.visible = false
			if cast_label:
				cast_label.visible = false
