shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

// Celestial Singularity: Cosmic gold/purple gravitational accretion disk

uniform vec4 cosmic_purple : source_color = vec4(0.7, 0.15, 0.95, 1.0);
uniform vec4 cosmic_gold : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 3.6;
uniform float vortex_speed : hint_range(0.0, 20.0) = 5.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}

	float theta = atan(p.y, p.x);
	// Accretion disk spiral arms
	float spiral = sin(theta * 3.0 + r * 14.0 - TIME * vortex_speed);
	float spiral_intensity = pow(spiral * 0.5 + 0.5, 2.0);

	// Event horizon center: deep dark core
	float event_horizon = smoothstep(0.08, 0.22, r);

	// Outer accretion disk falloff
	float outer_falloff = smoothstep(1.0, 0.65, r);

	// Color gradient: hot celestial gold near event horizon transition to deep cosmic purple
	vec3 col = mix(cosmic_gold.rgb, cosmic_purple.rgb, smoothstep(0.2, 0.8, r));
	col += cosmic_gold.rgb * spiral_intensity * 0.5;

	float alpha = event_horizon * outer_falloff * (spiral_intensity * 0.7 + 0.3);

	ALBEDO = col * emission_energy;
	ALPHA = clamp(alpha * 1.1, 0.0, 1.0);
}
