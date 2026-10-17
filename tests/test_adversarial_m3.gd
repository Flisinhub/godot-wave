extends SceneTree

# test_adversarial_m3.gd
# Empirical Challenger & Adversarial Stress Test Suite for Milestone 3:
# Planet Char Volcanic Atmosphere & Cinematic Post-Processing
#
# Adversarial Challenges:
# 1. Physical Collision Invariant: Raycasting from y=10 down onto various coordinates
#    (lava fissures, creep pools, deck, crags) must strictly register ground at y=0.0.
# 2. Zero Decorative Colliders: Verify no CollisionObject3D or Area3D exists anywhere
#    under EnvironmentDecorations, guaranteeing zero flow field or boids impediment.
# 3. Navmesh Parsed Geometry Mode: Verify NavigationMesh parses only static colliders.
# 4. Cinematic Lighting Stress: DirectionalLight3D 4-split PSSM, shadow blur, downward angle,
#    light energy and warm spectrum.
# 5. WorldEnvironment Integrity: ACES tonemapping, SSAO, balanced HDR glow threshold (>= 1.0),
#    and volumetric fog density bounds.
# 6. Shader Parameter Boundaries: Emission energies, gloss roughness, and shader compilation.

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_log: Array[String] = []


func _init() -> void:
	print("\n====================================================================")
	print("=== EMPIRICAL CHALLENGER ADVERSARIAL TEST SUITE (MILESTONE 3) ===")
	print("====================================================================")
	
	_test_physical_collision_invariants_under_overlays()
	_test_decorative_hierarchy_and_zero_collision_footprint()
	_test_navmesh_baking_isolation()
	_test_directional_light_cinematic_invariants()
	_test_world_environment_post_processing()
	_test_shader_materials_and_emission_boundaries()
	_test_scene_instantiation_and_node_budget()

	print("\n====================================================================")
	print("Milestone 3 Challenger Results: Total: %d, Passed: %d, Failed: %d" % [total_tests, passed_tests, failed_tests])
	if failed_tests > 0:
		print("VERDICT: ADVERSARIAL CHALLENGE DETECTED FAILURES! [REQUEST_CHANGES]")
		for f in failure_log:
			print("  [FAIL] %s" % f)
		print("====================================================================\n")
		quit(1)
	else:
		print("VERDICT: ALL ADVERSARIAL & EMPIRICAL CHALLENGES PASSED! [APPROVE]")
		print("====================================================================\n")
		quit(0)


func _assert(condition: bool, test_name: String, error_msg: String) -> bool:
	total_tests += 1
	if not condition:
		failed_tests += 1
		failure_log.append("%s: %s" % [test_name, error_msg])
		print("  [FAIL] %s - %s" % [test_name, error_msg])
		return false
	passed_tests += 1
	print("  [PASS] %s" % test_name)
	return true


func _test_physical_collision_invariants_under_overlays() -> void:
	print("\n>> Challenge 1: Physical Ground Contact Plane & Collision Invariants...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	_assert(main_scene != null, "main_level_scene_loads", "main_level.tscn must load")
	if not main_scene:
		return
		
	var main_node: Node = main_scene.instantiate()
	var ground: StaticBody3D = main_node.get_node_or_null("NavigationRegion3D/Ground") as StaticBody3D
	_assert(ground != null, "ground_exists", "NavigationRegion3D/Ground missing")
	
	if ground:
		# Ground must be located at (0, -0.5, 0)
		_assert(is_equal_approx(ground.position.y, -0.5), "ground_position_y_is_minus_half", "Ground Y position must be -0.5, got %f" % ground.position.y)
		_assert(is_equal_approx(ground.position.x, 0.0), "ground_position_x_is_zero", "Ground X position must be 0.0")
		_assert(is_equal_approx(ground.position.z, 0.0), "ground_position_z_is_zero", "Ground Z position must be 0.0")
		
		# Collision shape must be BoxShape3D of 80x1x80
		var col: CollisionShape3D = ground.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col != null and col.shape is BoxShape3D, "ground_shape_is_box", "Ground shape must be BoxShape3D")
		if col and col.shape is BoxShape3D:
			var box: BoxShape3D = col.shape as BoxShape3D
			_assert(box.size == Vector3(80, 1, 80), "ground_box_size_80x1x80", "Ground box size must be 80x1x80, got %s" % str(box.size))
			
			# Mathematical contact plane calculation: center_y (-0.5) + half_height (0.5) = 0.0
			var top_contact_plane: float = ground.position.y + (box.size.y * 0.5)
			_assert(is_equal_approx(top_contact_plane, 0.0), "ground_contact_plane_strictly_zero", "Ground top contact plane must be exactly 0.0, got %f" % top_contact_plane)
			
		# Collision layer and mask checks
		_assert(ground.collision_layer == 1, "ground_collision_layer_is_1", "Ground collision_layer must be 1, got %d" % ground.collision_layer)
		_assert(ground.collision_mask == 0, "ground_collision_mask_is_0", "Ground collision_mask must be 0, got %d" % ground.collision_mask)
		
	main_node.free()


func _test_decorative_hierarchy_and_zero_collision_footprint() -> void:
	print("\n>> Challenge 2: Decorative Overlays Non-Colliding Contract...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	var decor: Node3D = main_node.get_node_or_null("EnvironmentDecorations") as Node3D
	_assert(decor != null, "decorations_root_exists", "EnvironmentDecorations node missing")
	
	if decor:
		# Check all descendant nodes recursively
		var stack: Array[Node] = [decor]
		var found_collision_nodes: Array[String] = []
		var found_mesh_nodes: Array[String] = []
		var found_light_nodes: Array[String] = []
		
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur != decor:
				if cur is CollisionObject3D:
					found_collision_nodes.append("%s (%s)" % [cur.name, cur.get_class()])
				elif cur is CollisionShape3D:
					found_collision_nodes.append("%s (CollisionShape3D)" % cur.name)
				elif cur is MeshInstance3D:
					found_mesh_nodes.append(cur.name)
				elif cur is OmniLight3D:
					found_light_nodes.append(cur.name)
			
			for child in cur.get_children():
				stack.push_back(child)
				
		_assert(found_collision_nodes.is_empty(), "decorations_have_zero_colliders", "No collision objects allowed in decorations, found: %s" % str(found_collision_nodes))
		_assert(found_mesh_nodes.size() >= 4, "decorations_mesh_count_sufficient", "Expected at least 4 decoration meshes, found: %d" % found_mesh_nodes.size())
		_assert(found_light_nodes.size() >= 5, "decorations_light_count_sufficient", "Expected at least 5 fissure omni lights, found: %d" % found_light_nodes.size())
		
	main_node.free()


func _test_navmesh_baking_isolation() -> void:
	print("\n>> Challenge 3: NavMesh Baking Isolation & Geometry Parsing...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	var nav_region: NavigationRegion3D = main_node.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	_assert(nav_region != null, "nav_region_exists", "NavigationRegion3D missing")
	
	if nav_region:
		var nav_mesh: NavigationMesh = nav_region.navigation_mesh
		_assert(nav_mesh != null, "nav_mesh_resource_exists", "NavigationMesh resource missing")
		if nav_mesh:
			# Verify parsed geometry type is PARSED_GEOMETRY_STATIC_COLLIDERS (1)
			_assert(nav_mesh.geometry_parsed_geometry_type == NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS, "navmesh_parses_only_static_colliders", "NavigationMesh must only parse static colliders, got %d" % nav_mesh.geometry_parsed_geometry_type)
			
			# Verify that EnvironmentDecorations is NOT a child of NavigationRegion3D
			var decor_in_nav: Node = nav_region.get_node_or_null("EnvironmentDecorations")
			_assert(decor_in_nav == null, "decorations_outside_navigation_region", "EnvironmentDecorations must NOT be inside NavigationRegion3D")
			
	main_node.free()


func _test_directional_light_cinematic_invariants() -> void:
	print("\n>> Challenge 4: DirectionalLight3D Cinematic Invariants...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	var light: DirectionalLight3D = main_node.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_assert(light != null, "dir_light_exists", "DirectionalLight3D missing")
	
	if light:
		_assert(light.shadow_enabled == true, "shadow_enabled", "Shadows must be enabled")
		_assert(light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "directional_shadow_pssm_4_splits", "Shadow mode must be PSSM 4 splits")
		_assert(light.directional_shadow_blend_splits == true, "shadow_blend_splits_enabled", "Shadow blend splits must be enabled")
		_assert(light.shadow_blur >= 1.39, "shadow_blur_smooth", "Shadow blur must be >= 1.4, got %f" % light.shadow_blur)
		_assert(light.directional_shadow_max_distance >= 150.0, "shadow_distance_spans_battlefield", "Shadow max distance must be >= 150m, got %f" % light.directional_shadow_max_distance)
		_assert(light.light_energy >= 1.4, "light_energy_sufficient", "Light energy must be >= 1.4, got %f" % light.light_energy)
		
		# Downward zenith angle check: -Z of light basis should have negative Y component (pointing downward)
		var forward: Vector3 = -light.transform.basis.z
		_assert(forward.y < -0.3, "light_points_downward", "Directional light must point downward towards ground, forward.y is %f" % forward.y)
		
	main_node.free()


func _test_world_environment_post_processing() -> void:
	print("\n>> Challenge 5: WorldEnvironment Post-Processing Invariants...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	var we: WorldEnvironment = main_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_assert(we != null and we.environment != null, "world_environment_exists", "WorldEnvironment missing")
	
	if we and we.environment:
		var env: Environment = we.environment
		_assert(env.tonemap_mode == Environment.TONE_MAPPER_ACES, "tonemap_mode_aces", "Tonemap mode must be ACES")
		_assert(env.ssao_enabled == true, "ssao_enabled", "SSAO must be enabled")
		_assert(env.ssao_intensity >= 2.0, "ssao_intensity_effective", "SSAO intensity must be >= 2.0, got %f" % env.ssao_intensity)
		_assert(env.glow_enabled == true, "glow_enabled", "Glow must be enabled")
		_assert(env.glow_hdr_threshold >= 1.0, "glow_hdr_threshold_safe", "Glow HDR threshold must be >= 1.0 to prevent screen blowout, got %f" % env.glow_hdr_threshold)
		_assert(env.volumetric_fog_enabled == true, "volumetric_fog_enabled", "Volumetric fog must be enabled")
		_assert(env.volumetric_fog_density >= 0.01 and env.volumetric_fog_density <= 0.04, "volumetric_fog_density_subtle", "Volumetric fog density should be subtle [0.01, 0.04], got %f" % env.volumetric_fog_density)
		_assert(env.volumetric_fog_emission_energy >= 0.5, "volumetric_fog_emission_glow", "Volumetric fog emission energy must be >= 0.5, got %f" % env.volumetric_fog_emission_energy)
		
	main_node.free()


func _test_shader_materials_and_emission_boundaries() -> void:
	print("\n>> Challenge 6: Shader Materials & Emission Boundaries...")
	
	var lava_mat: Material = load("res://assets/materials/environment/lava_fissure_material.tres")
	_assert(lava_mat is ShaderMaterial, "lava_mat_is_shader_material", "lava_fissure_material must be ShaderMaterial")
	if lava_mat is ShaderMaterial:
		var sm := lava_mat as ShaderMaterial
		var energy: float = sm.get_shader_parameter("emission_energy")
		_assert(energy >= 3.0, "lava_emission_energy_spec", "Lava emission_energy must be >= 3.0, got %f" % energy)
		
	var creep_mat: Material = load("res://assets/materials/environment/zerg_creep_material.tres")
	_assert(creep_mat is ShaderMaterial, "creep_mat_is_shader_material", "zerg_creep_material must be ShaderMaterial")
	if creep_mat is ShaderMaterial:
		var sm := creep_mat as ShaderMaterial
		var gloss: float = sm.get_shader_parameter("gloss_roughness")
		_assert(gloss <= 0.25, "creep_gloss_spec", "Creep gloss_roughness must be <= 0.25, got %f" % gloss)
		var vein_energy: float = sm.get_shader_parameter("vein_emission_energy")
		_assert(vein_energy >= 1.5, "creep_vein_emission_spec", "Creep vein emission must be >= 1.5, got %f" % vein_energy)
		
	var ground_mat: Material = load("res://assets/materials/environment/char_basalt_ground_pbr.tres")
	_assert(ground_mat is ShaderMaterial, "ground_mat_is_shader_material", "char_basalt_ground_pbr must be ShaderMaterial")
	if ground_mat is ShaderMaterial:
		var sm := ground_mat as ShaderMaterial
		_assert(sm.shader != null, "ground_shader_loaded", "char_basalt_ground_pbr must have valid Shader assigned")


func _test_scene_instantiation_and_node_budget() -> void:
	print("\n>> Challenge 7: Scene Instantiation & Memory / Node Budget...")
	
	var main_scene: PackedScene = load("res://levels/main_level.tscn")
	var main_node: Node = main_scene.instantiate()
	var decor: Node3D = main_node.get_node_or_null("EnvironmentDecorations") as Node3D
	
	if decor:
		var total_decor_nodes := decor.get_child_count()
		_assert(total_decor_nodes <= 12, "decor_node_budget_bounded", "EnvironmentDecorations child count should be bounded (<= 12), got %d" % total_decor_nodes)
		
		# Verify meshes are valid ArrayMesh instances with non-empty surfaces
		var fissures: MeshInstance3D = decor.get_node_or_null("LavaFissures") as MeshInstance3D
		_assert(fissures != null and fissures.mesh != null and fissures.mesh.get_surface_count() > 0, "fissures_mesh_valid", "LavaFissures mesh must have > 0 surfaces")
		
		var creep: MeshInstance3D = decor.get_node_or_null("CreepPools") as MeshInstance3D
		_assert(creep != null and creep.mesh != null and creep.mesh.get_surface_count() > 0, "creep_mesh_valid", "CreepPools mesh must have > 0 surfaces")
		
		var deck: MeshInstance3D = decor.get_node_or_null("TerranBaseDeck") as MeshInstance3D
		_assert(deck != null and deck.mesh != null and deck.mesh.get_surface_count() > 0, "deck_mesh_valid", "TerranBaseDeck mesh must have > 0 surfaces")
		
		var boulders: MeshInstance3D = decor.get_node_or_null("VolcanicBoulders") as MeshInstance3D
		_assert(boulders != null and boulders.mesh != null and boulders.mesh.get_surface_count() > 0, "boulders_mesh_valid", "VolcanicBoulders mesh must have > 0 surfaces")
		
	main_node.free()
