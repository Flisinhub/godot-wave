shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

// Plasma Shield: Luminous hexagonal energy dome with fresnel rim and emission 2.8

uniform vec4 shield_color : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform vec4 hex_edge_color : source_color = vec4(0.6, 0.95, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 2.8;
uniform float hex_scale : hint_range(1.0, 50.0) = 18.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float fresnel_power : hint_range(0.5, 6.0) = 2.2;

// Hexagonal tiling helper
vec2 hex_coords(vec2 uv) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	return dot(a, a) < dot(b, b) ? a : b;
}

void fragment() {
	// Fresnel rim glow
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);

	// Hexagonal lattice coordinates
	vec2 uv_scaled = UV * hex_scale;
	vec2 h_coord = hex_coords(uv_scaled);
	float dist_to_edge = max(abs(h_coord.x) * 1.5 + abs(h_coord.y) * 0.866025, abs(h_coord.y) * 1.7320508);
	float hex_border = smoothstep(0.75, 0.95, dist_to_edge);

	// Energy pulse traveling across dome
	float wave = sin(UV.y * 14.0 - TIME * pulse_speed) * 0.5 + 0.5;
	float energy_glow = mix(0.2, 0.8, wave);

	// Combine base shield tint, hexagonal lattice, and fresnel
	vec3 col = mix(shield_color.rgb, hex_edge_color.rgb, hex_border);
	float alpha = clamp((hex_border * 0.7 + fresnel * 0.9 + energy_glow * 0.25), 0.0, 1.0);

	ALBEDO = col * emission_energy;
	ALPHA = alpha * 0.85;
}
