shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

// Concentrated High-Intensity Laser Beam with Ion Wake

uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 beam_color : source_color = vec4(0.2, 0.75, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 12.0) = 4.5;
uniform float pulse_speed : hint_range(0.0, 20.0) = 12.0;

void fragment() {
	// UV.x spans perimeter of beam cylinder (or width of quad)
	float lateral_dist = abs(UV.x - 0.5) * 2.0;
	float core = pow(1.0 - clamp(lateral_dist, 0.0, 1.0), 4.0);
	float halo = pow(1.0 - clamp(lateral_dist, 0.0, 1.0), 1.5);

	// Ion wake oscillations along beam length (UV.y)
	float ion_wake = sin(UV.y * 30.0 - TIME * pulse_speed) * 0.15 + 0.85;

	vec3 col = mix(beam_color.rgb, core_color.rgb, core);
	float alpha = clamp((core + halo * 0.5) * ion_wake, 0.0, 1.0);

	ALBEDO = col * emission_energy;
	ALPHA = alpha;
}
