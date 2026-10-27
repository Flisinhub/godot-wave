extends SceneTree

# Milestone 3 Verification Harness:
# Planet Char Volcanic Atmosphere & Cinematic Post-Processing

var failures: Array[String] = []
var tests_run: int = 0
var tests_passed: int = 0


func _init() -> void:
	print("==================================================================")
	print("=== MILESTONE 3: PLANET CHAR ENVIRONMENT & LIGHTING VERIFICATION ===")
	print("==================================================================")
	
	test_ground_pbr_and_collision_invariants()
	test_lava_fissures_and_emission_invariants()
	test_zerg_creep_pools_invariants()
	test_terran_base_deck_invariants()
	test_directional_light_cinematic_invariants()
	test_world_environment_post_processing_invariants()
	test_omni_lights_and_non_colliding_overlays()
	
	print("\n==================================================================")
	print("Milestone 3 Verification Results:")
	print("Tests Run:    %d" % tests_run)
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % failures.size())
	
	if failures.is_empty():
		print("\u001b[32mALL MILESTONE 3 VERIFICATION CHECKS PASSED! [VERDICT: APPROVE]\u001b[0m")
		print("==================================================================")
		quit(0)
	else:
		print("\u001b[31mMILESTONE 3 VERIFICATION FAILED: [VERDICT: REJECT]\u001b[0m")
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
# 1. GROUND TERRAIN & COLLISION INVARIANTS
# ==============================================================================

func test_ground_pbr_and_collision_invariants() -> void:
	print("\n>> Checking Ground Terrain & Collision Invariants...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	_assert(main_scene != null, "main_level_loaded", "Failed to load res://levels/main_level.tscn")
	
	var main_node: Node = main_scene.instantiate()
	var ground_body: StaticBody3D = main_node.get_node_or_null("NavigationRegion3D/Ground") as StaticBody3D
	_assert(ground_body != null, "ground_static_body_exists", "Ground StaticBody3D missing under NavigationRegion3D")
	
	if ground_body:
		# Ground must be at y = -0.5 with BoxShape 80 x 1 x 80 (top at y = 0.0)
		_assert(is_equal_approx(ground_body.position.y, -0.5), "ground_y_position", "Ground y pos must be -0.5, got %f" % ground_body.position.y)
		_assert(ground_body.collision_layer == 1, "ground_collision_layer", "Ground collision layer must be 1, got %d" % ground_body.collision_layer)
		_assert(ground_body.collision_mask == 0, "ground_collision_mask", "Ground collision mask must be 0, got %d" % ground_body.collision_mask)
		
		var col_shape: CollisionShape3D = ground_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col_shape != null and col_shape.shape is BoxShape3D, "ground_collision_shape", "Ground must have BoxShape3D")
		if col_shape and col_shape.shape is BoxShape3D:
			var box: BoxShape3D = col_shape.shape as BoxShape3D
			_assert(box.size == Vector3(80, 1, 80), "ground_collision_size", "Ground BoxShape3D size must be 80x1x80, got %s" % str(box.size))
		
		# Ground mesh must have PBR material
		var ground_mesh_node: MeshInstance3D = ground_body.get_node_or_null("GroundMesh") as MeshInstance3D
		_assert(ground_mesh_node != null, "ground_mesh_node_exists", "GroundMesh node missing under Ground")
		if ground_mesh_node and ground_mesh_node.mesh is BoxMesh:
			var bm: BoxMesh = ground_mesh_node.mesh as BoxMesh
			_assert(bm.material != null, "ground_mesh_material_assigned", "Ground BoxMesh has no material assigned")
			_assert(bm.material is ShaderMaterial, "ground_mesh_shader_material", "Ground material must be ShaderMaterial for PBR basalt relief")
	
	main_node.free()


# ==============================================================================
# 2. EMISSIVE MAGMA FISSURES INVARIANTS
# ==============================================================================

func test_lava_fissures_and_emission_invariants() -> void:
	print("\n>> Checking Emissive Magma Fissures Invariants...")
	
	var lava_mat: Material = load("res://assets/materials/environment/lava_fissure_material.tres")
	_assert(lava_mat != null, "lava_material_exists", "lava_fissure_material.tres missing")
	
	if lava_mat is ShaderMaterial:
		var sm: ShaderMaterial = lava_mat as ShaderMaterial
		_assert(sm.shader != null, "lava_shader_assigned", "lava_fissure_material has no shader assigned")
		var emission_energy: float = sm.get_shader_parameter("emission_energy")
		_assert(emission_energy >= 3.0, "lava_emission_energy_multiplier", "Lava emission_energy must be >= 3.0, got %f" % emission_energy)
	
	var lava_mesh: Mesh = load("res://assets/models/environment/lava_fissures_mesh.tres")
	_assert(lava_mesh != null, "lava_mesh_exists", "lava_fissures_mesh.tres missing")
	if lava_mesh:
		var aabb := lava_mesh.get_aabb()
		_assert(aabb.size.x > 30.0, "lava_mesh_spans_width", "Lava mesh x span should exceed 30m, got %f" % aabb.size.x)
		_assert(aabb.size.z > 25.0, "lava_mesh_spans_depth", "Lava mesh z span should exceed 25m, got %f" % aabb.size.z)


# ==============================================================================
# 3. ZERG CREEP POOLS INVARIANTS
# ==============================================================================

func test_zerg_creep_pools_invariants() -> void:
	print("\n>> Checking Zerg Creep Pools Invariants...")
	
	var creep_mat: Material = load("res://assets/materials/environment/zerg_creep_material.tres")
	_assert(creep_mat != null, "creep_material_exists", "zerg_creep_material.tres missing")
	
	if creep_mat is ShaderMaterial:
		var sm: ShaderMaterial = creep_mat as ShaderMaterial
		var roughness: float = sm.get_shader_parameter("gloss_roughness")
		_assert(roughness <= 0.25, "creep_gloss_roughness", "Creep gloss roughness must be <= 0.25 for glistening slime, got %f" % roughness)
		var vein_energy: float = sm.get_shader_parameter("vein_emission_energy")
		_assert(vein_energy >= 1.5, "creep_vein_emission_energy", "Creep vein emission must be >= 1.5, got %f" % vein_energy)
	
	var creep_mesh: Mesh = load("res://assets/models/environment/zerg_creep_pools_mesh.tres")
	_assert(creep_mesh != null, "creep_mesh_exists", "zerg_creep_pools_mesh.tres missing")
	if creep_mesh:
		var aabb := creep_mesh.get_aabb()
		_assert(aabb.position.z <= -30.0, "creep_covers_north_spawners", "Creep must cover north spawners at z <= -30, min z is %f" % aabb.position.z)


# ==============================================================================
# 4. TERRAN INDUSTRIAL BASE DECK INVARIANTS
# ==============================================================================

func test_terran_base_deck_invariants() -> void:
	print("\n>> Checking Terran Base Deck Invariants...")
	
	var deck_mat: Material = load("res://assets/materials/environment/terran_base_deck_material.tres")
	_assert(deck_mat != null, "base_deck_material_exists", "terran_base_deck_material.tres missing")
	
	var deck_mesh: Mesh = load("res://assets/models/environment/terran_base_deck_mesh.tres")
	_assert(deck_mesh != null, "base_deck_mesh_exists", "terran_base_deck_mesh.tres missing")
	if deck_mesh:
		var aabb := deck_mesh.get_aabb()
		_assert(is_equal_approx(aabb.position.x, -17.5), "deck_min_x", "Deck min x should be -17.5, got %f" % aabb.position.x)
		_assert(is_equal_approx(aabb.position.z, 4.5), "deck_min_z", "Deck min z should be 4.5, got %f" % aabb.position.z)
		_assert(is_equal_approx(aabb.end.x, 17.5), "deck_max_x", "Deck max x should be 17.5, got %f" % aabb.end.x)
		_assert(is_equal_approx(aabb.end.z, 23.5), "deck_max_z", "Deck max z should be 23.5, got %f" % aabb.end.z)


# ==============================================================================
# 5. DIRECTIONALLIGHT3D CINEMATIC INVARIANTS
# ==============================================================================

func test_directional_light_cinematic_invariants() -> void:
	print("\n>> Checking DirectionalLight3D Cinematic Invariants...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	var dir_light: DirectionalLight3D = main_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_assert(dir_light != null, "dir_light_exists", "DirectionalLight3D node missing")
	
	if dir_light:
		_assert(dir_light.shadow_enabled, "dir_light_shadow_enabled", "Shadows must be enabled on DirectionalLight3D")
		_assert(dir_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "dir_light_4_splits", "Directional shadow mode must be PSSM 4 splits (2), got %d" % dir_light.directional_shadow_mode)
		_assert(dir_light.directional_shadow_blend_splits, "dir_light_blend_splits", "Directional shadow blend splits must be enabled")
		_assert(dir_light.shadow_blur >= 1.39, "dir_light_shadow_blur", "Shadow blur must be >= 1.4, got %f" % dir_light.shadow_blur)
		_assert(dir_light.light_color.r > 0.95 and dir_light.light_color.g > 0.80, "dir_light_warm_color", "Light color should be warm ashen sunlight, got %s" % str(dir_light.light_color))
		_assert(dir_light.light_energy >= 1.4, "dir_light_energy", "Light energy must be >= 1.4, got %f" % dir_light.light_energy)
	
	main_node.free()


# ==============================================================================
# 6. WORLDENVIRONMENT POST-PROCESSING INVARIANTS
# ==============================================================================

func test_world_environment_post_processing_invariants() -> void:
	print("\n>> Checking WorldEnvironment Post-Processing Invariants...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	var world_env_node: WorldEnvironment = main_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_assert(world_env_node != null and world_env_node.environment != null, "world_env_exists", "WorldEnvironment node or environment resource missing")
	
	if world_env_node and world_env_node.environment:
		var env: Environment = world_env_node.environment
		
		# SSAO
		_assert(env.ssao_enabled, "ssao_enabled", "SSAO must be enabled in WorldEnvironment")
		_assert(env.ssao_radius >= 1.5, "ssao_radius", "SSAO radius must be >= 1.5, got %f" % env.ssao_radius)
		_assert(env.ssao_intensity >= 2.0, "ssao_intensity", "SSAO intensity must be >= 2.0, got %f" % env.ssao_intensity)
		
		# Glow / Bloom
		_assert(env.glow_enabled, "glow_enabled", "Glow must be enabled in WorldEnvironment")
		_assert(env.glow_hdr_threshold >= 1.0, "glow_hdr_threshold", "Glow HDR threshold must be >= 1.0 to prevent blowing out screen, got %f" % env.glow_hdr_threshold)
		_assert(env.glow_bloom > 0.1, "glow_bloom", "Glow bloom must be > 0.1, got %f" % env.glow_bloom)
		
		# Tone Mapping
		_assert(env.tonemap_mode == Environment.TONE_MAPPER_ACES, "tonemap_mode_aces", "Tone mapping must be ACES (3), got %d" % env.tonemap_mode)
		
		# Volumetric Fog
		_assert(env.volumetric_fog_enabled, "volumetric_fog_enabled", "Volumetric fog must be enabled")
		_assert(env.volumetric_fog_density >= 0.01 and env.volumetric_fog_density <= 0.03, "volumetric_fog_density", "Volumetric fog density should be ~0.015-0.025, got %f" % env.volumetric_fog_density)
		_assert(env.volumetric_fog_emission.r > 0.15, "volumetric_fog_warm_emission", "Volumetric fog emission must have warm reddish glow, got %s" % str(env.volumetric_fog_emission))
	
	main_node.free()


# ==============================================================================
# 7. OMNI LIGHTS & NON-COLLIDING OVERLAYS
# ==============================================================================

func test_omni_lights_and_non_colliding_overlays() -> void:
	print("\n>> Checking EnvironmentDecorations Non-Colliding Overlays & Omni Lights...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	var decor: Node3D = main_node.get_node_or_null("EnvironmentDecorations") as Node3D
	_assert(decor != null, "decorations_node_exists", "EnvironmentDecorations missing from main_level.tscn")
	
	if decor:
		var colliders: Array[Node] = []
		for child in decor.get_children():
			if child is CollisionObject3D:
				colliders.append(child)
			for subchild in child.get_children():
				if subchild is CollisionObject3D:
					colliders.append(subchild)
		_assert(colliders.is_empty(), "decorations_zero_colliders", "EnvironmentDecorations must have 0 colliders to prevent impeding flow fields, found %d" % colliders.size())
		
		var lights_node: Node = decor.get_node_or_null("LavaLights")
		_assert(lights_node != null, "lava_lights_node_exists", "LavaLights node missing")
		if lights_node:
			var light_count: int = 0
			for c in lights_node.get_children():
				if c is OmniLight3D:
					light_count += 1
			_assert(light_count >= 5, "lava_omni_light_count", "Expected at least 5 warm OmniLight3D along fissures, found %d" % light_count)
	
	main_node.free()
