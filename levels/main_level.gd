class_name MainLevel
extends Node3D

## MainLevel - Primary battleground for Sprint 1.
## Sets up volcanic Char atmosphere, fortified Terran base, and navigation.

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var rts_controller: RTSController = $RTSController
@onready var camera_rig: RTSCamera3D = $RTSCamera3D

func _ready() -> void:
	# Ensure the navigation mesh is baked and ready for immediate unit micromanagement
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
		
		# Bake navigation mesh synchronously so units have paths ready on frame 1
		nav_region.bake_navigation_mesh(false)
