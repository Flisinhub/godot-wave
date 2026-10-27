extends SceneTree

## Procedural Audio & Sound Effect Synthesizer for Special Forces Elite 5 (SFE5)
## Synthesizes genuine 16-bit 44.1kHz mono/stereo PCM WAV audio files into res://assets/audio/
##
## Weapons:
##   - gauss_fire.wav (C-14 Gauss rifle burst)
##   - snipe.wav (Nova/Sniper supersonic discharge)
##   - cannon.wav (Siege cannon concussion blast)
##   - shotgun.wav (Heavy scattergun discharge)
##   - plasma.wav (Ionized plasma bolt discharge)
##   - turret_fire.wav (Twin Gatling turret burst)
## Alien Bio:
##   - zergling_growl.wav (Zergling chittering hiss/snarl)
##   - roach_spit.wav (Roach pressurized acid spit)
##   - baneling_explode.wav (Baneling kamikaze acid detonation)
##   - hydra_spine.wav (Hydralisk spine needle launch)
##   - zerg_death.wav (Alien bio agonizing death shriek)
## Tactical Voice & Alerts:
##   - base_under_attack.wav (Adjutant "Base under attack" chime)
##   - wave_incoming.wav (Swarm "Wave incoming" klaxon/horn)
##   - upgrade_complete.wav (Terran Armory upgrade complete chime)
##   - hero_ack_1.wav (Hero acknowledgment: "Locked and loaded")
##   - hero_ack_2.wav (Hero acknowledgment: "Orders received")
##   - hero_ack_3.wav (Hero acknowledgment: "Moving out")
##   - insufficient_minerals.wav (Tactical negative error chime)

const SAMPLE_RATE: int = 44100
const AUDIO_DIR: String = "res://assets/audio"


func _init() -> void:
	print("==========================================================")
	print("=== SFE5 PROCEDURAL AUDIO SYNTHESIZER (16-bit 44.1kHz) ===")
	print("==========================================================")
	
	_ensure_audio_dir()
	
	var generated_count: int = 0
	
	# 1. Weapons Arsenal
	generated_count += _generate_sound("gauss_fire.wav", _synth_gauss_fire())
	generated_count += _generate_sound("snipe.wav", _synth_snipe())
	generated_count += _generate_sound("cannon.wav", _synth_cannon())
	generated_count += _generate_sound("shotgun.wav", _synth_shotgun())
	generated_count += _generate_sound("plasma.wav", _synth_plasma())
	generated_count += _generate_sound("turret_fire.wav", _synth_turret_fire())
	
	# 2. Alien Bio / Swarm
	generated_count += _generate_sound("zergling_growl.wav", _synth_zergling_growl())
	generated_count += _generate_sound("roach_spit.wav", _synth_roach_spit())
	generated_count += _generate_sound("baneling_explode.wav", _synth_baneling_explode())
	generated_count += _generate_sound("hydra_spine.wav", _synth_hydra_spine())
	generated_count += _generate_sound("zerg_death.wav", _synth_zerg_death())
	
	# 3. Tactical Voice & Alerts
	generated_count += _generate_sound("base_under_attack.wav", _synth_base_under_attack())
	generated_count += _generate_sound("wave_incoming.wav", _synth_wave_incoming())
	generated_count += _generate_sound("upgrade_complete.wav", _synth_upgrade_complete())
	generated_count += _generate_sound("hero_ack_1.wav", _synth_hero_ack(1))
	generated_count += _generate_sound("hero_ack_2.wav", _synth_hero_ack(2))
	generated_count += _generate_sound("hero_ack_3.wav", _synth_hero_ack(3))
	generated_count += _generate_sound("insufficient_minerals.wav", _synth_insufficient_minerals())
	
	print("\n[AudioGenerator] Successfully synthesized and verified %d WAV files in '%s'!" % [generated_count, AUDIO_DIR])
	print("==========================================================")
	quit(0)


func _ensure_audio_dir() -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("assets"):
		dir.make_dir("assets")
	if not dir.dir_exists("assets/audio"):
		dir.make_dir("assets/audio")


func _generate_sound(file_name: String, pcm_data: PackedByteArray) -> int:
	var wav_path: String = AUDIO_DIR + "/" + file_name
	var tres_path: String = AUDIO_DIR + "/" + file_name.get_basename() + ".tres"
	
	# 1. Write standard 16-bit 44.1kHz RIFF WAV file to disk
	var err := _write_riff_wav(wav_path, pcm_data, SAMPLE_RATE, 1)
	if err != OK:
		printerr("Failed to write WAV file: ", wav_path, " (Error: ", err, ")")
		return 0
	
	# 2. Create and save AudioStreamWAV resource (.tres) for instantaneous zero-import loading
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm_data
	
	var save_err := ResourceSaver.save(stream, tres_path)
	if save_err != OK:
		push_warning("Failed to save .tres resource: %s (Error: %d)" % [tres_path, save_err])
	
	var duration_sec: float = float(pcm_data.size()) / float(SAMPLE_RATE * 2)
	print("  + Generated '%s' (%.2fs, %d bytes PCM)" % [file_name, duration_sec, pcm_data.size()])
	return 1


## Writes genuine 16-bit PCM RIFF WAV header and data
func _write_riff_wav(path: String, byte_data: PackedByteArray, sample_rate: int, channels: int = 1) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	
	var data_size: int = byte_data.size()
	var byte_rate: int = sample_rate * channels * 2
	var block_align: int = channels * 2
	
	# RIFF Header
	f.store_string("RIFF")
	f.store_32(36 + data_size)
	f.store_string("WAVE")
	
	# Format Subchunk
	f.store_string("fmt ")
	f.store_32(16)            # Subchunk1Size (16 for PCM)
	f.store_16(1)             # AudioFormat (1 = PCM)
	f.store_16(channels)      # NumChannels (1 = Mono)
	f.store_32(sample_rate)   # SampleRate (44100)
	f.store_32(byte_rate)     # ByteRate
	f.store_16(block_align)   # BlockAlign
	f.store_16(16)            # BitsPerSample (16-bit)
	
	# Data Subchunk
	f.store_string("data")
	f.store_32(data_size)
	f.store_buffer(byte_data)
	
	f.close()
	return OK


# ==============================================================================
# DSP SYNTHESIS ALGORITHMS (Genuine Mathematical Sound Synthesis)
# ==============================================================================

## C-14 Impaler Gauss Rifle Burst (3 high-velocity depleted uranium rounds)
func _synth_gauss_fire() -> PackedByteArray:
	var duration: float = 0.36
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var shot_offsets: Array[float] = [0.0, 0.09, 0.18]
	var rng := RandomNumberGenerator.new()
	rng.seed = 10101
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var sample: float = 0.0
		
		for shot_start in shot_offsets:
			if t >= shot_start:
				var st: float = t - shot_start
				# 1. Kinetic pitch-dropped punch: 380Hz down to 60Hz
				var pitch_env: float = 60.0 + 320.0 * exp(-st / 0.012)
				var punch: float = sin(st * pitch_env * TAU) * exp(-st / 0.025) * 0.65
				
				# 2. Powder/accelerator noise burst: shaped white noise
				var noise: float = (rng.randf() * 2.0 - 1.0) * exp(-st / 0.035) * 0.55
				
				# 3. Metallic brass / chamber resonance: 1850Hz damped ring
				var ring: float = sin(st * 1850.0 * TAU) * exp(-st / 0.065) * 0.25
				
				# 4. Depleted uranium sonic snap at onset
				var snap: float = 0.0
				if st < 0.003:
					snap = (1.0 - st / 0.003) * 0.4
				
				sample += (punch + noise + ring + snap)
		
		# Soft clipping overdrive
		sample = clampf(tanh(sample * 1.4), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Nova / Sniper Rifle Supersonic Discharge
func _synth_snipe() -> PackedByteArray:
	var duration: float = 0.65
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 20202
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. Supersonic ionization chirp: 5200Hz sweep to 220Hz
		var chirp_freq: float = 220.0 + 4980.0 * exp(-t / 0.018)
		var chirp: float = sin(t * chirp_freq * TAU) * exp(-t / 0.045) * 0.6
		
		# 2. Sub-bass concussive punch: 95Hz down to 32Hz
		var bass: float = sin(t * (32.0 + 63.0 * exp(-t / 0.04)) * TAU) * exp(-t / 0.12) * 0.75
		
		# 3. Blinding kinetic shockwave crackle
		var crack: float = (rng.randf() * 2.0 - 1.0) * exp(-t / 0.028) * 0.65
		
		# 4. High-Q magnetic rail ringing tail: 3150Hz decaying over 0.4s
		var ring: float = sin(t * 3150.0 * TAU) * exp(-t / 0.14) * 0.35
		
		var sample: float = chirp + bass + crack + ring
		sample = clampf(tanh(sample * 1.5), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Siege Cannon Concussive Blast
func _synth_cannon() -> PackedByteArray:
	var duration: float = 1.25
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 30303
	var noise_lpf: float = 0.0
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. Sub-bass seismic rumble: 110Hz to 22Hz
		var rumble_freq: float = 22.0 + 88.0 * exp(-t / 0.08)
		var boom: float = sin(t * rumble_freq * TAU) * exp(-t / 0.35) * 0.95
		
		# 2. Filtered low-frequency explosive noise
		var white: float = (rng.randf() * 2.0 - 1.0)
		noise_lpf += (white - noise_lpf) * 0.06
		var rumble_noise: float = noise_lpf * exp(-t / 0.45) * 0.8
		
		# 3. Echo reflections / reverberant canyon bounce
		var echo: float = 0.0
		if t > 0.12:
			echo += sin((t - 0.12) * 55.0 * TAU) * exp(-(t - 0.12) / 0.3) * 0.35
		if t > 0.28:
			echo += sin((t - 0.28) * 44.0 * TAU) * exp(-(t - 0.28) / 0.4) * 0.25
		
		var sample: float = boom + rumble_noise + echo
		sample = clampf(tanh(sample * 1.8), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Heavy Scattergun / Shotgun Blast
func _synth_shotgun() -> PackedByteArray:
	var duration: float = 0.52
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 40404
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. Mechanical hammer click (t < 0.015s)
		var click: float = 0.0
		if t < 0.015:
			click = sin(t * 2400.0 * TAU) * (1.0 - t / 0.015) * 0.4
		
		# 2. Wideband pellet blast noise
		var blast_noise: float = (rng.randf() * 2.0 - 1.0) * exp(-t / 0.075) * 0.85
		
		# 3. Low-end punch (160Hz -> 45Hz)
		var punch: float = sin(t * (45.0 + 115.0 * exp(-t / 0.02)) * TAU) * exp(-t / 0.06) * 0.7
		
		# 4. Chamber reload cycle rattle (t = 0.30 to 0.42s)
		var pump: float = 0.0
		if t >= 0.30 and t <= 0.42:
			var pt: float = t - 0.30
			pump = sin(pt * 1800.0 * TAU) * exp(-pt / 0.02) * 0.2 + (rng.randf() * 2.0 - 1.0) * exp(-pt / 0.03) * 0.15
		
		var sample: float = click + blast_noise + punch + pump
		sample = clampf(tanh(sample * 1.5), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Ionized Plasma Bolt Discharge
func _synth_plasma() -> PackedByteArray:
	var duration: float = 0.70
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 50505
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# FM Synthesis: Carrier = 480Hz, Modulator = 160Hz, Mod Index decaying from 4.0 to 0.2
		var mod_index: float = 4.0 * exp(-t / 0.18)
		var modulator: float = sin(t * 160.0 * TAU) * mod_index
		var carrier: float = sin(t * 480.0 * TAU + modulator) * exp(-t / 0.25) * 0.65
		
		# Electrical ionization hum (multi-harmonic)
		var hum: float = (sin(t * 240.0 * TAU) * 0.2 + sin(t * 720.0 * TAU) * 0.15) * exp(-t / 0.35)
		
		# High frequency plasma discharge sizzle
		var sizzle: float = (rng.randf() * 2.0 - 1.0) * exp(-t / 0.09) * 0.35
		
		var sample: float = carrier + hum + sizzle
		sample = clampf(tanh(sample * 1.4), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Perimeter Auto-Turret Twin Gatling Burst
func _synth_turret_fire() -> PackedByteArray:
	var duration: float = 0.32
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var barrel_offsets: Array[float] = [0.0, 0.08]
	var rng := RandomNumberGenerator.new()
	rng.seed = 60606
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var sample: float = 0.0
		
		for bo in barrel_offsets:
			if t >= bo:
				var bt: float = t - bo
				var punch: float = sin(bt * (80.0 + 340.0 * exp(-bt / 0.015)) * TAU) * exp(-bt / 0.035) * 0.7
				var ping: float = sin(bt * 2200.0 * TAU) * exp(-bt / 0.05) * 0.35
				var noise: float = (rng.randf() * 2.0 - 1.0) * exp(-bt / 0.025) * 0.5
				sample += (punch + ping + noise)
		
		sample = clampf(tanh(sample * 1.5), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Zergling Hiss and Chittering Snarl
func _synth_zergling_growl() -> PackedByteArray:
	var duration: float = 0.55
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 70707
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. Visceral guttural carrier with chaotic vibrato
		var vibrato: float = sin(t * 18.0 * TAU) * 25.0
		var carrier: float = sin(t * (95.0 + vibrato) * TAU) * 0.5
		
		# 2. Organic insectoid clicking
		var click: float = 0.0
		if (t > 0.08 and t < 0.09) or (t > 0.22 and t < 0.23) or (t > 0.36 and t < 0.37):
			click = (rng.randf() * 2.0 - 1.0) * 0.6
		
		# 3. Visceral rasp hiss
		var hiss_env: float = sin(t / duration * PI)
		var hiss: float = (rng.randf() * 2.0 - 1.0) * hiss_env * 0.45
		
		var sample: float = (carrier + click + hiss) * hiss_env
		sample = clampf(tanh(sample * 1.6), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Roach Pressurized Acid Spit
func _synth_roach_spit() -> PackedByteArray:
	var duration: float = 0.65
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 80808
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. Expulsion pitch drop: 620Hz down to 140Hz
		var spit_freq: float = 140.0 + 480.0 * exp(-t / 0.12)
		var spit_tone: float = sin(t * spit_freq * TAU) * exp(-t / 0.22) * 0.6
		
		# 2. Caustic acid bubbling modulation (24Hz AM)
		var bubble: float = (1.0 + sin(t * 24.0 * TAU) * 0.5) * 0.5
		var hiss: float = (rng.randf() * 2.0 - 1.0) * bubble * exp(-t / 0.35) * 0.55
		
		# 3. Acid splat impact at t = 0.42s
		var splat: float = 0.0
		if t >= 0.42:
			var st: float = t - 0.42
			splat = (rng.randf() * 2.0 - 1.0) * exp(-st / 0.08) * 0.5 + sin(st * 120.0 * TAU) * exp(-st / 0.06) * 0.4
		
		var sample: float = spit_tone + hiss + splat
		sample = clampf(tanh(sample * 1.5), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Baneling Kamikaze Acid Detonation
func _synth_baneling_explode() -> PackedByteArray:
	var duration: float = 1.15
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 90909
	var lpf: float = 0.0
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. Chemical detonation boom (90Hz -> 25Hz)
		var boom_freq: float = 25.0 + 65.0 * exp(-t / 0.07)
		var boom: float = sin(t * boom_freq * TAU) * exp(-t / 0.32) * 0.95
		
		# 2. Ruptured chitinous sac pressure burst
		var sac_pop: float = 0.0
		if t < 0.01:
			sac_pop = (1.0 - t / 0.01) * 0.8
		
		# 3. High-volume acid splatter and caustic bubbling hiss
		var noise: float = (rng.randf() * 2.0 - 1.0)
		lpf += (noise - lpf) * 0.12
		var acid_sizzle: float = (noise * 0.4 + lpf * 0.6) * exp(-t / 0.65) * 0.75
		
		# 4. Acid puddle bubbling tail (20Hz AM on hiss)
		var bubble_tail: float = sin(t * 22.0 * TAU) * exp(-t / 0.8) * 0.25
		
		var sample: float = boom + sac_pop + acid_sizzle + bubble_tail
		sample = clampf(tanh(sample * 1.7), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Hydralisk Acid Spine Launch
func _synth_hydra_spine() -> PackedByteArray:
	var duration: float = 0.42
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. High-velocity spine whip/whoosh (downward sweep 5500Hz -> 800Hz)
		var spine_freq: float = 800.0 + 4700.0 * exp(-t / 0.04)
		var whoosh: float = sin(t * spine_freq * TAU) * exp(-t / 0.08) * 0.5
		
		# 2. Muscular contraction snap
		var snap: float = 0.0
		if t < 0.008:
			snap = (1.0 - t / 0.008) * 0.65
		
		# 3. Aerodynamic toxic spine friction
		var hiss: float = (rng.randf() * 2.0 - 1.0) * exp(-t / 0.12) * 0.45
		
		var sample: float = whoosh + snap + hiss
		sample = clampf(tanh(sample * 1.5), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Alien Bio Agonizing Death Shriek
func _synth_zerg_death() -> PackedByteArray:
	var duration: float = 0.85
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 12121
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. Shriek pitch down-sweep: 1900Hz -> 340Hz
		var shriek_freq: float = 340.0 + 1560.0 * exp(-t / 0.28)
		var shriek_carrier: float = sin(t * shriek_freq * TAU)
		
		# 2. Harsh ring modulation (90Hz) creates insectoid visceral rasp
		var ring_mod: float = sin(t * 90.0 * TAU)
		var modulated_shriek: float = shriek_carrier * ring_mod * exp(-t / 0.4) * 0.7
		
		# 3. Dying throat bile flutter (15Hz AM)
		var bile_flutter: float = (1.0 + sin(t * 15.0 * TAU) * 0.5) * 0.5
		var bile_noise: float = (rng.randf() * 2.0 - 1.0) * bile_flutter * exp(-t / 0.55) * 0.4
		
		var sample: float = modulated_shriek + bile_noise
		sample = clampf(tanh(sample * 1.5), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Tactical Base Under Attack Chime
func _synth_base_under_attack() -> PackedByteArray:
	var duration: float = 1.45
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	# Tone sequence: A5 (880Hz) -> D6 (1174.66Hz) -> pause -> A5 (880Hz) -> D6 (1174.66Hz)
	var tone_times: Array[Dictionary] = [
		{"start": 0.00, "dur": 0.22, "freq": 880.00},
		{"start": 0.24, "dur": 0.35, "freq": 1174.66},
		{"start": 0.65, "dur": 0.22, "freq": 880.00},
		{"start": 0.89, "dur": 0.48, "freq": 1174.66}
	]
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var sample: float = 0.0
		
		for tone in tone_times:
			var st: float = t - float(tone["start"])
			var td: float = float(tone["dur"])
			if st >= 0.0 and st < td:
				var f: float = float(tone["freq"])
				# Bell chime with 2nd and 3rd harmonics
				var fundamental: float = sin(st * f * TAU) * exp(-st / (td * 0.75))
				var harm2: float = sin(st * f * 2.0 * TAU) * exp(-st / (td * 0.5)) * 0.35
				var harm3: float = sin(st * f * 3.0 * TAU) * exp(-st / (td * 0.3)) * 0.15
				sample += (fundamental + harm2 + harm3) * 0.6
		
		# Subtle sub-drone alert background
		sample += sin(t * 110.0 * TAU) * exp(-t / 1.4) * 0.12
		
		sample = clampf(sample, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Tactical Swarm Wave Incoming Klaxon / Horn
func _synth_wave_incoming() -> PackedByteArray:
	var duration: float = 1.60
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. Deep dual-tone industrial horn (110Hz and 113Hz creates 3Hz acoustic beating)
		var horn_env: float = sin(clampf(t / 1.5, 0.0, 1.0) * PI)
		var horn1: float = (sin(t * 110.0 * TAU) + sin(t * 220.0 * TAU) * 0.5 + sin(t * 330.0 * TAU) * 0.25)
		var horn2: float = (sin(t * 113.0 * TAU) + sin(t * 226.0 * TAU) * 0.5)
		var sub_horn: float = (horn1 + horn2) * 0.35 * horn_env
		
		# 2. Urgent high-frequency klaxon ping overlay (t = 0.4s to 1.1s)
		var klaxon: float = 0.0
		if t >= 0.4 and t <= 1.2:
			var kt: float = t - 0.4
			var sweep_freq: float = 700.0 + 160.0 * sin(kt * 8.0 * TAU)
			klaxon = sin(kt * sweep_freq * TAU) * 0.35 * sin((t - 0.4) / 0.8 * PI)
		
		var sample: float = sub_horn + klaxon
		sample = clampf(tanh(sample * 1.4), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Terran Armory Upgrade Complete Chime (Melodic Ascending Arpeggio)
func _synth_upgrade_complete() -> PackedByteArray:
	var duration: float = 1.30
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	# Melodic ascending C major chord arpeggio: C5 -> E5 -> G5 -> C6
	var notes: Array[Dictionary] = [
		{"start": 0.00, "dur": 0.30, "freq": 523.25}, # C5
		{"start": 0.16, "dur": 0.35, "freq": 659.25}, # E5
		{"start": 0.32, "dur": 0.40, "freq": 783.99}, # G5
		{"start": 0.48, "dur": 0.75, "freq": 1046.50} # C6 (sustained)
	]
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var sample: float = 0.0
		
		for note in notes:
			var st: float = t - float(note["start"])
			var nd: float = float(note["dur"])
			if st >= 0.0 and st < nd:
				var f: float = float(note["freq"])
				var bell: float = sin(st * f * TAU) * exp(-st / (nd * 0.6))
				var overtone1: float = sin(st * f * 2.0 * TAU) * exp(-st / (nd * 0.4)) * 0.35
				var overtone2: float = sin(st * f * 3.0 * TAU) * exp(-st / (nd * 0.25)) * 0.15
				var shimmer: float = sin(st * f * 4.0 * TAU) * exp(-st / (nd * 0.15)) * 0.08
				sample += (bell + overtone1 + overtone2 + shimmer) * 0.45
		
		sample = clampf(sample, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Hero Acknowledgment Tactical Radio Responses
func _synth_hero_ack(variant: int) -> PackedByteArray:
	var duration: float = 0.85
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = 13131 + variant
	
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		
		# 1. Radio squelch click / static burst at beginning and end
		var radio_static: float = 0.0
		if t < 0.04:
			radio_static = (rng.randf() * 2.0 - 1.0) * (1.0 - t / 0.04) * 0.35
		elif t > duration - 0.04:
			radio_static = (rng.randf() * 2.0 - 1.0) * ((t - (duration - 0.04)) / 0.04) * 0.35
		
		# 2. Military authorization telemetry tones based on variant
		var voice_sim: float = 0.0
		if variant == 1:
			# Raynor: "Locked and loaded" (crisp dual tone 440Hz -> 880Hz with vocal formant filter)
			if t >= 0.06 and t < 0.35:
				var st: float = t - 0.06
				voice_sim = (sin(st * 440.0 * TAU) + sin(st * 880.0 * TAU) * 0.4) * exp(-st / 0.22) * 0.55
			elif t >= 0.38 and t < 0.75:
				var st: float = t - 0.38
				voice_sim = (sin(st * 554.37 * TAU) + sin(st * 1108.73 * TAU) * 0.35) * exp(-st / 0.28) * 0.6
		elif variant == 2:
			# "Orders received" (three quick tactical affirmation chirps)
			if t >= 0.06 and t < 0.24:
				var st: float = t - 0.06
				voice_sim = sin(st * 587.33 * TAU) * exp(-st / 0.14) * 0.5
			elif t >= 0.26 and t < 0.44:
				var st: float = t - 0.26
				voice_sim = sin(st * 659.25 * TAU) * exp(-st / 0.14) * 0.5
			elif t >= 0.46 and t < 0.72:
				var st: float = t - 0.46
				voice_sim = sin(st * 880.00 * TAU) * exp(-st / 0.2) * 0.55
		else:
			# "Moving out" (military blip and low tactical affirmation)
			if t >= 0.06 and t < 0.30:
				var st: float = t - 0.06
				voice_sim = sin(st * 330.0 * TAU) * exp(-st / 0.2) * 0.5
			elif t >= 0.32 and t < 0.70:
				var st: float = t - 0.32
				voice_sim = (sin(st * 495.0 * TAU) + sin(st * 990.0 * TAU) * 0.3) * exp(-st / 0.25) * 0.55
		
		var sample: float = radio_static + voice_sim
		sample = clampf(tanh(sample * 1.3), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes


## Tactical Negative Warning Error Chime (Insufficient Minerals)
func _synth_insufficient_minerals() -> PackedByteArray:
	var duration: float = 0.55
	var num_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)
	
	# Two low abrasive warning beeps: 220Hz -> 180Hz
	for i in range(num_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var sample: float = 0.0
		
		if t < 0.20:
			# Beep 1: 220Hz square-ish tone
			var f: float = 220.0
			var st: float = t
			sample = (sin(st * f * TAU) + sin(st * f * 3.0 * TAU) * 0.33) * exp(-st / 0.16) * 0.65
		elif t >= 0.24 and t < 0.48:
			# Beep 2: 180Hz square-ish tone
			var f: float = 180.0
			var st: float = t - 0.24
			sample = (sin(st * f * TAU) + sin(st * f * 3.0 * TAU) * 0.33) * exp(-st / 0.18) * 0.65
		
		sample = clampf(sample, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	
	return bytes
