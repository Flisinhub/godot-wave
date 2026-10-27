shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

// Revolving Protective Hexagonal Energy Matrix for Stetmann Defensive Matrix

uniform vec4 matrix_color : source_color = vec4(0.15, 0.95, 0.65, 1.0);
uniform vec4 hex_glow_color : source_color = vec4(0.4, 1.0, 0.85, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 2.8;
uniform float hex_scale : hint_range(1.0, 40.0) = 14.0;
uniform float rotation_speed : hint_range(-10.0, 10.0) = 1.8;

vec2 hex_coords(vec2 uv) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	return dot(a, a) < dot(b, b) ? a : b;
}

void fragment() {
	// Revolving rotation around vertical axis (UV.x)
	vec2 uv_rotated = UV;
	uv_rotated.x += TIME * rotation_speed * 0.1;
	
	vec2 uv_scaled = uv_rotated * hex_scale;
	vec2 h_coord = hex_coords(uv_scaled);
	float dist_to_edge = max(abs(h_coord.x) * 1.5 + abs(h_coord.y) * 0.866025, abs(h_coord.y) * 1.7320508);
	float hex_border = smoothstep(0.72, 0.94, dist_to_edge);

	// Fresnel rim glow
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);

	// Secondary counter-rotating matrix layer
	vec2 uv_counter = UV;
	uv_counter.x -= TIME * rotation_speed * 0.07;
	vec2 h2 = hex_coords(uv_counter * (hex_scale * 0.7));
	float dist2 = max(abs(h2.x) * 1.5 + abs(h2.y) * 0.866025, abs(h2.y) * 1.7320508);
	float hex_border2 = smoothstep(0.75, 0.96, dist2);

	float net_hex = max(hex_border, hex_border2 * 0.6);
	vec3 col = mix(matrix_color.rgb, hex_glow_color.rgb, net_hex);
	float alpha = clamp(net_hex * 0.8 + fresnel * 0.6, 0.0, 1.0);

	ALBEDO = col * emission_energy;
	ALPHA = alpha * 0.8;
}
