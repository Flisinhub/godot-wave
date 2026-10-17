class_name SC2CommandCard
extends PanelContainer

## Procedural StarCraft II Style 3x5 Command Card UI.
## Dynamically populates standard RTS commands and hero ability buttons with hotkeys,
## cooldown sweeps, energy checks, and headless DisplayServer safety guards.

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

func _init() -> void:
	custom_minimum_size = Vector2(280, 180)
	_setup_procedural_grid()

func _ready() -> void:
	_setup_procedural_grid()

func _setup_procedural_grid() -> void:
	if grid_container != null:
		return

	grid_container = GridContainer.new()
	grid_container.columns = COLS
	add_child(grid_container)

	for i in range(TOTAL_SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(50, 48)
		btn.text = DEFAULT_HOTKEYS[i]
		btn.clip_text = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_slot_pressed.bind(i))
		grid_container.add_child(btn)
		slot_buttons.append(btn)
		slot_data.append({})

	clear_card()

func _process(_delta: float) -> void:
	# Update ability cooldown sweeps and energy validation in real time
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
		btn.text = "%s\n%s" % [hotkey, skill.skill_name.left(6)]
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

	# Row 2: Tactical Move (Slot 10: M)
	_bind_order_button(10, "MOVE", "M", "Move (M)\nMove directly to location ignoring hostiles.")

func _populate_standard_unit_card(_unit: Node) -> void:
	_bind_order_button(5, "ATTACK", "A", "Attack (A)")
	_bind_order_button(6, "STOP", "S", "Stop (S)")
	_bind_order_button(7, "HOLD", "H", "Hold Position (H)")
	_bind_order_button(10, "MOVE", "M", "Move (M)")

func _bind_order_button(slot_idx: int, order_id: String, hotkey: String, tooltip: String) -> void:
	if slot_idx >= slot_buttons.size():
		return
	var btn: Button = slot_buttons[slot_idx]
	btn.text = "%s\n%s" % [hotkey, order_id.capitalize().left(5)]
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
				btn.text = "%s\n[%.1f]" % [hotkey, cd_remain]
			elif cur_energy < skill.energy_cost:
				btn.disabled = true
				btn.text = "%s\n(NRG)" % [hotkey]
			else:
				btn.disabled = false
				btn.text = "%s\n%s" % [hotkey, skill.skill_name.left(6)]

func _on_slot_pressed(slot_idx: int) -> void:
	if slot_idx >= slot_data.size():
		return
	var info: Dictionary = slot_data[slot_idx]
	if info.is_empty():
		return

	var slot_type: String = info.get("type", "")
	if slot_type == "skill":
		var skill: HeroSkillData = info.get("skill")
		if bound_unit and bound_unit.has_method("cast_skill"):
			bound_unit.cast_skill(skill, null)
		command_triggered.emit("cast_skill", skill)
	elif slot_type == "order":
		var order_id: String = info.get("id", "")
		if bound_unit and is_instance_valid(bound_unit):
			if order_id == "STOP" and bound_unit.has_method("stop_action"):
				bound_unit.stop_action()
		command_triggered.emit(order_id, null)
