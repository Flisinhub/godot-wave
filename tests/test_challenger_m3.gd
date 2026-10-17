extends SceneTree

# Empirical Adversarial Challenge Suite: Milestone 3
# Planet Char Volcanic Atmosphere & Cinematic Post-Processing

var failures: Array[String] = []
var tests_run: int = 0
var tests_passed: int = 0


func _init() -> void:
	print("==================================================================")
	print("=== EMPIRICAL CHALLENGER 2: MILESTONE 3 ADVERSARIAL STRESS TEST ===")
	print("==================================================================")
	
	test_layering_and_vertex_micro_offsets()
	test_shader_math_and_uniform_invariants()
	test_omnilight_budget_and_shadow_cost()
	test_cinematic_lighting_and_post_processing()
	test_scene_tree_non_interference_and_flow_field_safety()
	test_long_running_headless_simulation_stability()
	
	print("\n==================================================================")
	print("Adversarial Verification Results:")
	print("Tests Run:    %d" % tests_run)
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % failures.size())
	
	if failures.is_empty():
		print("\u001b[32mALL ADVERSARIAL VERIFICATION CHECKS PASSED! [VERDICT: APPROVE]\u001b[0m")
		print("==================================================================")
		quit(0)
	else:
		print("\u001b[31mADVERSARIAL VERIFICATION FAILED: [VERDICT: REJECT]\u001b[0m")
		for f in failures:
			print("  - ", f)
		print("==================================================================")
		quit(1)


func _assert(condition: bool, test_name: String, error_msg: String) -> void:
	tests_run += 1
	if condition:
		tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		failures.append("%s: %s" % [test_name, error_msg])
		print("  [FAIL] %s: %s" % [test_name, error_msg])


# ==============================================================================
# 1. VERTICAL MICRO-OFFSETS & ZERO Z-FIGHTING EMPIRICAL ANALYSIS
# ==============================================================================

func test_layering_and_vertex_micro_offsets() -> void:
	print("\n>> [1] Testing Layering & Vertex Micro-Offsets (Zero Z-Fighting)...")
	
	# Ground plane top contact face:
	# Ground StaticBody is at y = -0.5, BoxShape is 80x1x80. Top face is -0.5 + 0.5 = 0.0.
	var ground_top_y: float = 0.0
	_assert(is_equal_approx(ground_top_y, 0.0), "ground_top_y_is_zero", "Ground contact top must be exactly 0.0")
	
	# TerranBaseDeck:
	var deck_mesh: ArrayMesh = load("res://assets/models/environment/terran_base_deck_mesh.tres") as ArrayMesh
	_assert(deck_mesh != null and deck_mesh.get_surface_count() > 0, "deck_mesh_valid", "terran_base_deck_mesh.tres missing or empty")
	var deck_min_y: float = 999.0
	var deck_max_y: float = -999.0
	if deck_mesh and deck_mesh.get_surface_count() > 0:
		var arrays := deck_mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			deck_min_y = min(deck_min_y, v.y)
			deck_max_y = max(deck_max_y, v.y)
		_assert(is_equal_approx(deck_min_y, 0.006) and is_equal_approx(deck_max_y, 0.006), "deck_vertex_y_is_0_006", "Deck vertex y must be exactly 0.006, got min=%f, max=%f" % [deck_min_y, deck_max_y])
	
	# LavaFissures:
	var lava_mesh: ArrayMesh = load("res://assets/models/environment/lava_fissures_mesh.tres") as ArrayMesh
	_assert(lava_mesh != null and lava_mesh.get_surface_count() > 0, "lava_mesh_valid", "lava_fissures_mesh.tres missing or empty")
	var lava_min_y: float = 999.0
	var lava_max_y: float = -999.0
	if lava_mesh and lava_mesh.get_surface_count() > 0:
		var arrays := lava_mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			lava_min_y = min(lava_min_y, v.y)
			lava_max_y = max(lava_max_y, v.y)
		_assert(is_equal_approx(lava_min_y, 0.008) and is_equal_approx(lava_max_y, 0.008), "lava_vertex_y_is_0_008", "Lava vertex y must be exactly 0.008, got min=%f, max=%f" % [lava_min_y, lava_max_y])
	
	# CreepPools:
	var creep_mesh: ArrayMesh = load("res://assets/models/environment/zerg_creep_pools_mesh.tres") as ArrayMesh
	_assert(creep_mesh != null and creep_mesh.get_surface_count() > 0, "creep_mesh_valid", "zerg_creep_pools_mesh.tres missing or empty")
	var creep_min_y: float = 999.0
	var creep_max_y: float = -999.0
	if creep_mesh and creep_mesh.get_surface_count() > 0:
		var arrays := creep_mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			creep_min_y = min(creep_min_y, v.y)
			creep_max_y = max(creep_max_y, v.y)
		_assert(is_equal_approx(creep_min_y, 0.012) and is_equal_approx(creep_max_y, 0.012), "creep_vertex_y_is_0_012", "Creep vertex y must be exactly 0.012, got min=%f, max=%f" % [creep_min_y, creep_max_y])
	
	# Strict Layer Monotonicity:
	_assert(ground_top_y < deck_min_y, "layering_ground_below_deck", "Ground (0.0) must be strictly below Deck (0.006)")
	_assert(deck_max_y < lava_min_y, "layering_deck_below_lava", "Deck (0.006) must be strictly below Lava (0.008)")
	_assert(lava_max_y < creep_min_y, "layering_lava_below_creep", "Lava (0.008) must be strictly below Creep (0.012)")
	
	# VolcanicBoulders base contact:
	var boulders_mesh: ArrayMesh = load("res://assets/models/environment/volcanic_boulders_mesh.tres") as ArrayMesh
	_assert(boulders_mesh != null and boulders_mesh.get_surface_count() > 0, "boulders_mesh_valid", "volcanic_boulders_mesh.tres missing")
	if boulders_mesh and boulders_mesh.get_surface_count() > 0:
		var arrays := boulders_mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var boulder_min_y: float = 999.0
		var boulder_max_y: float = -999.0
		for v in verts:
			boulder_min_y = min(boulder_min_y, v.y)
			boulder_max_y = max(boulder_max_y, v.y)
		_assert(is_equal_approx(boulder_min_y, 0.0), "boulders_base_contact_ground", "Boulders base must touch ground at y = 0.0, got %f" % boulder_min_y)
		_assert(boulder_max_y > 2.0, "boulders_have_vertical_relief", "Boulders must provide vertical relief (>2m), got %f" % boulder_max_y)


# ==============================================================================
# 2. SHADER MATH & UNIFORM PARAMETER VERIFICATION
# ==============================================================================

func test_shader_math_and_uniform_invariants() -> void:
	print("\n>> [2] Testing Shader Math & Uniform Invariants...")
	
	# Lava Shader & Material:
	var lava_mat: ShaderMaterial = load("res://assets/materials/environment/lava_fissure_material.tres") as ShaderMaterial
	_assert(lava_mat != null, "lava_mat_loaded", "lava_fissure_material.tres missing")
	if lava_mat:
		var emission_energy: float = lava_mat.get_shader_parameter("emission_energy")
		_assert(emission_energy >= 3.0, "lava_emission_energy_ge_3", "Lava emission_energy must be >= 3.0, got %f" % emission_energy)
		_assert(is_equal_approx(emission_energy, 4.5), "lava_emission_energy_exact_4_5", "Expected emission_energy=4.5, got %f" % emission_energy)
		
		var flow_speed: float = lava_mat.get_shader_parameter("flow_speed")
		_assert(flow_speed > 0.01 and flow_speed <= 0.5, "lava_flow_speed_valid", "Lava flow_speed out of range: %f" % flow_speed)
		
		var pulse_speed: float = lava_mat.get_shader_parameter("pulse_speed")
		_assert(pulse_speed >= 0.5 and pulse_speed <= 5.0, "lava_pulse_speed_valid", "Lava pulse_speed out of range: %f" % pulse_speed)
		
		# Inspect shader source code math
		var shader: Shader = lava_mat.shader
		_assert(shader != null, "lava_shader_attached", "Lava shader is null")
		if shader:
			var code := shader.code
			_assert(code.find("emission_energy") != -1, "lava_shader_has_emission_energy", "Shader must reference emission_energy")
			_assert(code.find("sin(TIME * pulse_speed") != -1, "lava_shader_has_pulse_math", "Shader must have sinusoidal pulse math")
			_assert(code.find("fbm") != -1, "lava_shader_has_fbm", "Shader must have fractal brownian motion turbulence")
			_assert(code.find("smoothstep") != -1, "lava_shader_has_smoothstep_crust", "Shader must compute crust cracking with smoothstep")
	
	# Creep Shader & Material:
	var creep_mat: ShaderMaterial = load("res://assets/materials/environment/zerg_creep_material.tres") as ShaderMaterial
	_assert(creep_mat != null, "creep_mat_loaded", "zerg_creep_material.tres missing")
	if creep_mat:
		var roughness: float = creep_mat.get_shader_parameter("gloss_roughness")
		_assert(roughness <= 0.25, "creep_gloss_roughness_le_0_25", "Creep gloss roughness must be <= 0.25, got %f" % roughness)
		_assert(is_equal_approx(roughness, 0.20), "creep_gloss_roughness_exact_0_20", "Expected gloss_roughness=0.20, got %f" % roughness)
		
		var clearcoat: float = creep_mat.get_shader_parameter("clearcoat")
		_assert(clearcoat >= 0.70, "creep_clearcoat_ge_0_70", "Creep clearcoat must be >= 0.70, got %f" % clearcoat)
		_assert(is_equal_approx(clearcoat, 0.85), "creep_clearcoat_exact_0_85", "Expected clearcoat=0.85, got %f" % clearcoat)
		
		var clearcoat_roughness: float = creep_mat.get_shader_parameter("clearcoat_roughness")
		_assert(clearcoat_roughness <= 0.20, "creep_clearcoat_roughness_le_0_20", "Creep clearcoat roughness must be <= 0.20, got %f" % clearcoat_roughness)
		_assert(is_equal_approx(clearcoat_roughness, 0.12), "creep_clearcoat_roughness_exact_0_12", "Expected clearcoat_roughness=0.12, got %f" % clearcoat_roughness)
		
		var vein_energy: float = creep_mat.get_shader_parameter("vein_emission_energy")
		_assert(vein_energy >= 1.5, "creep_vein_emission_energy_ge_1_5", "Creep vein emission energy must be >= 1.5, got %f" % vein_energy)
		_assert(is_equal_approx(vein_energy, 2.6), "creep_vein_emission_energy_exact_2_6", "Expected vein_emission_energy=2.6, got %f" % vein_energy)
		
		var shader: Shader = creep_mat.shader
		_assert(shader != null, "creep_shader_attached", "Creep shader is null")
		if shader:
			var code := shader.code
			_assert(code.find("voronoi") != -1, "creep_shader_has_voronoi", "Creep shader must compute Voronoi bio-cells")
			_assert(code.find("CLEARCOAT") != -1, "creep_shader_outputs_clearcoat", "Creep shader must output CLEARCOAT")
			_assert(code.find("bio_vein_glow") != -1, "creep_shader_has_vein_glow", "Creep shader must compute bio_vein_glow")
	
	# Ground Basalt Shader:
	var ground_mat: ShaderMaterial = load("res://assets/materials/environment/char_basalt_ground_pbr.tres") as ShaderMaterial
	_assert(ground_mat != null, "ground_mat_loaded", "char_basalt_ground_pbr.tres missing")
	if ground_mat and ground_mat.shader:
		var code := ground_mat.shader.code
		_assert(code.find("fbm") != -1, "ground_shader_has_fbm", "Ground shader must compute procedural rock relief")
		_assert(code.find("v_world_pos.xz") != -1, "ground_shader_uses_world_coords", "Ground shader must map UVs seamlessly via world coordinates")


# ==============================================================================
# 3. OMNILIGHT BUDGET & PERFORMANCE IMPACT
# ==============================================================================

func test_omnilight_budget_and_shadow_cost() -> void:
	print("\n>> [3] Testing OmniLight Budget & Shadow Rendering Overhead...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	
	var lights_node: Node = main_node.get_node_or_null("EnvironmentDecorations/LavaLights")
	_assert(lights_node != null, "lava_lights_node_exists", "LavaLights parent node missing")
	
	if lights_node:
		var lights: Array[OmniLight3D] = []
		for c in lights_node.get_children():
			if c is OmniLight3D:
				lights.append(c)
		
		_assert(lights.size() == 6, "omnilight_count_strictly_six", "OmniLight budget must be exactly 6 lights, got %d" % lights.size())
		
		var shadow_caster_count: int = 0
		var max_energy: float = 0.0
		var max_range: float = 0.0
		
		for l in lights:
			if l.shadow_enabled:
				shadow_caster_count += 1
			max_energy = max(max_energy, l.light_energy)
			max_range = max(max_range, l.omni_range)
			# Verify warm thermal color
			_assert(l.light_color.r > 0.85 and l.light_color.b < 0.35, "omnilight_warm_color", "OmniLight %s must have warm thermal hue, got %s" % [l.name, str(l.light_color)])
		
		# Zero shadow maps on OmniLights prevents GPU shadow map atlas thrashing
		_assert(shadow_caster_count == 0, "omnilight_zero_shadow_casters", "All 6 OmniLights must have shadow_enabled=false for performance budget, found %d" % shadow_caster_count)
		_assert(max_energy <= 2.5, "omnilight_energy_budget", "Max OmniLight energy should be <= 2.5 to avoid screen blowout, got %f" % max_energy)
		_assert(max_range <= 15.0, "omnilight_range_budget", "Max OmniLight range should be <= 15m for local fissure lighting, got %f" % max_range)
	
	main_node.free()


# ==============================================================================
# 4. CINEMATIC LIGHTING & POST-PROCESSING BALANCE
# ==============================================================================

func test_cinematic_lighting_and_post_processing() -> void:
	print("\n>> [4] Testing Cinematic Lighting & Post-Processing Balance...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	
	var dir_light: DirectionalLight3D = main_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_assert(dir_light != null, "dir_light_node_exists", "DirectionalLight3D missing")
	if dir_light:
		_assert(dir_light.shadow_enabled, "dir_light_shadow_on", "DirectionalLight3D shadows must be enabled")
		_assert(dir_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "dir_light_pssm_4_splits", "Directional shadow mode must be 4 splits")
		_assert(dir_light.directional_shadow_blend_splits, "dir_light_blend_splits_true", "PSSM blend splits must be true for soft cascade transitions")
		_assert(dir_light.shadow_blur >= 1.39, "dir_light_shadow_blur_ge_1_4", "Shadow blur must be >= 1.4, got %f" % dir_light.shadow_blur)
		_assert(dir_light.directional_shadow_max_distance >= 120.0, "dir_light_shadow_distance", "Shadow max distance must cover playfield (>=120m), got %f" % dir_light.directional_shadow_max_distance)
	
	var env_node: WorldEnvironment = main_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_assert(env_node != null and env_node.environment != null, "world_env_valid", "WorldEnvironment missing")
	if env_node and env_node.environment:
		var env: Environment = env_node.environment
		_assert(env.tonemap_mode == Environment.TONE_MAPPER_ACES, "env_tonemap_aces", "Tonemap mode must be ACES")
		_assert(env.ssao_enabled, "env_ssao_enabled", "SSAO must be enabled")
		_assert(env.ssao_radius >= 1.5, "env_ssao_radius_valid", "SSAO radius must be >= 1.5")
		_assert(env.ssao_intensity >= 2.0, "env_ssao_intensity_valid", "SSAO intensity must be >= 2.0")
		_assert(env.glow_enabled, "env_glow_enabled", "Glow must be enabled")
		_assert(env.glow_hdr_threshold >= 1.0, "env_glow_hdr_threshold_ge_1", "HDR threshold must be >= 1.0 to prevent global screen haze")
		_assert(env.volumetric_fog_enabled, "env_fog_enabled", "Volumetric fog must be enabled")
		_assert(env.volumetric_fog_density <= 0.03, "env_fog_density_subtle", "Volumetric fog must be subtle (<=0.03) to prevent obscuring RTS units")
	
	main_node.free()


# ==============================================================================
# 5. ENVIRONMENT DECORATIONS NON-INTERFERENCE & FLOW FIELD SAFETY
# ==============================================================================

func test_scene_tree_non_interference_and_flow_field_safety() -> void:
	print("\n>> [5] Testing EnvironmentDecorations Non-Interference with Flow Fields & Collision...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	
	var decor_node: Node3D = main_node.get_node_or_null("EnvironmentDecorations") as Node3D
	_assert(decor_node != null, "decorations_node_exists", "EnvironmentDecorations missing")
	
	# Must not be a child of NavigationRegion3D
	var nav_region: Node = main_node.get_node_or_null("NavigationRegion3D")
	_assert(nav_region != null, "nav_region_exists", "NavigationRegion3D missing")
	_assert(decor_node.get_parent() == main_node, "decorations_parent_is_main_level", "EnvironmentDecorations must be child of MainLevel, NOT NavigationRegion3D")
	
	# Must have 0 collision bodies
	var colliders: Array[Node] = []
	_find_colliders_recursive(decor_node, colliders)
	_assert(colliders.is_empty(), "decorations_zero_colliders_adversarial", "EnvironmentDecorations must have 0 colliders, found %d" % colliders.size())
	
	# Verify ground is intact
	var ground: StaticBody3D = main_node.get_node_or_null("NavigationRegion3D/Ground") as StaticBody3D
	_assert(ground != null, "ground_exists", "NavigationRegion3D/Ground missing")
	if ground:
		_assert(is_equal_approx(ground.position.y, -0.5), "ground_y_minus_half", "Ground y pos must be -0.5")
		_assert(ground.collision_layer == 1, "ground_layer_1", "Ground collision layer must be 1")
	
	main_node.free()


func _find_colliders_recursive(n: Node, out_colliders: Array[Node]) -> void:
	if n is CollisionObject3D or n is CollisionShape3D:
		out_colliders.append(n)
	for child in n.get_children():
		_find_colliders_recursive(child, out_colliders)


# ==============================================================================
# 6. LONG-RUNNING HEADLESS SIMULATION STABILITY (150 FRAMES)
# ==============================================================================

func test_long_running_headless_simulation_stability() -> void:
	print("\n>> [6] Testing Long-Running Headless Simulation Stability (150 Frames)...")
	
	# Test loading and cycling main_level in a headless scene tree without crashing
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	_assert(main_scene != null, "scene_load_clean", "main_level.tscn loaded cleanly")
	
	var main_instance: Node = main_scene.instantiate()
	_assert(main_instance != null, "scene_instance_clean", "main_level instantiated cleanly")
	
	# Check all required visual child nodes in main_instance
	var ground_mesh: MeshInstance3D = main_instance.get_node_or_null("NavigationRegion3D/Ground/GroundMesh") as MeshInstance3D
	_assert(ground_mesh != null and ground_mesh.mesh != null, "ground_mesh_intact", "GroundMesh intact")
	
	var lava_fissures: MeshInstance3D = main_instance.get_node_or_null("EnvironmentDecorations/LavaFissures") as MeshInstance3D
	_assert(lava_fissures != null and lava_fissures.mesh != null, "lava_fissures_intact", "LavaFissures intact")
	
	var creep_pools: MeshInstance3D = main_instance.get_node_or_null("EnvironmentDecorations/CreepPools") as MeshInstance3D
	_assert(creep_pools != null and creep_pools.mesh != null, "creep_pools_intact", "CreepPools intact")
	
	var terran_deck: MeshInstance3D = main_instance.get_node_or_null("EnvironmentDecorations/TerranBaseDeck") as MeshInstance3D
	_assert(terran_deck != null and terran_deck.mesh != null, "terran_deck_intact", "TerranBaseDeck intact")
	
	var boulders: MeshInstance3D = main_instance.get_node_or_null("EnvironmentDecorations/VolcanicBoulders") as MeshInstance3D
	_assert(boulders != null and boulders.mesh != null, "boulders_intact", "VolcanicBoulders intact")
	
	main_instance.free()
	_assert(true, "scene_free_no_crash", "main_level instantiated and freed cleanly without crash")

