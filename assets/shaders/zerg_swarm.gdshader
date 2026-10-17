shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Zerg Swarm GPU Instanced PBR Shader with Organic Locomotion
// Provides high-performance vertex displacement for scuttling/waddling
// without any CPU animation overhead, maintaining >60 FPS for >1,000 units.

uniform vec4 albedo_carapace : source_color = vec4(0.24, 0.10, 0.28, 1.0);
uniform vec4 albedo_flesh : source_color = vec4(0.38, 0.08, 0.12, 1.0);
uniform vec4 emission_color : source_color = vec4(0.25, 1.0, 0.25, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 3.0;

uniform float metallic : hint_range(0.0, 1.0) = 0.12;
uniform float roughness : hint_range(0.0, 1.0) = 0.32;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.65;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.20;

// Locomotion tuning parameters
uniform float scuttle_speed = 18.0;
uniform float leg_stride = 0.08;
uniform float leg_lift = 0.04;
uniform float body_sway = 0.025;
uniform float breathing_rate = 3.0;

void vertex() {
	// Instance world position provides unique animation phase per swarm member
	vec3 world_pos = MODEL_MATRIX[3].xyz;
	float instance_phase = (world_pos.x * 2.13 + world_pos.z * 1.77);
	float t = TIME * scuttle_speed + instance_phase;
	
	// Separate locomotion logic by vertex height and anatomical region
	if (VERTEX.y < 0.35) {
		// Leg scuttling kinematics:
		// Alternate left (x < 0) vs right (x > 0) and front (z < 0) vs back (z > 0)
		float leg_phase = sign(VERTEX.x) * 1.57 + sign(VERTEX.z) * 0.78;
		float stride_cycle = sin(t + leg_phase);
		float lift_cycle = max(0.0, cos(t + leg_phase));
		
		// Move legs back and forth along heading axis (Z) and lift off ground
		VERTEX.z += stride_cycle * leg_stride;
		VERTEX.y += lift_cycle * leg_lift;
		
		// Lateral claw reach
		VERTEX.x += sin(t + leg_phase) * (leg_stride * 0.35);
	} else {
		// Dorsal carapace, spine, and raptor blades undulation
		float sway_cycle = sin(t * 0.5) * body_sway;
		VERTEX.x += sway_cycle;
		
		// Breathing / pulsing bio-glands
		float breath = sin(TIME * breathing_rate + instance_phase) * 0.015;
		VERTEX += NORMAL * breath;
		
		// Raptor scythe blade / head twitch (forward vertices)
		if (VERTEX.z < -0.15) {
			VERTEX.y += sin(t * 0.75) * 0.02;
		}
	}
}

void fragment() {
	// COLOR.r determines Carapace (1.0) vs Underbelly Flesh (0.0)
	// COLOR.g determines Emissive bio-glands / eyes / acid conduits (1.0)
	float carapace_blend = clamp(COLOR.r, 0.0, 1.0);
	float emission_mask = clamp(COLOR.g, 0.0, 1.0);
	
	// Blend base albedo between chitinous shell and fleshy tissue
	vec3 base_color = mix(albedo_flesh.rgb, albedo_carapace.rgb, carapace_blend);
	
	// Apply emission on glands/eyes
	vec3 emit = emission_color.rgb * (emission_mask * emission_energy);
	
	ALBEDO = base_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	EMISSION = emit;
}
