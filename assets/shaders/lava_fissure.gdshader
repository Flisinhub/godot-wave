shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Planet Char Emissive Magma Fissure Shader
// High-energy thermal emission (multiplier >= 3.0) with fluid turbulence and crust cracking

uniform vec4 magma_core : source_color = vec4(1.0, 0.75, 0.20, 1.0);
uniform vec4 magma_flow : source_color = vec4(0.95, 0.25, 0.04, 1.0);
uniform vec4 crust_color : source_color = vec4(0.12, 0.07, 0.06, 1.0);
uniform float emission_energy : hint_range(1.0, 16.0) = 4.5;
uniform float flow_speed : hint_range(0.01, 1.0) = 0.07;
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.8;
uniform float uv_scale = 5.0;

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
	// Boiling thermal convection micro-displacement
	float bubble = sin(TIME * pulse_speed * 1.5 + VERTEX.x * 4.0 + VERTEX.z * 4.0) * 0.012;
	VERTEX.y += bubble;
}

void fragment() {
	// Opposing UV currents for churning molten turbulence
	vec2 uv1 = UV * uv_scale + vec2(TIME * flow_speed, TIME * flow_speed * 0.35);
	vec2 uv2 = UV * (uv_scale * 1.35) + vec2(-TIME * flow_speed * 0.5, TIME * flow_speed * 0.7);
	
	float n1 = fbm(uv1);
	float n2 = fbm(uv2);
	float n = mix(n1, n2, 0.5);
	
	// Crust cracking threshold
	float crust_mask = smoothstep(0.42, 0.58, n);
	float core_mask = 1.0 - smoothstep(0.24, 0.44, n);
	
	// Thermal surging pulse
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed + UV.x * 5.0 + UV.y * 3.0);
	
	// Molten liquid color gradient
	vec3 molten_color = mix(magma_flow.rgb, magma_core.rgb, core_mask);
	vec3 final_albedo = mix(molten_color, crust_color.rgb, crust_mask);
	
	// Intense HDR thermal emission on exposed molten rock
	float emit_factor = (1.0 - crust_mask * 0.88);
	vec3 emission = molten_color * (emission_energy * pulse * emit_factor);
	
	// Surface relief and specular
	float eps = 0.05;
	float hL = fbm(uv1 - vec2(eps, 0.0));
	float hR = fbm(uv1 + vec2(eps, 0.0));
	float hD = fbm(uv1 - vec2(0.0, eps));
	float hU = fbm(uv1 + vec2(0.0, eps));
	vec3 world_norm = normalize(vec3((hL - hR) * 2.2, 1.0, (hD - hU) * 2.2));
	
	ALBEDO = final_albedo;
	EMISSION = emission;
	ROUGHNESS = mix(0.18, 0.88, crust_mask);
	METALLIC = 0.12;
	SPECULAR = 0.75;
	NORMAL = (VIEW_MATRIX * vec4(world_norm, 0.0)).xyz;
}
