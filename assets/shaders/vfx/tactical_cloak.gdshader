shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

// Tactical Cloak: Refractive stealth shimmer with alpha transparency fade

uniform vec4 cloak_shimmer_color : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float stealth_alpha : hint_range(0.0, 1.0) = 0.18;
uniform float shimmer_speed : hint_range(0.0, 10.0) = 4.0;
uniform float distortion_freq : hint_range(1.0, 30.0) = 14.0;

void vertex() {
	// Micro-distortion vertex perturbation simulating active camouflage light bending
	float disp = sin(VERTEX.y * distortion_freq + TIME * shimmer_speed) * 0.008;
	VERTEX += NORMAL * disp;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	
	// Shimmer ripple
	float ripple = sin((UV.x + UV.y) * 20.0 + TIME * shimmer_speed) * 0.5 + 0.5;
	float highlight = fresnel * ripple;

	vec3 col = mix(vec3(0.1, 0.15, 0.2), cloak_shimmer_color.rgb, highlight);
	
	ALBEDO = col;
	EMISSION = cloak_shimmer_color.rgb * highlight * 1.5;
	ALPHA = mix(stealth_alpha, 0.75, highlight);
	ROUGHNESS = 0.1;
	METALLIC = 0.9;
}
