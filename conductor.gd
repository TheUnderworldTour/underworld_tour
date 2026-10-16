extends AudioStreamPlayer

signal beat(position: int)
signal measure(position: int)

@export var bpm := 100
@export var measures := 4

var song_position: float = 0.0
var song_position_in_beats: int = 1
var sec_per_beat: float = 60.0 / bpm
var last_reported_beat: int = 0
var beats_before_start: int = 0
var measure_count: int = 1

@onready var start_timer: Timer = $StartTimer


func _ready() -> void:
	sec_per_beat = 60.0 / bpm
	start_timer.timeout.connect(_on_start_timer_timeout)


func _physics_process(_delta: float) -> void:
	if playing:
		song_position = get_playback_position() + AudioServer.get_time_since_last_mix()
		song_position -= AudioServer.get_output_latency()
		song_position_in_beats = int(floor(song_position / sec_per_beat)) + beats_before_start
		_report_beat()


func _report_beat() -> void:
	if last_reported_beat < song_position_in_beats:
		if measure_count > measures:
			measure_count = 1
		beat.emit(song_position_in_beats)
		measure.emit(measure_count)
		last_reported_beat = song_position_in_beats
		measure_count += 1


func play_with_beat_offset(num: int) -> void:
	beats_before_start = num
	start_timer.wait_time = sec_per_beat
	start_timer.start()


func closest_beat(nth: int) -> Vector2:
	var clamped_position: float = maxf(song_position, 0.0)
	var closest: int = int(round(clamped_position / sec_per_beat / nth) * nth)
	var time_off_beat: float = absf(closest * sec_per_beat - clamped_position)
	return Vector2(closest, time_off_beat)


func play_from_beat(beat_number: int, offset: int) -> void:
	play()
	seek(beat_number * sec_per_beat)
	beats_before_start = offset
	measure_count = (beat_number % measures) + 1


func _on_start_timer_timeout() -> void:
	song_position_in_beats += 1
	if song_position_in_beats < beats_before_start - 1:
		start_timer.start()
	elif song_position_in_beats == beats_before_start - 1:
		start_timer.wait_time = start_timer.wait_time - (AudioServer.get_time_to_next_mix()
				+ AudioServer.get_output_latency())
		start_timer.start()
	else:
		play()
		start_timer.stop()
	_report_beat()
