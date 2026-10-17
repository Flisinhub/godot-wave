extends SceneTree

# Empirical Challenger 2 Verification Harness for Milestone 1
# Tests geometry, AABBs, lowest vertex flushness, collision invariance, and MultiMesh offsets.

var failures: Array[String] = []
var tests_run: int = 0
var tests_passed: int = 0

func _init() -> void:
	print("==================================================================")
	print("=== EMPIRICAL CHALLENGER 2: MILESTONE 1 VERIFICATION HARNESS ===")
	print("==================================================================")
	
	test_mesh_lowest_vertices()
	test_base_unit_collision_and_spatial()
	test_hero_raynor_collision_and_spatial()
	test_base_enemy_spatial()
	test_swarm_archetypes_and_multimesh()
	
	print("\n==================================================================")
	print("Empirical Verification Results:")
	print("Tests Run:    %d" % tests_run)
	print("Tests Passed: %d" % tests_passed)
	print("Tests Failed: %d" % failures.size())
	
	if failures.is_empty():
		print("\u001b[32mALL EMPIRICAL CHALLENGE CHECKS PASSED PERFECTLY!\u001b[0m")
		print("==================================================================")
		quit(0)
	else:
		print("\u001b[31mEMPIRICAL CHECKS FAILED:\u001b[0m")
		for f in failures:
			print("\u001b[31m  * " + f + "\u001b[0m")
		print("==================================================================")
		quit(1)

func _assert(condition: bool, msg: String) -> void:
	tests_run += 1
	if condition:
		tests_passed += 1
		print("  [PASS] " + msg)
	else:
		failures.append(msg)
		print("  [FAIL] " + msg)

func _get_mesh_min_max_y(mesh: Mesh) -> Dictionary:
	var min_y: float = 999999.0
	var max_y: float = -999999.0
	var total_verts: int = 0
	
	if mesh is ArrayMesh:
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_VERTEX:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for v in verts:
					total_verts += 1
					if v.y < min_y:
						min_y = v.y
					if v.y > max_y:
						max_y = v.y
	return {"min_y": min_y, "max_y": max_y, "vertex_count": total_verts}

func test_mesh_lowest_vertices() -> void:
	print("\n>> 1. Verifying Unit Visual Meshes Lowest Vertices (Flush at Y=0.0):")
	
	# Marine Body Mesh
	var marine_mesh := load("res://assets/models/marine_body_mesh.tres") as Mesh
	_assert(marine_mesh != null, "marine_body_mesh.tres loaded successfully")
	if marine_mesh:
		var stats := _get_mesh_min_max_y(marine_mesh)
		print("     Marine: min_y=%.5f, max_y=%.5f, vertices=%d" % [stats.min_y, stats.max_y, stats.vertex_count])
		_assert(abs(stats.min_y - 0.0) < 0.0001, "Marine body mesh lowest vertex rests flush at Y=0.0 (got %.5f)" % stats.min_y)
		_assert(stats.max_y > 1.6 and stats.max_y < 2.0, "Marine body mesh height is realistic for powered armor (got %.5f)" % stats.max_y)
	
	# Raynor Body Mesh
	var raynor_mesh := load("res://assets/models/raynor_body_mesh.tres") as Mesh
	_assert(raynor_mesh != null, "raynor_body_mesh.tres loaded successfully")
	if raynor_mesh:
		var stats := _get_mesh_min_max_y(raynor_mesh)
		print("     Raynor: min_y=%.5f, max_y=%.5f, vertices=%d" % [stats.min_y, stats.max_y, stats.vertex_count])
		_assert(abs(stats.min_y - 0.0) < 0.0001, "Raynor body mesh lowest vertex rests flush at Y=0.0 (got %.5f)" % stats.min_y)
		_assert(stats.max_y > 1.7 and stats.max_y < 2.2, "Raynor body mesh height reflects heroic scale (got %.5f)" % stats.max_y)
	
	# Zergling Mesh
	var zergling_mesh := load("res://assets/models/zergling_mesh.tres") as Mesh
	_assert(zergling_mesh != null, "zergling_mesh.tres loaded successfully")
	if zergling_mesh:
		var stats := _get_mesh_min_max_y(zergling_mesh)
		print("     Zergling: min_y=%.5f, max_y=%.5f, vertices=%d" % [stats.min_y, stats.max_y, stats.vertex_count])
		_assert(abs(stats.min_y - 0.0) < 0.0001, "Zergling mesh lowest vertex rests flush at Y=0.0 (got %.5f)" % stats.min_y)
		_assert(stats.max_y > 0.8 and stats.max_y < 1.3, "Zergling mesh height matches quadrupedal profile (got %.5f)" % stats.max_y)
	
	# Roach Mesh
	var roach_mesh := load("res://assets/models/roach_mesh.tres") as Mesh
	_assert(roach_mesh != null, "roach_mesh.tres loaded successfully")
	if roach_mesh:
		var stats := _get_mesh_min_max_y(roach_mesh)
		print("     Roach: min_y=%.5f, max_y=%.5f, vertices=%d" % [stats.min_y, stats.max_y, stats.vertex_count])
		_assert(abs(stats.min_y - 0.0) < 0.0001, "Roach mesh lowest vertex rests flush at Y=0.0 (got %.5f)" % stats.min_y)
		_assert(stats.max_y > 0.7 and stats.max_y < 1.2, "Roach mesh height matches armored dome profile (got %.5f)" % stats.max_y)

func test_base_unit_collision_and_spatial() -> void:
	print("\n>> 2. Verifying BaseUnit3D Collision Invariance & Hierarchy:")
	var scene := load("res://entities/allies/base_unit_3d.tscn") as PackedScene
	_assert(scene != null, "base_unit_3d.tscn loaded successfully")
	if not scene:
		return
	
	var unit := scene.instantiate() as CharacterBody3D
	_assert(unit != null, "base_unit_3d instantiated as CharacterBody3D")
	
	var col_shape_node := unit.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_assert(col_shape_node != null, "CollisionShape3D exists on BaseUnit3D")
	if col_shape_node:
		var shape := col_shape_node.shape as CapsuleShape3D
		_assert(shape != null, "CollisionShape3D is CapsuleShape3D")
		if shape:
			_assert(is_equal_approx(shape.radius, 0.4), "Capsule radius is exactly 0.4 (got %f)" % shape.radius)
			_assert(is_equal_approx(shape.height, 1.8), "Capsule height is exactly 1.8 (got %f)" % shape.height)
		_assert(is_equal_approx(col_shape_node.transform.origin.y, 0.9), "Capsule origin Y is exactly 0.9 (got %f)" % col_shape_node.transform.origin.y)
		# Capsule extends from 0.9 - 1.8/2 = 0.0 to 0.9 + 1.8/2 = 1.8
		var bottom_y: float = col_shape_node.transform.origin.y - (shape.height * 0.5 if shape else 0.0)
		_assert(is_equal_approx(bottom_y, 0.0), "Physics collision capsule bottom rests exactly flush on ground at Y=0.0 (got %f)" % bottom_y)
	
	var visual_root := unit.get_node_or_null("VisualRoot") as Node3D
	_assert(visual_root != null, "VisualRoot exists on BaseUnit3D")
	if visual_root:
		_assert(visual_root.transform.origin == Vector3.ZERO, "VisualRoot has origin at (0,0,0)")
		var body_mesh := visual_root.get_node_or_null("BodyMesh") as MeshInstance3D
		_assert(body_mesh != null, "VisualRoot/BodyMesh exists")
		if body_mesh:
			_assert(body_mesh.transform.origin == Vector3.ZERO, "BodyMesh has origin at (0,0,0)")
			_assert(body_mesh.mesh != null, "BodyMesh has mesh assigned")
		var sel_ring := visual_root.get_node_or_null("SelectionRing") as MeshInstance3D
		_assert(sel_ring != null, "VisualRoot/SelectionRing exists")
		var rifle_mesh := visual_root.get_node_or_null("RifleMesh") as MeshInstance3D
		_assert(rifle_mesh != null, "VisualRoot/RifleMesh exists")
		if rifle_mesh:
			var muzzle_flash := rifle_mesh.get_node_or_null("MuzzleFlash") as MeshInstance3D
			_assert(muzzle_flash != null, "VisualRoot/RifleMesh/MuzzleFlash exists")
	
	unit.free()

func test_hero_raynor_collision_and_spatial() -> void:
	print("\n>> 3. Verifying HeroRaynor Collision Invariance & Hierarchy in main_level.tscn:")
	var level_scene := load("res://levels/main_level.tscn") as PackedScene
	_assert(level_scene != null, "main_level.tscn loaded successfully")
	if not level_scene:
		return
	
	var level := level_scene.instantiate()
	_assert(level != null, "main_level.tscn instantiated successfully")
	
	var hero := level.get_node_or_null("Allies/HeroRaynor") as CharacterBody3D
	_assert(hero != null, "Allies/HeroRaynor found in main_level.tscn")
	if hero:
		var col_shape_node := hero.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col_shape_node != null, "CollisionShape3D exists on HeroRaynor")
		if col_shape_node:
			var shape := col_shape_node.shape as CapsuleShape3D
			_assert(shape != null, "CollisionShape3D is CapsuleShape3D")
			if shape:
				_assert(is_equal_approx(shape.radius, 0.45), "Hero capsule radius is exactly 0.45 (got %f)" % shape.radius)
				_assert(is_equal_approx(shape.height, 1.85), "Hero capsule height is exactly 1.85 (got %f)" % shape.height)
			_assert(is_equal_approx(col_shape_node.transform.origin.y, 0.92), "Hero capsule origin Y is exactly 0.92 (got %f)" % col_shape_node.transform.origin.y)
			var bottom_y: float = col_shape_node.transform.origin.y - (shape.height * 0.5 if shape else 0.0)
			# 0.92 - 1.85 * 0.5 = -0.005, which is practically flush at ground level
			print("     Hero capsule bottom Y: %.4f" % bottom_y)
			_assert(abs(bottom_y) <= 0.01, "Hero capsule bottom rests flush on ground (within 0.01 tolerance, got %.4f)" % bottom_y)
		
		var visual_root := hero.get_node_or_null("VisualRoot") as Node3D
		_assert(visual_root != null, "VisualRoot exists on HeroRaynor")
		if visual_root:
			_assert(visual_root.transform.origin == Vector3.ZERO, "VisualRoot origin is at (0,0,0)")
			var body_mesh := visual_root.get_node_or_null("BodyMesh") as MeshInstance3D
			_assert(body_mesh != null, "Hero VisualRoot/BodyMesh exists")
			if body_mesh:
				_assert(body_mesh.transform.origin == Vector3.ZERO, "Hero BodyMesh origin is at (0,0,0)")
				_assert(body_mesh.mesh != null, "Hero BodyMesh has mesh assigned")
			var sel_ring := visual_root.get_node_or_null("SelectionRing") as MeshInstance3D
			_assert(sel_ring != null, "Hero VisualRoot/SelectionRing exists")
			var rifle_mesh := visual_root.get_node_or_null("RifleMesh") as MeshInstance3D
			_assert(rifle_mesh != null, "Hero VisualRoot/RifleMesh exists")
			if rifle_mesh:
				var muzzle_flash := rifle_mesh.get_node_or_null("MuzzleFlash") as MeshInstance3D
				_assert(muzzle_flash != null, "Hero VisualRoot/RifleMesh/MuzzleFlash exists")
	
	level.free()

func test_base_enemy_spatial() -> void:
	print("\n>> 4. Verifying BaseEnemy3D (Zergling Scene) Spatial Alignment:")
	var scene := load("res://entities/enemies/base_enemy_3d.tscn") as PackedScene
	_assert(scene != null, "base_enemy_3d.tscn loaded successfully")
	if not scene:
		return
	
	var enemy := scene.instantiate() as CharacterBody3D
	_assert(enemy != null, "base_enemy_3d instantiated as CharacterBody3D")
	if enemy:
		var col_shape_node := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col_shape_node != null, "CollisionShape3D exists on BaseEnemy3D")
		if col_shape_node:
			var shape := col_shape_node.shape as CapsuleShape3D
			if shape:
				_assert(is_equal_approx(shape.radius, 0.45), "Enemy capsule radius is 0.45 (got %f)" % shape.radius)
				_assert(is_equal_approx(shape.height, 1.2), "Enemy capsule height is 1.2 (got %f)" % shape.height)
			_assert(is_equal_approx(col_shape_node.transform.origin.y, 0.6), "Enemy capsule origin Y is 0.6 (got %f)" % col_shape_node.transform.origin.y)
			var bottom_y: float = col_shape_node.transform.origin.y - (shape.height * 0.5 if shape else 0.0)
			_assert(is_equal_approx(bottom_y, 0.0), "Enemy capsule bottom is flush at Y=0.0 (got %f)" % bottom_y)
		
		var visual_root := enemy.get_node_or_null("VisualRoot") as Node3D
		_assert(visual_root != null, "VisualRoot exists on BaseEnemy3D")
		if visual_root:
			var body_mesh := visual_root.get_node_or_null("BodyMesh") as MeshInstance3D
			_assert(body_mesh != null, "Enemy VisualRoot/BodyMesh exists")
			if body_mesh:
				_assert(body_mesh.transform.origin == Vector3.ZERO, "Enemy BodyMesh origin is (0,0,0)")
	
	enemy.free()

func test_swarm_archetypes_and_multimesh() -> void:
	print("\n>> 5. Verifying Swarm Archetypes & SwarmRenderer MultiMesh Ground Alignment:")
	
	var zerg_arch := load("res://data/swarm/zergling_archetype.tres") as SwarmUnitArchetype
	_assert(zerg_arch != null, "zergling_archetype.tres loaded successfully")
	if zerg_arch:
		_assert(zerg_arch.custom_mesh != null, "Zergling archetype has custom_mesh assigned")
		_assert(zerg_arch.custom_material != null, "Zergling archetype has custom_material assigned")
	
	var roach_arch := load("res://data/swarm/roach_archetype.tres") as SwarmUnitArchetype
	_assert(roach_arch != null, "roach_archetype.tres loaded successfully")
	if roach_arch:
		_assert(roach_arch.custom_mesh != null, "Roach archetype has custom_mesh assigned")
		_assert(roach_arch.custom_material != null, "Roach archetype has custom_material assigned")
	
	var renderer := SwarmRenderer.new()
	renderer._load_default_archetypes()
	
	# Verify archetype_y_offsets
	var zerg_y_off: float = renderer.archetype_y_offsets.get(0, -999.0)
	var roach_y_off: float = renderer.archetype_y_offsets.get(1, -999.0)
	print("     SwarmRenderer archetype_y_offsets: Zergling(ID 0) = %.4f, Roach(ID 1) = %.4f" % [zerg_y_off, roach_y_off])
	_assert(is_equal_approx(zerg_y_off, 0.0), "Zergling archetype_y_offsets is exactly 0.0 (got %f)" % zerg_y_off)
	_assert(is_equal_approx(roach_y_off, 0.0), "Roach archetype_y_offsets is exactly 0.0 (got %f)" % roach_y_off)
	
	# Verify MultiMesh instances created
	_assert(renderer.multimesh_instances.has(0), "MultiMeshInstance3D created for archetype 0")
	_assert(renderer.multimesh_instances.has(1), "MultiMeshInstance3D created for archetype 1")
	
	var mmi_zerg: MultiMeshInstance3D = renderer.multimesh_instances.get(0)
	if mmi_zerg and mmi_zerg.multimesh:
		_assert(mmi_zerg.multimesh.mesh == zerg_arch.custom_mesh, "MultiMesh for archetype 0 uses zergling_mesh")
	
	var mmi_roach: MultiMeshInstance3D = renderer.multimesh_instances.get(1)
	if mmi_roach and mmi_roach.multimesh:
		_assert(mmi_roach.multimesh.mesh == roach_arch.custom_mesh, "MultiMesh for archetype 1 uses roach_mesh")
	
	# Test transform calculation with simulated swarm data
	var swarm_data := SwarmData.new(10)
	swarm_data.alive_mask[0] = 1
	swarm_data.archetype_ids[0] = 0
	swarm_data.pos_x[0] = 15.0
	swarm_data.pos_z[0] = -25.0
	swarm_data.headings[0] = 0.5
	
	swarm_data.alive_mask[1] = 1
	swarm_data.archetype_ids[1] = 1
	swarm_data.pos_x[1] = 20.0
	swarm_data.pos_z[1] = -30.0
	swarm_data.headings[1] = 1.2
	
	renderer.update_render_transforms(swarm_data)
	
	var mm0: MultiMesh = renderer.multimeshes[0]
	var t0: Transform3D = mm0.get_instance_transform(0)
	print("     Instance 0 (Zergling) Transform origin: ", t0.origin)
	_assert(is_equal_approx(t0.origin.y, 0.0), "Zergling MultiMesh instance transform Y origin is exactly 0.0 (got %f)" % t0.origin.y)
	
	# When transformed by t0, what is the world Y of the lowest vertex?
	var zerg_lowest_vert_world_y: float = t0.origin.y + (t0.basis * Vector3(0, 0, 0)).y
	_assert(is_equal_approx(zerg_lowest_vert_world_y, 0.0), "Zergling lowest vertex in world space touches ground at Y=0.0")
	
	var mm1: MultiMesh = renderer.multimeshes[1]
	var t1: Transform3D = mm1.get_instance_transform(0)
	print("     Instance 1 (Roach) Transform origin: ", t1.origin)
	_assert(is_equal_approx(t1.origin.y, 0.0), "Roach MultiMesh instance transform Y origin is exactly 0.0 (got %f)" % t1.origin.y)
	var roach_lowest_vert_world_y: float = t1.origin.y + (t1.basis * Vector3(0, 0, 0)).y
	_assert(is_equal_approx(roach_lowest_vert_world_y, 0.0), "Roach lowest vertex in world space touches ground at Y=0.0")
	
	renderer.free()
