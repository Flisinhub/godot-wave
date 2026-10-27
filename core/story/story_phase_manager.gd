class_name StoryPhaseManager
extends RefCounted

## StoryPhaseManager - SFE5 Match Narrative Progression (Tasks 9.1 - 9.5).
## Tracks story phases: Zerg -> Protoss 1 -> Protoss 2 (Xel'Naga) -> Pinnacle Bosses.
## Governs triggers, Xel'Naga crystal harmonization, and environmental lighting presets.

signal phase_changed(old_phase: int, new_phase: int, phase_title: String, announcement: String)
signal xelnaga_crystal_harmonized(crystal_index: int, total_harmonized: int)
signal pinnacle_bosses_ready()

enum StoryPhase {
	ZERG = 0,
	PROTOSS_1 = 1,
	PROTOSS_2 = 2,
	PINNACLE_BOSSES = 3
}

var current_phase: StoryPhase = StoryPhase.ZERG
var zerg_spawners_cleared: int = 0
var zerg_spawners_goal: int = 6

var protoss_spawners_cleared: int = 0
var protoss_spawners_goal: int = 4

var xelnaga_crystals_harmonized: int = 0
var total_xelnaga_crystals: int = 3
var pinnacle_bosses_unlocked: bool = false


func _init(z_goal: int = 6, p_goal: int = 4) -> void:
	zerg_spawners_goal = z_goal
	protoss_spawners_goal = p_goal
	current_phase = StoryPhase.ZERG


## Reports a spawner destruction and triggers story progression when thresholds are met.
func report_spawner_cleared(race_or_family: StringName = &"zerg") -> void:
	match current_phase:
		StoryPhase.ZERG:
			zerg_spawners_cleared += 1
			if zerg_spawners_cleared >= zerg_spawners_goal:
				advance_to_phase(StoryPhase.PROTOSS_1)
		StoryPhase.PROTOSS_1:
			protoss_spawners_cleared += 1
			if protoss_spawners_cleared >= protoss_spawners_goal:
				advance_to_phase(StoryPhase.PROTOSS_2)


## Advances game story to a designated phase.
func advance_to_phase(target_phase: StoryPhase) -> void:
	if target_phase <= current_phase:
		return

	var old: StoryPhase = current_phase
	current_phase = target_phase
	var title: String = get_phase_title(current_phase)
	var announcement: String = get_phase_announcement(current_phase)

	phase_changed.emit(old, current_phase, title, announcement)


## Harmonizes a Xel'Naga crystal during Protoss Phase 2 (Task 9.4).
func harmonize_xelnaga_crystal(crystal_idx: int) -> bool:
	if current_phase != StoryPhase.PROTOSS_2:
		return false

	xelnaga_crystals_harmonized = mini(xelnaga_crystals_harmonized + 1, total_xelnaga_crystals)
	xelnaga_crystal_harmonized.emit(crystal_idx, xelnaga_crystals_harmonized)

	if xelnaga_crystals_harmonized >= total_xelnaga_crystals:
		pinnacle_bosses_unlocked = true
		advance_to_phase(StoryPhase.PINNACLE_BOSSES)
		pinnacle_bosses_ready.emit()
		return true

	return false


func get_phase_title(phase: StoryPhase = current_phase) -> String:
	match phase:
		StoryPhase.ZERG:
			return "FASE ZERG: ASALTO INICIAL"
		StoryPhase.PROTOSS_1:
			return "FASE PROTOSS 1: DESPERTAR TEMPLARIO"
		StoryPhase.PROTOSS_2:
			return "FASE PROTOSS 2: CRISTALES XEL'NAGA"
		StoryPhase.PINNACLE_BOSSES:
			return "FASE CÚSPIDE: DESAFÍO DE LOS ANTIGUOS"
	return "FASE DESCONOCIDA"


func get_phase_header_status() -> String:
	match current_phase:
		StoryPhase.ZERG:
			return "FASE 1/4: ZERG (Nidos: %d/%d)" % [zerg_spawners_cleared, zerg_spawners_goal]
		StoryPhase.PROTOSS_1:
			return "FASE 2/4: PROTOSS (Portales: %d/%d)" % [protoss_spawners_cleared, protoss_spawners_goal]
		StoryPhase.PROTOSS_2:
			return "FASE 3/4: CRISTALES XEL'NAGA (%d/%d)" % [xelnaga_crystals_harmonized, total_xelnaga_crystals]
		StoryPhase.PINNACLE_BOSSES:
			return "FASE 4/4: JEFE CÚSPIDE"
	return "FASE 1/4: ZERG"


func get_phase_announcement(phase: StoryPhase = current_phase) -> String:
	match phase:
		StoryPhase.ZERG:
			return "Destruye los nidos del Enjambre para contener la infestación."
		StoryPhase.PROTOSS_1:
			return "¡Red de distorsión Protoss activada! Los cráteres subterráneos Nydus se abren."
		StoryPhase.PROTOSS_2:
			return "¡Cristales Xel'Naga localizados! Armoniza los 3 monolitos psiónicos."
		StoryPhase.PINNACLE_BOSSES:
			return "¡Portal Cúspide desbloqueado! Los Jefes de los Antiguos aguardan tu invocación."
	return ""


## Returns the environment ambient light tint for each phase (Task 9.5).
func get_ambient_lighting_color(phase: StoryPhase = current_phase) -> Color:
	match phase:
		StoryPhase.ZERG:
			return Color(0.85, 0.45, 0.35, 1.0) # Amber Creep
		StoryPhase.PROTOSS_1:
			return Color(0.35, 0.65, 0.95, 1.0) # Aiur Psionic Blue
		StoryPhase.PROTOSS_2:
			return Color(0.45, 0.85, 0.55, 1.0) # Xel'Naga Emerald
		StoryPhase.PINNACLE_BOSSES:
			return Color(0.9, 0.25, 0.3, 1.0)  # Abyssal Crimson
	return Color.WHITE
