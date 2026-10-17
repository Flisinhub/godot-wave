shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Planet Char Basalt Ground PBR Shader
// Features multi-octave basalt rock relief, ash dusting, and subtle geothermal embers

uniform vec4 basalt_dark : source_color = vec4(0.09, 0.08, 0.09, 1.0);
uniform vec4 basalt_mid : source_color = vec4(0.16, 0.13, 0.14, 1.0);
uniform vec4 ash_color : source_color = vec4(0.25, 0.20, 0.19, 1.0);
uniform vec4 micro_fissure_color : source_color = vec4(1.0, 0.40, 0.08, 1.0);
uniform float micro_emission_energy : hint_range(0.0, 8.0) = 1.5;
uniform float uv_scale = 32.0;

varying vec3 v_world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = rot * p * 2.02;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world_pos.xz * (uv_scale / 80.0);
	
	// Multi-frequency rock relief
	float n_rock = fbm(p);
	float n_ash = fbm(p * 0.35 + vec2(14.2, 7.8));
	
	// Crack lines in basalt rock
	float cracks = smoothstep(0.44, 0.52, abs(n_rock - 0.5));
	
	// Ash deposits settling in lower crags
	float ash_mask = smoothstep(0.52, 0.70, n_ash);
	
	// Base color blending
	vec3 rock_albedo = mix(basalt_dark.rgb, basalt_mid.rgb, cracks);
	vec3 final_albedo = mix(rock_albedo, ash_color.rgb, ash_mask * 0.75);
	
	// Subsurface geothermal embers in rock crevices
	float fissure_mask = (1.0 - smoothstep(0.0, 0.04, abs(n_rock - 0.49))) * (1.0 - ash_mask);
	float pulse = 0.85 + 0.15 * sin(TIME * 1.8 + v_world_pos.x * 0.5 + v_world_pos.z * 0.5);
	vec3 emission = micro_fissure_color.rgb * (micro_emission_energy * fissure_mask * pulse);
	
	// Procedural normal mapping from height derivatives
	float eps = 0.06;
	float hL = fbm(p - vec2(eps, 0.0));
	float hR = fbm(p + vec2(eps, 0.0));
	float hD = fbm(p - vec2(0.0, eps));
	float hU = fbm(p + vec2(0.0, eps));
	vec3 world_norm = normalize(vec3((hL - hR) * 2.8, 1.0, (hD - hU) * 2.8));
	
	ALBEDO = final_albedo;
	EMISSION = emission;
	ROUGHNESS = mix(0.72, 0.94, ash_mask) - fissure_mask * 0.35;
	METALLIC = 0.14 * (1.0 - ash_mask);
	SPECULAR = 0.35;
	NORMAL = (VIEW_MATRIX * vec4(world_norm, 0.0)).xyz;
}
