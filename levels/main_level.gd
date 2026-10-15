class_name MainLevel
extends Node3D

## MainLevel - Primary battleground for Sprint 1.
## Sets up volcanic Char atmosphere, fortified Terran base, and navigation.

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var rts_controller: RTSController = $RTSController
@onready var camera_rig: RTSCamera3D = $RTSCamera3D

func _ready() -> void:
	# Temporarily disable gate door collisions during bake so the navigation mesh
	# creates walkable corridors through the blast door openings.
	var gates: Array[Node] = get_tree().get_nodes_in_group("gates")
	for node in gates:
		if node is GateStructure:
			var gate: GateStructure = node as GateStructure
			if gate.door_collision:
				gate.door_collision.disabled = true

	# Ensure Jolt physics has updated the collision shape state before baking
	await get_tree().physics_frame

	# Ensure navigation mesh is baked with Static Colliders
	if nav_region:
		if not nav_region.navigation_mesh:
			var nav_mesh: NavigationMesh = NavigationMesh.new()
			nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
			nav_mesh.agent_radius = 0.5
			nav_mesh.agent_height = 1.75
			nav_mesh.agent_max_climb = 0.5
			nav_mesh.cell_size = 0.25
			nav_mesh.cell_height = 0.25
			nav_region.navigation_mesh = nav_mesh
		else:
			nav_region.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS

		nav_region.bake_navigation_mesh(false)

	# Ensure navigation mesh is fully registered before restoring gate physical collision
	await get_tree().physics_frame

	# Restore gate states and collisions according to their configured initial_state
	for node in gates:
		if node is GateStructure:
			var gate: GateStructure = node as GateStructure
			if gate.initial_state == GateStructure.GateState.CLOSED:
				gate.close_gate(false)
			else:
				gate.open_gate(false)
