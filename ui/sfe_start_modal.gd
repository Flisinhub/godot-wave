class_name SFEStartModal
extends CanvasLayer

## SFEStartModal - Pre-Mission Deployment & Hero Selection Console for SFE5.
## Allows the player to view their BankManager career stats, choose mission game mode & difficulty,
## select from 12 Hero Archetypes (or roll Random with +15.000/players minerals bonus and 1% secret roll),
## and deploy into Planet Char.

const SFEDifficultyManager = preload("res://core/economy/sfe_difficulty_manager.gd")
const HeroSelector = preload("res://core/heroes/hero_selector.gd")
const HeroData = preload("res://core/heroes/hero_data.gd")
const BankManager = preload("res://core/persistence/bank_manager.gd")
const GameModeManager = preload("res://core/modes/game_mode_manager.gd")
const RankSystem = preload("res://core/meta/rank_system.gd")
const AchievementSystem = preload("res://core/meta/achievement_system.gd")
const SecretHeroManager = preload("res://core/meta/secret_hero_manager.gd")

signal deployment_confirmed(selected_hero: HeroData, difficulty_tier: int, is_random_hero: bool)
signal mode_selected(mode_id: StringName)

var selected_mode_id: StringName = &"classic"
var selected_difficulty: int = 1 # 1 = NORMAL
var selected_archetype_id: StringName = &"raynor"
var is_random_selected: bool = false
var achievements_enabled: bool = true
var bank_data: Dictionary = {}

# UI Nodes
var root_panel: PanelContainer
var profile_label: Label
var mode_desc_label: Label
var difficulty_desc_label: Label
var hero_desc_label: Label
var mode_buttons: Array[Button] = []
var diff_buttons: Array[Button] = []
var hero_buttons: Array[Button] = []
var random_button: Button
var deploy_btn: Button

const MODES_DATA := [
	{"id": &"classic", "name": "CLÁSICO", "desc": "MODO CLÁSICO: Partida estándar SFE5. Héroes normales, bufos T1-T7, fases de historia (Zerg/Protoss/Cúspide) y eventos."},
	{"id": &"torment", "name": "TORMENTO", "desc": "MODO TORMENTO: Muerte permanente. Los héroes caídos no reviven. Daño de enemigos extremo y tensión máxima."},
	{"id": &"hardcore", "name": "HARDCORE", "desc": "MODO HARDCORE: Despliegue con 12 unidades élite iniciales. Sin tienda de bufos ni eventos de bonificación."},
	{"id": &"nightmare", "name": "PESADILLA", "desc": "MODO PESADILLA: Base central en (0,0), barrera de radiación y ciclos infinitos de 10 oleadas periódicas."},
	{"id": &"mutation", "name": "MUTACIÓN", "desc": "MODO MUTACIÓN: Mutadores caóticos activos (nidos acelerados, regeneración enemiga y enjambres voraces)."},
	{"id": &"split_income", "name": "SPLIT INCOME", "desc": "MODO ECONOMÍA DIVIDIDA: Recursos no compartidos. Cada jugador gestiona sus propios minerales de forma individual."}
]

const HEROES_CATALOG := [
	# Row 1: SFE5 Heroes
	{"id": &"raynor", "label": "RAYNOR\n(Marine)"},
	{"id": &"tychus", "label": "TYCHUS\n(Marauder)"},
	{"id": &"nova", "label": "NOVA\n(Ghost)"},
	{"id": &"zeratul", "label": "ZERATUL\n(Dark Templar)"},
	{"id": &"tassadar", "label": "TASSADAR\n(High Templar)"},
	{"id": &"medic", "label": "STETMANN\n(Support)"},
	# Row 2: Standard Units & Secret Archetypes
	{"id": &"marine", "label": "MARINE\n(Assault)"},
	{"id": &"marauder", "label": "MARAUDER\n(Shock)"},
	{"id": &"reaper", "label": "REAPER\n(Jetpack)"},
	{"id": &"ghost", "label": "GHOST\n(Sniper Ops)"},
	{"id": &"spectre", "label": "🔒 SPECTRE\n(Black-Ops)"},
	{"id": &"secret_harbinger", "label": "🔒 HARBINGER\n(Xel'Naga)"}
]


func _init() -> void:
	layer = 100
	_build_modal_layout()


func _ready() -> void:
	load_player_profile()
	_update_mode_selection(&"classic")
	_update_difficulty_selection(1)
	_update_hero_selection(&"raynor", false)


func load_player_profile() -> void:
	bank_data = BankManager.load_bank()
	var acc_id: String = bank_data.get("account_id", "Recruit")
	var rank_pts: int = bank_data.get("rank_points", 0)
	var rank_str: String = RankSystem.get_rank_string(rank_pts)
	var ach_pts: int = AchievementSystem.get_total_achievement_points()
	var kills: int = bank_data.get("total_kills", 0)
	if profile_label:
		profile_label.text = "OPERADOR: %s  |  RANGO: %s (%d pts)  |  LOGROS: %d pts  |  BAJAS: %d" % [
			acc_id, rank_str, rank_pts, ach_pts, kills
		]


func _build_modal_layout() -> void:
	if root_panel != null:
		return

	# Dimmed backdrop
	var bg_tint := ColorRect.new()
	bg_tint.name = "BackdropTint"
	bg_tint.anchor_right = 1.0
	bg_tint.anchor_bottom = 1.0
	bg_tint.color = Color(0.015, 0.025, 0.04, 0.90)
	add_child(bg_tint)

	# Main Dialog Box
	root_panel = PanelContainer.new()
	root_panel.name = "ModalContainer"
	root_panel.anchor_left = 0.5
	root_panel.anchor_top = 0.5
	root_panel.anchor_right = 0.5
	root_panel.anchor_bottom = 0.5
	root_panel.offset_left = -440.0
	root_panel.offset_top = -340.0
	root_panel.offset_right = 440.0
	root_panel.offset_bottom = 340.0
	root_panel.custom_minimum_size = Vector2(880, 680)

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
	panel_style.shadow_size = 16
	panel_style.content_margin_left = 22.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 16.0
	panel_style.content_margin_bottom = 16.0
	root_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(root_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	root_panel.add_child(main_vbox)

	# Title Banner
	var title_lbl := Label.new()
	title_lbl.text = "SPECIAL FORCES ELITE 5 : MISSION DEPLOYMENT"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 19)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 1.0))
	main_vbox.add_child(title_lbl)

	# Profile Bar
	profile_label = Label.new()
	profile_label.text = "OPERATOR: Loading...  |  VETERANCY LEVEL: 1  |  CAREER KILLS: 0"
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_label.add_theme_font_size_override("font_size", 11)
	profile_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3, 1.0))
	main_vbox.add_child(profile_label)

	main_vbox.add_child(HSeparator.new())

	# Section 1: Game Mode Selector
	var mode_title := Label.new()
	mode_title.text = "1. MODO DE JUEGO (GAME MODE)"
	mode_title.add_theme_font_size_override("font_size", 12)
	mode_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	main_vbox.add_child(mode_title)

	var mode_hbox := HBoxContainer.new()
	mode_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(mode_hbox)

	for m in MODES_DATA:
		var btn := Button.new()
		btn.text = m["name"]
		btn.custom_minimum_size = Vector2(130, 28)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_mode_button_pressed.bind(m["id"]))
		mode_hbox.add_child(btn)
		mode_buttons.append(btn)

	mode_desc_label = Label.new()
	mode_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_desc_label.add_theme_font_size_override("font_size", 11)
	mode_desc_label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0, 0.85))
	main_vbox.add_child(mode_desc_label)

	main_vbox.add_child(HSeparator.new())

	# Section 2: Difficulty
	var diff_title := Label.new()
	diff_title.text = "2. DIFICULTAD DE MISIÓN (DIFFICULTY TIER)"
	diff_title.add_theme_font_size_override("font_size", 12)
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
		btn.custom_minimum_size = Vector2(140, 28)
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

	# Section 3: Hero Archetype Selection
	var hero_title := Label.new()
	hero_title.text = "3. ARQUETIPO DE HÉROE (12 CLASES SFE5 + RANDOM)"
	hero_title.add_theme_font_size_override("font_size", 12)
	hero_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 0.9))
	main_vbox.add_child(hero_title)

	var hero_grid := GridContainer.new()
	hero_grid.columns = 6
	hero_grid.add_theme_constant_override("h_separation", 6)
	hero_grid.add_theme_constant_override("v_separation", 6)
	main_vbox.add_child(hero_grid)

	for entry in HEROES_CATALOG:
		var btn := Button.new()
		btn.text = entry["label"]
		btn.custom_minimum_size = Vector2(132, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_hero_button_pressed.bind(entry["id"]))
		hero_grid.add_child(btn)
		hero_buttons.append(btn)

	# Random Hero Button
	random_button = Button.new()
	random_button.text = "🎲 RANDOM (+15.000 / Nº Jugadores Minerales | 1.0% Probabilidad Heraldo Secreto)"
	random_button.custom_minimum_size = Vector2(0, 32)
	random_button.focus_mode = Control.FOCUS_NONE
	random_button.pressed.connect(_on_random_button_pressed)
	main_vbox.add_child(random_button)

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
	details_style.content_margin_top = 6.0
	details_style.content_margin_bottom = 6.0
	hero_details_panel.add_theme_stylebox_override("panel", details_style)
	main_vbox.add_child(hero_details_panel)

	hero_desc_label = Label.new()
	hero_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_desc_label.add_theme_font_size_override("font_size", 11)
	hero_desc_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.95))
	hero_details_panel.add_child(hero_desc_label)

	# Deploy Button
	deploy_btn = Button.new()
	deploy_btn.text = "▶ INICIAR DESPLIEGUE EN CHAR [ ENTER / SPACE ]"
	deploy_btn.custom_minimum_size = Vector2(300, 38)
	deploy_btn.add_theme_font_size_override("font_size", 14)
	deploy_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))
	deploy_btn.pressed.connect(_on_deploy_pressed)
	main_vbox.add_child(deploy_btn)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_deploy_pressed()


func _on_mode_button_pressed(mode_id: StringName) -> void:
	_update_mode_selection(mode_id)


func _update_mode_selection(mode_id: StringName) -> void:
	selected_mode_id = mode_id
	mode_selected.emit(mode_id)
	for i in range(mode_buttons.size()):
		var btn: Button = mode_buttons[i]
		var m_data: Dictionary = MODES_DATA[i]
		if m_data["id"] == mode_id:
			btn.modulate = Color(1.2, 1.1, 0.4, 1.0)
			if mode_desc_label:
				mode_desc_label.text = m_data["desc"]
		else:
			btn.modulate = Color(0.85, 0.85, 0.85, 1.0)


func _on_difficulty_button_pressed(tier: int) -> void:
	_update_difficulty_selection(tier)


func _update_difficulty_selection(tier: int) -> void:
	selected_difficulty = tier
	for i in range(diff_buttons.size()):
		var btn: Button = diff_buttons[i]
		if i == tier:
			btn.modulate = Color(1.2, 1.1, 0.4, 1.0)
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
		difficulty_desc_label.text = "Multiplicadores: Tasa de Ingreso: %.2fx  |  Vida y Daño Enemigo: %.2fx  |  Cadencia de Nidos: %ds" % [
			income_mult, enemy_mult, int(cadence)
		]


func _on_hero_button_pressed(id: StringName) -> void:
	_update_hero_selection(id, false)


func _on_random_button_pressed() -> void:
	_update_hero_selection(&"", true)


func _update_hero_selection(id: StringName, is_rand: bool) -> void:
	is_random_selected = is_rand
	selected_archetype_id = id

	for btn in hero_buttons:
		btn.modulate = Color(0.85, 0.85, 0.85, 1.0)

	if random_button:
		random_button.modulate = Color(1.3, 0.85, 0.2, 1.0) if is_rand else Color(0.85, 0.85, 0.85, 1.0)

	if is_rand:
		if hero_desc_label:
			hero_desc_label.text = "🎲 ASIGNACIÓN DE HÉROE ALEATORIO (+15.000 / Nº JUGADORES MINERALES)\n" + \
				"Despliégate con un héroe aleatorio del catálogo. Otorga una bonificación de 15.000 minerales dividida entre los jugadores.\n" + \
				"✦ ¡Incluye una probabilidad auténtica del 1,0 % de despertar al mítico Heraldo Xel'Naga (Secret Hero)!"
		return

	var hero_index: int = -1
	for i in range(HEROES_CATALOG.size()):
		if HEROES_CATALOG[i]["id"] == id:
			hero_index = i
			break

	if hero_index >= 0 and hero_index < hero_buttons.size():
		hero_buttons[hero_index].modulate = Color(0.4, 1.1, 1.3, 1.0)

	var all_heroes: Dictionary = HeroSelector.get_all_archetypes()
	var h_data: HeroData = all_heroes.get(id)
	if h_data == null:
		h_data = HeroSelector.select_hero_manual(id, true)

	if h_data and hero_desc_label:
		var skill_names: Array[String] = []
		for sk in h_data.skills:
			if sk:
				skill_names.append("%s [%s]" % [sk.skill_name, sk.hotkey])
		var skills_text: String = ", ".join(skill_names) if not skill_names.is_empty() else "None"
		var secret_tag: String = " [🔒 ARQUETIPO SECRETO: Selección 1% en Random o Modo Debug]" if h_data.is_secret else ""
		hero_desc_label.text = "✦ %s (%s)%s\nHP: %d | Shields: %d | Energy: %d | Damage: %d | Armor: %d | Speed: %.1f\nHabilidades: %s" % [
			h_data.hero_name,
			h_data.role_description,
			secret_tag,
			int(h_data.max_hp),
			int(h_data.max_shield),
			int(h_data.max_energy),
			int(h_data.weapon_damage),
			int(h_data.flat_armor),
			h_data.move_speed,
			skills_text
		]


func _on_deploy_pressed() -> void:
	achievements_enabled = true
	var final_hero: HeroData = null

	# Roll Secret Hero if eligible (>= 3000 achievement points and difficulty < Torment (4))
	var ach_pts: int = AchievementSystem.get_total_achievement_points()
	if ach_pts >= 3000 and selected_difficulty < 4:
		var secret_roll: Dictionary = SecretHeroManager.roll_secret_hero_activation(ach_pts, selected_difficulty)
		if secret_roll.get("activated", false) and secret_roll.get("hero_data") != null:
			final_hero = secret_roll["hero_data"]
			achievements_enabled = false

	if final_hero == null:
		if is_random_selected:
			final_hero = HeroSelector.select_hero_random()
		else:
			var allow_secret: bool = (selected_mode_id == &"debug")
			final_hero = HeroSelector.select_hero_manual(selected_archetype_id, allow_secret)
			if final_hero == null:
				# If user clicked a secret hero without debug, fall back to random roll with bonus
				final_hero = HeroSelector.select_hero_random()
				is_random_selected = true

	if final_hero == null:
		final_hero = HeroSelector.select_hero_manual(&"raynor")

	var sess = Engine.get_singleton("GameSession") if Engine.has_singleton("GameSession") else null
	if not sess and is_inside_tree() and get_tree() and get_tree().root.has_node("GameSession"):
		sess = get_tree().root.get_node("GameSession")
	if sess:
		sess.set_meta("achievements_enabled", achievements_enabled)

	deployment_confirmed.emit(final_hero, selected_difficulty, is_random_selected)
	visible = false
	queue_free()
