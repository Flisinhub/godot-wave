shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

// Zeratul Shadow Cleave: 360° sweeping emerald psionic blade crescent arc

uniform vec4 blade_emerald : source_color = vec4(0.2, 1.0, 0.4, 1.0);
uniform vec4 blade_core : source_color = vec4(0.8, 1.0, 0.9, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 3.2;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || r < 0.3) {
		discard;
	}

	// Sharp leading blade edge at outer perimeter
	float blade_edge = smoothstep(0.98, 0.88, r) * smoothstep(0.35, 0.75, r);
	float core = pow(blade_edge, 3.0);

	vec3 col = mix(blade_emerald.rgb, blade_core.rgb, core);
	float alpha = clamp(blade_edge * 1.3, 0.0, 1.0);

	ALBEDO = col * emission_energy;
	ALPHA = alpha;
}
