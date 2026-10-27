shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

// Psionic Storm: Vortex of swirling electric psionic lightning arcs
// Specifications: radius 5.2m, emission 3.5, electric blue/violet arcs

uniform vec4 storm_color_inner : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform vec4 storm_color_outer : source_color = vec4(0.75, 0.25, 0.95, 1.0);
uniform float emission_energy : hint_range(0.0, 10.0) = 3.5;
uniform float swirl_speed : hint_range(0.0, 10.0) = 3.2;
uniform float pulse_speed : hint_range(0.0, 10.0) = 4.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}

	float theta = atan(p.y, p.x);
	// Swirling vortex coordinates
	float swirl = theta + (1.0 - r) * 4.0 + TIME * swirl_speed;
	
	// Electrical lightning arcs via modulated high-frequency waves
	float wave1 = sin(swirl * 8.0 + sin(r * 16.0 - TIME * pulse_speed));
	float wave2 = cos(swirl * 12.0 - sin(r * 12.0 + TIME * pulse_speed * 1.5));
	float arc = abs(wave1 * wave2);
	arc = pow(clamp(arc, 0.0, 1.0), 3.0);

	// Edge falloff and center void
	float edge_fade = smoothstep(1.0, 0.7, r);
	float center_fade = smoothstep(0.05, 0.25, r);
	float alpha_mask = arc * edge_fade * center_fade;

	// Dual-tone color ramp (cyan-blue core transitioning to psionic violet fringe)
	vec3 col = mix(storm_color_inner.rgb, storm_color_outer.rgb, r);
	col += vec3(0.4, 0.5, 1.0) * pow(arc, 5.0) * 2.0; // intense hot-spots

	ALBEDO = col * emission_energy;
	ALPHA = clamp(alpha_mask * 1.2, 0.0, 1.0);
}
