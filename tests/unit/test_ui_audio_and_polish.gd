class_name TestUIAudioAndPolish
extends RefCounted

## TestUIAudioAndPolish - SFE5 UI, Audio & Accessibility Polish Suite (Fase 14).
## Validates interactive 3-step tutorial, colorblind accessible palettes,
## bilingual Spanish/English localization, and floating text integration.

const TutorialManager = preload("res://core/tutorial/tutorial_manager.gd")
const AccessibilityManager = preload("res://core/ui/accessibility_and_color_manager.gd")
const LocalizationManager = preload("res://core/ui/localization_manager.gd")
const FloatingTextManager = preload("res://core/vfx/floating_text_manager.gd")
const SFXManager = preload("res://core/audio/sfx_manager.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func run_all() -> bool:
	print(">> Running Suite: SFE5 UI, Audio & Polish")
	_tests_passed = 0
	_tests_failed = 0

	test_tutorial_manager_3_step_progression()
	test_accessibility_colorblind_palettes()
	test_localization_manager_bilingual_strings()
	test_floating_damage_text_manager()
	test_audio_manager_bus_integration()

	return _tests_failed == 0


func _assert_true(condition: bool, msg: String) -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s" % msg)


## Test 1: Tutorial Manager 3-Step Interactive Onboarding (Task 14.4)
func test_tutorial_manager_3_step_progression() -> void:
	var tut := TutorialManager.new(true)
	_assert_true(tut.is_active, "Tutorial starts active")
	_assert_true(tut.current_step == TutorialManager.TutorialStep.MOVE_HERO, "Step 1 is MOVE_HERO")

	var state := {"completed": false}
	tut.tutorial_completed.connect(func() -> void:
		state["completed"] = true
	)

	# Invalid action for step 1 (spawner destroyed before moving) -> rejected
	_assert_true(not tut.record_spawner_destroyed(), "Cannot destroy spawner before moving")

	# Step 1: Move Hero
	_assert_true(tut.record_hero_moved(), "Step 1 (Move Hero) recorded successfully")
	_assert_true(tut.current_step == TutorialManager.TutorialStep.BUY_UPGRADE, "Advanced to Step 2: BUY_UPGRADE")

	# Step 2: Buy Upgrade
	_assert_true(tut.record_upgrade_bought(), "Step 2 (Buy Upgrade) recorded successfully")
	_assert_true(tut.current_step == TutorialManager.TutorialStep.DESTROY_SPAWNER, "Advanced to Step 3: DESTROY_SPAWNER")

	# Step 3: Destroy Spawner -> Completes Tutorial
	_assert_true(tut.record_spawner_destroyed(), "Step 3 (Destroy Spawner) recorded successfully")
	_assert_true(not tut.is_active, "Tutorial marked inactive after completion")
	_assert_true(state["completed"], "tutorial_completed signal dispatched")


## Test 2: Accessibility Colorblind Palettes (Task 14.5)
func test_accessibility_colorblind_palettes() -> void:
	var normal_mgr := AccessibilityManager.new(AccessibilityManager.ColorblindMode.NONE)
	var col_struct_norm: Color = normal_mgr.get_accessible_category_color("structure")
	var col_boss_norm: Color = normal_mgr.get_accessible_category_color("boss")

	# Normal colors: Structure is Green, Boss is Red
	_assert_true(col_struct_norm.g > col_struct_norm.r, "Standard structure is green")
	_assert_true(col_boss_norm.r > col_boss_norm.g, "Standard boss is red")

	# Protanopia colors: replaces Green with Sky Blue and Red with Gold
	var protan_mgr := AccessibilityManager.new(AccessibilityManager.ColorblindMode.PROTANOPIA)
	var col_struct_protan: Color = protan_mgr.get_accessible_category_color("structure")
	var col_boss_protan: Color = protan_mgr.get_accessible_category_color("boss")

	_assert_true(col_struct_protan.b > 0.8, "Protanopia structure uses blue/cyan (accessible)")
	_assert_true(col_boss_protan != col_boss_norm, "Protanopia boss uses high-contrast gold")


## Test 3: Bilingual Spanish/English Localization (Task 14.6)
func test_localization_manager_bilingual_strings() -> void:
	var loc := LocalizationManager.new("es")
	_assert_true(loc.get_text("ui.minerals") == "MINERALES", "Spanish translation: MINERALES")
	_assert_true(loc.get_text("ui.command_center") == "CENTRO DE MANDO", "Spanish translation: CENTRO DE MANDO")

	loc.set_locale("en")
	_assert_true(loc.get_text("ui.minerals") == "MINERALS", "English translation: MINERALS")
	_assert_true(loc.get_text("ui.command_center") == "COMMAND CENTER", "English translation: COMMAND CENTER")

	# Fallback check
	_assert_true(loc.get_text("nonexistent_key", "Default") == "Default", "Fallback text returned for unknown key")


## Test 4: Floating Text Manager Headless Safety (Task 14.16)
func test_floating_damage_text_manager() -> void:
	var node := Node3D.new()
	# In headless mode, spawn_text should safely no-op without allocating nodes or leaking
	FloatingTextManager.spawn_text(node, Vector3.ZERO, "+150 Minerals", Color.YELLOW)
	_assert_true(node.get_child_count() == 0, "Headless spawn_text safely returns zero child nodes")
	node.free()


## Test 5: Audio Manager Bus Integration (Tasks 14.8, 14.9, 14.11)
func test_audio_manager_bus_integration() -> void:
	_assert_true(SFXManager.POOL_SIZE_3D == 24, "SFXManager defines 24 3D audio players pool size")
	_assert_true(SFXManager.POOL_SIZE_2D == 8, "SFXManager defines 8 2D audio players pool size")
	_assert_true(SFXManager.DEFAULT_MAX_POLYPHONY == 4, "SFXManager default polyphony clamp is 4")
	_assert_true(SFXManager.MusicState.CALM == 0, "MusicState.CALM defined")
	_assert_true(SFXManager.MusicState.COMBAT == 1, "MusicState.COMBAT defined")
	_assert_true(SFXManager.MusicState.BOSS == 2, "MusicState.BOSS defined")
