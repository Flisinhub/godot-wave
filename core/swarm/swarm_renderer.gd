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


func register_archetype(archetype_id: int, archetype: SwarmUnitArchetype) -> void:
	archetypes[archetype_id] = archetype
	archetype_scales[archetype_id] = archetype.mesh_scale
	archetype_y_offsets[archetype_id] = archetype.mesh_scale.y * 0.5
	
	_create_or_update_multimesh(archetype_id, archetype.custom_mesh, archetype.custom_material, archetype.body_color)


func register_fallback_archetype(archetype_id: int, _name: String, color: Color, scale: Vector3) -> void:
	archetype_scales[archetype_id] = scale
	archetype_y_offsets[archetype_id] = scale.y * 0.5
	_create_or_update_multimesh(archetype_id, null, null, color)


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
	
	mesh.material = mat
	mm.mesh = mesh
	mmi.multimesh = mm
	multimeshes[archetype_id] = mm


func ensure_capacity(target_capacity: int) -> void:
	if target_capacity > max_instances_per_archetype:
		max_instances_per_archetype = target_capacity
		for mm in multimeshes.values():
			if mm.instance_count < max_instances_per_archetype:
				mm.instance_count = max_instances_per_archetype


func update_render_transforms(swarm_data: SwarmData) -> void:
	if swarm_data.capacity > max_instances_per_archetype:
		ensure_capacity(swarm_data.capacity)
	
	var counters: Dictionary = {}
	for arch_id in multimeshes.keys():
		counters[arch_id] = 0
	
	var alive := swarm_data.alive_mask
	var arch_ids := swarm_data.archetype_ids
	var px := swarm_data.pos_x
	var pz := swarm_data.pos_z
	var headings := swarm_data.headings
	var cap: int = swarm_data.capacity
	
	for i in range(cap):
		if alive[i] == 0:
			continue
		
		var a_id: int = arch_ids[i]
		if not multimeshes.has(a_id):
			continue
		
		var mm: MultiMesh = multimeshes[a_id]
		var inst_idx: int = counters[a_id]
		if inst_idx >= mm.instance_count:
			var new_sz: int = maxi(mm.instance_count * 2, inst_idx + 1)
			mm.instance_count = new_sz
			max_instances_per_archetype = maxi(max_instances_per_archetype, new_sz)
		
		var scale: Vector3 = archetype_scales.get(a_id, Vector3.ONE)
		var y_off: float = archetype_y_offsets.get(a_id, 0.0)
		var angle: float = headings[i]
		
		var basis := Basis(Vector3.UP, angle).scaled(scale)
		var origin := Vector3(px[i], y_off, pz[i])
		var t := Transform3D(basis, origin)
		
		mm.set_instance_transform(inst_idx, t)
		counters[a_id] = inst_idx + 1
	
	for arch_id in multimeshes.keys():
		var mm: MultiMesh = multimeshes[arch_id]
		mm.visible_instance_count = counters[arch_id]
