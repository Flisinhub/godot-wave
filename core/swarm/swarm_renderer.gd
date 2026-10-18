class_name SwarmRenderer
extends Node3D

## SwarmRenderer - MultiMesh batch renderer for swarm simulation.
## Manages high-performance GPU instanced draw calls per archetype (Zergling, Roach, etc.).

@export var max_instances_per_archetype: int = 4096

var archetypes: Dictionary = {} # archetype_id (int) -> SwarmUnitArchetype
var multimesh_instances: Dictionary = {} # archetype_id (int) -> MultiMeshInstance3D
var multimeshes: Dictionary = {} # archetype_id (int) -> MultiMesh
var archetype_scales: Dictionary = {} # archetype_id (int) -> Vector3
var archetype_y_offsets: Dictionary = {} # archetype_id (int) -> float

var _flat_scales: Array[Vector3] = []
var _flat_y_offsets: PackedFloat32Array = PackedFloat32Array()
var _flat_mm: Array[MultiMesh] = []
var _flat_counters: PackedInt32Array = PackedInt32Array()
var _cached_basis_y: Array[Vector3] = []
var _cached_scale_x: PackedFloat32Array = PackedFloat32Array()
var _cached_scale_z: PackedFloat32Array = PackedFloat32Array()
var _cache_valid: bool = false


func _ready() -> void:
	# Ensure default archetypes are loaded if none registered
	if archetypes.is_empty():
		_load_default_archetypes()


func _load_default_archetypes() -> void:
	var zergling_path: String = "res://data/swarm/zergling_archetype.tres"
	if ResourceLoader.exists(zergling_path):
		var zerg_res: SwarmUnitArchetype = load(zergling_path) as SwarmUnitArchetype
		if zerg_res:
			register_archetype(zerg_res.archetype_id, zerg_res)
	else:
		register_fallback_archetype(0, "Zergling", Color(0.25, 0.08, 0.35), Vector3(0.8, 0.7, 1.1))
	
	var roach_path: String = "res://data/swarm/roach_archetype.tres"
	if ResourceLoader.exists(roach_path):
		var roach_res: SwarmUnitArchetype = load(roach_path) as SwarmUnitArchetype
		if roach_res:
			register_archetype(roach_res.archetype_id, roach_res)
	else:
		register_fallback_archetype(1, "Roach", Color(0.3, 0.2, 0.12), Vector3(1.15, 0.95, 1.3))

	var baneling_path: String = "res://data/swarm/baneling_archetype.tres"
	if ResourceLoader.exists(baneling_path):
		var baneling_res: SwarmUnitArchetype = load(baneling_path) as SwarmUnitArchetype
		if baneling_res:
			register_archetype(baneling_res.archetype_id, baneling_res)
	else:
		register_fallback_archetype(2, "Baneling", Color(0.18, 0.45, 0.12), Vector3(0.9, 0.85, 0.9))

	var hydralisk_path: String = "res://data/swarm/hydralisk_archetype.tres"
	if ResourceLoader.exists(hydralisk_path):
		var hydra_res: SwarmUnitArchetype = load(hydralisk_path) as SwarmUnitArchetype
		if hydra_res:
			register_archetype(hydra_res.archetype_id, hydra_res)
	else:
		register_fallback_archetype(3, "Hydralisk", Color(0.35, 0.15, 0.38), Vector3(1.0, 1.3, 1.5))


func register_archetype(archetype_id: int, archetype: SwarmUnitArchetype) -> void:
	archetypes[archetype_id] = archetype
	archetype_scales[archetype_id] = archetype.mesh_scale

	var target_mesh: Mesh = archetype.custom_mesh
	if target_mesh == null:
		target_mesh = _try_load_archetype_mesh(archetype_id, archetype.unit_name)

	if target_mesh != null:
		archetype_y_offsets[archetype_id] = 0.0
	else:
		archetype_y_offsets[archetype_id] = archetype.mesh_scale.y * 0.5
	
	_create_or_update_multimesh(archetype_id, target_mesh, archetype.custom_material, archetype.body_color)
	_cache_valid = false


func _try_load_archetype_mesh(archetype_id: int, unit_name: String) -> Mesh:
	var name_lower := unit_name.to_lower()
	var tres_path := "res://assets/models/%s_mesh.tres" % name_lower
	if ResourceLoader.exists(tres_path):
		var m := load(tres_path) as Mesh
		if m:
			return m
	
	var glb_path := "res://assets/models/%s.glb" % name_lower
	if ResourceLoader.exists(glb_path):
		var glb_scene := load(glb_path) as PackedScene
		if glb_scene:
			var inst := glb_scene.instantiate()
			var found_mesh: Mesh = null
			var mesh_instances := inst.find_children("*", "MeshInstance3D", true, false)
			if not mesh_instances.is_empty():
				var mi := mesh_instances[0] as MeshInstance3D
				if mi and mi.mesh:
					found_mesh = mi.mesh
			inst.free()
			if found_mesh:
				return found_mesh
	return null


func register_fallback_archetype(archetype_id: int, _name: String, color: Color, scale: Vector3) -> void:
	archetype_scales[archetype_id] = scale
	archetype_y_offsets[archetype_id] = scale.y * 0.5
	_create_or_update_multimesh(archetype_id, null, null, color)
	_cache_valid = false


func _create_or_update_multimesh(archetype_id: int, custom_mesh: Mesh, custom_material: Material, fallback_color: Color) -> void:
	var mmi: MultiMeshInstance3D
	if multimesh_instances.has(archetype_id):
		mmi = multimesh_instances[archetype_id]
	else:
		mmi = MultiMeshInstance3D.new()
		mmi.name = "SwarmMMI_%d" % archetype_id
		add_child(mmi)
		multimesh_instances[archetype_id] = mmi
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.instance_count = max_instances_per_archetype
	mm.visible_instance_count = 0
	
	var mesh: Mesh = custom_mesh
	if not mesh:
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		mesh = box
	
	var mat: Material = custom_material
	if not mat:
		var std_mat := StandardMaterial3D.new()
		std_mat.albedo_color = fallback_color
		std_mat.roughness = 0.5
		mat = std_mat
	
	if mesh is PrimitiveMesh:
		mesh.material = mat
	elif mesh is ArrayMesh and mat:
		for s in range(mesh.get_surface_count()):
			mesh.surface_set_material(s, mat)
	
	if mat:
		mmi.material_override = mat
		
	mm.mesh = mesh
	mmi.multimesh = mm
	multimeshes[archetype_id] = mm
	_cache_valid = false


func ensure_capacity(target_capacity: int) -> void:
	if target_capacity > max_instances_per_archetype:
		max_instances_per_archetype = target_capacity
		for mm in multimeshes.values():
			if mm.instance_count < max_instances_per_archetype:
				mm.instance_count = max_instances_per_archetype


func _rebuild_archetype_cache() -> void:
	var max_aid: int = -1
	for arch_id in multimeshes.keys():
		if arch_id > max_aid:
			max_aid = arch_id
	if max_aid < 0:
		return
	var flat_size: int = max_aid + 1
	_flat_scales.resize(flat_size)
	_flat_y_offsets.resize(flat_size)
	_flat_mm.resize(flat_size)
	_flat_counters.resize(flat_size)
	_cached_basis_y.resize(flat_size)
	_cached_scale_x.resize(flat_size)
	_cached_scale_z.resize(flat_size)
	
	for arch_id in multimeshes.keys():
		var sc: Vector3 = archetype_scales.get(arch_id, Vector3.ONE)
		_flat_mm[arch_id] = multimeshes[arch_id]
		_flat_scales[arch_id] = sc
		_flat_y_offsets[arch_id] = archetype_y_offsets.get(arch_id, 0.0)
		_cached_basis_y[arch_id] = Vector3(0.0, sc.y, 0.0)
		_cached_scale_x[arch_id] = sc.x
		_cached_scale_z[arch_id] = sc.z
	_cache_valid = true


func update_render_transforms(swarm_data: SwarmData) -> void:
	if swarm_data.capacity > max_instances_per_archetype:
		ensure_capacity(swarm_data.capacity)
	
	if not _cache_valid:
		_rebuild_archetype_cache()
	
	_flat_counters.fill(0)
	
	var active_limit: int = swarm_data.active_count
	if active_limit <= 0:
		for arch_id in multimeshes.keys():
			multimeshes[arch_id].visible_instance_count = 0
		return
	
	var alive := swarm_data.alive_mask
	var arch_ids := swarm_data.archetype_ids
	var px := swarm_data.pos_x
	var pz := swarm_data.pos_z
	var headings := swarm_data.headings
	var cap: int = swarm_data.capacity
	var processed: int = 0
	
	# Pre-bind cached arrays to local variables for fastest GDScript register access
	var flat_mm := _flat_mm
	var flat_cnt := _flat_counters
	var flat_y_off := _flat_y_offsets
	var flat_basis_y := _cached_basis_y
	var flat_sx := _cached_scale_x
	var flat_sz := _cached_scale_z
	var flat_size: int = flat_mm.size()
	
	for i in range(cap):
		if alive[i] == 0:
			continue
		
		var a_id: int = arch_ids[i]
		if a_id < 0 or a_id >= flat_size:
			processed += 1
			if processed >= active_limit:
				break
			continue
		
		var mm: MultiMesh = flat_mm[a_id]
		if mm == null:
			processed += 1
			if processed >= active_limit:
				break
			continue
		
		var inst_idx: int = flat_cnt[a_id]
		var angle: float = headings[i]
		var cur_px: float = px[i]
		var cur_pz: float = pz[i]
		var cur_y: float = flat_y_off[a_id]
		
		# Direct column Basis construction: eliminates .scaled() dynamic matrix multiplication
		var ca := cos(angle)
		var sa := sin(angle)
		var sx := flat_sx[a_id]
		var sz := flat_sz[a_id]
		
		var t := Transform3D(
			Vector3(ca * sx, 0.0, -sa * sx),
			flat_basis_y[a_id],
			Vector3(sa * sz, 0.0, ca * sz),
			Vector3(cur_px, cur_y, cur_pz)
		)
		
		mm.set_instance_transform(inst_idx, t)
		flat_cnt[a_id] = inst_idx + 1
		
		processed += 1
		if processed >= active_limit:
			break
	
	for arch_id in multimeshes.keys():
		multimeshes[arch_id].visible_instance_count = flat_cnt[arch_id]
