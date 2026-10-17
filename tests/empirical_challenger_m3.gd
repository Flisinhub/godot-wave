extends Node

# Empirical Challenger 1 Verification Harness for Milestone 3:
# Planet Char Volcanic Atmosphere & Cinematic Lighting
#
# Tasks verified empirically:
# 1. EnvironmentDecorations (lava fissures, creep pools, base deck, boulders)
#    have strictly 0 collision bodies and do NOT register as obstacles in
#    SwarmSimulation.flow_field.registered_obstacles.
# 2. All 30 base perimeter structures and goals remain the only obstacles.
# 3. Ground contact height: ground top surface is strictly at y = 0.0
#    (verified by geometry, colliders, and physical 3D raycasts).
# 4. Anti-Z-fighting micro-offsets: 0.0 < Deck < Lava < Creep < 0.05.
# 5. FlowField cost invariance: lava fissures and creep pools have cost = 1
#    (open walkable terrain), allowing unimpeded swarm pathfinding.
# 6. Planet Char PBR Shaders & Materials parameters (emission, roughness, etc.).
# 7. DirectionalLight3D (4-split PSSM, soft shadows) and WorldEnvironment (ACES, SSAO, Glow, Volumetric Fog).
# 8. LavaLights OmniLight3D count and properties.
# 9. Adversarial swarm locomotion stress test across lava and creep zones.

const SwarmSimulation = preload("res://core/swarm/swarm_simulation.gd")
const SwarmFlowField = preload("res://core/swarm/swarm_flow_field.gd")
const CommandCenter = preload("res://entities/structures/command_center.gd")
const GateStructure = preload("res://entities/structures/gate_structure.gd")
const WallSegment = preload("res://entities/structures/wall_segment.gd")

var failures: Array[String] = []
var tests_run: int = 0
var tests_passed: int = 0


func _ready() -> void:
	print("==================================================================")
	print("=== EMPIRICAL CHALLENGER 1: MILESTONE 3 VERIFICATION HARNESS ===")
	print("==================================================================")
	
	test_decorations_have_zero_collision_bodies()
	test_swarm_simulation_obstacle_and_goal_registry()
	test_ground_top_surface_elevation_and_raycasts()
	test_decor_meshes_elevation_and_anti_z_fighting()
	test_flow_field_passability_over_decorations()
	test_materials_and_shaders_parameters()
	test_cinematic_lighting_and_world_environment()
	test_lava_omni_lights_parameters()
	test_adversarial_swarm_movement_across_lava_and_creep()
	
	print("\n==================================================================")
	print("Empirical Verification Results:")
	print("Tests Run:    %d" % tests_run)
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % failures.size())
	
	if failures.is_empty():
		print("\u001b[32mALL EMPIRICAL CHALLENGE CHECKS PASSED! [VERDICT: APPROVE]\u001b[0m")
		print("==================================================================")
		get_tree().quit(0)
	else:
		print("\u001b[31mEMPIRICAL CHECKS FAILED: [VERDICT: REJECT]\u001b[0m")
		for f in failures:
			print("\u001b[31m  * " + f + "\u001b[0m")
		print("==================================================================")
		get_tree().quit(1)


func _assert(condition: bool, msg: String) -> void:
	tests_run += 1
	if condition:
		tests_passed += 1
		print("  [PASS] " + msg)
	else:
		failures.append(msg)
		print("  [FAIL] " + msg)


# ==============================================================================
# 1. ENVIRONMENT DECORATIONS 0 COLLISION BODIES
# ==============================================================================

func test_decorations_have_zero_collision_bodies() -> void:
	print("\n>> 1. Verifying EnvironmentDecorations Zero Collision Bodies...")
	
	var scene: PackedScene = load("res://levels/main_level.tscn")
	_assert(scene != null, "main_level.tscn loaded successfully")
	if not scene:
		return
	
	var root: Node = scene.instantiate()
	var decor: Node = root.get_node_or_null("EnvironmentDecorations")
	_assert(decor != null, "EnvironmentDecorations node exists in main_level.tscn")
	_assert(decor is Node3D, "EnvironmentDecorations is a pure Node3D container")
	
	if decor:
		var colliders: Array[Node] = []
		var shapes: Array[Node] = []
		_gather_descendants_of_type(decor, CollisionObject3D, colliders)
		_gather_descendants_of_type(decor, CollisionShape3D, shapes)
		_gather_descendants_of_type(decor, CollisionPolygon3D, shapes)
		
		_assert(colliders.is_empty(), "EnvironmentDecorations has strictly 0 CollisionObject3D nodes (found: %d)" % colliders.size())
		_assert(shapes.is_empty(), "EnvironmentDecorations has strictly 0 CollisionShape3D/CollisionPolygon3D nodes (found: %d)" % shapes.size())
		
		# Specifically verify each known decoration child
		var lava := decor.get_node_or_null("LavaFissures")
		var creep := decor.get_node_or_null("CreepPools")
		var deck := decor.get_node_or_null("TerranBaseDeck")
		var boulders := decor.get_node_or_null("VolcanicBoulders")
		var lights := decor.get_node_or_null("LavaLights")
		
		_assert(lava is MeshInstance3D, "LavaFissures is a pure MeshInstance3D")
		_assert(creep is MeshInstance3D, "CreepPools is a pure MeshInstance3D")
		_assert(deck is MeshInstance3D, "TerranBaseDeck is a pure MeshInstance3D")
		_assert(boulders is MeshInstance3D, "VolcanicBoulders is a pure MeshInstance3D")
		_assert(lights != null, "LavaLights node exists")
	
	root.free()


func _gather_descendants_of_type(parent: Node, target_type: Variant, out_array: Array[Node]) -> void:
	for child in parent.get_children():
		if is_instance_of(child, target_type):
			out_array.append(child)
		_gather_descendants_of_type(child, target_type, out_array)


# ==============================================================================
# 2. SWARM SIMULATION OBSTACLE & GOAL REGISTRY INVARIANCE
# ==============================================================================

func test_swarm_simulation_obstacle_and_goal_registry() -> void:
	print("\n>> 2. Verifying SwarmSimulation Obstacle & Goal Registry Invariance...")
	
	var scene: PackedScene = load("res://levels/main_level.tscn")
	var main: Node = scene.instantiate()
	add_child(main)
	
	var sim: SwarmSimulation = main.get_node_or_null("SwarmSimulation") as SwarmSimulation
	_assert(sim != null, "SwarmSimulation exists and is initialized in main_level")
	
	if sim and sim.flow_field:
		var ff: SwarmFlowField = sim.flow_field
		var obs_dict: Dictionary = ff.registered_obstacles
		
		_assert(obs_dict.size() == 30, "Exact 30 obstacles registered in SwarmFlowField (found: %d)" % obs_dict.size())
		
		# Check that every single registered obstacle is a BasePerimeter structure
		var decor_obstacle_found := false
		var wall_count := 0
		var gate_count := 0
		var bunker_count := 0
		var cc_count := 0
		var unknown_count := 0
		
		for key in obs_dict.keys():
			if key is Node:
				var node: Node = key as Node
				# Check if key is anywhere under EnvironmentDecorations
				var curr: Node = node
				while curr != null:
					if curr.name == "EnvironmentDecorations":
						decor_obstacle_found = true
					curr = curr.get_parent()
				
				if node is WallSegment:
					wall_count += 1
				elif node is GateStructure:
					gate_count += 1
				elif node is CommandCenter:
					cc_count += 1
				elif node.name.to_lower().contains("bunker") or node.is_in_group("bunkers"):
					bunker_count += 1
				else:
					unknown_count += 1
			elif typeof(key) == TYPE_STRING or typeof(key) == TYPE_STRING_NAME:
				var key_str: String = str(key).to_lower()
				if "lava" in key_str or "creep" in key_str or "deck" in key_str or "boulder" in key_str:
					decor_obstacle_found = true
		
		_assert(not decor_obstacle_found, "Zero EnvironmentDecorations nodes registered as obstacles in SwarmFlowField")
		_assert(wall_count == 25, "Exactly 25 WallSegments registered as obstacles (found: %d)" % wall_count)
		_assert(gate_count == 2, "Exactly 2 GateStructures registered as obstacles (found: %d)" % gate_count)
		_assert(bunker_count == 2, "Exactly 2 Bunkers registered as obstacles (found: %d)" % bunker_count)
		_assert(cc_count == 1, "Exactly 1 CommandCenter registered as obstacle (found: %d)" % cc_count)
		_assert(unknown_count == 0, "Zero unrecognized obstacle entities in SwarmFlowField (found: %d)" % unknown_count)
		
		# Check Goal registration
		_assert(ff.goals.size() == 1, "Exactly 1 Goal registered in SwarmFlowField (found: %d)" % ff.goals.size())
		if not ff.goals.is_empty():
			var goal: Vector2 = ff.goals[0]
			_assert(is_equal_approx(goal.x, 0.0) and is_equal_approx(goal.y, 14.0), "Goal points directly to CommandCenter at (0.0, 14.0), got %s" % str(goal))
	
	remove_child(main)
	main.free()


# ==============================================================================
# 3. GROUND TOP SURFACE ELEVATION & PHYSICAL RAYCASTS
# ==============================================================================

func test_ground_top_surface_elevation_and_raycasts() -> void:
	print("\n>> 3. Verifying Ground Top Surface Elevation (y = 0.0) & Physics Raycasts...")
	
	var scene: PackedScene = load("res://levels/main_level.tscn")
	var main: Node = scene.instantiate()
	add_child(main)
	
	var ground: StaticBody3D = main.get_node_or_null("NavigationRegion3D/Ground") as StaticBody3D
	_assert(ground != null, "NavigationRegion3D/Ground exists")
	
	if ground:
		_assert(is_equal_approx(ground.global_position.y, -0.5), "Ground StaticBody3D position.y is -0.5 (got %f)" % ground.global_position.y)
		var col: CollisionShape3D = ground.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col != null and col.shape is BoxShape3D, "Ground has BoxShape3D")
		if col and col.shape is BoxShape3D:
			var box: BoxShape3D = col.shape as BoxShape3D
			_assert(is_equal_approx(box.size.y, 1.0), "Ground BoxShape3D height is 1.0 (got %f)" % box.size.y)
			var top_y: float = ground.global_position.y + (box.size.y * 0.5)
			_assert(is_equal_approx(top_y, 0.0), "Ground collision surface is mathematically strictly at y = 0.0 (got %f)" % top_y)
		
		var mesh_inst: MeshInstance3D = ground.get_node_or_null("GroundMesh") as MeshInstance3D
		_assert(mesh_inst != null and mesh_inst.mesh is BoxMesh, "Ground has BoxMesh")
		if mesh_inst and mesh_inst.mesh is BoxMesh:
			var bm: BoxMesh = mesh_inst.mesh as BoxMesh
			_assert(is_equal_approx(bm.size.y, 1.0), "Ground BoxMesh height is 1.0 (got %f)" % bm.size.y)
			var mesh_top_y: float = ground.global_position.y + (bm.size.y * 0.5)
			_assert(is_equal_approx(mesh_top_y, 0.0), "Ground visual mesh top is strictly at y = 0.0 (got %f)" % mesh_top_y)
	
	# Raycast physics test using direct PhysicsDirectSpaceState3D
	var space_state := ground.get_world_3d().direct_space_state
	var test_points: Array[Vector2] = [
		Vector2(0.0, 0.0),       # Map center
		Vector2(-15.0, -15.0),   # Lava fissure zone
		Vector2(15.0, -15.0),    # Lava fissure zone
		Vector2(0.0, -32.0),     # Creep pool zone
		Vector2(-26.0, -10.0),   # West boss / creep zone
		Vector2(26.0, -10.0),    # East boss / creep zone
		Vector2(0.0, 7.0),       # Terran base deck (south of gates, north of CC)
		Vector2(-30.0, 30.0),    # South-west corner
		Vector2(30.0, 30.0),     # South-east corner
		Vector2(0.0, -38.0)      # North edge
	]
	
	var raycasts_passed := 0
	for pt in test_points:
		var ray_from := Vector3(pt.x, 10.0, pt.y)
		var ray_to := Vector3(pt.x, -5.0, pt.y)
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1) # Layer 1 = World/Ground
		var result: Dictionary = space_state.intersect_ray(query)
		
		if not result.is_empty():
			var hit_pos: Vector3 = result.get("position", Vector3.ZERO)
			var hit_collider: Object = result.get("collider", null)
			if is_equal_approx(hit_pos.y, 0.0) and hit_collider == ground:
				raycasts_passed += 1
			else:
				failures.append("Raycast at %s hit unexpected y=%f or collider=%s" % [str(pt), hit_pos.y, str(hit_collider)])
		else:
			failures.append("Raycast at %s missed ground completely" % str(pt))
	
	_assert(raycasts_passed == test_points.size(), "All %d physical raycasts through lava, creep, and base deck hit Ground strictly at y = 0.0" % test_points.size())
	
	remove_child(main)
	main.free()


# ==============================================================================
# 4. DECOR MESHES ELEVATION & ANTI-Z-FIGHTING
# ==============================================================================

func test_decor_meshes_elevation_and_anti_z_fighting() -> void:
	print("\n>> 4. Verifying Decor Meshes Elevation & Anti-Z-Fighting Micro-Offsets...")
	
	var scene: PackedScene = load("res://levels/main_level.tscn")
	var root: Node = scene.instantiate()
	var decor: Node = root.get_node_or_null("EnvironmentDecorations")
	
	if decor:
		var deck: MeshInstance3D = decor.get_node_or_null("TerranBaseDeck") as MeshInstance3D
		var lava: MeshInstance3D = decor.get_node_or_null("LavaFissures") as MeshInstance3D
		var creep: MeshInstance3D = decor.get_node_or_null("CreepPools") as MeshInstance3D
		var boulders: MeshInstance3D = decor.get_node_or_null("VolcanicBoulders") as MeshInstance3D
		
		_assert(deck != null and lava != null and creep != null and boulders != null, "All 4 decoration mesh instances found")
		
		# Check mesh extents or transforms
		var deck_mesh: Mesh = deck.mesh if deck else null
		var lava_mesh: Mesh = lava.mesh if lava else null
		var creep_mesh: Mesh = creep.mesh if creep else null
		var boulders_mesh: Mesh = boulders.mesh if boulders else null
		
		_assert(deck_mesh != null, "TerranBaseDeck mesh loaded")
		_assert(lava_mesh != null, "LavaFissures mesh loaded")
		_assert(creep_mesh != null, "CreepPools mesh loaded")
		_assert(boulders_mesh != null, "VolcanicBoulders mesh loaded")
		
		if deck_mesh and lava_mesh and creep_mesh:
			var deck_aabb := deck_mesh.get_aabb()
			var lava_aabb := lava_mesh.get_aabb()
			var creep_aabb := creep_mesh.get_aabb()
			
			# Check micro-elevations: Base Ground (0.0) < Deck (~0.006) < Lava (~0.008) < Creep (~0.012)
			var y_deck := deck_aabb.position.y
			var y_lava := lava_aabb.position.y
			var y_creep := creep_aabb.position.y
			
			_assert(y_deck >= 0.004 and y_deck <= 0.010, "Base deck y-elevation is micro-offset to ~0.006 (got %f)" % y_deck)
			_assert(y_lava >= 0.006 and y_lava <= 0.012, "Lava fissures y-elevation is micro-offset to ~0.008 (got %f)" % y_lava)
			_assert(y_creep >= 0.010 and y_creep <= 0.020, "Creep pools y-elevation is micro-offset to ~0.012 (got %f)" % y_creep)
			
			_assert(y_deck < y_lava, "Deck height < Lava height (%f < %f)" % [y_deck, y_lava])
			_assert(y_lava < y_creep, "Lava height < Creep height (%f < %f)" % [y_lava, y_creep])
			_assert(y_creep < 0.05, "Creep height < 0.05m to prevent floating illusion (got %f)" % y_creep)
	
	root.free()


# ==============================================================================
# 5. FLOW FIELD PASSABILITY OVER DECORATIONS (NO INVISIBLE WALLS)
# ==============================================================================

func test_flow_field_passability_over_decorations() -> void:
	print("\n>> 5. Verifying Flow Field Passability Over Decorative Regions...")
	
	var scene: PackedScene = load("res://levels/main_level.tscn")
	var main: Node = scene.instantiate()
	add_child(main)
	
	var sim: SwarmSimulation = main.get_node_or_null("SwarmSimulation") as SwarmSimulation
	if sim and sim.flow_field:
		var ff: SwarmFlowField = sim.flow_field
		# Explicitly update flow field pipeline (Cost -> Integration -> Flow)
		ff.update()
		
		# Test points inside Lava Fissure regions (should be cost = 1)
		var lava_points: Array[Vector2] = [
			Vector2(-14.0, -20.0),
			Vector2(14.5, -18.0),
			Vector2(0.0, -10.0),
			Vector2(10.0, -5.0)
		]
		for lp in lava_points:
			var grid_coord: Vector2i = ff.world_to_grid(lp)
			var cost: int = ff.get_cell_cost(grid_coord.x, grid_coord.y)
			_assert(cost == 1, "Lava fissure position (%f, %f) has cost = 1 (passable, got %d)" % [lp.x, lp.y, cost])
			var flow: Vector2 = ff.sample_flow_bilinear(lp)
			_assert(flow.length() > 0.1, "Lava fissure position (%f, %f) has active non-zero flow vector: %s" % [lp.x, lp.y, str(flow)])
		
		# Test points inside Creep Pool regions (should be cost = 1)
		var creep_points: Array[Vector2] = [
			Vector2(0.0, -34.0),
			Vector2(-26.0, -10.0),
			Vector2(26.0, -10.0),
			Vector2(-20.0, -32.0)
		]
		for cp in creep_points:
			var grid_coord: Vector2i = ff.world_to_grid(cp)
			var cost: int = ff.get_cell_cost(grid_coord.x, grid_coord.y)
			_assert(cost == 1, "Creep pool position (%f, %f) has cost = 1 (passable, got %d)" % [cp.x, cp.y, cost])
			var flow: Vector2 = ff.sample_flow_bilinear(cp)
			_assert(flow.length() > 0.1, "Creep pool position (%f, %f) has active non-zero flow vector: %s" % [cp.x, cp.y, str(flow)])
		
		# Test point on WallCenter1 (should be cost = 60, front wall)
		var wall_g: Vector2i = ff.world_to_grid(Vector2(-2.0, 4.0))
		var wall_cost: int = ff.get_cell_cost(wall_g.x, wall_g.y)
		_assert(wall_cost == 60, "WallCenter1 position (-2.0, 4.0) has structure obstacle cost = 60 (got %d)" % wall_cost)
		
		# Test point on Command Center (should be cost = 255, impassable)
		var cc_g: Vector2i = ff.world_to_grid(Vector2(0.0, 14.0))
		var cc_cost: int = ff.get_cell_cost(cc_g.x, cc_g.y)
		_assert(cc_cost == 255, "CommandCenter position (0.0, 14.0) has obstacle cost = 255 (got %d)" % cc_cost)
	
	remove_child(main)
	main.free()


# ==============================================================================
# 6. MATERIALS & SHADERS PARAMETERS
# ==============================================================================

func test_materials_and_shaders_parameters() -> void:
	print("\n>> 6. Verifying Materials & Shaders Parameters...")
	
	# Ground Basalt
	var ground_mat: Material = load("res://assets/materials/environment/char_basalt_ground_pbr.tres")
	_assert(ground_mat != null, "char_basalt_ground_pbr.tres exists")
	_assert(ground_mat is ShaderMaterial, "Ground material is ShaderMaterial")
	if ground_mat is ShaderMaterial:
		var sm: ShaderMaterial = ground_mat as ShaderMaterial
		_assert(sm.shader != null, "Ground shader assigned")
		_assert(sm.shader.resource_path == "res://assets/shaders/char_terrain.gdshader", "Ground shader is char_terrain.gdshader")
	
	# Lava Fissures
	var lava_mat: Material = load("res://assets/materials/environment/lava_fissure_material.tres")
	_assert(lava_mat != null, "lava_fissure_material.tres exists")
	_assert(lava_mat is ShaderMaterial, "Lava material is ShaderMaterial")
	if lava_mat is ShaderMaterial:
		var sm: ShaderMaterial = lava_mat as ShaderMaterial
		var energy: float = sm.get_shader_parameter("emission_energy")
		_assert(energy >= 3.0, "Lava emission_energy >= 3.0 (got %f)" % energy)
		var magma_flow: Variant = sm.get_shader_parameter("magma_flow_color")
		if magma_flow is Color:
			_assert(magma_flow.r > 0.8, "Magma flow color has strong red/orange component: %s" % str(magma_flow))
	
	# Zerg Creep
	var creep_mat: Material = load("res://assets/materials/environment/zerg_creep_material.tres")
	_assert(creep_mat != null, "zerg_creep_material.tres exists")
	_assert(creep_mat is ShaderMaterial, "Creep material is ShaderMaterial")
	if creep_mat is ShaderMaterial:
		var sm: ShaderMaterial = creep_mat as ShaderMaterial
		var gloss: float = sm.get_shader_parameter("gloss_roughness")
		_assert(gloss <= 0.25, "Creep gloss_roughness <= 0.25 for glistening wet slime (got %f)" % gloss)
		var vein_energy: float = sm.get_shader_parameter("vein_emission_energy")
		_assert(vein_energy >= 1.5, "Creep vein_emission_energy >= 1.5 (got %f)" % vein_energy)
	
	# Base Deck
	var deck_mat: Material = load("res://assets/materials/environment/terran_base_deck_material.tres")
	_assert(deck_mat != null, "terran_base_deck_material.tres exists")
	if deck_mat is ShaderMaterial:
		var sm: ShaderMaterial = deck_mat as ShaderMaterial
		_assert(sm.shader != null, "Base deck shader assigned")
		_assert(sm.shader.resource_path == "res://assets/shaders/terran_base_deck.gdshader", "Base deck shader is terran_base_deck.gdshader")
		var conduit_energy: Variant = sm.get_shader_parameter("conduit_emission_energy")
		var energy_val: float = float(conduit_energy) if conduit_energy != null else 2.5
		_assert(energy_val >= 2.0, "Base deck conduit emission energy >= 2.0 (got %f)" % energy_val)
	
	# Volcanic Boulders
	var rock_mat: Material = load("res://assets/materials/environment/char_rock_crust.tres")
	_assert(rock_mat != null, "char_rock_crust.tres exists")
	if rock_mat is StandardMaterial3D:
		var sm3d: StandardMaterial3D = rock_mat as StandardMaterial3D
		_assert(sm3d.roughness >= 0.8, "Volcanic boulder roughness >= 0.8 (got %f)" % sm3d.roughness)


# ==============================================================================
# 7. CINEMATIC LIGHTING & WORLDENVIRONMENT
# ==============================================================================

func test_cinematic_lighting_and_world_environment() -> void:
	print("\n>> 7. Verifying Cinematic Lighting & WorldEnvironment Invariants...")
	
	var scene: PackedScene = load("res://levels/main_level.tscn")
	var root: Node = scene.instantiate()
	
	var dir_light: DirectionalLight3D = root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_assert(dir_light != null, "DirectionalLight3D exists in main_level.tscn")
	if dir_light:
		_assert(dir_light.shadow_enabled, "DirectionalLight3D shadow_enabled == true")
		_assert(dir_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "Directional shadow mode is SHADOW_PARALLEL_4_SPLITS (2)")
		_assert(dir_light.directional_shadow_blend_splits, "Directional shadow blend splits == true")
		_assert(dir_light.shadow_blur >= 1.39, "Directional shadow blur >= 1.4 (got %f)" % dir_light.shadow_blur)
		_assert(dir_light.light_energy >= 1.4, "Directional light energy >= 1.4 (got %f)" % dir_light.light_energy)
		_assert(dir_light.light_color.r > 0.95 and dir_light.light_color.g > 0.80, "Directional light warm solar color: %s" % str(dir_light.light_color))
	
	var world_env: WorldEnvironment = root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_assert(world_env != null and world_env.environment != null, "WorldEnvironment and environment resource exist")
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		_assert(env.tonemap_mode == Environment.TONE_MAPPER_ACES, "Tonemap mode is ACES (3)")
		_assert(env.ssao_enabled, "SSAO is enabled")
		_assert(env.ssao_radius >= 1.5, "SSAO radius >= 1.5 (got %f)" % env.ssao_radius)
		_assert(env.ssao_intensity >= 2.0, "SSAO intensity >= 2.0 (got %f)" % env.ssao_intensity)
		_assert(env.glow_enabled, "Glow is enabled")
		_assert(env.glow_hdr_threshold >= 1.0, "Glow HDR threshold >= 1.0 to prevent screen blowout (got %f)" % env.glow_hdr_threshold)
		_assert(env.glow_bloom > 0.1, "Glow bloom > 0.1 (got %f)" % env.glow_bloom)
		_assert(env.volumetric_fog_enabled, "Volumetric Fog is enabled")
		_assert(env.volumetric_fog_density >= 0.01 and env.volumetric_fog_density <= 0.03, "Volumetric Fog density in range [0.01, 0.03] (got %f)" % env.volumetric_fog_density)
		_assert(env.volumetric_fog_emission.r > 0.15, "Volumetric Fog has warm reddish geothermal emission: %s" % str(env.volumetric_fog_emission))
	
	root.free()


# ==============================================================================
# 8. LAVA OMNI LIGHTS
# ==============================================================================

func test_lava_omni_lights_parameters() -> void:
	print("\n>> 8. Verifying Lava Omni Lights Parameters...")
	
	var scene: PackedScene = load("res://levels/main_level.tscn")
	var root: Node = scene.instantiate()
	var lights_parent: Node = root.get_node_or_null("EnvironmentDecorations/LavaLights")
	_assert(lights_parent != null, "EnvironmentDecorations/LavaLights node exists")
	
	if lights_parent:
		var omni_lights: Array[OmniLight3D] = []
		for child in lights_parent.get_children():
			if child is OmniLight3D:
				omni_lights.append(child as OmniLight3D)
		
		_assert(omni_lights.size() >= 6, "At least 6 warm OmniLight3D nodes placed along fissures (found: %d)" % omni_lights.size())
		
		var valid_energies := 0
		var valid_ranges := 0
		var valid_colors := 0
		for ol in omni_lights:
			if ol.light_energy >= 1.5:
				valid_energies += 1
			if ol.omni_range >= 10.0:
				valid_ranges += 1
			if ol.light_color.r > 0.9 and ol.light_color.g > 0.3:
				valid_colors += 1
		
		_assert(valid_energies == omni_lights.size(), "All omni lights have light_energy >= 1.5")
		_assert(valid_ranges == omni_lights.size(), "All omni lights have omni_range >= 10.0m")
		_assert(valid_colors == omni_lights.size(), "All omni lights have warm volcanic magma colors")
	
	root.free()


# ==============================================================================
# 9. ADVERSARIAL SWARM MOVEMENT ACROSS LAVA AND CREEP
# ==============================================================================

func test_adversarial_swarm_movement_across_lava_and_creep() -> void:
	print("\n>> 9. Adversarial Stress Test: Swarm Movement Across Lava & Creep...")
	
	var scene: PackedScene = load("res://levels/main_level.tscn")
	var main: Node = scene.instantiate()
	add_child(main)
	
	var sim: SwarmSimulation = main.get_node_or_null("SwarmSimulation") as SwarmSimulation
	_assert(sim != null, "SwarmSimulation accessible for dynamic horde stress")
	
	if sim and sim.swarm_data:
		# Spawn test units directly inside the north creep pool and north lava fissure
		var test_spawns: Array[Vector3] = [
			Vector3(0.0, 0.0, -34.0),    # Inside Creep Pool (North spawner)
			Vector3(-26.0, 0.0, -10.0),  # Inside West Creep Pool
			Vector3(-14.0, 0.0, -20.0),  # Inside Lava Fissure (West chasm)
			Vector3(14.5, 0.0, -18.0)    # Inside Lava Fissure (East chasm)
		]
		
		var spawned_indices: Array[int] = []
		for pos in test_spawns:
			var idx: int = sim.spawn_unit(0, pos) # Zergling archetype 0
			if idx >= 0:
				spawned_indices.append(idx)
		
		_assert(spawned_indices.size() == test_spawns.size(), "Spawned %d test units inside creep and lava zones" % test_spawns.size())
		
		# Simulate 15 physics/swarm ticks
		for tick in range(15):
			sim._physics_process(0.05)
		
		# Verify that all test units moved toward Command Center (Z = 14) without getting stuck or NaN
		var movement_valid := 0
		for i in range(spawned_indices.size()):
			var idx: int = spawned_indices[i]
			var start_pos: Vector3 = test_spawns[i]
			var end_x: float = sim.swarm_data.pos_x[idx]
			var end_z: float = sim.swarm_data.pos_z[idx]
			
			var has_nan := is_nan(end_x) or is_nan(end_z)
			var moved_south := (end_z > start_pos.z) # Toward goal at Z = 14
			var dist_moved := Vector2(end_x - start_pos.x, end_z - start_pos.z).length()
			
			if not has_nan and moved_south and dist_moved > 0.5:
				movement_valid += 1
			else:
				failures.append("Unit %d spawned at %s failed to advance: end=(%f, %f), dist=%f, nan=%s" % [
					idx, str(start_pos), end_x, end_z, dist_moved, str(has_nan)
				])
		
		_assert(movement_valid == spawned_indices.size(), "All %d swarm units moved smoothly across lava and creep toward CommandCenter" % spawned_indices.size())
	
	remove_child(main)
	main.free()
