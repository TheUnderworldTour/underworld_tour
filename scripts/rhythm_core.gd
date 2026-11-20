class_name RhythmCore
extends Node2D

signal note_judged(event: RhythmJudgment)
signal extra_note_played(lane: int, song_time_sec: float)
signal chart_completed

const NOTE_SCENE := preload("res://scenes/note.tscn")
const FLAME_SCENE := preload("res://scenes/flame_particles.tscn")
const HIT_ACTIONS: Dictionary[String, int] = {
	"hit_up": 0,
	"hit_right": 1,
	"hit_down": 2,
	"hit_left": 3,
}

@export var start_delay_beats := 4
@export_file("*.json") var chart_path: String

@onready var _conductor: AudioStreamPlayer = $Conductor
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _combo_label: Label = $HUD/ComboLabel
@onready var _judgement_label: Label = $HUD/JudgementLabel
@onready var _receptors: Array[Dictionary] = [
	{"direction": 0, "position": Vector2(500, 550)},
	{"direction": 1, "position": Vector2(800, 550)},
	{"direction": 2, "position": Vector2(650, 550)},
	{"direction": 3, "position": Vector2(350, 550)},
]

@onready var character_portrait: CharacterPortrait = $GuitaristPortrait

var _judge: Judge
var _next_note: int = 0
var _completed_notes: int = 0
var _chart_stopped: bool = false
var _notes: Array[Note] = []
var _chart: Array[Vector3i] = []
var _judgement_tween: Tween
var _judgement_flames: Array[CPUParticles2D] = []
var _last_hellish_frame := -1


func _ready() -> void:
	if not _load_chart():
		stop_chart()
		return
	_chart.sort_custom(func(first: Vector3i, second: Vector3i) -> bool: return first.x < second.x)
	_judge = Judge.new()
	add_child(_judge)
	_judge.judged.connect(_on_judge_judged)
	_conductor.beat.connect(_on_conductor_beat)
	_conductor.play_with_beat_offset(start_delay_beats)


func _unhandled_input(event: InputEvent) -> void:
	if _chart_stopped:
		return
	var direction: int = -1
	var released := false
	for action: String in HIT_ACTIONS:
		if event.is_action_pressed(action) or event.is_action_released(action):
			direction = HIT_ACTIONS[action]
			released = event.is_action_released(action)
			break
	if direction == -1:
		return
	if released:
		var holding_note: Note = _find_holding_note(direction)
		if holding_note != null:
			holding_note.release_hold()
			_prune_despawned_notes()
		return
	var best: Note = null
	var best_accuracy: float = INF
	for note: Note in _notes:
		if not is_instance_valid(note) or note.lane != direction or not note.can_hit():
			continue
		var accuracy: float = note.get_accuracy()
		if accuracy < best_accuracy:
			best = note
			best_accuracy = accuracy
	if best != null:
		best.hit_note()
	elif _find_holding_note(direction) != null:
		pass
	elif _conductor.is_song_running():
		extra_note_played.emit(direction, _conductor.song_position)


func _find_holding_note(lane: int) -> Note:
	for note: Note in _notes:
		if is_instance_valid(note) and note.lane == lane and note.is_holding():
			return note
	return null


func stop_chart() -> void:
	_chart_stopped = true
	_conductor.stop()
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)


func _load_chart() -> bool:
	var file := FileAccess.open(chart_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open chart '%s': %s" % [chart_path, error_string(FileAccess.get_open_error())])
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Invalid JSON in chart '%s' at line %d: %s" % [
			chart_path, json.get_error_line(), json.get_error_message()
		])
		return false
	var rows: Variant = json.data
	if not (rows is Array) or rows.is_empty():
		push_error("Chart '%s' must contain a non-empty array of notes." % chart_path)
		return false
	var entries: Array[Vector3i] = []
	for index in range(rows.size()):
		var row: Variant = rows[index]
		if not (row is Array) or row.size() != 3 \
				or not _is_chart_integer(row[0], 0, 2147483647) \
				or not _is_chart_integer(row[1], 0, _receptors.size() - 1) \
				or not _is_chart_integer(row[2], 1, 2147483647):
			push_error("Invalid note %d in chart '%s': expected [beat, lane, length]." % [
				index + 1, chart_path
			])
			return false
		entries.append(Vector3i(int(row[0]), int(row[1]), int(row[2])))
	_chart = entries
	return true


func _is_chart_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return number >= minimum and number <= maximum and number == floorf(number)


func _on_conductor_beat(position: int) -> void:
	if _chart_stopped:
		return
	while _next_note < _chart.size() and _chart[_next_note].x - _conductor.beats_before_start <= position:
		_spawn_note(_chart[_next_note])
		_next_note += 1


func _spawn_note(entry: Vector3i) -> void:
	var note: Note = NOTE_SCENE.instantiate()
	note.chart_note_id = _next_note
	note.chart_coords = entry
	note.target_position = _receptors[entry.y]["position"]
	note.hit.connect(_on_note_hit.bind(note))
	note.missed.connect(_on_note_missed.bind(note))
	note.hold_completed.connect(_on_note_hold_completed.bind(note))
	note.hold_broken.connect(_on_note_hold_broken.bind(note))
	$Playfield.add_child(note)
	_notes.append(note)


func _on_note_hit(accuracy: float, note: Note) -> void:
	var phase := Judge.Phase.HOLD_START if note.length_beats > 1 else Judge.Phase.TAP
	_judge.judge_note_hit(note, accuracy, phase)
	character_portrait.play_good()


func _on_note_missed(note: Note) -> void:
	_judge.judge_note_miss(note)
	_prune_despawned_notes()
	character_portrait.play_bad()


func _on_note_hold_completed(release_accuracy: float, note: Note) -> void:
	_judge.judge_hold_completed(note, release_accuracy)
	_prune_despawned_notes()


func _on_note_hold_broken(note: Note) -> void:
	_judge.judge_hold_broken(note)
	_prune_despawned_notes()


func _prune_despawned_notes() -> void:
	for i in range(_notes.size() - 1, -1, -1):
		if not is_instance_valid(_notes[i]):
			_notes.remove_at(i)


func _on_judge_judged(
	judgement: Judge.Judgement, accuracy: float, time_error: float, note: Note, phase: Judge.Phase
) -> void:
	if _chart_stopped:
		return
	_score_label.text = "Score: %d" % _judge.score
	_combo_label.text = "Combo: %d" % _judge.combo
	_show_judgement(judgement)

	var event: RhythmJudgment = RhythmJudgment.new()
	event.note_id = note.chart_note_id
	event.lane = note.lane
	event.target_beat = note.target_beat
	event.song_time_sec = _conductor.song_position
	event.tier = judgement
	event.phase = phase
	event.accuracy_sec = accuracy
	event.time_error_sec = time_error if is_finite(accuracy) else INF
	event.has_input_timing = is_finite(accuracy)
	note_judged.emit(event)
	if phase != Judge.Phase.HOLD_START:
		_completed_notes += 1
		if _completed_notes == _chart.size():
			chart_completed.emit()


func _show_judgement(judgement: Judge.Judgement) -> void:
	var hellish := judgement == Judge.Judgement.HELLISH
	var frame := Engine.get_process_frames()
	if hellish:
		_last_hellish_frame = frame
	elif frame == _last_hellish_frame:
		return
	if _judgement_tween != null:
		_judgement_tween.kill()
	_judgement_label.text = Judge.Judgement.keys()[judgement]
	_judgement_label.add_theme_color_override("font_color", Judge.TIER_COLORS[judgement])
	_judgement_label.modulate.a = 1.0
	_judgement_label.scale = Vector2.ONE * (1.85 if hellish else 1.2)
	_set_judgement_fire(hellish)

	var settled_scale := Vector2.ONE * (1.45 if hellish else 1.0)
	_judgement_tween = _judgement_label.create_tween().set_parallel(true)
	_judgement_tween.tween_property(
		_judgement_label, "scale", settled_scale, 0.2 if hellish else 0.08
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_judgement_tween.tween_property(_judgement_label, "modulate:a", 0.0, 0.4).set_delay(
		0.4 if hellish else 0.15
	)
	_judgement_tween.chain().tween_callback(_set_judgement_fire.bind(false))


func _set_judgement_fire(active: bool) -> void:
	if active and _judgement_flames.is_empty():
		_create_judgement_flames()
	for flame: CPUParticles2D in _judgement_flames:
		if active:
			flame.show()
			flame.restart()
		else:
			flame.emitting = false
			flame.hide()


func _create_judgement_flames() -> void:
	var text := _judgement_label.text
	var font := _judgement_label.get_theme_font("font")
	var font_size := _judgement_label.get_theme_font_size("font_size")
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var left := (_judgement_label.size.x - text_width) * 0.5
	var previous_end := 0.0
	for index in range(text.length()):
		var letter_end := font.get_string_size(
			text.left(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x
		var flame := FLAME_SCENE.instantiate() as CPUParticles2D
		flame.position = Vector2(left + (previous_end + letter_end) * 0.5, _judgement_label.size.y * 0.44)
		flame.emission_rect_extents.x = (letter_end - previous_end) * 0.24
		flame.amount = 12
		flame.local_coords = true
		flame.show_behind_parent = true
		_judgement_label.add_child(flame)
		_judgement_flames.append(flame)
		previous_end = letter_end
