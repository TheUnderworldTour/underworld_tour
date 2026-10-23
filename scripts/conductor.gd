extends AudioStreamPlayer

## Emitted each time a new beat is reached while the song plays.
## `position` is the current beat index, including any count-in beats.
signal beat(position: int)

## Emitted alongside [signal beat] each time the measure counter advances.
## `position` is the current measure number within the song.
signal measure(position: int)

## Tempo of the song in beats per minute.
@export var bpm := 100

## Number of measures per repetition of the song's rhythm pattern.
@export var measures := 4

## Playback position of the song in seconds, corrected for audio latency.
var song_position: float = 0.0

## Current beat index derived from `song_position`, plus count-in beats.
var song_position_in_beats: int = 1

## Duration of a single beat in seconds, derived from `bpm`.
var sec_per_beat: float = 60.0 / bpm

## Last beat index that was reported via signals, used to detect new beats.
var last_reported_beat: int = 0

## Number of count-in beats played by the timer before the audio starts.
var beats_before_start: int = 0

## Enables the wall-clock fallback after the count-in when no audio stream
## is assigned, so gameplay still works while testing without audio.
var _use_fallback_clock := false

## Current measure number, cycles from 1 through `measures`.
var measure_count: int = 1

@onready var start_timer: Timer = $StartTimer


func _ready() -> void:
	# Re-derive beat length here so exported `bpm` changes made in the
	# editor are respected, and wire up the count-in timer signal.
	sec_per_beat = 60.0 / bpm
	start_timer.timeout.connect(_on_start_timer_timeout)


func _physics_process(_delta: float) -> void:
	# While playing, track the song's playback position. Combining the
	# reported playback position with the time since the last mix and
	# subtracting output latency gives a more accurate clock than
	# `get_playback_position()` alone.
	if playing and stream != null:
		song_position = get_playback_position() + AudioServer.get_time_since_last_mix()
		song_position -= AudioServer.get_output_latency()
	elif _use_fallback_clock:
		song_position += _delta
	else:
		return
	song_position_in_beats = int(floor(song_position / sec_per_beat)) + beats_before_start
	_report_beat()


func _report_beat() -> void:
	# Only emit once per new beat, so repeated physics ticks don't spam signals.
	if last_reported_beat < song_position_in_beats:
		# Wrap the measure counter so it stays within 1..`measures`.
		if measure_count > measures:
			measure_count = 1
		beat.emit(song_position_in_beats)
		measure.emit(measure_count)
		last_reported_beat = song_position_in_beats
		measure_count += 1


func play_with_beat_offset(num: int) -> void:
	# Schedule `num` count-in beats before the audio starts, ticking the
	# beat signals once per beat via the timer.
	beats_before_start = num
	start_timer.wait_time = sec_per_beat
	start_timer.start()


func closest_beat(nth: int) -> Vector2:
	# Returns (beat_index, time_off_beat): the nearest `nth` beat (e.g.
	# `nth = 2` snaps to every second beat / half notes) and how many
	# seconds the player is away from it. Useful for quantizing input.
	var clamped_position: float = maxf(song_position, 0.0)
	var closest: int = int(round(clamped_position / sec_per_beat / nth) * nth)
	var time_off_beat: float = absf(closest * sec_per_beat - clamped_position)
	return Vector2(closest, time_off_beat)


func play_from_beat(beat_number: int, offset: int) -> void:
	# Start playback immediately at the given beat and set up bookkeeping:
	# `offset` becomes the count-in beat count and the measure counter is
	# computed so measure signals stay in sync with the starting position.
	play()
	seek(beat_number * sec_per_beat)
	beats_before_start = offset
	measure_count = (beat_number % measures) + 1


func _on_start_timer_timeout() -> void:
	# Runs once per count-in beat before the audio stream starts.
	song_position_in_beats += 1
	if song_position_in_beats < beats_before_start - 1:
		# Still counting in: keep ticking once per beat.
		start_timer.start()
	elif song_position_in_beats == beats_before_start - 1:
		# Final count-in beat: shorten the wait so the audio starts exactly
		# on the next beat, accounting for the time until the next mix and
		# the audio output latency.
		start_timer.wait_time = start_timer.wait_time - (AudioServer.get_time_to_next_mix()
				+ AudioServer.get_output_latency())
		start_timer.start()
	else:
		# Count-in finished: start the actual playback and stop the timer.
		play()
		start_timer.stop()
		_use_fallback_clock = stream == null
	_report_beat()
