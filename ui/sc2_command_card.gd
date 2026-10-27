class_name SC2CommandCard
extends PanelContainer

## Procedural StarCraft II Style 3x5 Command Card UI.
## Dynamically populates standard RTS commands and hero ability buttons with hotkeys,
## cooldown sweeps, energy checks, and headless DisplayServer safety guards.
## Features procedural StyleBoxFlat military frames, cyan hover glow, and amber pressed feedback.

const HeroSkillData = preload("res://data/skills/hero_skill_data.gd")

signal command_triggered(command_id: String, payload: Variant)

const ROWS: int = 3
const COLS: int = 5
const TOTAL_SLOTS: int = ROWS * COLS

const DEFAULT_HOTKEYS: Array[String] = [
	"Q", "W", "E", "R", "T",
	"A", "S", "H", "P", "F",
	"Z", "X", "C", "V", "M"
]

var grid_container: GridContainer
var slot_buttons: Array[Button] = []
var slot_data: Array[Dictionary] = [] # stores {type: "order"|"skill", id: String, data: Variant}

var bound_unit: Node = null

var _btn_normal_style: StyleBoxFlat
var _btn_hover_style: StyleBoxFlat
var _btn_pressed_style: StyleBoxFlat
var _btn_disabled_style: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = Vector2(280, 180)
	_setup_procedural_grid()


func _ready() -> void:
	_setup_procedural_grid()


func _setup_procedural_grid() -> void:
	if grid_container != null:
		return

	# Style Command Card container with Terran steel console frame
	var card_panel_style := StyleBoxFlat.new()
	card_panel_style.bg_color = Color(0.045, 0.065, 0.095, 0.92)
	card_panel_style.border_width_top = 2
	card_panel_style.border_width_left = 2
	card_panel_style.border_width_right = 2
	card_panel_style.border_width_bottom = 2
	card_panel_style.border_color = Color(0.22, 0.48, 0.78, 0.75)
	card_panel_style.corner_radius_top_left = 4
	card_panel_style.corner_radius_top_right = 4
	card_panel_style.corner_radius_bottom_left = 4
	card_panel_style.corner_radius_bottom_right = 4
	card_panel_style.content_margin_left = 6.0
	card_panel_style.content_margin_right = 6.0
	card_panel_style.content_margin_top = 6.0
	card_panel_style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", card_panel_style)

	_init_button_styles()

	grid_container = GridContainer.new()
	grid_container.columns = COLS
	grid_container.add_theme_constant_override("h_separation", 4)
	grid_container.add_theme_constant_override("v_separation", 4)
	add_child(grid_container)

	for i in range(TOTAL_SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(50, 48)
		btn.clip_text = true
		btn.focus_mode = Control.FOCUS_NONE
		_apply_slot_button_style(btn)
		btn.pressed.connect(_on_slot_pressed.bind(i))
		grid_container.add_child(btn)
		slot_buttons.append(btn)
		slot_data.append({})

	clear_card()


func _init_button_styles() -> void:
	# Normal state: dark brushed steel panel with subtle cyan inset bevel
	_btn_normal_style = StyleBoxFlat.new()
	_btn_normal_style.bg_color = Color(0.06, 0.09, 0.14, 0.95)
	_btn_normal_style.border_width_top = 1
	_btn_normal_style.border_width_bottom = 1
	_btn_normal_style.border_width_left = 1
	_btn_normal_style.border_width_right = 1
	_btn_normal_style.border_color = Color(0.20, 0.45, 0.70, 0.75)
	_btn_normal_style.corner_radius_top_left = 3
	_btn_normal_style.corner_radius_top_right = 3
	_btn_normal_style.corner_radius_bottom_left = 3
	_btn_normal_style.corner_radius_bottom_right = 3

	# Hover state: brightened cyan border glow
	_btn_hover_style = StyleBoxFlat.new()
	_btn_hover_style.bg_color = Color(0.08, 0.14, 0.22, 0.95)
	_btn_hover_style.border_width_top = 2
	_btn_hover_style.border_width_bottom = 2
	_btn_hover_style.border_width_left = 2
	_btn_hover_style.border_width_right = 2
	_btn_hover_style.border_color = Color(0.35, 0.85, 1.0, 1.0)
	_btn_hover_style.corner_radius_top_left = 3
	_btn_hover_style.corner_radius_top_right = 3
	_btn_hover_style.corner_radius_bottom_left = 3
	_btn_hover_style.corner_radius_bottom_right = 3

	# Pressed state: energized amber/gold border glow
	_btn_pressed_style = StyleBoxFlat.new()
	_btn_pressed_style.bg_color = Color(0.18, 0.26, 0.38, 1.0)
	_btn_pressed_style.border_width_top = 2
	_btn_pressed_style.border_width_bottom = 2
	_btn_pressed_style.border_width_left = 2
	_btn_pressed_style.border_width_right = 2
	_btn_pressed_style.border_color = Color(1.0, 0.75, 0.15, 1.0)
	_btn_pressed_style.corner_radius_top_left = 3
	_btn_pressed_style.corner_radius_top_right = 3
	_btn_pressed_style.corner_radius_bottom_left = 3
	_btn_pressed_style.corner_radius_bottom_right = 3

	# Disabled state: darkened, desaturated state
	_btn_disabled_style = StyleBoxFlat.new()
	_btn_disabled_style.bg_color = Color(0.03, 0.04, 0.06, 0.5)
	_btn_disabled_style.border_width_top = 1
	_btn_disabled_style.border_width_bottom = 1
	_btn_disabled_style.border_width_left = 1
	_btn_disabled_style.border_width_right = 1
	_btn_disabled_style.border_color = Color(0.10, 0.14, 0.20, 0.35)
	_btn_disabled_style.corner_radius_top_left = 3
	_btn_disabled_style.corner_radius_top_right = 3
	_btn_disabled_style.corner_radius_bottom_left = 3
	_btn_disabled_style.corner_radius_bottom_right = 3


func _apply_slot_button_style(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _btn_normal_style)
	btn.add_theme_stylebox_override("hover", _btn_hover_style)
	btn.add_theme_stylebox_override("pressed", _btn_pressed_style)
	btn.add_theme_stylebox_override("disabled", _btn_disabled_style)
	btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0)) # Gold/amber hotkey badge
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.75, 0.15, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.40, 0.45, 0.4))
	btn.add_theme_font_size_override("font_size", 10)


func _process(_delta: float) -> void:
	if bound_unit == null or not is_instance_valid(bound_unit):
		return
	_update_slot_states()


func clear_card() -> void:
	for i in range(slot_buttons.size()):
		var btn: Button = slot_buttons[i]
		btn.text = ""
		btn.disabled = true
		btn.tooltip_text = ""
		slot_data[i] = {}


## Populates the 3x5 command card based on the active selected unit.
func populate_for_unit(unit: Node) -> void:
	_setup_procedural_grid()
	bound_unit = unit
	clear_card()

	if unit == null or not is_instance_valid(unit):
		return

	# Check if hero unit
	if unit.has_method("cast_skill") and "hero_data" in unit and unit.hero_data != null:
		_populate_hero_card(unit)
	else:
		_populate_standard_unit_card(unit)

	_update_slot_states()


func _populate_hero_card(hero: Node) -> void:
	var h_data = hero.hero_data
	var skills: Array = h_data.skills if h_data else []

	# Row 0: Bind Hero Skills (Slots 0 to 3: Q, W, E, R)
	for i in range(mini(skills.size(), 4)):
		var skill: HeroSkillData = skills[i]
		if skill == null:
			continue
		var slot_idx: int = i
		var btn: Button = slot_buttons[slot_idx]
		var hotkey: String = skill.hotkey if not skill.hotkey.is_empty() else DEFAULT_HOTKEYS[slot_idx]
		btn.text = "[%s]\n%s" % [hotkey, skill.skill_name.left(6)]
		btn.tooltip_text = "%s [%s]\nCost: %d Energy | CD: %.1fs\n%s" % [
			skill.skill_name,
			hotkey,
			int(skill.energy_cost),
			skill.cooldown,
			skill.description
		]
		btn.disabled = false
		slot_data[slot_idx] = {
			"type": "skill",
			"id": skill.skill_id,
			"skill": skill,
			"hotkey": hotkey
		}

	# Row 1: Standard RTS Orders (Slots 5..8: Attack, Stop, Hold, Patrol)
	_bind_order_button(5, "ATTACK", "A", "Attack (A)\nOrder unit to attack-move to destination.")
	_bind_order_button(6, "STOP", "S", "Stop (S)\nHalt current action immediately.")
	_bind_order_button(7, "HOLD", "H", "Hold Position (H)\nStand ground and engage enemies in range.")
	_bind_order_button(8, "PATROL", "P", "Patrol (P)\nPatrol back and forth between points.")

	# Row 2: Tactical Move (Slot 10: M), SFE5 Console (Slot 12 & 14: C), Elite Troops (Slot 13: V)
	_bind_order_button(10, "MOVE", "M", "Move (M)\nMove directly to location ignoring hostiles.")
	_bind_order_button(12, "CONSOLA", "C", "Consola SFE5 (C / Alt+C)\nAbre la consola de atributos, bufos y mejoras raciales.")
	_bind_order_button(13, "ÉLITE", "V", "Mejorar Élite / Tropas (V)\nAbre el reclutamiento de tropas y ascenso a veteranía élite.")
	_bind_order_button(14, "CONSOLA", "C", "Consola SFE5 (C / Alt+C)\nAbre la consola de atributos, bufos y mejoras raciales.")


func _populate_standard_unit_card(_unit: Node) -> void:
	_bind_order_button(5, "ATTACK", "A", "Attack (A)")
	_bind_order_button(6, "STOP", "S", "Stop (S)")
	_bind_order_button(7, "HOLD", "H", "Hold Position (H)")
	_bind_order_button(10, "MOVE", "M", "Move (M)")
	_bind_order_button(12, "CONSOLA", "C", "Consola SFE5 (C / Alt+C)\nAbre la consola de atributos, bufos y mejoras raciales.")
	_bind_order_button(13, "ÉLITE", "V", "Mejorar Élite / Tropas (V)\nAbre el reclutamiento de tropas y ascenso a veteranía élite.")
	_bind_order_button(14, "CONSOLA", "C", "Consola SFE5 (C / Alt+C)\nAbre la consola de atributos, bufos y mejoras raciales.")


func _bind_order_button(slot_idx: int, order_id: String, hotkey: String, tooltip: String = "") -> void:
	if slot_idx >= slot_buttons.size():
		return
	var btn: Button = slot_buttons[slot_idx]
	btn.text = "[%s]\n%s" % [hotkey, order_id.capitalize().left(5)]
	btn.tooltip_text = tooltip
	btn.disabled = false
	slot_data[slot_idx] = {
		"type": "order",
		"id": order_id,
		"hotkey": hotkey
	}


func _update_slot_states() -> void:
	if bound_unit == null or not is_instance_valid(bound_unit):
		return

	var is_hero: bool = bound_unit.has_method("cast_skill") and "hero_data" in bound_unit and bound_unit.hero_data != null

	for i in range(slot_buttons.size()):
		var info: Dictionary = slot_data[i]
		if info.is_empty():
			continue

		if info.get("type") == "skill" and is_hero:
			var skill: HeroSkillData = info.get("skill")
			var cd_remain: float = bound_unit.get_skill_cooldown_remaining(skill.skill_id)
			var cur_energy: float = bound_unit.hero_data.current_energy
			var btn: Button = slot_buttons[i]
			var hotkey: String = info.get("hotkey", "")

			if cd_remain > 0.0:
				btn.disabled = true
				btn.text = "[%s]\n[%.1f]" % [hotkey, cd_remain]
			elif cur_energy < skill.energy_cost:
				btn.disabled = true
				btn.text = "[%s]\n(NRG)" % [hotkey]
			else:
				btn.disabled = false
				btn.text = "[%s]\n%s" % [hotkey, skill.skill_name.left(6)]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	if bound_unit == null or not is_instance_valid(bound_unit):
		return

	var key_char: String = OS.get_keycode_string(event.keycode).to_upper()
	if key_char.is_empty():
		return

	# Match hotkey directly against active slots
	for i in range(slot_data.size()):
		var info: Dictionary = slot_data[i]
		if info.is_empty():
			continue
		var hotkey: String = str(info.get("hotkey", "")).to_upper()
		if hotkey == key_char and i < slot_buttons.size() and not slot_buttons[i].disabled:
			_on_slot_pressed(i)
			if get_viewport():
				get_viewport().set_input_as_handled()
			return


func _on_slot_pressed(slot_idx: int) -> void:
	if slot_idx >= slot_data.size():
		return
	var info: Dictionary = slot_data[slot_idx]
	if info.is_empty():
		return

	var slot_type: String = info.get("type", "")
	if slot_type == "skill":
		var skill: HeroSkillData = info.get("skill")
		if bound_unit and is_instance_valid(bound_unit):
			if bound_unit.has_method("activate_skill"):
				bound_unit.activate_skill(slot_idx, null)
			elif bound_unit.has_method("cast_skill"):
				bound_unit.cast_skill(skill, null)
		command_triggered.emit("cast_skill", skill)
	elif slot_type == "order":
		var order_id: String = info.get("id", "")
		if order_id == "CONSOLA":
			command_triggered.emit("open_console", null)
			return
		elif order_id == "ÉLITE":
			command_triggered.emit("open_recruitment", null)
			return
		if bound_unit and is_instance_valid(bound_unit):
			if (order_id == "STOP" or order_id == "HOLD") and bound_unit.has_method("stop_action"):
				bound_unit.stop_action()
		command_triggered.emit(order_id, null)


## Programmatic API to trigger an ability slot directly (e.g. for testing)
func activate_skill_by_slot(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= slot_buttons.size() or slot_buttons[slot_idx].disabled:
		return false
	_on_slot_pressed(slot_idx)
	return true
