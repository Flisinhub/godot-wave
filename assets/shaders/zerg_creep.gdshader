shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Zerg Creep / Biomass Organic Membrane Shader
// Glistening bio-purple slime with alien luminescent veins and living respiration

uniform vec4 creep_base : source_color = vec4(0.16, 0.05, 0.22, 1.0);
uniform vec4 creep_flesh : source_color = vec4(0.30, 0.08, 0.32, 1.0);
uniform vec4 bio_vein_glow : source_color = vec4(0.30, 0.95, 0.45, 1.0);
uniform float vein_emission_energy : hint_range(0.0, 10.0) = 2.6;
uniform float gloss_roughness : hint_range(0.0, 1.0) = 0.20;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.85;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.12;
uniform float pulse_speed : hint_range(0.1, 5.0) = 2.2;
uniform float uv_scale = 6.0;

varying vec3 v_world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 2D Cellular / Voronoi pattern for organic bio-cells and vein boundaries
vec2 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	vec2 mg = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash(n + g), hash(n + g + vec2(17.3, 31.7)));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mg = g;
			}
		}
	}
	return vec2(sqrt(md), hash(n + mg));
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
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p = rot * p * 2.02;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Living organism respiratory undulation
	float breathing = sin(TIME * pulse_speed + VERTEX.x * 2.2 + VERTEX.z * 2.2) * 0.015;
	VERTEX.y += breathing;
}

void fragment() {
	vec2 p = UV * uv_scale;
	
	// Organic cell lobes & vein channels
	vec2 v = voronoi(p);
	float cell_dist = v.x;
	float cell_id = v.y;
	
	// Wrinkled fleshy micro-tissue
	float flesh_wrinkles = fbm(p * 2.5 + vec2(TIME * 0.02, 0.0));
	
	// Alien veins along cell boundaries
	float vein_mask = 1.0 - smoothstep(0.08, 0.22, cell_dist);
	float pustule_mask = smoothstep(0.35, 0.70, cell_dist);
	
	// Bioluminescent vein pulse
	float vein_pulse = 0.70 + 0.30 * sin(TIME * pulse_speed * 1.4 + cell_id * 6.28);
	vec3 vein_emission = bio_vein_glow.rgb * (vein_emission_energy * vein_mask * vein_pulse);
	
	// Color blending across slimy membrane
	vec3 base_color = mix(creep_base.rgb, creep_flesh.rgb, pustule_mask);
	base_color = mix(base_color, bio_vein_glow.rgb * 0.4, vein_mask * 0.5);
	
	// Organic surface normal
	float eps = 0.06;
	float vL = voronoi(p - vec2(eps, 0.0)).x;
	float vR = voronoi(p + vec2(eps, 0.0)).x;
	float vD = voronoi(p - vec2(0.0, eps)).x;
	float vU = voronoi(p + vec2(0.0, eps)).x;
	vec3 world_norm = normalize(vec3((vL - vR) * 1.8, 1.0, (vD - vU) * 1.8));
	
	ALBEDO = base_color;
	EMISSION = vein_emission;
	ROUGHNESS = gloss_roughness + (1.0 - pustule_mask) * 0.12;
	METALLIC = 0.08;
	SPECULAR = 0.85;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	NORMAL = (VIEW_MATRIX * vec4(world_norm, 0.0)).xyz;
}
