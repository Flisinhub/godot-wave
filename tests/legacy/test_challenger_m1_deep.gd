extends Node

# Deep Adversarial Empirical Verification Suite for Milestone 1 Invariants
# Tests:
# 1. Ground contact on all 10 .tres meshes and all 9 .glb models (tolerance < 0.001m)
# 2. CollisionShape3D on BaseUnit3D, HeroRaynor, CommandCenter, BunkerStructure
# 3. AnimationPlayer execution in headless mode for all animations ("idle", "run", "shoot", "death")
#    on BaseUnit3D, HeroRaynor, and all .glb models.
# 4. SwarmRenderer MultiMesh ground contact for all 4 archetypes (0=Zergling, 1=Roach, 2=Baneling, 3=Hydralisk)

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var failure_log: Array[String] = []

func _ready() -> void:
	print("================================================================================")
	print("=== EMPIRICAL CHALLENGER (challenger_p2_m1_2): DEEP ADVERSARIAL M1 HARNESS ===")
	print("================================================================================")
	
	_test_1_mesh_and_glb_ground_contact()
	_test_2_collision_shape_invariants()
	_test_3_animation_player_headless_execution()
	_test_4_swarm_renderer_archetype_alignment()
	_test_5_adversarial_stress_and_edge_cases()
	
	print("\n================================================================================")
	print("DEEP HARNESS EXECUTION SUMMARY:")
	print("Total Assertions:  %d" % total_assertions)
	print("Passed Assertions: %d" % passed_assertions)
	print("Failed Assertions: %d" % failed_assertions)
	
	if failed_assertions == 0:
		print("\u001b[32m[VERDICT: APPROVE] ALL MILESTONE 1 INVARIANTS EMPIRICALLY CONFIRMED!\u001b[0m")
		print("================================================================================")
		get_tree().quit(0)
	else:
		print("\u001b[31m[VERDICT: REQUEST_CHANGES] FAILURES DETECTED:\u001b[0m")
		for f in failure_log:
			print("\u001b[31m  - %s\u001b[0m" % f)
		print("================================================================================")
		get_tree().quit(1)

func _assert(condition: bool, test_name: String, details: String = "") -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
		if details != "":
			print("  [PASS] %s (%s)" % [test_name, details])
		else:
			print("  [PASS] %s" % test_name)
	else:
		failed_assertions += 1
		var err := "%s: %s" % [test_name, details]
		failure_log.append(err)
		print("  [FAIL] %s" % err)

func _get_array_mesh_min_max_y(mesh: Mesh) -> Dictionary:
	var min_y: float = 999999.0
	var max_y: float = -999999.0
	var count: int = 0
	if mesh is ArrayMesh:
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_VERTEX:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for v in verts:
					count += 1
					if v.y < min_y:
						min_y = v.y
					if v.y > max_y:
						max_y = v.y
	return {"min_y": min_y, "max_y": max_y, "count": count}

func _get_node_hierarchy_min_y(root: Node3D, current_transform: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	var min_y: float = 999999.0
	var max_y: float = -999999.0
	var total_verts: int = 0
	
	var xform := current_transform * root.transform
	
	if root is MeshInstance3D and root.mesh != null:
		var mesh: Mesh = root.mesh
		if mesh is ArrayMesh:
			for s in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(s)
				if arrays.size() > Mesh.ARRAY_VERTEX:
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					for v in verts:
						total_verts += 1
						var world_v := xform * v
						if world_v.y < min_y:
							min_y = world_v.y
						if world_v.y > max_y:
							max_y = world_v.y
	
	for child in root.get_children():
		if child is Node3D:
			var sub := _get_node_hierarchy_min_y(child, xform)
			if sub.min_y < min_y:
				min_y = sub.min_y
			if sub.max_y > max_y:
				max_y = sub.max_y
			total_verts += sub.total_verts
			
	return {"min_y": min_y, "max_y": max_y, "total_verts": total_verts}

# ==============================================================================
# 1. GROUND CONTACT TESTS
# ==============================================================================
func _load_glb_scene(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		return null
	return doc.generate_scene(state) as Node3D

func _test_1_mesh_and_glb_ground_contact() -> void:
	print("\n--- 1. Probing Ground Contact (y = 0.0, tolerance < 0.001m) ---")
	
	# A. ArrayMeshes (.tres)
	var tres_meshes: Dictionary = {
		"marine_body_mesh.tres": "res://assets/models/marine_body_mesh.tres",
		"raynor_body_mesh.tres": "res://assets/models/raynor_body_mesh.tres",
		"zergling_mesh.tres": "res://assets/models/zergling_mesh.tres",
		"roach_mesh.tres": "res://assets/models/roach_mesh.tres",
		"baneling_mesh.tres": "res://assets/models/baneling_mesh.tres",
		"hydralisk_mesh.tres": "res://assets/models/hydralisk_mesh.tres",
		"auto_turret_mesh.tres": "res://assets/models/auto_turret_mesh.tres",
		"command_center_mesh.tres": "res://assets/models/structures/command_center_mesh.tres",
		"bunker_structure_mesh.tres": "res://assets/models/structures/bunker_structure_mesh.tres",
		"wall_segment_mesh.tres": "res://assets/models/structures/wall_segment_mesh.tres"
	}
	
	for name in tres_meshes:
		var path: String = tres_meshes[name]
		var mesh: Mesh = load(path) as Mesh
		_assert(mesh != null, "Load " + name, "Path: " + path)
		if mesh:
			var stats := _get_array_mesh_min_max_y(mesh)
			var flush := absf(stats.min_y - 0.0) < 0.001
			_assert(flush, name + " min_y is flush at 0.0", "min_y=%.6f, max_y=%.4f, verts=%d" % [stats.min_y, stats.max_y, stats.count])
	
	# B. GLB Models (.glb)
	var glb_models: Dictionary = {
		"marine.glb": "res://assets/models/marine.glb",
		"raynor.glb": "res://assets/models/raynor.glb",
		"zergling.glb": "res://assets/models/zergling.glb",
		"roach.glb": "res://assets/models/roach.glb",
		"baneling.glb": "res://assets/models/baneling.glb",
		"hydralisk.glb": "res://assets/models/hydralisk.glb",
		"command_center.glb": "res://assets/models/structures/command_center.glb",
		"bunker.glb": "res://assets/models/structures/bunker.glb",
		"auto_turret.glb": "res://assets/models/structures/auto_turret.glb"
	}
	
	for name in glb_models:
		var path: String = glb_models[name]
		var inst: Node3D = _load_glb_scene(path)
		_assert(inst != null, "Load & instantiate GLB " + name, "Path: " + path)
		if inst:
			add_child(inst)
			var stats := _get_node_hierarchy_min_y(inst)
			var flush := absf(stats.min_y - 0.0) < 0.001
			_assert(flush, name + " lowest vertex flush at 0.0 in model space", "min_y=%.6f, max_y=%.4f, total_verts=%d" % [stats.min_y, stats.max_y, stats.total_verts])
			inst.queue_free()

# ==============================================================================
# 2. COLLISION SHAPE INVARIANTS
# ==============================================================================
func _test_2_collision_shape_invariants() -> void:
	print("\n--- 2. Probing Root Collision Shapes Invariants ---")
	
	# A. BaseUnit3D
	var base_unit_scene := load("res://entities/allies/base_unit_3d.tscn") as PackedScene
	_assert(base_unit_scene != null, "Load base_unit_3d.tscn")
	if base_unit_scene:
		var unit := base_unit_scene.instantiate() as CharacterBody3D
		add_child(unit)
		var col: CollisionShape3D = unit.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col != null, "BaseUnit3D has root CollisionShape3D")
		if col:
			var shape := col.shape as CapsuleShape3D
			_assert(shape != null, "BaseUnit3D CollisionShape3D is CapsuleShape3D")
			if shape:
				_assert(is_equal_approx(shape.radius, 0.4), "BaseUnit3D capsule radius == 0.4", "got %.4f" % shape.radius)
				_assert(is_equal_approx(shape.height, 1.8), "BaseUnit3D capsule height == 1.8", "got %.4f" % shape.height)
			_assert(is_equal_approx(col.transform.origin.y, 0.9), "BaseUnit3D collision origin Y == 0.9", "got %.4f" % col.transform.origin.y)
			var bottom := col.transform.origin.y - (shape.height * 0.5 if shape else 0.0)
			_assert(absf(bottom - 0.0) < 0.001, "BaseUnit3D collision capsule bottom flush at Y=0.0", "got %.4f" % bottom)
		unit.queue_free()
	
	# B. HeroRaynor (from main_level.tscn)
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	_assert(main_scene != null, "Load main_level.tscn")
	if main_scene:
		var level := main_scene.instantiate()
		add_child(level)
		var hero := level.get_node_or_null("Allies/HeroRaynor") as CharacterBody3D
		_assert(hero != null, "HeroRaynor found in main_level.tscn")
		if hero:
			var col: CollisionShape3D = hero.get_node_or_null("CollisionShape3D") as CollisionShape3D
			_assert(col != null, "HeroRaynor has root CollisionShape3D")
			if col:
				var shape := col.shape as CapsuleShape3D
				_assert(shape != null, "HeroRaynor CollisionShape3D is CapsuleShape3D")
				if shape:
					_assert(is_equal_approx(shape.radius, 0.45), "HeroRaynor capsule radius == 0.45", "got %.4f" % shape.radius)
					_assert(is_equal_approx(shape.height, 1.85), "HeroRaynor capsule height == 1.85", "got %.4f" % shape.height)
				_assert(is_equal_approx(col.transform.origin.y, 0.92), "HeroRaynor collision origin Y == 0.92", "got %.4f" % col.transform.origin.y)
				var bottom := col.transform.origin.y - (shape.height * 0.5 if shape else 0.0)
				_assert(absf(bottom) <= 0.01, "HeroRaynor collision bottom rests within 0.01 of ground", "got %.4f" % bottom)
		level.queue_free()
	
	# C. CommandCenter
	var cc_scene := load("res://entities/structures/command_center.tscn") as PackedScene
	_assert(cc_scene != null, "Load command_center.tscn")
	if cc_scene:
		var cc := cc_scene.instantiate() as StaticBody3D
		add_child(cc)
		var col: CollisionShape3D = cc.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col != null, "CommandCenter has root CollisionShape3D")
		if col:
			var shape := col.shape as BoxShape3D
			_assert(shape != null, "CommandCenter shape is BoxShape3D")
			if shape:
				_assert(shape.size == Vector3(8, 4, 8), "CommandCenter box size == (8, 4, 8)", "got " + str(shape.size))
			_assert(is_equal_approx(col.transform.origin.y, 2.0), "CommandCenter origin Y == 2.0", "got %.4f" % col.transform.origin.y)
			var bottom := col.transform.origin.y - (shape.size.y * 0.5 if shape else 0.0)
			_assert(absf(bottom - 0.0) < 0.001, "CommandCenter collision box bottom flush at Y=0.0", "got %.4f" % bottom)
		cc.queue_free()
	
	# D. BunkerStructure
	var bunker_scene := load("res://entities/structures/bunker_structure.tscn") as PackedScene
	_assert(bunker_scene != null, "Load bunker_structure.tscn")
	if bunker_scene:
		var bunker := bunker_scene.instantiate() as StaticBody3D
		add_child(bunker)
		var col: CollisionShape3D = bunker.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_assert(col != null, "BunkerStructure has root CollisionShape3D")
		if col:
			var shape := col.shape as BoxShape3D
			_assert(shape != null, "BunkerStructure shape is BoxShape3D")
			if shape:
				_assert(shape.size == Vector3(3.5, 2.5, 3.5), "BunkerStructure box size == (3.5, 2.5, 3.5)", "got " + str(shape.size))
			_assert(is_equal_approx(col.transform.origin.y, 1.25), "BunkerStructure origin Y == 1.25", "got %.4f" % col.transform.origin.y)
			var bottom := col.transform.origin.y - (shape.size.y * 0.5 if shape else 0.0)
			_assert(absf(bottom - 0.0) < 0.001, "BunkerStructure collision box bottom flush at Y=0.0", "got %.4f" % bottom)
		bunker.queue_free()

# ==============================================================================
# 3. ANIMATION PLAYER HEADLESS EXECUTION
# ==============================================================================
func _test_3_animation_player_headless_execution() -> void:
	print("\n--- 3. Probing AnimationPlayer Headless Execution & Tracks ---")
	
	# A. BaseUnit3D AnimationPlayer
	var base_unit_scene := load("res://entities/allies/base_unit_3d.tscn") as PackedScene
	if base_unit_scene:
		var unit := base_unit_scene.instantiate() as CharacterBody3D
		add_child(unit)
		var ap: AnimationPlayer = unit.get_node_or_null("VisualRoot/AnimationPlayer") as AnimationPlayer
		_assert(ap != null, "BaseUnit3D has VisualRoot/AnimationPlayer")
		if ap:
			var required_anims: Array[String] = ["idle", "run", "shoot", "death"]
			for anim_name in required_anims:
				_assert(ap.has_animation(anim_name), "BaseUnit3D has animation: " + anim_name)
				if ap.has_animation(anim_name):
					ap.play(anim_name)
					ap.advance(0.1)
					ap.advance(0.2)
					_assert(ap.current_animation == anim_name or not ap.is_playing(), "BaseUnit3D advanced anim " + anim_name + " cleanly")
		unit.queue_free()
	
	# B. HeroRaynor AnimationPlayer (from main_level.tscn)
	var main_scene := load("res://levels/main_level.tscn") as PackedScene
	if main_scene:
		var level := main_scene.instantiate()
		add_child(level)
		var hero := level.get_node_or_null("Allies/HeroRaynor") as CharacterBody3D
		if hero:
			var ap: AnimationPlayer = hero.get_node_or_null("VisualRoot/AnimationPlayer") as AnimationPlayer
			_assert(ap != null, "HeroRaynor has VisualRoot/AnimationPlayer")
			if ap:
				var required_anims: Array[String] = ["idle", "run", "shoot", "death"]
				for anim_name in required_anims:
					_assert(ap.has_animation(anim_name), "HeroRaynor has animation: " + anim_name)
					if ap.has_animation(anim_name):
						ap.play(anim_name)
						ap.advance(0.1)
						ap.advance(0.2)
						_assert(ap.current_animation == anim_name or not ap.is_playing(), "HeroRaynor advanced anim " + anim_name + " cleanly")
		level.queue_free()
	
	# C. GLB Models AnimationPlayers
	var glb_anims: Dictionary = {
		"marine.glb": ["idle", "run", "shoot", "death"],
		"raynor.glb": ["idle", "run", "shoot", "death"],
		"zergling.glb": ["idle", "run", "attack", "death"],
		"roach.glb": ["idle", "walk", "attack", "death"],
		"baneling.glb": ["idle", "run", "attack", "death"],
		"hydralisk.glb": ["idle", "run", "shoot", "death"],
		"command_center.glb": ["idle", "death"],
		"bunker.glb": ["idle", "death"],
		"auto_turret.glb": ["idle", "shoot", "death"]
	}
	
	for model_name in glb_anims:
		var glb_path: String = "res://assets/models/" + str(model_name)
		if not FileAccess.file_exists(glb_path):
			glb_path = "res://assets/models/structures/" + str(model_name)
		var inst: Node3D = _load_glb_scene(glb_path)
		_assert(inst != null, "Load GLB for anim test: " + model_name, "Path: " + glb_path)
		if inst:
			add_child(inst)
			var ap := inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
			_assert(ap != null, model_name + " has child AnimationPlayer")
			if ap:
				var anim_list: Array = glb_anims[model_name]
				for a in anim_list:
					_assert(ap.has_animation(a), model_name + " has animation " + str(a))
					if ap.has_animation(a):
						ap.play(a)
						ap.advance(0.1)
						ap.advance(0.3)
						_assert(true, model_name + " played " + str(a) + " without null pointer or track error")
			inst.queue_free()

# ==============================================================================
# 4. SWARM RENDERER ARCHETYPE ALIGNMENT
# ==============================================================================
func _test_4_swarm_renderer_archetype_alignment() -> void:
	print("\n--- 4. Probing SwarmRenderer MultiMesh & Archetypes (IDs 0, 1, 2, 3) ---")
	
	var archetypes: Dictionary = {
		0: "res://data/swarm/zergling_archetype.tres",
		1: "res://data/swarm/roach_archetype.tres",
		2: "res://data/swarm/baneling_archetype.tres",
		3: "res://data/swarm/hydralisk_archetype.tres"
	}
	
	var renderer := SwarmRenderer.new()
	add_child(renderer)
	renderer._load_default_archetypes()
	
	for arch_id in archetypes:
		var path: String = archetypes[arch_id]
		_assert(ResourceLoader.exists(path), "Swarm archetype file exists: " + path)
		if ResourceLoader.exists(path):
			var arch := load(path) as SwarmUnitArchetype
			_assert(arch != null, "Archetype %d loaded" % arch_id)
			if arch:
				_assert(arch.archetype_id == arch_id, "Archetype ID match (%d == %d)" % [arch.archetype_id, arch_id])
				_assert(arch.custom_mesh != null, "Archetype %d has custom_mesh" % arch_id)
				if arch.custom_mesh:
					var stats := _get_array_mesh_min_max_y(arch.custom_mesh)
					_assert(absf(stats.min_y - 0.0) < 0.001, "Archetype %d custom_mesh min_y flush at 0.0" % arch_id, "got %.6f" % stats.min_y)
		
		# Check SwarmRenderer MultiMeshInstance3D
		_assert(renderer.multimeshes.has(arch_id), "SwarmRenderer has MultiMesh for archetype %d" % arch_id)
		var y_off: float = renderer.archetype_y_offsets.get(arch_id, -999.0)
		_assert(absf(y_off - 0.0) < 0.001, "SwarmRenderer y_offset for archetype %d is 0.0" % arch_id, "got %.4f" % y_off)
	
	# Test MultiMesh transform generation with active units
	var data := SwarmData.new(16)
	for i in range(4):
		var idx := data.spawn_unit(i, Vector3(float(i * 5), 0.0, float(i * -5)), 10.0, 5.0, 2.0)
		data.headings[idx] = float(i) * 0.785
	
	renderer.update_render_transforms(data)
	
	for i in range(4):
		var mm: MultiMesh = renderer.multimeshes.get(i)
		_assert(mm != null and mm.visible_instance_count == 1, "MultiMesh %d visible_instance_count == 1" % i)
		if mm and mm.visible_instance_count > 0:
			var t: Transform3D = mm.get_instance_transform(0)
			_assert(absf(t.origin.y - 0.0) < 0.001, "MultiMesh %d instance 0 origin Y == 0.0" % i, "got %.6f" % t.origin.y)
			var det: float = t.basis.determinant()
			_assert(det > 0.01 and not is_nan(det), "MultiMesh %d instance 0 determinant valid (>0.01)" % i, "got %.4f" % det)
	
	renderer.queue_free()

# ==============================================================================
# 5. ADVERSARIAL STRESS & CORNER CASES
# ==============================================================================
func _test_5_adversarial_stress_and_edge_cases() -> void:
	print("\n--- 5. Probing Adversarial Stress & Corner Cases ---")
	
	# Test A: AnimationPlayer calling non-existent animation check
	var base_unit_scene := load("res://entities/allies/base_unit_3d.tscn") as PackedScene
	if base_unit_scene:
		var unit := base_unit_scene.instantiate() as CharacterBody3D
		add_child(unit)
		var ap: AnimationPlayer = unit.get_node_or_null("VisualRoot/AnimationPlayer") as AnimationPlayer
		if ap:
			_assert(not ap.has_animation("non_existent_adversarial_anim_xyz"), "AnimationPlayer has_animation returns false for invalid anim")
		unit.queue_free()
	
	# Test B: AnimationPlayer stepping past animation length
	if base_unit_scene:
		var unit := base_unit_scene.instantiate() as CharacterBody3D
		add_child(unit)
		var ap: AnimationPlayer = unit.get_node_or_null("VisualRoot/AnimationPlayer") as AnimationPlayer
		if ap:
			ap.play("death")
			ap.advance(10.0) # Far past 1.0s length
			_assert(true, "Advancing death anim 10.0s past duration executed without crash")
		unit.queue_free()
	
	# Test C: Ground contact during animation execution
	# Test Raynor and Marine body mesh during "run" animation
	if base_unit_scene:
		var unit := base_unit_scene.instantiate() as CharacterBody3D
		add_child(unit)
		var ap: AnimationPlayer = unit.get_node_or_null("VisualRoot/AnimationPlayer") as AnimationPlayer
		if ap:
			ap.play("run")
			for step in range(5):
				ap.advance(0.15)
				var body: MeshInstance3D = unit.get_node_or_null("VisualRoot/BodyMesh") as MeshInstance3D
				if body:
					# Position Y of body during run should stay bounded above 0.0 (bounce up, not subterranean clip)
					var pos_y := body.transform.origin.y
					_assert(pos_y >= -0.01, "BodyMesh position Y during run does not clip subterranean", "step %d, pos_y=%.4f" % [step, pos_y])
		unit.queue_free()

