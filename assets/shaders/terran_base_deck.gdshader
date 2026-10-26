shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Terran Industrial Base Deck Foundation Shader
// Heavy diamond steel plating with perimeter hazard borders and glowing power conduits

uniform vec4 steel_albedo : source_color = vec4(0.22, 0.25, 0.28, 1.0);
uniform vec4 steel_dark : source_color = vec4(0.13, 0.15, 0.17, 1.0);
uniform vec4 hazard_yellow : source_color = vec4(0.95, 0.75, 0.10, 1.0);
uniform vec4 hazard_black : source_color = vec4(0.10, 0.10, 0.10, 1.0);
uniform vec4 conduit_blue : source_color = vec4(0.15, 0.55, 1.0, 1.0);
uniform float conduit_emission_energy = 2.5;
uniform vec2 deck_min = vec2(-37.0, 14.5);
uniform vec2 deck_max = vec2(-14.5, 37.0);
uniform vec2 cc_pos = vec2(-24.0, 24.0);

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV;
	
	// Panel grid seams (every 4 meters)
	vec2 grid = abs(fract(v_world_pos.xz * 0.25) - 0.5);
	float seam = 1.0 - smoothstep(0.46, 0.49, max(grid.x, grid.y));
	
	// Diamond tread micro-relief
	vec2 tread_uv = fract(v_world_pos.xz * 4.0) - 0.5;
	float diamond = 1.0 - smoothstep(0.18, 0.32, abs(tread_uv.x) + abs(tread_uv.y));
	
	// Perimeter hazard warning border (1.2m margin along perimeter boundaries)
	float border_x = min(v_world_pos.x - deck_min.x, deck_max.x - v_world_pos.x);
	float border_z = min(v_world_pos.z - deck_min.y, deck_max.y - v_world_pos.z);
	float border_dist = min(border_x, border_z);
	// Leave choke point breach open without hazard border near (-17.5, 17.5)
	float dist_to_breach = distance(v_world_pos.xz, vec2(-17.5, 17.5));
	float is_border = (1.0 - smoothstep(0.4, 1.2, border_dist)) * smoothstep(2.5, 4.5, dist_to_breach);
	
	// 45-degree diagonal hazard stripes
	float stripe_diag = fract((v_world_pos.x + v_world_pos.z) * 1.2);
	float stripe_mask = step(0.5, stripe_diag);
	vec3 hazard_color = mix(hazard_black.rgb, hazard_yellow.rgb, stripe_mask);
	
	// Central power conduits radiating from CommandCenter at (-24, 24)
	// Conduit line 1: diagonal trunk towards choke point
	vec2 to_choke = v_world_pos.xz - cc_pos;
	float diag_dist = abs(to_choke.x + to_choke.y) * 0.7071;
	float line_choke = (1.0 - smoothstep(0.10, 0.24, diag_dist)) * step(-26.0, v_world_pos.x) * step(v_world_pos.x, -16.0);
	
	// Conduit line 2: line towards ArmoryTerminal at (-20, 26)
	float line_armory = (1.0 - smoothstep(0.10, 0.22, abs(v_world_pos.z - 26.0))) * step(-25.0, v_world_pos.x) * step(v_world_pos.x, -19.0);
	
	// Conduit line 3: line towards RallyPoint at (-22, 20)
	float line_rally = (1.0 - smoothstep(0.10, 0.22, abs(v_world_pos.x - (-22.0)))) * step(19.0, v_world_pos.z) * step(v_world_pos.z, 25.0);
	
	float conduit_line = max(line_choke, max(line_armory, line_rally));
	float conduit_pulse = 0.85 + 0.15 * sin(TIME * 2.2 - (v_world_pos.x + v_world_pos.z) * 0.6);
	vec3 conduit_glow = conduit_blue.rgb * (conduit_emission_energy * conduit_pulse * conduit_line);
	
	// Final plate albedo
	vec3 deck_albedo = mix(steel_albedo.rgb, steel_dark.rgb, seam * 0.6);
	deck_albedo = mix(deck_albedo, steel_albedo.rgb * 1.2, diamond * 0.15);
	deck_albedo = mix(deck_albedo, hazard_color, is_border);
	deck_albedo = mix(deck_albedo, conduit_blue.rgb * 0.4, conduit_line * 0.8);
	
	ALBEDO = deck_albedo;
	EMISSION = conduit_glow * (1.0 - is_border);
	METALLIC = mix(0.85, 0.30, is_border * 0.5);
	ROUGHNESS = mix(0.32, 0.60, is_border) + seam * 0.2;
	SPECULAR = 0.70;
}
