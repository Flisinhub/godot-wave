extends "res://tests/test_base.gd"

## SFE5 Phase 3 E2E Test Suite — Heroes Catalog, VisualRoot & 3D VFX
## Covers Requirements R1, R2, R4:
## 14 comprehensive tests covering all 7 heroes: Raynor, Tychus, Nova, Zeratul, Tassadar, Stetmann, Harbinger.
## Verifies node instantiation under VisualRoot, base & derived stats, skill casting, and headless VFX safety.

const HeroDataScript := preload("res://core/heroes/hero_data.gd")
const HeroUnit3DScript := preload("res://entities/allies/hero_unit_3d.gd")
const HeroSkillDataScript := preload("res://data/skills/hero_skill_data.gd")
const SFECombatEngine := preload("res://core/combat/sfe_combat_engine.gd")

const RAYNOR_PATH := "res://data/heroes/raynor.tres"
const TYCHUS_PATH := "res://data/heroes/tychus.tres"
const NOVA_PATH := "res://data/heroes/nova.tres"
const ZERATUL_PATH := "res://data/heroes/zeratul.tres"
const TASSADAR_PATH := "res://data/heroes/tassadar.tres"
const MEDIC_PATH := "res://data/heroes/medic.tres"
const HARBINGER_PATH := "res://data/heroes/secret_harbinger.tres"


func _setup_visual_tree(hero: HeroUnit3D) -> Node3D:
	var vr := Node3D.new()
	vr.name = "VisualRoot"
	hero.add_child(vr)
	hero.visual_root = vr

	var bm := MeshInstance3D.new()
	bm.name = "BodyMesh"
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.8, 0.8)
	bm.mesh = box
	vr.add_child(bm)
	hero.body_mesh = bm

	return vr


# ==============================================================================
# HERO 1: Jim Raynor (Marine Commander)
# ==============================================================================
func test_hero_raynor_instantiation_and_stats() -> Dictionary:
	if not ResourceLoader.exists(RAYNOR_PATH):
		return skip_test("Raynor hero resource not found")

	var raynor_data = load(RAYNOR_PATH)
	if not assert_not_null(raynor_data, "Raynor data must load"):
		return get_last_failure()
	if not assert_eq(raynor_data.archetype_id, &"raynor", "Raynor archetype_id must be &\"raynor\""):
		return get_last_failure()
	if not assert_eq(raynor_data.hero_name, "Jim Raynor", "Raynor name"):
		return get_last_failure()
	if not assert_eq(raynor_data.is_secret, false, "Raynor is not secret"):
		return get_last_failure()

	var hero = HeroUnit3DScript.new()
	hero.hero_data = raynor_data
	hero._bind_hero_data()

	# Base attribute checks
	if not assert_eq(raynor_data.strength, 12, "Raynor base STR"):
		hero.free()
		return get_last_failure()
	if not assert_eq(raynor_data.dexterity, 10, "Raynor base DEX"):
		hero.free()
		return get_last_failure()
	if not assert_eq(raynor_data.intelligence, 8, "Raynor base INT"):
		hero.free()
		return get_last_failure()

	# Derived stats: HP = 550 + 12 * 20 = 790.0, Damage = 28 + 12 * 1.5 = 46.0
	if not assert_almost_eq(hero.max_health, 790.0, 0.1, "Raynor Level 1 Max HP"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_damage, 46.0, 0.1, "Raynor Level 1 Damage"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.move_speed, 5.2, 0.1, "Raynor Move Speed"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_range, 8.5, 0.1, "Raynor Attack Range"):
		hero.free()
		return get_last_failure()

	# Derived attributes in HeroData
	if not assert_almost_eq(raynor_data.max_energy, 200.0, 0.1, "Raynor Level 1 Max Energy"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(raynor_data.hp_regen, 2.5, 0.1, "Raynor Level 1 HP Regen"):
		hero.free()
		return get_last_failure()

	hero.free()
	return pass_test()


func test_hero_raynor_abilities_and_vfx() -> Dictionary:
	if not ResourceLoader.exists(RAYNOR_PATH):
		return skip_test("Raynor hero resource not found")

	var raynor_data = load(RAYNOR_PATH)
	var hero = HeroUnit3DScript.new()
	hero.hero_data = raynor_data
	hero._bind_hero_data()

	# Verify skills presence: slot 0 Stimpack, slot 1 Penetrating Round
	if not assert_ge(raynor_data.skills.size(), 2, "Raynor must have at least 2 skills"):
		hero.free()
		return get_last_failure()

	# Stimpack casting test
	hero.current_health = 100.0
	var cast_stim: bool = hero.activate_skill(0)
	if not assert_true(cast_stim, "Stimpack must cast successfully when HP > 10"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.current_health, 90.0, 0.1, "Stimpack consumes exactly 10 HP"):
		hero.free()
		return get_last_failure()
	if not assert_true(hero.buff_engine.has_buff(&"stimpack"), "Stimpack buff must be active"):
		hero.free()
		return get_last_failure()

	# Stimpack low-health guard
	hero.current_health = 8.0
	hero.skill_cooldowns.clear()
	var low_hp_stim: bool = hero.activate_skill(0)
	if not assert_false(low_hp_stim, "Stimpack must fail if HP <= 10 to prevent death"):
		hero.free()
		return get_last_failure()

	# Penetrating round casting test
	hero.skill_cooldowns.clear()
	hero.hero_data.current_energy = 100.0
	var cast_pen: bool = hero.activate_skill(1, Vector3(0, 0, 10))
	if not assert_true(cast_pen, "Penetrating Round must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 65.0, 0.1, "Penetrating Round consumes 35 energy"):
		hero.free()
		return get_last_failure()

	# Headless VFX safety check
	hero._spawn_stimpack_vfx()

	hero.free()
	return pass_test()


# ==============================================================================
# HERO 2: Tychus Findlay (Heavy Commando)
# ==============================================================================
func test_hero_tychus_instantiation_and_stats() -> Dictionary:
	if not ResourceLoader.exists(TYCHUS_PATH):
		return skip_test("Tychus hero resource not found")

	var tychus_data = load(TYCHUS_PATH)
	if not assert_not_null(tychus_data, "Tychus data must load"):
		return get_last_failure()
	if not assert_eq(tychus_data.archetype_id, &"tychus", "Tychus archetype_id"):
		return get_last_failure()
	if not assert_eq(tychus_data.hero_name, "Tychus Findlay", "Tychus name"):
		return get_last_failure()

	var hero = HeroUnit3DScript.new()
	hero.hero_data = tychus_data
	hero._bind_hero_data()

	# Stats: STR: 16, DEX: 8, INT: 6
	# Derived: HP = 720 + 16 * 20 = 1040.0, Damage = 24 + 16 * 1.5 = 48.0, Armor = 3.0
	if not assert_almost_eq(hero.max_health, 1040.0, 0.1, "Tychus Level 1 Max HP (1040.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_damage, 48.0, 0.1, "Tychus Level 1 Damage (48.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.flat_armor, 3.0, 0.1, "Tychus Flat Armor (3.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.hp_regen, 2.7, 0.1, "Tychus HP Regen (2.7)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.max_energy, 170.0, 0.1, "Tychus Max Energy (170.0)"):
		hero.free()
		return get_last_failure()

	hero.free()
	return pass_test()


func test_hero_tychus_overkill_and_grenade_vfx() -> Dictionary:
	if not ResourceLoader.exists(TYCHUS_PATH):
		return skip_test("Tychus hero resource not found")

	var tychus_data = load(TYCHUS_PATH)
	var hero = HeroUnit3DScript.new()
	hero.hero_data = tychus_data
	hero._bind_hero_data()

	# Overkill (slot 0)
	hero.hero_data.current_energy = 100.0
	var cast_overkill: bool = hero.activate_skill(0)
	if not assert_true(cast_overkill, "Overkill must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 70.0, 0.1, "Overkill costs 30 energy"):
		hero.free()
		return get_last_failure()
	if not assert_true(hero.buff_engine.has_buff(&"frenzy"), "Frenzy buff applied by Overkill"):
		hero.free()
		return get_last_failure()

	# Shredder Grenade (slot 1)
	hero.skill_cooldowns.clear()
	var cast_grenade: bool = hero.activate_skill(1, Vector3(4.0, 0.0, 0.0))
	if not assert_true(cast_grenade, "Shredder Grenade must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 35.0, 0.1, "Grenade costs 35 energy (leaves 35)"):
		hero.free()
		return get_last_failure()

	# Test Minigun Frenzy stack extension up to 20
	hero.buff_engine.apply_buff(&"tychus_passive", 4.0, 20)
	for i in range(25):
		hero.buff_engine.apply_buff(&"tychus_passive", 4.0, 20)
	var stacks: int = hero.buff_engine.get_stacks(&"tychus_passive")
	if not assert_le(stacks, 20, "Tychus passive stacks must clamp at 20"):
		hero.free()
		return get_last_failure()

	# Headless VFX safety
	hero._spawn_grenade_explosion_vfx(Vector3.ZERO, 4.5)

	hero.free()
	return pass_test()


# ==============================================================================
# HERO 3: Nova Terra (Ghost Operative)
# ==============================================================================
func test_hero_nova_instantiation_and_stats() -> Dictionary:
	if not ResourceLoader.exists(NOVA_PATH):
		return skip_test("Nova hero resource not found")

	var nova_data = load(NOVA_PATH)
	if not assert_not_null(nova_data, "Nova data must load"):
		return get_last_failure()
	if not assert_eq(nova_data.archetype_id, &"nova", "Nova archetype_id"):
		return get_last_failure()

	var hero = HeroUnit3DScript.new()
	hero.hero_data = nova_data
	hero._bind_hero_data()

	# Base: STR: 8, DEX: 12, INT: 16
	# Derived: HP = 420 + 8 * 20 = 580.0, Damage = 45 + 8 * 1.5 = 57.0, Energy = 200 + 16 * 10 = 360.0
	# Attack range = 14.0, Vision = 18 + 16 * 0.2 = 21.2
	if not assert_almost_eq(hero.max_health, 580.0, 0.1, "Nova Max HP (580.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_damage, 57.0, 0.1, "Nova Damage (57.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_range, 14.0, 0.1, "Nova Attack Range (14.0m sniper reach)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(nova_data.max_energy, 360.0, 0.1, "Nova Max Energy (360.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(nova_data.vision_radius, 21.2, 0.1, "Nova Vision Radius (21.2m)"):
		hero.free()
		return get_last_failure()

	hero.free()
	return pass_test()


func test_hero_nova_snipe_and_cloak_vfx() -> Dictionary:
	if not ResourceLoader.exists(NOVA_PATH):
		return skip_test("Nova hero resource not found")

	var nova_data = load(NOVA_PATH)
	var hero = HeroUnit3DScript.new()
	hero.hero_data = nova_data
	hero._bind_hero_data()

	# Snipe (slot 0)
	hero.hero_data.current_energy = 200.0
	var cast_snipe: bool = hero.activate_skill(0)
	if not assert_true(cast_snipe, "Snipe must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 150.0, 0.1, "Snipe costs 50 energy"):
		hero.free()
		return get_last_failure()

	# Verify Snipe bypasses flat armor mathematically
	var snipe_calc = SFECombatEngine.calculate_damage(
		250.0,
		SFECombatEngine.DamageType.SPELL,
		12.0, # Target with heavy 12 flat armor
		0,
		SFECombatEngine.StructureType.NONE,
		false,
		false,
		false,
		0.0,
		500.0
	)
	if not assert_almost_eq(snipe_calc.damage_dealt, 250.0, 0.01, "Snipe pure spell damage must bypass flat armor"):
		hero.free()
		return get_last_failure()

	# Tactical Cloak (slot 1)
	hero.skill_cooldowns.clear()
	var cast_cloak: bool = hero.activate_skill(1)
	if not assert_true(cast_cloak, "Tactical Cloak must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 125.0, 0.1, "Cloak costs 25 energy"):
		hero.free()
		return get_last_failure()
	if not assert_true(hero.buff_engine.has_buff(&"cloak"), "Cloak buff active"):
		hero.free()
		return get_last_failure()

	hero.free()
	return pass_test()


# ==============================================================================
# HERO 4: Zeratul (Dark Templar Prelate)
# ==============================================================================
func test_hero_zeratul_instantiation_and_stats() -> Dictionary:
	if not ResourceLoader.exists(ZERATUL_PATH):
		return skip_test("Zeratul hero resource not found")

	var zeratul_data = load(ZERATUL_PATH)
	if not assert_not_null(zeratul_data, "Zeratul data must load"):
		return get_last_failure()
	if not assert_eq(zeratul_data.archetype_id, &"zeratul", "Zeratul archetype_id"):
		return get_last_failure()

	var hero = HeroUnit3DScript.new()
	hero.hero_data = zeratul_data
	hero._bind_hero_data()

	# Base: STR: 14, DEX: 18, INT: 12, Shield: 250.0, Armor: 2.0
	# Derived: HP = 480 + 14 * 20 = 760.0, Damage = 52 + 14 * 1.5 = 73.0, Shield = 250.0
	if not assert_almost_eq(hero.max_health, 760.0, 0.1, "Zeratul Max HP (760.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_damage, 73.0, 0.1, "Zeratul Damage (73.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(zeratul_data.max_shield, 250.0, 0.1, "Zeratul Base Plasma Shield (250.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_range, 2.2, 0.1, "Zeratul Melee Range (2.2m)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.move_speed, 5.6, 0.1, "Zeratul Fast Mobility (5.6 m/s)"):
		hero.free()
		return get_last_failure()

	hero.free()
	return pass_test()


func test_hero_zeratul_blink_and_cleave_vfx() -> Dictionary:
	if not ResourceLoader.exists(ZERATUL_PATH):
		return skip_test("Zeratul hero resource not found")

	var zeratul_data = load(ZERATUL_PATH)
	var hero = HeroUnit3DScript.new()
	hero.hero_data = zeratul_data
	hero._bind_hero_data()
	hero.position = Vector3(0, 0, 0)

	# Blink (slot 0)
	hero.hero_data.current_energy = 150.0
	var dest := Vector3(0, 0, 7.0)
	var cast_blink: bool = hero.activate_skill(0, dest)
	if not assert_true(cast_blink, "Blink must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 125.0, 0.1, "Blink costs 25 energy"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.position.distance_to(Vector3.ZERO), 7.0, 0.1, "Blink teleports unit to destination"):
		hero.free()
		return get_last_failure()

	# Shadow Cleave (slot 1)
	hero.skill_cooldowns.clear()
	var cast_cleave: bool = hero.activate_skill(1)
	if not assert_true(cast_cleave, "Shadow Cleave must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 95.0, 0.1, "Shadow Cleave costs 30 energy"):
		hero.free()
		return get_last_failure()

	# Headless VFX safety
	hero._spawn_blink_vfx(Vector3.ZERO, Vector3(0, 0, 8))
	hero._spawn_shadow_cleave_vfx(Vector3.ZERO, 3.2)

	hero.free()
	return pass_test()


# ==============================================================================
# HERO 5: Tassadar (High Templar)
# ==============================================================================
func test_hero_tassadar_instantiation_and_stats() -> Dictionary:
	if not ResourceLoader.exists(TASSADAR_PATH):
		return skip_test("Tassadar hero resource not found")

	var tassadar_data = load(TASSADAR_PATH)
	if not assert_not_null(tassadar_data, "Tassadar data must load"):
		return get_last_failure()
	if not assert_eq(tassadar_data.archetype_id, &"tassadar", "Tassadar archetype_id"):
		return get_last_failure()

	var hero = HeroUnit3DScript.new()
	hero.hero_data = tassadar_data
	hero._bind_hero_data()

	# Base: STR: 10, DEX: 10, INT: 20, Shield: 300.0, Energy: 220.0
	# Derived: HP = 420 + 10 * 20 = 620.0, Damage = 32 + 10 * 1.5 = 47.0, Energy = 220 + 20 * 10 = 420.0
	if not assert_almost_eq(hero.max_health, 620.0, 0.1, "Tassadar Max HP (620.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_damage, 47.0, 0.1, "Tassadar Damage (47.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(tassadar_data.max_shield, 300.0, 0.1, "Tassadar Base Shield (300.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(tassadar_data.max_energy, 420.0, 0.1, "Tassadar Max Energy (420.0)"):
		hero.free()
		return get_last_failure()

	hero.free()
	return pass_test()


func test_hero_tassadar_storm_and_shield_vfx() -> Dictionary:
	if not ResourceLoader.exists(TASSADAR_PATH):
		return skip_test("Tassadar hero resource not found")

	var tassadar_data = load(TASSADAR_PATH)
	var hero = HeroUnit3DScript.new()
	hero.hero_data = tassadar_data
	hero._bind_hero_data()

	# Psionic Storm (slot 0)
	hero.hero_data.current_energy = 200.0
	var cast_storm: bool = hero.activate_skill(0, Vector3(6.0, 0.0, 0.0))
	if not assert_true(cast_storm, "Psionic Storm must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 150.0, 0.1, "Psionic Storm costs 50 energy"):
		hero.free()
		return get_last_failure()

	# Plasma Shield (slot 1)
	hero.skill_cooldowns.clear()
	hero.hero_data.current_shield = 100.0
	var cast_shield: bool = hero.activate_skill(1)
	if not assert_true(cast_shield, "Plasma Shield must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 115.0, 0.1, "Plasma Shield costs 35 energy"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_shield, 250.0, 0.1, "Plasma Shield restores 150 shield points"):
		hero.free()
		return get_last_failure()

	# Headless VFX safety
	hero._spawn_psionic_storm_vfx(Vector3.ZERO, 5.2)
	hero._spawn_shield_bubble_vfx()

	hero.free()
	return pass_test()


# ==============================================================================
# HERO 6: Egon Stetmann (Medic)
# ==============================================================================
func test_hero_medic_stetmann_instantiation_and_stats() -> Dictionary:
	if not ResourceLoader.exists(MEDIC_PATH):
		return skip_test("Medic hero resource not found")

	var medic_data = load(MEDIC_PATH)
	if not assert_not_null(medic_data, "Medic data must load"):
		return get_last_failure()
	if not assert_eq(medic_data.archetype_id, &"medic", "Medic archetype_id"):
		return get_last_failure()

	var hero = HeroUnit3DScript.new()
	hero.hero_data = medic_data
	hero._bind_hero_data()

	# Base: STR: 11, DEX: 11, INT: 16, Flat Armor: 2.0
	# Derived: HP = 460 + 11 * 20 = 680.0, Damage = 18 + 11 * 1.5 = 34.5, Energy = 200 + 16 * 10 = 360.0
	if not assert_almost_eq(hero.max_health, 680.0, 0.1, "Medic Max HP (680.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_damage, 34.5, 0.1, "Medic Damage (34.5)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(medic_data.max_energy, 360.0, 0.1, "Medic Max Energy (360.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(medic_data.hp_regen, 3.65, 0.1, "Medic HP Regen (3.65 HP/s)"):
		hero.free()
		return get_last_failure()

	hero.free()
	return pass_test()


func test_hero_medic_heal_beam_and_matrix_vfx() -> Dictionary:
	if not ResourceLoader.exists(MEDIC_PATH):
		return skip_test("Medic hero resource not found")

	var medic_data = load(MEDIC_PATH)
	var hero = HeroUnit3DScript.new()
	hero.hero_data = medic_data
	hero._bind_hero_data()

	# Heal Beam (slot 0) specification contract
	var heal_skill: HeroSkillData = medic_data.skills[0] as HeroSkillData
	if not assert_not_null(heal_skill, "Medic slot 0 must be heal_skill"):
		hero.free()
		return get_last_failure()
	if not assert_eq(heal_skill.skill_id, &"heal_beam", "Skill ID must be heal_beam"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(heal_skill.base_power, 120.0, 0.1, "Heal Beam base power is 120.0 HP"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(heal_skill.energy_cost, 20.0, 0.1, "Heal Beam energy cost is 20.0"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(heal_skill.cooldown, 3.0, 0.1, "Heal Beam cooldown is 3.0s"):
		hero.free()
		return get_last_failure()

	# Defensive Matrix (slot 1) live skill casting
	hero.hero_data.current_energy = 200.0
	hero.skill_cooldowns.clear()
	var cast_matrix: bool = hero.activate_skill(1)
	if not assert_true(cast_matrix, "Defensive Matrix must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 155.0, 0.1, "Defensive Matrix costs 45 energy (leaves 155)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_shield, 150.0, 0.1, "Defensive Matrix grants +150 shield points"):
		hero.free()
		return get_last_failure()

	# Headless VFX safety
	hero._spawn_heal_beam_vfx(Vector3.ZERO, Vector3(0, 1, 5))
	hero._spawn_shield_bubble_vfx()

	if hero.get_parent():
		hero.get_parent().remove_child(hero)
	hero.free()
	return pass_test()


# ==============================================================================
# HERO 7: Xel'Naga Harbinger (Secret Hero)
# ==============================================================================
func test_hero_harbinger_secret_archetype_and_stats() -> Dictionary:
	if not ResourceLoader.exists(HARBINGER_PATH):
		return skip_test("Harbinger hero resource not found")

	var harbinger_data = load(HARBINGER_PATH)
	if not assert_not_null(harbinger_data, "Harbinger data must load"):
		return get_last_failure()
	if not assert_eq(harbinger_data.archetype_id, &"harbinger", "Harbinger archetype_id"):
		return get_last_failure()
	if not assert_eq(harbinger_data.is_secret, true, "Harbinger is_secret must be true (1% RNG)"):
		return get_last_failure()

	var hero = HeroUnit3DScript.new()
	hero.hero_data = harbinger_data
	hero._bind_hero_data()

	# Base: STR: 18, DEX: 18, INT: 22, Armor: 4.0, Shield: 200.0
	# Derived: HP = 850 + 18 * 20 = 1210.0, Damage = 55 + 18 * 1.5 = 82.0, Energy = 300 + 22 * 10 = 520.0
	# Vision = 22 + 22 * 0.2 = 26.4
	if not assert_almost_eq(hero.max_health, 1210.0, 0.1, "Harbinger Max HP (1210.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.attack_damage, 82.0, 0.1, "Harbinger Damage (82.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(harbinger_data.max_shield, 200.0, 0.1, "Harbinger Plasma Shield (200.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(harbinger_data.max_energy, 520.0, 0.1, "Harbinger Max Energy (520.0)"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(harbinger_data.vision_radius, 26.4, 0.1, "Harbinger Vision (26.4m)"):
		hero.free()
		return get_last_failure()

	# Skills check
	if not assert_ge(harbinger_data.skills.size(), 2, "Harbinger must have at least 2 skills"):
		hero.free()
		return get_last_failure()

	# Cast Dimensional Beam (slot 0)
	hero.hero_data.current_energy = 300.0
	var cast_beam: bool = hero.activate_skill(0)
	if not assert_true(cast_beam, "Dimensional Beam must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 240.0, 0.1, "Dimensional Beam costs 60 energy"):
		hero.free()
		return get_last_failure()

	# Cast Celestial Singularity (slot 1)
	hero.skill_cooldowns.clear()
	var cast_sing: bool = hero.activate_skill(1, Vector3(8, 0, 0))
	if not assert_true(cast_sing, "Celestial Singularity must cast successfully"):
		hero.free()
		return get_last_failure()
	if not assert_almost_eq(hero.hero_data.current_energy, 155.0, 0.1, "Celestial Singularity costs 85 energy"):
		hero.free()
		return get_last_failure()

	hero.free()
	return pass_test()


# ==============================================================================
# VISUAL ROOT & PBR MATERIALS ACROSS ALL 7 HEROES
# ==============================================================================
func test_all_heroes_visual_root_and_materials() -> Dictionary:
	var hero_paths: Dictionary = {
		&"raynor": RAYNOR_PATH,
		&"tychus": TYCHUS_PATH,
		&"nova": NOVA_PATH,
		&"zeratul": ZERATUL_PATH,
		&"tassadar": TASSADAR_PATH,
		&"medic": MEDIC_PATH,
		&"harbinger": HARBINGER_PATH
	}

	for arch_id in hero_paths.keys():
		var path: String = hero_paths[arch_id]
		if not ResourceLoader.exists(path):
			return skip_test("Hero resource missing: %s" % path)

		var h_data = load(path)
		var hero = HeroUnit3DScript.new()
		var vr: Node3D = _setup_visual_tree(hero)

		# Apply visuals
		hero.apply_archetype_visuals(h_data)

		# Verify VisualRoot encapsulation and scale
		if not assert_not_null(hero.visual_root, "Hero must maintain VisualRoot reference"):
			hero.free()
			return get_last_failure()
		if not assert_gt(vr.scale.x, 0.0, "VisualRoot scale must be positive for %s" % str(arch_id)):
			hero.free()
			return get_last_failure()

		# Verify material override on BodyMesh
		var bm: MeshInstance3D = vr.get_node_or_null("BodyMesh") as MeshInstance3D
		if not assert_not_null(bm, "BodyMesh must be present under VisualRoot"):
			hero.free()
			return get_last_failure()

		var mat: Material = bm.material_override
		if not assert_true(mat is StandardMaterial3D, "BodyMesh material must be StandardMaterial3D"):
			hero.free()
			return get_last_failure()

		# Verify emission on energy-bearing archetypes
		if arch_id in [&"nova", &"zeratul", &"tassadar", &"medic", &"harbinger"]:
			var std_mat: StandardMaterial3D = mat as StandardMaterial3D
			if not assert_true(std_mat.emission_enabled, "Archetype %s must have emission enabled" % str(arch_id)):
				hero.free()
				return get_last_failure()

		hero.free()

	return pass_test()
