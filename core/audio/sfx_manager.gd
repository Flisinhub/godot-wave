extends Node

## SFXManager — Core Spatial Audio & Soundscape Management Engine
## Manages pooled 3D and 2D audio players, bus routing, distance attenuation,
## polyphony clamping, pitch jitter, and tactical voice rate limiting.
##
## Autoload: SFXManager ("*res://core/audio/sfx_manager.gd")
## Bus Layout: res://default_bus_layout.tres (Master, Music, Voice, Ambience, SFX, Weapons, Explosions, Swarm)

signal voice_alert_played(alert_id: StringName)
signal hero_voice_played(line_id: StringName)
signal sfx_played(sound_id: StringName, is_3d: bool)

# Static Singleton Reference
static var instance: SFXManager = null

# Configuration Constants
const POOL_SIZE_3D: int = 24
const POOL_SIZE_2D: int = 8
const DEFAULT_MAX_POLYPHONY: int = 4
const MIN_PITCH_JITTER: float = 0.94
const MAX_PITCH_JITTER: float = 1.06
const MAX_DISTANCE_3D: float = 35.0
const BASE_ATTACK_COOLDOWN: float = 15.0
const BREACH_COOLDOWN: float = 20.0
const BOSS_ALERT_COOLDOWN: float = 30.0
const DEFAULT_ALERT_COOLDOWN: float = 15.0

# Audio Buses
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_VOICE: StringName = &"Voice"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_SFX: StringName = &"SFX"
const BUS_WEAPONS: StringName = &"Weapons"
const BUS_EXPLOSIONS: StringName = &"Explosions"
const BUS_SWARM: StringName = &"Swarm"

# Exposed Public Parameters
var max_3d_players: int = POOL_SIZE_3D
var max_2d_players: int = POOL_SIZE_2D
var max_polyphony: int = DEFAULT_MAX_POLYPHONY
var min_jitter: float = MIN_PITCH_JITTER
var max_jitter: float = MAX_PITCH_JITTER
var max_distance: float = MAX_DISTANCE_3D
var base_attack_cooldown: float = BASE_ATTACK_COOLDOWN
var breach_cooldown: float = BREACH_COOLDOWN
var boss_alert_cooldown: float = BOSS_ALERT_COOLDOWN

var pool_3d: Array[AudioStreamPlayer3D]:
	get:
		return _pool_3d

var pool_2d: Array[AudioStreamPlayer]:
	get:
		return _pool_2d

# Headless & Runtime State
var is_headless: bool = false
var active_plays: int = 0
var dropped_plays: int = 0
var total_plays: int = 0

# Player Pools & Metadata
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_3d_sound_id: Array[StringName] = []
var _pool_3d_start_time: Array[float] = []
var _pool_3d_duration: Array[float] = []

var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_2d_sound_id: Array[StringName] = []
var _pool_2d_start_time: Array[float] = []
var _pool_2d_duration: Array[float] = []

# Audio Cache & Timers
var _stream_cache: Dictionary = {} # StringName -> AudioStream
var _last_alert_times: Dictionary = {} # StringName (category) -> float (sec)
var _last_hero_voice_time: float = -999.0

# Sound Bus Routing Lookup Table
const SOUND_BUS_MAP: Dictionary = {
	# Weapons
	&"gauss_fire": BUS_WEAPONS,
	&"snipe": BUS_WEAPONS,
	&"cannon": BUS_EXPLOSIONS,
	&"shotgun": BUS_WEAPONS,
	&"plasma": BUS_WEAPONS,
	&"turret_fire": BUS_WEAPONS,
	&"bunker_fire": BUS_WEAPONS,
	
	# Explosions
	&"baneling_explode": BUS_EXPLOSIONS,
	&"explosion": BUS_EXPLOSIONS,
	&"orbital_bombardment": BUS_EXPLOSIONS,
	
	# Swarm
	&"zergling_growl": BUS_SWARM,
	&"roach_spit": BUS_SWARM,
	&"hydra_spine": BUS_SWARM,
	&"zerg_death": BUS_SWARM,
	
	# Voice & Alerts
	&"base_under_attack": BUS_VOICE,
	&"wave_incoming": BUS_VOICE,
	&"upgrade_complete": BUS_VOICE,
	&"insufficient_minerals": BUS_VOICE,
	&"hero_ack_1": BUS_VOICE,
	&"hero_ack_2": BUS_VOICE,
	&"hero_ack_3": BUS_VOICE,
}

# Aliases mapping shorthand or alternative names to synthesized audio files
const SOUND_ALIASES: Dictionary = {
	&"gauss": &"gauss_fire",
	&"c14": &"gauss_fire",
	&"c14_fire": &"gauss_fire",
	&"rifle": &"gauss_fire",
	&"sniper": &"snipe",
	&"siege_cannon": &"cannon",
	&"tank_cannon": &"cannon",
	&"scattergun": &"shotgun",
	&"bunker": &"turret_fire",
	&"zerg_hiss": &"zergling_growl",
	&"zerg_snarl": &"zergling_growl",
	&"acid_spit": &"roach_spit",
	&"roach": &"roach_spit",
	&"baneling_explosion": &"baneling_explode",
	&"baneling": &"baneling_explode",
	&"spine": &"hydra_spine",
	&"spine_launch": &"hydra_spine",
	&"hydralisk_spine": &"hydra_spine",
	&"death": &"zerg_death",
	&"screech": &"zerg_death",
	&"shriek": &"zerg_death",
	&"base_attack": &"base_under_attack",
	&"base_attacked": &"base_under_attack",
	&"wave": &"wave_incoming",
	&"wave_alert": &"wave_incoming",
	&"horn": &"wave_incoming",
	&"upgrade": &"upgrade_complete",
	&"upgraded": &"upgrade_complete",
	&"hero_ack": &"hero_ack_1",
	&"hero_voice": &"hero_ack_1",
}


func _init() -> void:
	if instance == null:
		instance = self
	
	is_headless = (DisplayServer.get_name() == "headless")
	_build_pools()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if instance == self:
			instance = null


func _ready() -> void:
	# Add pool nodes as children for lifecycle management
	for p3 in _pool_3d:
		if p3.get_parent() == null:
			add_child(p3)
	for p2 in _pool_2d:
		if p2.get_parent() == null:
			add_child(p2)


## Initializes the 24 3D spatial players and 8 2D players
func _build_pools() -> void:
	_pool_3d.clear()
	_pool_3d_sound_id.clear()
	_pool_3d_start_time.clear()
	_pool_3d_duration.clear()
	
	for i in range(POOL_SIZE_3D):
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "AudioPlayer3D_%d" % i
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.max_distance = MAX_DISTANCE_3D
		p3.unit_size = 2.0
		p3.bus = BUS_SFX
		add_child(p3)
		
		_pool_3d.append(p3)
		_pool_3d_sound_id.append(&"")
		_pool_3d_start_time.append(0.0)
		_pool_3d_duration.append(0.0)
	
	_pool_2d.clear()
	_pool_2d_sound_id.clear()
	_pool_2d_start_time.clear()
	_pool_2d_duration.clear()
	
	for i in range(POOL_SIZE_2D):
		var p2 := AudioStreamPlayer.new()
		p2.name = "AudioPlayer2D_%d" % i
		p2.bus = BUS_SFX
		add_child(p2)
		
		_pool_2d.append(p2)
		_pool_2d_sound_id.append(&"")
		_pool_2d_start_time.append(0.0)
		_pool_2d_duration.append(0.0)


# ==============================================================================
# PRIMARY PUBLIC API
# ==============================================================================

## Plays a 3D positioned sound effect with polyphony clamping, pitch jitter, and distance attenuation
func play_sfx_3d(sound_id: StringName, global_pos: Vector3, custom_max_polyphony: int = DEFAULT_MAX_POLYPHONY) -> void:
	var canonical_id: StringName = _resolve_sound_id(sound_id)
	var active_count: int = get_active_voice_count(canonical_id)
	
	# 1. Polyphony Clamping
	if active_count >= custom_max_polyphony:
		dropped_plays += 1
		return
	
	# 2. Acquire best available 3D player
	var player_idx: int = _acquire_player_3d()
	if player_idx < 0:
		dropped_plays += 1
		return
	
	var stream: AudioStream = get_sound_stream(canonical_id)
	var duration: float = stream.get_length() if stream else 0.4
	if duration <= 0.0:
		duration = 0.4
	
	var now: float = Time.get_ticks_msec() / 1000.0
	_pool_3d_sound_id[player_idx] = canonical_id
	_pool_3d_start_time[player_idx] = now
	_pool_3d_duration[player_idx] = duration
	
	var p3: AudioStreamPlayer3D = _pool_3d[player_idx]
	if p3.is_inside_tree():
		p3.global_position = global_pos
	else:
		p3.position = global_pos
	p3.bus = get_bus_for_sound(canonical_id)
	p3.stream = stream
	p3.pitch_scale = randf_range(min_jitter, max_jitter)
	p3.max_distance = max_distance
	p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	
	# Headless safety: do not call hardware audio server in headless mode to prevent crashes
	if not is_headless and p3.is_inside_tree():
		p3.play()
	
	active_plays += 1
	total_plays += 1
	emit_signal("sfx_played", canonical_id, true)


## Plays a 2D non-spatial sound effect (UI, Alerts, Music, Voice)
func play_sfx_2d(sound_id: StringName, volume_db: float = 0.0) -> void:
	var canonical_id: StringName = _resolve_sound_id(sound_id)
	var player_idx: int = _acquire_player_2d()
	if player_idx < 0:
		dropped_plays += 1
		return
	
	var stream: AudioStream = get_sound_stream(canonical_id)
	var duration: float = stream.get_length() if stream else 0.5
	if duration <= 0.0:
		duration = 0.5
	
	var now: float = Time.get_ticks_msec() / 1000.0
	_pool_2d_sound_id[player_idx] = canonical_id
	_pool_2d_start_time[player_idx] = now
	_pool_2d_duration[player_idx] = duration
	
	var p2: AudioStreamPlayer = _pool_2d[player_idx]
	p2.bus = get_bus_for_sound(canonical_id)
	p2.volume_db = volume_db
	p2.stream = stream
	p2.pitch_scale = 1.0
	
	if not is_headless and p2.is_inside_tree():
		p2.play()
	
	total_plays += 1
	emit_signal("sfx_played", canonical_id, false)


## Plays a tactical voice alert subject to category-based rate limiting (min 15.0s cooldown)
func play_voice_alert(alert_id: StringName) -> void:
	var category: StringName = get_alert_category(alert_id)
	var cooldown: float = get_alert_cooldown(category)
	var now: float = Time.get_ticks_msec() / 1000.0
	var last_time: float = _last_alert_times.get(category, -99999.0)
	
	if (now - last_time) < cooldown:
		# Rate-limited: suppressed to prevent player alert fatigue
		return
	
	_last_alert_times[category] = now
	play_sfx_2d(alert_id, 1.5)
	emit_signal("voice_alert_played", alert_id)


## Plays a Hero voice acknowledgment line
func play_hero_voice(line_id: StringName) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if (now - _last_hero_voice_time) < 1.0:
		# Suppress rapid voice line spamming
		return
	_last_hero_voice_time = now
	
	var target_line: StringName = line_id
	if line_id == &"hero_ack" or line_id == &"hero_voice":
		var pick: int = (randi() % 3) + 1
		target_line = StringName("hero_ack_%d" % pick)
	
	play_sfx_2d(target_line, 1.0)
	emit_signal("hero_voice_played", target_line)


# ==============================================================================
# AUDIO ROUTING & STREAM RESOLUTION
# ==============================================================================

## Returns the audio bus name for a given sound ID
func get_bus_for_sound(sound_id: StringName) -> StringName:
	var canonical: StringName = _resolve_sound_id(sound_id)
	if SOUND_BUS_MAP.has(canonical):
		return SOUND_BUS_MAP[canonical]
	
	var s: String = String(canonical).to_lower()
	if s.contains("weapon") or s.contains("fire") or s.contains("shot") or s.contains("gun") or s.contains("laser"):
		return BUS_WEAPONS
	elif s.contains("explode") or s.contains("explosion") or s.contains("cannon") or s.contains("blast"):
		return BUS_EXPLOSIONS
	elif s.contains("zerg") or s.contains("swarm") or s.contains("growl") or s.contains("spit") or s.contains("spine") or s.contains("screech") or s.contains("shriek"):
		return BUS_SWARM
	elif s.contains("voice") or s.contains("alert") or s.contains("hero") or s.contains("adjutant") or s.contains("ack") or s.contains("chime") or s.contains("attack") or s.contains("incoming"):
		return BUS_VOICE
	elif s.contains("ambience") or s.contains("wind"):
		return BUS_AMBIENCE
	return BUS_SFX


## Determines the category for an alert ID to enforce cooldown intervals
func get_alert_category(alert_id: StringName) -> StringName:
	var s: String = String(alert_id).to_lower()
	if s.contains("attack"):
		return &"base_attack"
	elif s.contains("breach") or s.contains("gate"):
		return &"breach"
	elif s.contains("boss"):
		return &"boss"
	return alert_id


## Returns the cooldown duration in seconds for an alert category
func get_alert_cooldown(category: StringName) -> float:
	if category == &"base_attack":
		return base_attack_cooldown # 15.0s
	elif category == &"breach":
		return breach_cooldown      # 20.0s
	elif category == &"boss":
		return boss_alert_cooldown  # 30.0s
	return DEFAULT_ALERT_COOLDOWN   # 15.0s


## Resolves aliases to standard sound IDs
func _resolve_sound_id(sound_id: StringName) -> StringName:
	if SOUND_ALIASES.has(sound_id):
		return SOUND_ALIASES[sound_id]
	return sound_id


## Loads or retrieves cached AudioStream for a sound ID
func get_sound_stream(sound_id: StringName) -> AudioStream:
	var canonical: StringName = _resolve_sound_id(sound_id)
	if _stream_cache.has(canonical):
		return _stream_cache[canonical]
	
	var stream: AudioStream = _load_stream_from_assets(String(canonical))
	if stream == null:
		# Fallback synthetic tone
		stream = _create_fallback_stream()
	
	_stream_cache[canonical] = stream
	return stream


func _load_stream_from_assets(file_base: String) -> AudioStream:
	var tres_path: String = "res://assets/audio/%s.tres" % file_base
	if ResourceLoader.exists(tres_path):
		var res: Resource = ResourceLoader.load(tres_path)
		if res is AudioStream:
			return res
	
	var wav_path: String = "res://assets/audio/%s.wav" % file_base
	if ResourceLoader.exists(wav_path):
		var res: Resource = ResourceLoader.load(wav_path)
		if res is AudioStream:
			return res
		
		# In headless mode without editor import, parse WAV directly from disk
		var stream: AudioStreamWAV = _load_wav_from_disk(wav_path)
		if stream != null:
			return stream
	
	return null


## Direct RIFF WAV binary reader for standalone headless runtime
func _load_wav_from_disk(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	
	var magic := f.get_buffer(4).get_string_from_ascii()
	if magic != "RIFF":
		f.close()
		return null
	
	var _chunk_size: int = f.get_32()
	var format := f.get_buffer(4).get_string_from_ascii()
	if format != "WAVE":
		f.close()
		return null
	
	var stream := AudioStreamWAV.new()
	var num_channels: int = 1
	var sample_rate: int = 44100
	var bits_per_sample: int = 16
	
	while f.get_position() < f.get_length():
		if f.get_position() + 8 > f.get_length():
			break
		var subchunk_id := f.get_buffer(4).get_string_from_ascii()
		var subchunk_size: int = f.get_32()
		var next_pos: int = f.get_position() + subchunk_size
		
		if subchunk_id == "fmt ":
			var _audio_format: int = f.get_16()
			num_channels = f.get_16()
			sample_rate = f.get_32()
			var _byte_rate: int = f.get_32()
			var _block_align: int = f.get_16()
			bits_per_sample = f.get_16()
			f.seek(next_pos)
		elif subchunk_id == "data":
			var data: PackedByteArray = f.get_buffer(subchunk_size)
			stream.data = data
			f.seek(next_pos)
		else:
			f.seek(next_pos)
	
	f.close()
	
	stream.stereo = (num_channels == 2)
	stream.mix_rate = sample_rate
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	return stream


func _create_fallback_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	var samples: int = 4410 # 0.1s
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t: float = float(i) / 44100.0
		var sample: float = sin(t * 440.0 * TAU) * exp(-t / 0.05) * 0.3
		data.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = data
	return stream


# ==============================================================================
# POOL MANAGEMENT & POLYPHONY STATE
# ==============================================================================

## Returns number of currently active 3D voices playing the given sound ID
func get_active_voice_count(sound_id: StringName) -> int:
	var count: int = 0
	for i in range(_pool_3d.size()):
		if _pool_3d_sound_id[i] == sound_id and _is_player_3d_active(i):
			count += 1
	return count


func _is_player_3d_active(idx: int) -> bool:
	if _pool_3d_sound_id[idx] == &"":
		return false
	
	# Hardware check if running in graphics/audio mode
	if not is_headless and _pool_3d[idx].is_inside_tree() and _pool_3d[idx].playing:
		return true
	
	# Simulated playback state for headless and consistency
	var now: float = Time.get_ticks_msec() / 1000.0
	if (now - _pool_3d_start_time[idx]) < _pool_3d_duration[idx]:
		return true
	
	# Playback concluded
	_pool_3d_sound_id[idx] = &""
	return false


func _acquire_player_3d() -> int:
	# 1. Search for an inactive player
	for i in range(_pool_3d.size()):
		if not _is_player_3d_active(i):
			return i
	
	# 2. All 24 players active: voice steal the oldest playing voice
	var oldest_idx: int = 0
	var oldest_time: float = _pool_3d_start_time[0]
	for i in range(1, _pool_3d.size()):
		if _pool_3d_start_time[i] < oldest_time:
			oldest_time = _pool_3d_start_time[i]
			oldest_idx = i
	
	return oldest_idx


func _acquire_player_2d() -> int:
	for i in range(_pool_2d.size()):
		if not _is_player_2d_active(i):
			return i
	
	var oldest_idx: int = 0
	var oldest_time: float = _pool_2d_start_time[0]
	for i in range(1, _pool_2d.size()):
		if _pool_2d_start_time[i] < oldest_time:
			oldest_time = _pool_2d_start_time[i]
			oldest_idx = i
	
	return oldest_idx


func _is_player_2d_active(idx: int) -> bool:
	if _pool_2d_sound_id[idx] == &"":
		return false
	
	if not is_headless and _pool_2d[idx].is_inside_tree() and _pool_2d[idx].playing:
		return true
	
	var now: float = Time.get_ticks_msec() / 1000.0
	if (now - _pool_2d_start_time[idx]) < _pool_2d_duration[idx]:
		return true
	
	_pool_2d_sound_id[idx] = &""
	return false
