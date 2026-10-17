class_name SFEStartModal
extends CanvasLayer

## SFEStartModal - Pre-Mission Deployment & Hero Selection Console for SFE5.
## Allows the player to view their BankManager career stats, choose mission difficulty,
## select their Hero Archetype (or roll Random with +50 bonus minerals and 1% secret roll),
## and deploy into Planet Char.

const SFEDifficultyManager = preload("res://core/economy/sfe_difficulty_manager.gd")
const HeroSelector = preload("res://core/heroes/hero_selector.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const BankManager = preload("res://core/persistence/bank_manager.gd")

signal deployment_confirmed(selected_hero: HeroData, difficulty_tier: int, is_random_hero: bool)

var selected_difficulty: int = 1 # 1 = NORMAL
var selected_archetype_id: StringName = &"raynor"
var is_random_selected: bool = false
var bank_data: Dictionary = {}

# UI Nodes
var root_panel: PanelContainer
var profile_label: Label
var difficulty_desc_label: Label
var hero_desc_label: Label
var diff_buttons: Array[Button] = []
var hero_buttons: Array[Button] = []
var random_button: Button
var deploy_btn: Button


func _init() -> void:
	layer = 100
	_build_modal_layout()


func _ready() -> void:
	load_player_profile()
	_update_difficulty_selection(1)
	_update_hero_selection(&"raynor", false)


func load_player_profile() -> void:
	bank_data = BankManager.load_bank()
	var acc_id: String = bank_data.get("account_id", "Recruit")
	var vet_lvl: int = bank_data.get("veterancy_level", 1)
	var kills: int = bank_data.get("total_kills", 0)
	if profile_label:
		profile_label.text = "OPERATOR: %s  |  VETERANCY LEVEL: %d  |  CAREER KILLS: %d" % [acc_id, vet_lvl, kills]


func _build_modal_layout() -> void:
	if root_panel != null:
		return

	# Dimmed backdrop
	var bg_tint := ColorRect.new()
	bg_tint.name = "BackdropTint"
	bg_tint.anchor_right = 1.0
	bg_tint.anchor_bottom = 1.0
	bg_tint.color = Color(0.015, 0.025, 0.04, 0.88)
	add_child(bg_tint)

	# Main Dialog Box
	root_panel = PanelContainer.new()
	root_panel.name = "ModalContainer"
	root_panel.anchor_left = 0.5
	root_panel.anchor_top = 0.5
	root_panel.anchor_right = 0.5
	root_panel.anchor_bottom = 0.5
	root_panel.offset_left = -380.0
	root_panel.offset_top = -280.0
	root_panel.offset_right = 380.0
	root_panel.offset_bottom = 280.0
	root_panel.custom_minimum_size = Vector2(760, 560)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.065, 0.095, 0.98)
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = Color(0.22, 0.52, 0.85, 0.85)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	panel_style.shadow_size = 14
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	root_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(root_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	root_panel.add_child(main_vbox)

	# Title Banner
	var title_lbl := Label.new()
	title_lbl.text = "SPECIAL FORCES ELITE 5 : MISSION DEPLOYMENT"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 1.0))
	main_vbox.add_child(title_lbl)

	# Profile Bar
	profile_label = Label.new()
	profile_label.text = "OPERATOR: Loading...  |  VETERANCY LEVEL: 1  |  CAREER KILLS: 0"
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_label.add_theme_font_size_override("font_size", 12)
	profile_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))
	main_vbox.add_child(profile_label)

	main_vbox.add_child(HSeparator.new())

	# Section 1: Difficulty
	var diff_title := Label.new()
	diff_title.text = "SELECT DIFFICULTY TIER"
	diff_title.add_theme_font_size_override("font_size", 13)
	diff_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	main_vbox.add_child(diff_title)

	var diff_hbox := HBoxContainer.new()
	diff_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(diff_hbox)

	var diff_names: Array[String] = ["CASUAL", "NORMAL", "HARD", "BRUTAL", "TORMENT"]
	for i in range(5):
		var btn := Button.new()
		btn.text = diff_names[i]
		btn.custom_minimum_size = Vector2(130, 34)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_difficulty_button_pressed.bind(i))
		diff_hbox.add_child(btn)
		diff_buttons.append(btn)

	difficulty_desc_label = Label.new()
	difficulty_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_desc_label.add_theme_font_size_override("font_size", 11)
	difficulty_desc_label.add_theme_color_override("font_color", Color(0.65, 0.8, 0.9, 0.8))
	main_vbox.add_child(difficulty_desc_label)

	main_vbox.add_child(HSeparator.new())

	# Section 2: Hero Selection
	var hero_title := Label.new()
	hero_title.text = "SELECT HERO ARCHETYPE"
	hero_title.add_theme_font_size_override("font_size", 13)
	hero_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	main_vbox.add_child(hero_title)

	var hero_hbox := HBoxContainer.new()
	hero_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(hero_hbox)

	var heroes_data := [
		{"id": &"raynor", "label": "RAYNOR\n(Marine)"},
		{"id": &"tychus", "label": "TYCHUS\n(Marauder)"},
		{"id": &"nova", "label": "NOVA\n(Ghost)"},
		{"id": &"zeratul", "label": "ZERATUL\n(Dark Templar)"},
		{"id": &"tassadar", "label": "TASSADAR\n(High Templar)"},
		{"id": &"medic", "label": "STETMANN\n(Support)"}
	]

	for entry in heroes_data:
		var btn := Button.new()
		btn.text = entry["label"]
		btn.custom_minimum_size = Vector2(98, 48)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_hero_button_pressed.bind(entry["id"]))
		hero_hbox.add_child(btn)
		hero_buttons.append(btn)

	# Random Hero Button
	random_button = Button.new()
	random_button.text = "🎲 RANDOM\n(+50 Minerals)"
	random_button.custom_minimum_size = Vector2(110, 48)
	random_button.focus_mode = Control.FOCUS_NONE
	random_button.pressed.connect(_on_random_button_pressed)
	hero_hbox.add_child(random_button)

	# Hero Details Box
	var hero_details_panel := PanelContainer.new()
	var details_style := StyleBoxFlat.new()
	details_style.bg_color = Color(0.03, 0.045, 0.07, 0.95)
	details_style.border_width_left = 1
	details_style.border_width_right = 1
	details_style.border_width_top = 1
	details_style.border_width_bottom = 1
	details_style.border_color = Color(0.18, 0.35, 0.55, 0.6)
	details_style.content_margin_left = 12.0
	details_style.content_margin_right = 12.0
	details_style.content_margin_top = 8.0
	details_style.content_margin_bottom = 8.0
	hero_details_panel.add_theme_stylebox_override("panel", details_style)
	main_vbox.add_child(hero_details_panel)

	hero_desc_label = Label.new()
	hero_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_desc_label.add_theme_font_size_override("font_size", 12)
	hero_desc_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.95))
	hero_details_panel.add_child(hero_desc_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	main_vbox.add_child(spacer)

	# Deploy Button
	deploy_btn = Button.new()
	deploy_btn.text = "▶ INITIATE DEPLOYMENT [ ENTER / SPACE ]"
	deploy_btn.custom_minimum_size = Vector2(300, 44)
	deploy_btn.add_theme_font_size_override("font_size", 15)
	deploy_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))
	deploy_btn.pressed.connect(_on_deploy_pressed)
	main_vbox.add_child(deploy_btn)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_deploy_pressed()


func _on_difficulty_button_pressed(tier: int) -> void:
	_update_difficulty_selection(tier)


func _update_difficulty_selection(tier: int) -> void:
	selected_difficulty = tier
	for i in range(diff_buttons.size()):
		var btn: Button = diff_buttons[i]
		if i == tier:
			btn.modulate = Color(1.2, 1.1, 0.4, 1.0) # Highlight selected
		else:
			btn.modulate = Color(0.85, 0.85, 0.85, 1.0)

	var income_mult: float = 1.0
	var enemy_mult: float = 1.0
	var cadence: float = 120.0
	match tier:
		0:
			income_mult = 1.50
			enemy_mult = 0.75
			cadence = 180.0
		1:
			income_mult = 1.00
			enemy_mult = 1.00
			cadence = 120.0
		2:
			income_mult = 0.80
			enemy_mult = 1.30
			cadence = 90.0
		3:
			income_mult = 0.65
			enemy_mult = 1.75
			cadence = 60.0
		4:
			income_mult = 0.50
			enemy_mult = 2.50
			cadence = 40.0

	if difficulty_desc_label:
		difficulty_desc_label.text = "Difficulty Multipliers: Income Rate: %.2fx  |  Enemy Health & Damage: %.2fx  |  Hive Evolution Cadence: %ds" % [
			income_mult, enemy_mult, int(cadence)
		]


func _on_hero_button_pressed(id: StringName) -> void:
	_update_hero_selection(id, false)


func _on_random_button_pressed() -> void:
	_update_hero_selection(&"", true)


func _update_hero_selection(id: StringName, is_rand: bool) -> void:
	is_random_selected = is_rand
	selected_archetype_id = id

	# Update button modulations
	for btn in hero_buttons:
		btn.modulate = Color(0.85, 0.85, 0.85, 1.0)

	if random_button:
		random_button.modulate = Color(1.3, 0.85, 0.2, 1.0) if is_rand else Color(0.85, 0.85, 0.85, 1.0)

	if is_rand:
		if hero_desc_label:
			hero_desc_label.text = "🎲 RANDOM HERO ASSIGNMENT (+50 STARTING MINERALS)\n" + \
				"Deploy with a randomized hero drawn from the standard catalog. Grants an immediate +50 Minerals resource cache.\n" + \
				"✦ Includes an authentic 1.0% chance of awakening the mythical Xel'Naga Harbinger secret archetype!"
		return

	var hero_index: int = -1
	match id:
		&"raynor": hero_index = 0
		&"tychus": hero_index = 1
		&"nova": hero_index = 2
		&"zeratul": hero_index = 3
		&"tassadar": hero_index = 4
		&"medic": hero_index = 5

	if hero_index >= 0 and hero_index < hero_buttons.size():
		hero_buttons[hero_index].modulate = Color(0.4, 1.1, 1.3, 1.0)

	var h_data: HeroData = HeroSelector.select_hero_manual(id)
	if h_data and hero_desc_label:
		var skill_names: Array[String] = []
		for sk in h_data.skills:
			if sk:
				skill_names.append("%s [%s]" % [sk.skill_name, sk.hotkey])
		var skills_text: String = ", ".join(skill_names) if not skill_names.is_empty() else "None"
		hero_desc_label.text = "✦ %s (%s)\nHP: %d | Shields: %d | Energy: %d | Damage: %d | Armor: %d | Speed: %.1f\nAbilities: %s" % [
			h_data.hero_name,
			h_data.role_description,
			int(h_data.max_hp),
			int(h_data.max_shield),
			int(h_data.max_energy),
			int(h_data.weapon_damage),
			int(h_data.flat_armor),
			h_data.move_speed,
			skills_text
		]


func _on_deploy_pressed() -> void:
	var final_hero: HeroData = null
	if is_random_selected:
		final_hero = HeroSelector.select_hero_random()
	else:
		final_hero = HeroSelector.select_hero_manual(selected_archetype_id)

	if final_hero == null:
		final_hero = HeroSelector.select_hero_manual(&"raynor")

	deployment_confirmed.emit(final_hero, selected_difficulty, is_random_selected)
	visible = false
	queue_free()
