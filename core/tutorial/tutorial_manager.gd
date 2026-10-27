class_name TutorialManager
extends RefCounted

## TutorialManager - SFE5 Interactive Onboarding System (Task 14.4).
## Guides new operators through 3 foundational steps:
## Step 1: Mover al Héroe (Click derecho en el terreno).
## Step 2: Mejorar Atributos (Abrir consola Alt+C o Armería para potenciar stats).
## Step 3: Destruir el Primer Nido Zerg (Asaltar y purgar un engendrador).

signal step_advanced(step_index: int, total_steps: int, instruction: String)
signal tutorial_completed()

enum TutorialStep {
	MOVE_HERO = 0,
	BUY_UPGRADE = 1,
	DESTROY_SPAWNER = 2,
	COMPLETED = 3
}

const TOTAL_STEPS: int = 3

const STEP_INSTRUCTIONS: Array[String] = [
	"Paso 1: Haz clic derecho en el terreno para ordenar a tu héroe que se mueva.",
	"Paso 2: Abre la Consola (Alt+C) o la Armería para comprar una mejora de atributos con tus minerales.",
	"Paso 3: Localiza el primer Nido Zerg en el radar y destrúyelo con tu escuadrón."
]

var current_step: TutorialStep = TutorialStep.MOVE_HERO
var is_active: bool = true


func _init(active: bool = true) -> void:
	is_active = active
	current_step = TutorialStep.MOVE_HERO


func get_current_instruction() -> String:
	if current_step >= TutorialStep.COMPLETED:
		return "¡Tutorial completado con éxito! Estás listo para la batalla."
	return STEP_INSTRUCTIONS[current_step]


func record_hero_moved() -> bool:
	if not is_active or current_step != TutorialStep.MOVE_HERO:
		return false
	return _advance_step()


func record_upgrade_bought() -> bool:
	if not is_active or current_step != TutorialStep.BUY_UPGRADE:
		return false
	return _advance_step()


func record_spawner_destroyed() -> bool:
	if not is_active or current_step != TutorialStep.DESTROY_SPAWNER:
		return false
	return _advance_step()


func _advance_step() -> bool:
	current_step = (current_step + 1) as TutorialStep
	if current_step >= TutorialStep.COMPLETED:
		is_active = false
		tutorial_completed.emit()
		return true
	else:
		step_advanced.emit(current_step, TOTAL_STEPS, get_current_instruction())
		return true
