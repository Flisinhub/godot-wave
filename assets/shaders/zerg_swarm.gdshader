shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Zerg Swarm GPU Instanced PBR Shader with Organic Locomotion & Strain Kinematics
// Supports all 4 swarm archetypes:
// 0 = Zergling / Roach (quadruped / hexapod scuttle + carapace breathing)
// 1 = Baneling (blister sac pulsating breathing + rolling wobble)
// 2 = Hydralisk (serpentine tail S-wave undulation + crest sway + scythe flex)

uniform vec4 albedo_carapace : source_color = vec4(0.24, 0.10, 0.28, 1.0);
uniform vec4 albedo_flesh : source_color = vec4(0.38, 0.08, 0.12, 1.0);
uniform vec4 emission_color : source_color = vec4(0.25, 1.0, 0.25, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 3.0;

uniform float metallic : hint_range(0.0, 1.0) = 0.12;
uniform float roughness : hint_range(0.0, 1.0) = 0.32;
uniform float clearcoat : hint_range(0.0, 1.0) = 0.65;
uniform float clearcoat_roughness : hint_range(0.0, 1.0) = 0.20;

// Locomotion mode: 0 = Insectoid/Hexapod, 1 = Baneling Bio-Bomb, 2 = Hydralisk Serpentine
uniform int locomotion_mode : hint_range(0, 2) = 0;

// Standard leg locomotion parameters (Mandatory tokens preserved)
uniform float scuttle_speed = 18.0;
uniform float leg_stride = 0.08;
uniform float leg_lift = 0.04;
uniform float body_sway = 0.025;
uniform float breathing_rate = 3.0;

// Baneling blister sac pulsating & rolling parameters
uniform float blister_pulse_amplitude = 0.07;
uniform float blister_pulse_rate = 5.0;
uniform float roll_wobble = 0.04;

// Hydralisk serpentine kinematics parameters
uniform float tail_wave_speed = 12.0;
uniform float tail_wave_frequency = 4.2;
uniform float tail_amplitude = 0.14;
uniform float crest_sway = 0.045;

void vertex() {
	vec3 world_pos = MODEL_MATRIX[3].xyz;
	float instance_phase = (world_pos.x * 2.13 + world_pos.z * 1.77);
	
	if (locomotion_mode == 0) {
		// --- MODE 0: INSECTOID / HEXAPOD SCUTTLE (Zergling & Roach) ---
		float t = TIME * scuttle_speed + instance_phase;
		
		if (VERTEX.y < 0.35) {
			float leg_phase = sign(VERTEX.x) * 1.57 + sign(VERTEX.z) * 0.78;
			float stride_cycle = sin(t + leg_phase);
			float lift_cycle = max(0.0, cos(t + leg_phase));
			
			VERTEX.z += stride_cycle * leg_stride;
			VERTEX.y += lift_cycle * leg_lift;
			VERTEX.x += sin(t + leg_phase) * (leg_stride * 0.35);
		} else {
			float sway_cycle = sin(t * 0.5) * body_sway;
			VERTEX.x += sway_cycle;
			
			float breath = sin(TIME * breathing_rate + instance_phase) * 0.015;
			VERTEX += NORMAL * breath;
			
			if (VERTEX.z < -0.15) {
				VERTEX.y += sin(t * 0.75) * 0.02;
			}
		}
	} else if (locomotion_mode == 1) {
		// --- MODE 1: BANELING ROLLING BIO-BOMB & BLISTER SAC PULSATING ---
		float t = TIME * scuttle_speed + instance_phase;
		
		// Blister Sac Pulsating Breathing:
		float pulse_cycle = sin(TIME * blister_pulse_rate + instance_phase);
		float is_sac = step(0.28, VERTEX.y) * step(-0.15, VERTEX.z);
		float pulse_amount = mix(0.015, blister_pulse_amplitude, max(is_sac, COLOR.g));
		VERTEX += NORMAL * (pulse_cycle * pulse_amount);
		
		// Rolling Tumble Wobble:
		VERTEX.y += abs(cos(t * 1.2)) * roll_wobble;
		VERTEX.x += sin(t * 0.6) * (roll_wobble * 0.6);
		
		// Vestigial Claw Paddling:
		if (VERTEX.y < 0.25) {
			float leg_phase = sign(VERTEX.x) * 1.57;
			VERTEX.z += sin(t * 1.5 + leg_phase) * (leg_stride * 0.6);
			VERTEX.y += max(0.0, cos(t * 1.5 + leg_phase)) * (leg_lift * 0.5);
		}
	} else if (locomotion_mode == 2) {
		// --- MODE 2: HYDRALISK SERPENTINE SLITHER & CREST SWAY ---
		float t_slither = TIME * tail_wave_speed + instance_phase;
		
		// Serpentine Tail Undulation:
		if (VERTEX.y < 0.45 && VERTEX.z > -0.15) {
			float tail_weight = smoothstep(-0.15, 0.8, VERTEX.z);
			float s_wave = sin(t_slither - VERTEX.z * tail_wave_frequency);
			VERTEX.x += s_wave * (tail_amplitude * tail_weight);
			VERTEX.y += abs(cos(t_slither * 0.5 - VERTEX.z * tail_wave_frequency * 0.5)) * 0.02 * tail_weight;
		}
		
		// Armored Head Crest & Hood Sway:
		if (VERTEX.y > 0.95) {
			float crest_weight = smoothstep(0.95, 1.5, VERTEX.y);
			float sway = -sin(t_slither * 0.5) * crest_sway * crest_weight;
			VERTEX.x += sway;
			
			float crest_breath = sin(TIME * breathing_rate + instance_phase) * 0.018;
			VERTEX += NORMAL * crest_breath;
		}
		
		// Dorsal Scythe Claw Tension:
		if (abs(VERTEX.x) > 0.22 && VERTEX.y > 0.35 && VERTEX.y < 1.05) {
			float claw_twitch = sin(TIME * (tail_wave_speed * 0.75) + instance_phase);
			VERTEX.y += claw_twitch * 0.02;
			VERTEX.z += cos(TIME * (tail_wave_speed * 0.75) + instance_phase) * 0.015;
		}
	}
}

void fragment() {
	float carapace_blend = clamp(COLOR.r, 0.0, 1.0);
	float emission_mask = clamp(COLOR.g, 0.0, 1.0);
	
	vec3 base_color = mix(albedo_flesh.rgb, albedo_carapace.rgb, carapace_blend);
	vec3 emit = emission_color.rgb * (emission_mask * emission_energy);
	
	ALBEDO = base_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = clearcoat_roughness;
	EMISSION = emit;
}
